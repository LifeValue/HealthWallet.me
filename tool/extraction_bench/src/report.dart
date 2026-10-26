/// Scoring a run against a dataset and writing `report.json` / `report.md`,
/// and the paired comparison of two runs.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'bootstrap.dart';
import 'dataset.dart';
import 'scoring.dart';

const strataKeys = ['split', 'lang', 'family', 'degradation'];

enum DocStatus { ok, error, missing }

class ScoredDoc {
  ScoredDoc(this.doc, this.record, this.status, this.score);
  final DatasetDoc doc;
  final PredictionRecord? record;
  final DocStatus status;
  final DocScore score;

  String stratum(String key) => switch (key) {
        'split' => doc.meta.split,
        'lang' => doc.meta.lang,
        'family' => doc.meta.family,
        'degradation' => doc.meta.degradation,
        _ => throw ArgumentError.value(key, 'key'),
      };
}

/// Scores every dataset document. A document without a record, or whose
/// record carries an error, is scored with no predictions.
List<ScoredDoc> scoreRun(List<DatasetDoc> dataset, Map<String, PredictionRecord> predictions) => [
      for (final doc in dataset)
        () {
          final record = predictions[doc.docId];
          final status = record == null
              ? DocStatus.missing
              : record.error != null
                  ? DocStatus.error
                  : DocStatus.ok;
          final pred = status == DocStatus.ok ? record!.predictedResources : const <Map<String, dynamic>>[];
          return ScoredDoc(doc, record, status, scoreResources(doc.goldResources, pred));
        }(),
    ];

/// Nearest-rank quantile; null for an empty list.
double? quantile(List<double> values, double q) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  final rank = (q * sorted.length).ceil().clamp(1, sorted.length);
  return sorted[rank - 1];
}

Map<String, dynamic> _distribution(List<double> values) => {
      'n': values.length,
      'median': quantile(values, 0.5),
      'p90': quantile(values, 0.9),
    };

Map<String, dynamic> _countStats(
  List<FieldCounts> counts, {
  required int seed,
  required int samples,
  required String label,
}) {
  final ci = bootstrapMeans({
    'f1': [for (final c in counts) c.f1],
    'precision': [for (final c in counts) c.precision],
    'recall': [for (final c in counts) c.recall],
    'omissionRate': [for (final c in counts) c.omissionRate],
    'hallucinationRate': [for (final c in counts) c.hallucinationRate],
  }, samples: samples, seed: seed, label: label);
  return {
    'docs': counts.length,
    'f1': ci['f1']!.toJson(),
    'precision': ci['precision']!.toJson(),
    'recall': ci['recall']!.toJson(),
    'omissionRate': ci['omissionRate']!.toJson(),
    'hallucinationRate': ci['hallucinationRate']!.toJson(),
  };
}

Map<String, dynamic> _groupStats(List<ScoredDoc> docs, {required int seed, required int samples, required String label}) {
  final generations = [for (final d in docs) ...?d.record?.generations];
  final valid = generations.where((g) => g.strictJsonValid).length;
  return {
    ..._countStats([for (final d in docs) d.score.total], seed: seed, samples: samples, label: label),
    'errors': docs.where((d) => d.status == DocStatus.error).length,
    'missing': docs.where((d) => d.status == DocStatus.missing).length,
    'generations': generations.length,
    'strictJsonValidRate': generations.isEmpty ? null : valid / generations.length,
  };
}

Map<String, List<ScoredDoc>> _strata(List<ScoredDoc> docs, String key) {
  final out = <String, List<ScoredDoc>>{};
  for (final d in docs) {
    out.putIfAbsent(d.stratum(key), () => []).add(d);
  }
  return Map.fromEntries(out.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
}

/// The report as JSON-ready data.
Map<String, dynamic> buildReport(
  List<ScoredDoc> scored, {
  required int seed,
  required int samples,
  required String datasetPath,
  required String predictionsPath,
  List<String> unknownDocIds = const [],
  int? excludedMissing,
}) {
  final records = [for (final d in scored) ?d.record];
  final generations = [for (final r in records) ...r.generations];
  List<double> collect(double? Function(GenerationRecord) f, [String? mode]) =>
      [for (final g in generations) if (mode == null || g.mode == mode) ?f(g)];
  final modes = {for (final g in generations) ?g.mode}.toList()..sort();

  final types = <String>{for (final d in scored) ...d.score.byType.keys}.toList()..sort();
  return {
    'dataset': datasetPath,
    'predictions': predictionsPath,
    'bootstrap': {'samples': samples, 'seed': seed, 'level': 0.95, 'method': 'percentile, documents resampled'},
    'runs': {
      'runIds': {for (final r in records) r.runId}.toList()..sort(),
      'models': {for (final r in records) r.model}.toList()..sort(),
      'platforms': {for (final r in records) r.platform}.toList()..sort(),
      'gpuLayers': {for (final r in records) r.gpuLayers?.toString() ?? 'auto'}.toList()..sort(),
    },
    'counts': {
      'documents': scored.length,
      'ok': scored.where((d) => d.status == DocStatus.ok).length,
      'errors': scored.where((d) => d.status == DocStatus.error).length,
      'missing': scored.where((d) => d.status == DocStatus.missing).length,
      'predictionsNotInDataset': unknownDocIds,
      'excludedMissing': ?excludedMissing,
    },
    'overall': _groupStats(scored, seed: seed, samples: samples, label: 'overall'),
    'strata': {
      for (final key in strataKeys)
        key: {
          for (final e in _strata(scored, key).entries)
            e.key: _groupStats(e.value, seed: seed, samples: samples, label: '$key=${e.key}'),
        },
    },
    'resourceTypes': {
      for (final t in types)
        t: _countStats(
          [for (final d in scored) ?d.score.byType[t]],
          seed: seed,
          samples: samples,
          label: 'type=$t',
        ),
    },
    'latency': {
      'timeToFirstTokenMs': _distribution(collect((g) => g.timeToFirstTokenMs)),
      'promptEvalMs': _distribution(collect((g) => g.promptEvalMs)),
      'imageEncodeMs': _distribution(collect((g) => g.imageEncodeMs)),
      // A vision call's time to first token includes the image encode, so
      // the modes are also reported apart.
      'byMode': {
        for (final m in modes)
          m: {
            'generations': generations.where((g) => g.mode == m).length,
            'timeToFirstTokenMs': _distribution(collect((g) => g.timeToFirstTokenMs, m)),
            'promptEvalMs': _distribution(collect((g) => g.promptEvalMs, m)),
            'imageEncodeMs': _distribution(collect((g) => g.imageEncodeMs, m)),
          },
      },
      'wallMsPerDoc': _distribution([for (final r in records) ?r.wallMs]),
    },
    'peakRssBytes': {
      ..._distribution([for (final r in records) ?r.peakRssBytes?.toDouble()]),
      'max': records.map((r) => r.peakRssBytes).whereType<int>().fold<int?>(null, (a, b) => a == null || b > a ? b : a),
    },
    'documents': [
      for (final d in scored)
        {
          'docId': d.doc.docId,
          for (final k in strataKeys) k: d.stratum(k),
          'status': d.status.name,
          'f1': d.score.total.f1,
          'precision': d.score.total.precision,
          'recall': d.score.total.recall,
          'omissionRate': d.score.total.omissionRate,
          'hallucinationRate': d.score.total.hallucinationRate,
          'counts': d.score.total.toJson(),
          if (d.record?.error != null) 'error': d.record!.error,
        },
    ],
  };
}

String _f(Object? v, {int digits = 3}) => v is num ? v.toStringAsFixed(digits) : 'n/a';

String _ci(Object? ci) {
  if (ci is! Map) return 'n/a';
  return '${_f(ci['mean'])} [${_f(ci['lo'])}, ${_f(ci['hi'])}]';
}

String _pct(Object? v) => v is num ? '${(v * 100).toStringAsFixed(1)}%' : 'n/a';

String _pctCi(Object? ci) {
  if (ci is! Map) return 'n/a';
  return '${_pct(ci['mean'])} [${_pct(ci['lo'])}, ${_pct(ci['hi'])}]';
}

const _groupHeader = '| Docs | F1 | Precision | Recall | Omission | Hallucination | Strict JSON | Errors | Missing |';
const _groupRule = '|---:|---|---|---|---:|---:|---:|---:|---:|';

String _groupCells(Map g) =>
    '| ${g['docs']} | ${_ci(g['f1'])} | ${_ci(g['precision'])} | ${_ci(g['recall'])} | '
    '${_pctCi(g['omissionRate'])} | ${_pctCi(g['hallucinationRate'])} | ${_pct(g['strictJsonValidRate'])} | '
    '${g['errors']} | ${g['missing']} |';

String renderReportMarkdown(Map<String, dynamic> r) {
  final b = StringBuffer();
  final counts = r['counts'] as Map;
  final runs = r['runs'] as Map;
  final boot = r['bootstrap'] as Map;
  b
    ..writeln('# Extraction benchmark report')
    ..writeln()
    ..writeln('- Dataset: `${r['dataset']}`')
    ..writeln('- Predictions: `${r['predictions']}`')
    ..writeln('- Runs: ${(runs['runIds'] as List).join(', ')}; models: ${(runs['models'] as List).join(', ')}; '
        'platforms: ${(runs['platforms'] as List).join(', ')}; GPU layers: ${(runs['gpuLayers'] as List).join(', ')}')
    ..writeln('- Documents: ${counts['documents']} (scored ${counts['ok']}, pipeline errors ${counts['errors']}, '
        'missing ${counts['missing']}); errors and missing documents are scored with no predictions'
        '${counts['excludedMissing'] == null ? '' : '; ${counts['excludedMissing']} dataset documents without a '
            'record are left out (--only-predicted)'}')
    ..writeln('- F1, precision and recall are per-document micro averages, then the mean over documents, with 95% '
        'percentile bootstrap CIs over documents (${boot['samples']} resamples, seed ${boot['seed']})');
  final unknown = counts['predictionsNotInDataset'] as List;
  if (unknown.isNotEmpty) b.writeln('- Predictions for documents not in the dataset (ignored): ${unknown.join(', ')}');
  b
    ..writeln()
    ..writeln('## Overall')
    ..writeln()
    ..writeln(_groupHeader)
    ..writeln(_groupRule)
    ..writeln(_groupCells(r['overall'] as Map))
    ..writeln()
    ..writeln('## By stratum');
  final strata = r['strata'] as Map;
  for (final key in strataKeys) {
    b
      ..writeln()
      ..writeln('### $key')
      ..writeln()
      ..writeln('| $key |${_groupHeader.substring(1)}')
      ..writeln('|---$_groupRule');
    for (final e in (strata[key] as Map).entries) {
      b.writeln('| ${e.key} ${_groupCells(e.value as Map)}');
    }
  }
  b
    ..writeln()
    ..writeln('## By resource type')
    ..writeln()
    ..writeln('| Type | Docs | F1 | Precision | Recall | Omission | Hallucination |')
    ..writeln('|---|---:|---|---|---|---:|---:|');
  for (final e in (r['resourceTypes'] as Map).entries) {
    final g = e.value as Map;
    b.writeln('| ${e.key} | ${g['docs']} | ${_ci(g['f1'])} | ${_ci(g['precision'])} | ${_ci(g['recall'])} | '
        '${_pctCi(g['omissionRate'])} | ${_pctCi(g['hallucinationRate'])} |');
  }
  final latency = r['latency'] as Map;
  final rss = r['peakRssBytes'] as Map;
  String mb(Object? v) => v is num ? (v / (1024 * 1024)).toStringAsFixed(0) : 'n/a';
  String row(String name, Map d) => '| $name | ${d['n']} | ${_f(d['median'], digits: 0)} | ${_f(d['p90'], digits: 0)} |';
  b
    ..writeln()
    ..writeln('## Latency and memory')
    ..writeln()
    ..writeln('| Metric | n | Median | p90 |')
    ..writeln('|---|---:|---:|---:|')
    ..writeln(row('Time to first token (ms, per generation)', latency['timeToFirstTokenMs'] as Map))
    ..writeln(row('Prompt eval (ms, per generation)', latency['promptEvalMs'] as Map))
    ..writeln(row('Image encode (ms, per generation, llama.cpp mtmd log)', latency['imageEncodeMs'] as Map));
  for (final e in (latency['byMode'] as Map).entries) {
    final m = e.value as Map;
    b
      ..writeln(row('${e.key}: time to first token (ms)', m['timeToFirstTokenMs'] as Map))
      ..writeln(row('${e.key}: prompt eval (ms)', m['promptEvalMs'] as Map))
      ..writeln(row('${e.key}: image encode (ms)', m['imageEncodeMs'] as Map));
  }
  b
    ..writeln(row('Wall time (ms, per document)', latency['wallMsPerDoc'] as Map))
    ..writeln('| Peak RSS (MB, per document; max ${mb(rss['max'])}) | ${rss['n']} | ${mb(rss['median'])} | ${mb(rss['p90'])} |')
    ..writeln()
    ..writeln('## Documents')
    ..writeln()
    ..writeln('| docId | lang | family | degradation | split | status | F1 | Precision | Recall |')
    ..writeln('|---|---|---|---|---|---|---:|---:|---:|');
  for (final d in (r['documents'] as List).cast<Map>()) {
    b.writeln('| ${d['docId']} | ${d['lang']} | ${d['family']} | ${d['degradation']} | ${d['split']} | '
        '${d['status']} | ${_f(d['f1'])} | ${_f(d['precision'])} | ${_f(d['recall'])} |');
  }
  return b.toString();
}

const _json = JsonEncoder.withIndent('  ');

/// Scores [predictionsPath] against [datasetPath] and writes `report.json` and
/// `report.md` into [outDir]. Returns the report.
Map<String, dynamic> runScore({
  required String datasetPath,
  required String predictionsPath,
  required String outDir,
  required int seed,
  int samples = 10000,
  bool onlyPredicted = false,
}) {
  final fullDataset = loadDataset(datasetPath);
  final predictions = loadPredictions(predictionsPath);
  final ids = {for (final d in fullDataset) d.docId};
  final unknown = predictions.keys.where((k) => !ids.contains(k)).toList()..sort();
  final dataset = onlyPredicted ? [for (final d in fullDataset) if (predictions.containsKey(d.docId)) d] : fullDataset;
  if (dataset.isEmpty) throw BenchInputException('No dataset document has a record in $predictionsPath');
  final report = buildReport(
    scoreRun(dataset, predictions),
    seed: seed,
    samples: samples,
    datasetPath: datasetPath,
    predictionsPath: predictionsPath,
    unknownDocIds: unknown,
    excludedMissing: onlyPredicted ? fullDataset.length - dataset.length : null,
  );
  Directory(outDir).createSync(recursive: true);
  File(p.join(outDir, 'report.json')).writeAsStringSync('${_json.convert(report)}\n');
  File(p.join(outDir, 'report.md')).writeAsStringSync(renderReportMarkdown(report));
  return report;
}

// ---------------------------------------------------------------------------
// Compare
// ---------------------------------------------------------------------------

Map<String, dynamic> buildComparison(
  List<ScoredDoc> a,
  List<ScoredDoc> b, {
  required int seed,
  required int samples,
  required String aPath,
  required String bPath,
}) {
  final bById = {for (final d in b) d.doc.docId: d};
  final pairs = <(ScoredDoc, ScoredDoc)>[
    for (final da in a)
      if (da.record != null && bById[da.doc.docId]?.record != null) (da, bById[da.doc.docId]!),
  ];
  final onlyA = [for (final d in a) if (d.record != null && bById[d.doc.docId]?.record == null) d.doc.docId];
  final onlyB = [
    for (final d in b)
      if (d.record != null && !a.any((x) => x.doc.docId == d.doc.docId && x.record != null)) d.doc.docId,
  ];

  Map<String, dynamic> diff(List<(ScoredDoc, ScoredDoc)> ps, String label) => pairedBootstrap(
        [for (final (x, _) in ps) x.score.total.f1],
        [for (final (_, y) in ps) y.score.total.f1],
        samples: samples,
        seed: seed,
        label: 'compare/$label',
      ).toJson();

  return {
    'a': aPath,
    'b': bPath,
    'metric': 'per-document F1, difference B - A',
    'bootstrap': {'samples': samples, 'seed': seed, 'level': 0.95, 'method': 'paired percentile, documents resampled'},
    'sharedDocs': pairs.length,
    'onlyInA': onlyA,
    'onlyInB': onlyB,
    'overall': diff(pairs, 'overall'),
    'strata': {
      for (final key in strataKeys)
        key: () {
          final groups = <String, List<(ScoredDoc, ScoredDoc)>>{};
          for (final pair in pairs) {
            groups.putIfAbsent(pair.$1.stratum(key), () => []).add(pair);
          }
          final keys = groups.keys.toList()..sort();
          return {for (final k in keys) k: diff(groups[k]!, '$key=$k')};
        }(),
    },
  };
}

String renderComparisonMarkdown(Map<String, dynamic> c) {
  final b = StringBuffer();
  final boot = c['bootstrap'] as Map;
  String row(String name, Map d) {
    final ci = d['diff'] as Map;
    return '| $name | ${d['docs']} | ${_f(d['meanA'])} | ${_f(d['meanB'])} | '
        '${_f(ci['mean'])} [${_f(ci['lo'])}, ${_f(ci['hi'])}] | ${_f(d['pDiffLeq0'])} |';
  }

  b
    ..writeln('# Extraction benchmark comparison')
    ..writeln()
    ..writeln('- A: `${c['a']}`')
    ..writeln('- B: `${c['b']}`')
    ..writeln('- Paired over ${c['sharedDocs']} documents present in both runs; ${boot['samples']} resamples, '
        'seed ${boot['seed']}, 95% percentile CI of the mean per-document F1 difference (B - A)');
  if ((c['onlyInA'] as List).isNotEmpty) b.writeln('- Only in A (not compared): ${(c['onlyInA'] as List).join(', ')}');
  if ((c['onlyInB'] as List).isNotEmpty) b.writeln('- Only in B (not compared): ${(c['onlyInB'] as List).join(', ')}');
  b
    ..writeln()
    ..writeln('| Group | Docs | F1 A | F1 B | B - A [95% CI] | P(B - A <= 0) |')
    ..writeln('|---|---:|---:|---:|---|---:|')
    ..writeln(row('overall', c['overall'] as Map));
  final strata = c['strata'] as Map;
  for (final key in strataKeys) {
    for (final e in (strata[key] as Map).entries) {
      b.writeln(row('$key=${e.key}', e.value as Map));
    }
  }
  return b.toString();
}

Map<String, dynamic> runCompare({
  required String datasetPath,
  required String aPath,
  required String bPath,
  required String outDir,
  required int seed,
  int samples = 10000,
}) {
  final dataset = loadDataset(datasetPath);
  final comparison = buildComparison(
    scoreRun(dataset, loadPredictions(aPath)),
    scoreRun(dataset, loadPredictions(bPath)),
    seed: seed,
    samples: samples,
    aPath: aPath,
    bPath: bPath,
  );
  Directory(outDir).createSync(recursive: true);
  File(p.join(outDir, 'compare.json')).writeAsStringSync('${_json.convert(comparison)}\n');
  File(p.join(outDir, 'compare.md')).writeAsStringSync(renderComparisonMarkdown(comparison));
  return comparison;
}

/// Predictions whose resources are each document's gold resources.
void writeOraclePredictions({required String datasetPath, required String outDir}) {
  final dataset = loadDataset(datasetPath);
  Directory(outDir).createSync(recursive: true);
  final sink = StringBuffer();
  for (final d in dataset) {
    final record = PredictionRecord(
      docId: d.docId,
      runId: 'oracle',
      model: 'oracle',
      platform: 'none',
      predictedResources: d.goldResources,
      generations: const [],
    );
    sink.writeln(jsonEncode(record.toJson()));
  }
  File(p.join(outDir, 'predictions.jsonl')).writeAsStringSync(sink.toString());
}
