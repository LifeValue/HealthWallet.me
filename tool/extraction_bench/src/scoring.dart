/// Per-document scoring: Hungarian matching of predicted to gold resources
/// within each resource type, then field-level TP/FP/FN.
///
/// Accounting, per scored field of a matched pair:
/// - both null (absent or empty): TP 1, the correct-null credit;
/// - gold null, predicted value: FP 1, a hallucinated field;
/// - gold value, predicted null: FN 1, an omitted field;
/// - both present with score s: TP s, FP 1−s, FN 1−s.
/// An unmatched gold record counts FN (omitted) per non-null gold field; an
/// unmatched predicted record counts FP (hallucinated) per non-null predicted
/// field. A pair the matching proposes but that agrees on no field (no field
/// present on both sides with a score above 0) is treated as unmatched.
library;

import 'fields.dart';
import 'hungarian.dart';

class FieldCounts {
  double tp = 0;
  double fp = 0;
  double fn = 0;

  /// FN from gold values with no predicted value (field or record omitted).
  double omitted = 0;

  /// FP from predicted values with no gold value (field or record invented).
  double hallucinated = 0;
  double goldNonNull = 0;
  double predNonNull = 0;

  void add(FieldCounts o) {
    tp += o.tp;
    fp += o.fp;
    fn += o.fn;
    omitted += o.omitted;
    hallucinated += o.hallucinated;
    goldNonNull += o.goldNonNull;
    predNonNull += o.predNonNull;
  }

  /// TP / (TP + FP); with nothing predicted, 1 if nothing was missed else 0.
  double get precision => tp + fp == 0 ? (fn == 0 ? 1 : 0) : tp / (tp + fp);

  /// TP / (TP + FN); with nothing to find, 1.
  double get recall => tp + fn == 0 ? 1 : tp / (tp + fn);

  /// 2TP / (2TP + FP + FN); 1 when there is nothing to score.
  double get f1 {
    final d = 2 * tp + fp + fn;
    return d == 0 ? 1 : 2 * tp / d;
  }

  double get omissionRate => goldNonNull == 0 ? 0 : omitted / goldNonNull;
  double get hallucinationRate => predNonNull == 0 ? 0 : hallucinated / predNonNull;

  Map<String, dynamic> toJson() => {
        'tp': tp,
        'fp': fp,
        'fn': fn,
        'omitted': omitted,
        'hallucinated': hallucinated,
        'goldNonNull': goldNonNull,
        'predNonNull': predNonNull,
      };
}

class DocScore {
  DocScore(this.total, this.byType);
  final FieldCounts total;
  final Map<String, FieldCounts> byType;
}

class _Extracted {
  _Extracted(this.values);
  final List<Object?> values;
}

Map<String, List<_Extracted>> _group(List<Map<String, dynamic>> resources) {
  final out = <String, List<_Extracted>>{};
  for (final r in resources) {
    final type = r['resourceType'];
    final specs = fieldSpecs[type];
    if (type is! String || specs == null) continue;
    out.putIfAbsent(type, () => []).add(_Extracted([for (final s in specs) extractField(r, s)]));
  }
  return out;
}

const _nonAgreeingCost = 1e6;

double _fieldScore(FieldKind kind, Object? g, Object? p) {
  if (g == null && p == null) return 1;
  if (g == null || p == null) return 0;
  return compareField(kind, g, p);
}

void _countUnmatched(FieldCounts c, _Extracted e, {required bool gold}) {
  for (final v in e.values) {
    if (v == null) continue;
    if (gold) {
      c.fn += 1;
      c.omitted += 1;
      c.goldNonNull += 1;
    } else {
      c.fp += 1;
      c.hallucinated += 1;
      c.predNonNull += 1;
    }
  }
}

/// Scores [pred] against [gold] (lists of FHIR resource JSON). Resource types
/// without a field spec are ignored.
DocScore scoreResources(
  List<Map<String, dynamic>> gold,
  List<Map<String, dynamic>> pred,
) {
  final g = _group(gold);
  final p = _group(pred);
  final types = {...g.keys, ...p.keys}.toList()..sort();
  final byType = <String, FieldCounts>{};
  final total = FieldCounts();

  for (final type in types) {
    final specs = fieldSpecs[type]!;
    final gs = g[type] ?? const <_Extracted>[];
    final ps = p[type] ?? const <_Extracted>[];
    final counts = FieldCounts();
    final goldMatched = List<bool>.filled(gs.length, false);
    final predMatched = List<bool>.filled(ps.length, false);

    if (gs.isNotEmpty && ps.isNotEmpty) {
      final scores = [
        for (final ge in gs)
          [
            for (final pe in ps)
              [
                for (var k = 0; k < specs.length; k++)
                  _fieldScore(specs[k].kind, ge.values[k], pe.values[k]),
              ],
          ],
      ];
      bool agrees(int i, int j) {
        for (var k = 0; k < specs.length; k++) {
          if (gs[i].values[k] != null && ps[j].values[k] != null && scores[i][j][k] > 0) return true;
        }
        return false;
      }

      // A pair that agrees on no field costs more than any agreeing pairing,
      // so a cheap all-null pair cannot take an agreeing pair's place.
      final cost = [
        for (var i = 0; i < gs.length; i++)
          [
            for (var j = 0; j < ps.length; j++)
              agrees(i, j) ? scores[i][j].fold<double>(0, (a, s) => a + (1 - s)) : _nonAgreeingCost,
          ],
      ];
      for (final (i, j) in hungarian(cost)) {
        final ge = gs[i];
        final pe = ps[j];
        if (!agrees(i, j)) continue;
        goldMatched[i] = true;
        predMatched[j] = true;
        for (var k = 0; k < specs.length; k++) {
          final gv = ge.values[k];
          final pv = pe.values[k];
          if (gv == null && pv == null) {
            counts.tp += 1;
          } else if (gv == null) {
            counts
              ..fp += 1
              ..hallucinated += 1
              ..predNonNull += 1;
          } else if (pv == null) {
            counts
              ..fn += 1
              ..omitted += 1
              ..goldNonNull += 1;
          } else {
            final s = scores[i][j][k];
            counts
              ..tp += s
              ..fp += 1 - s
              ..fn += 1 - s
              ..goldNonNull += 1
              ..predNonNull += 1;
          }
        }
      }
    }
    for (var i = 0; i < gs.length; i++) {
      if (!goldMatched[i]) _countUnmatched(counts, gs[i], gold: true);
    }
    for (var j = 0; j < ps.length; j++) {
      if (!predMatched[j]) _countUnmatched(counts, ps[j], gold: false);
    }
    byType[type] = counts;
    total.add(counts);
  }
  return DocScore(total, byType);
}
