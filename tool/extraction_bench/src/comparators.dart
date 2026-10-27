/// Field comparators. Each returns a score in [0, 1] for a gold value and a
/// predicted value, both already non-null.
library;

import 'dart:math' as math;

// ---------------------------------------------------------------------------
// Text
// ---------------------------------------------------------------------------

const _diacritics = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ă': 'a',
  'ā': 'a',
  'ç': 'c',
  'ć': 'c',
  'č': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ě': 'e',
  'ē': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ī': 'i',
  'ñ': 'n',
  'ń': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'ō': 'o',
  'ș': 's',
  'ş': 's',
  'š': 's',
  'ś': 's',
  'ț': 't',
  'ţ': 't',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ž': 'z',
  'ź': 'z',
  'ż': 'z',
  'ł': 'l',
  'ß': 'ss',
  'µ': 'u',
  'μ': 'u',
};

final _whitespace = RegExp(r'\s+');
final _nonWord = RegExp(r'[^a-z0-9]+');

/// Lower case, diacritics removed, whitespace collapsed.
String foldText(String s) {
  final lower = s.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final c = String.fromCharCode(rune);
    out.write(_diacritics[c] ?? c);
  }
  return out.toString().replaceAll(_whitespace, ' ').trim();
}

Set<String> textTokens(String s) =>
    foldText(s).split(_nonWord).where((t) => t.isNotEmpty).toSet();

double jaccard(Set<String> a, Set<String> b) {
  if (a.isEmpty && b.isEmpty) return 1;
  final inter = a.intersection(b).length;
  final union = a.union(b).length;
  return union == 0 ? 0 : inter / union;
}

final _digits = RegExp(r'\d+');
final _leadingZeros = RegExp(r'^0+(?=\d)');

/// 1 when equal after folding; 0 when the gold's numbers do not all appear,
/// in order, among the prediction's (`1-0-0` vs `1-0-1`, `20 IE` vs `14 IE`;
/// an added `(ICD-10: E11.9)` is fine); otherwise the token Jaccard when it is
/// at least 0.5, else 0.
double compareText(String gold, String pred) {
  final g = foldText(gold);
  final p = foldText(pred);
  if (g == p) return 1;
  List<String> numbers(String t) => [
    for (final m in _digits.allMatches(t))
      m[0]!.replaceFirst(_leadingZeros, ''),
  ];
  final gn = numbers(g);
  final pn = numbers(p);
  var next = 0;
  for (final n in gn) {
    while (next < pn.length && pn[next] != n) {
      next++;
    }
    if (next == pn.length) return 0;
    next++;
  }
  final j = jaccard(textTokens(gold), textTokens(pred));
  return j >= 0.5 ? j : 0;
}

double compareExact(String gold, String pred) =>
    foldText(gold) == foldText(pred) ? 1 : 0;

final _identifierNoise = RegExp(r'[\s\-/().]+');

/// Equal after removing spaces, dashes, slashes, parentheses and dots,
/// ignoring case.
double compareIdentifier(String gold, String pred) =>
    gold.replaceAll(_identifierNoise, '').toUpperCase() ==
        pred.replaceAll(_identifierNoise, '').toUpperCase()
    ? 1
    : 0;

/// Jaccard of the folded elements' tokens (`["Ana Maria"]` equals
/// `["Ana", "Maria"]`).
double compareSet(List<String> gold, List<String> pred) => jaccard(
  {for (final g in gold) ...textTokens(g)},
  {for (final p in pred) ...textTokens(p)},
);

// ---------------------------------------------------------------------------
// Dates
// ---------------------------------------------------------------------------

final _datePattern = RegExp(r'^\s*(\d{4})(?:-(\d{2})(?:-(\d{2}))?)?');

/// Year, month and day of a FHIR date/dateTime/instant; the time is ignored.
List<int>? parseFhirDate(String s) {
  final m = _datePattern.firstMatch(s);
  if (m == null) return null;
  return [
    int.parse(m.group(1)!),
    if (m.group(2) != null) int.parse(m.group(2)!),
    if (m.group(3) != null) int.parse(m.group(3)!),
  ];
}

/// 1 at the same precision and equal; 0.5 when one is a coarser prefix of the
/// other (`2019` vs `2019-05-12`); otherwise 0.
double compareDate(String gold, String pred) {
  final g = parseFhirDate(gold);
  final p = parseFhirDate(pred);
  if (g == null || p == null) return foldText(gold) == foldText(pred) ? 1 : 0;
  final n = math.min(g.length, p.length);
  for (var i = 0; i < n; i++) {
    if (g[i] != p[i]) return 0;
  }
  return g.length == p.length ? 1 : 0.5;
}

// ---------------------------------------------------------------------------
// Quantities and UCUM
// ---------------------------------------------------------------------------

class QuantityValue {
  const QuantityValue({this.value, this.unit, this.code, required this.raw});

  /// Parsed number; null when the source had none.
  final double? value;

  /// Unit as written (`unit`), may be null.
  final String? unit;

  /// UCUM code (`code`), may be null.
  final String? code;
  final String raw;

  @override
  String toString() => 'Quantity($value, unit: $unit, code: $code)';
}

final _numberWithRest = RegExp(r'^\s*[<>≤≥=~]?\s*([-+]?\d[\d.,]*)\s*(.*)$');

/// Parses `13.5`, `13,5`, `1.234,5` and `1,234.5`.
double? parseLocalizedNumber(String s) {
  var t = s.trim();
  final hasComma = t.contains(',');
  final hasDot = t.contains('.');
  if (hasComma && hasDot) {
    if (t.lastIndexOf(',') > t.lastIndexOf('.')) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else {
      t = t.replaceAll(',', '');
    }
  } else if (hasComma) {
    t = t.replaceAll(',', '.');
  }
  return double.tryParse(t);
}

/// A quantity from a FHIR Quantity map, a number, or a string such as
/// `13,5 g/dL`.
QuantityValue? toQuantity(Object? v) {
  if (v == null) return null;
  if (v is num) return QuantityValue(value: v.toDouble(), raw: '$v');
  if (v is String) {
    if (v.trim().isEmpty) return null;
    final m = _numberWithRest.firstMatch(v);
    if (m == null) return QuantityValue(raw: v);
    final rest = m.group(2)!.trim();
    return QuantityValue(
      value: parseLocalizedNumber(
        m.group(1)!.replaceFirst(RegExp(r'[.,]$'), ''),
      ),
      unit: rest.isEmpty ? null : rest,
      raw: v,
    );
  }
  if (v is Map) {
    final raw = v['value'];
    final value = raw is num
        ? raw.toDouble()
        : raw is String
        ? parseLocalizedNumber(raw)
        : null;
    if (value == null && raw == null) return null;
    String? str(Object? o) =>
        o is String && o.trim().isNotEmpty ? o.trim() : null;
    return QuantityValue(
      value: value,
      unit: str(v['unit']),
      code: str(v['code']),
      raw: '$raw',
    );
  }
  return null;
}

const _unitAliases = {
  '°c': 'Cel',
  'ºc': 'Cel',
  'cel': 'Cel',
  'degc': 'Cel',
  '℃': 'Cel',
  '°f': '[degF]',
  'ºf': '[degF]',
  '[degf]': '[degF]',
  'degf': '[degF]',
  'mmhg': 'mm[Hg]',
  'mm[hg]': 'mm[Hg]',
  'bpm': '/min',
  'lpm': '/min',
  'rpm': '/min',
  '/min': '/min',
  '1/min': '/min',
  'min-1': '/min',
  '/minute': '/min',
  'beats/min': '/min',
  'breaths/min': '/min',
  'x/min': '/min',
};

/// Normalized unit text: `µ`→`u`, `x10^9/L`→`10*9/L`, liters as `L`, common
/// aliases (`°C`→`Cel`, `mmHg`→`mm[Hg]`, `bpm`→`/min`), `IU`/`UI`→`[IU]`.
String normalizeUnitText(String unit) {
  var s = unit.trim().replaceAll(RegExp(r'\s+'), '');
  s = s.replaceAll('µ', 'u').replaceAll('μ', 'u').replaceAll('×', 'x');
  final alias = _unitAliases[s.toLowerCase()];
  if (alias != null) return alias;
  s = s.replaceAllMapped(
    RegExp(r'^x?10(?:\^|\*|E|e)(\d+)'),
    (m) => '10*${m[1]}',
  );
  s = s.replaceAll(RegExp(r'\[?(IU|UI)\]?'), '[IU]');
  // Liters: a lone or prefixed `l` atom.
  s = s.replaceAllMapped(
    RegExp(r'(^|[/.])([kdcmunpf]?)l(?=$|[/.\d])'),
    (m) => '${m[1]}${m[2]}L',
  );
  return s;
}

class _Unit {
  const _Unit(this.factor, this.dims, {this.special});
  final double factor;
  final Map<String, int> dims;
  final String? special;
}

const _prefixes = {
  'T': 1e12,
  'G': 1e9,
  'M': 1e6,
  'k': 1e3,
  'h': 1e2,
  'd': 1e-1,
  'c': 1e-2,
  'm': 1e-3,
  'u': 1e-6,
  'n': 1e-9,
  'p': 1e-12,
  'f': 1e-15,
};

/// Base atoms with their dimension and factor relative to the base.
const _atoms = <String, (String, double)>{
  'g': ('M', 1),
  'L': ('V', 1),
  'm': ('Len', 1),
  'mol': ('N', 1),
  'eq': ('Eq', 1),
  'U': ('U', 1),
  '[IU]': ('IU', 1),
  's': ('T', 1),
  'min': ('T', 60),
  'h': ('T', 3600),
  'd': ('T', 86400),
  '%': ('1', 0.01),
  'mm[Hg]': ('P', 1),
};

_Unit? _parseTerm(String term) {
  if (term.isEmpty) return const _Unit(1, {});
  var factor = 1.0;
  final dims = <String, int>{};
  for (final raw in term.split('.')) {
    var token = raw;
    final tenPow = RegExp(r'^10\*(\d+)').firstMatch(token);
    if (tenPow != null) {
      factor *= math.pow(10, int.parse(tenPow.group(1)!)).toDouble();
      token = token.substring(tenPow.end);
      if (token.isEmpty) continue;
    }
    var exponent = 1;
    final expMatch = RegExp(r'^(.*?)(-?\d+)$').firstMatch(token);
    if (expMatch != null &&
        expMatch.group(1)!.isNotEmpty &&
        !_atoms.containsKey(token)) {
      token = expMatch.group(1)!;
      exponent = int.parse(expMatch.group(2)!);
    }
    (String, double)? atom = _atoms[token];
    var prefix = 1.0;
    // A bare giga or tera is a count (`G/l` = 10^9/L); a bare `M` stays
    // unparsed, as it may mean molar.
    if (atom == null && (token == 'G' || token == 'T')) {
      atom = ('1', 1);
      prefix = _prefixes[token]!;
    }
    if (atom == null && token.length > 1) {
      final pf = _prefixes[token[0]];
      final rest = _atoms[token.substring(1)];
      if (pf != null && rest != null) {
        atom = rest;
        prefix = pf;
      }
    }
    if (atom == null) return null;
    factor *= math.pow(prefix * atom.$2, exponent).toDouble();
    if (atom.$1 != '1') dims[atom.$1] = (dims[atom.$1] ?? 0) + exponent;
  }
  dims.removeWhere((_, v) => v == 0);
  return _Unit(factor, dims);
}

_Unit? _parseUnit(String unit) {
  final s = normalizeUnitText(unit);
  if (s == 'Cel' || s == '[degF]') return _Unit(1, const {}, special: s);
  final slash = s.indexOf('/');
  final numerator = slash < 0 ? s : s.substring(0, slash);
  final denominator = slash < 0 ? '' : s.substring(slash + 1);
  final n = _parseTerm(numerator);
  final d = _parseTerm(denominator);
  if (n == null || d == null) return null;
  final dims = Map<String, int>.of(n.dims);
  d.dims.forEach((k, v) => dims[k] = (dims[k] ?? 0) - v);
  dims.removeWhere((_, v) => v == 0);
  return _Unit(n.factor / d.factor, dims);
}

bool _sameDims(Map<String, int> a, Map<String, int> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

/// [value] in [from] expressed in [to], or null when they don't convert.
double? convertUnit(double value, String from, String to) {
  final f = _parseUnit(from);
  final t = _parseUnit(to);
  if (f == null || t == null) return null;
  if (f.special != null || t.special != null) {
    if (f.special == t.special) return value;
    if (f.special == 'Cel' && t.special == '[degF]') return value * 9 / 5 + 32;
    if (f.special == '[degF]' && t.special == 'Cel') {
      return (value - 32) * 5 / 9;
    }
    return null;
  }
  if (!_sameDims(f.dims, t.dims)) return null;
  return value * f.factor / t.factor;
}

bool numbersMatch(double a, double b, {double relTol = 1e-3}) {
  if (a == b) return true;
  return (a - b).abs() <= relTol * math.max(a.abs(), b.abs());
}

/// 1 when the values agree after UCUM conversion (relative tolerance 1e-3),
/// or when value and normalized unit text are both equal. A predicted value
/// without a unit, against a gold value with one, scores 0.5 when the number
/// matches.
double compareQuantity(QuantityValue gold, QuantityValue pred) {
  final gv = gold.value;
  final pv = pred.value;
  if (gv == null || pv == null) {
    return foldText(gold.raw) == foldText(pred.raw) ? 1 : 0;
  }
  final goldUnits = [gold.code, gold.unit].whereType<String>().toList();
  final predUnit = pred.code ?? pred.unit;
  if (predUnit == null) {
    if (goldUnits.isEmpty) return numbersMatch(gv, pv) ? 1 : 0;
    return numbersMatch(gv, pv) ? 0.5 : 0;
  }
  if (goldUnits.isEmpty) return numbersMatch(gv, pv) ? 0.5 : 0;

  // Unit text is compared case-insensitively after normalization.
  final predText = normalizeUnitText(predUnit).toLowerCase();
  final predAlt = pred.unit == null
      ? null
      : normalizeUnitText(pred.unit!).toLowerCase();
  for (final g in goldUnits) {
    final gt = normalizeUnitText(g).toLowerCase();
    if (gt == predText || gt == predAlt) return numbersMatch(gv, pv) ? 1 : 0;
  }
  for (final g in goldUnits) {
    for (final p in [pred.code, pred.unit].whereType<String>()) {
      final converted = convertUnit(pv, p, g);
      if (converted != null) return numbersMatch(gv, converted) ? 1 : 0;
    }
  }
  return 0;
}

// ---------------------------------------------------------------------------
// Coded concepts
// ---------------------------------------------------------------------------

class ConceptValue {
  const ConceptValue({
    required this.codes,
    required this.alternatives,
    required this.texts,
  });

  /// `system|code` of every coding.
  final Set<String> codes;

  /// `system|code` of codes the gold accepts for partial credit.
  final Set<String> alternatives;

  /// `text` first, then coding displays.
  final List<String> texts;

  bool get isEmpty => codes.isEmpty && texts.isEmpty;
}

String _normSystem(String s) =>
    s.trim().replaceFirst(RegExp(r'/$'), '').toLowerCase();

/// A [ConceptValue] from a CodeableConcept map or a plain string.
ConceptValue? toConcept(Object? v, {String? alternativeUrl}) {
  if (v == null) return null;
  if (v is String) {
    return v.trim().isEmpty
        ? null
        : ConceptValue(
            codes: const {},
            alternatives: const {},
            texts: [v.trim()],
          );
  }
  if (v is! Map) return null;
  final codes = <String>{};
  final texts = <String>[];
  final text = v['text'];
  if (text is String && text.trim().isNotEmpty) texts.add(text.trim());
  for (final c in (v['coding'] as List?) ?? const []) {
    if (c is! Map) continue;
    final code = c['code'];
    if (code is String && code.trim().isNotEmpty) {
      codes.add('${_normSystem('${c['system'] ?? ''}')}|${code.trim()}');
    }
    final display = c['display'];
    if (display is String && display.trim().isNotEmpty) {
      texts.add(display.trim());
    }
  }
  final alternatives = <String>{};
  for (final e in (v['extension'] as List?) ?? const []) {
    if (e is! Map || (alternativeUrl != null && e['url'] != alternativeUrl)) {
      continue;
    }
    final c = e['valueCoding'];
    if (c is Map && c['code'] is String) {
      alternatives.add(
        '${_normSystem('${c['system'] ?? ''}')}|${(c['code'] as String).trim()}',
      );
    }
  }
  final concept = ConceptValue(
    codes: codes,
    alternatives: alternatives,
    texts: texts,
  );
  return concept.isEmpty ? null : concept;
}

/// A shared coding scores 1, a gold-listed alternative code 0.75, a text or
/// display match 0.5 times its text score. When the gold concept has no
/// codings at all it is compared as text, at full weight.
double compareConcept(ConceptValue gold, ConceptValue pred) {
  var best = 0.0;
  for (final g in gold.texts) {
    for (final p in pred.texts) {
      best = math.max(best, compareText(g, p));
    }
  }
  if (gold.codes.isEmpty) return best;
  if (pred.codes.intersection(gold.codes).isNotEmpty) return 1;
  if (pred.codes.intersection(gold.alternatives).isNotEmpty) return 0.75;
  return 0.5 * best;
}
