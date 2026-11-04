import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extractor.dart';

/// OCR lines of a clearvis.io document, compared folded (lower case, no
/// diacritics, slashes spaced alike), since OCR keeps or drops "ț", "ă" and
/// spacing at random. Apple Vision gives one line per text block, printing a
/// form's columns one after the other, so values are found from their label
/// rather than from their position on the page.
class ClearvisText {
  ClearvisText(String text)
    : lines = [
        for (final line in text.split('\n'))
          if (line.trim().isNotEmpty) line.trim(),
      ] {
    folded = [for (final line in lines) fold(line)];
  }

  final List<String> lines;
  late final List<String> folded;

  static String fold(String text) => LayoutKeys.foldDiacritics(
    text.toLowerCase(),
  ).replaceAll(RegExp(r'\s*/\s*'), ' / ').replaceAll(RegExp(r'\s+'), ' ');

  // The labels the forms print, Romanian then (on the prescriptions) " / "
  // and English; a label ends its line or is followed by its value.
  static final store = RegExp(r'^magazin( / [a-z -]*)?$');
  static final address = RegExp(r'^adres[ae]( / [a-z -]*)?$');
  static final patient = RegExp(r'^pacient( / [a-z -]*)?$');
  static final birthDate = RegExp(r'^dat[ae] nastere( / [a-z -]*)?$');
  static final patientId = RegExp(r'^identificator pacient( / [a-z -]*)?$');
  static final phone = RegExp(r'^telefon( / [a-z -]*)?$');
  static final email = RegExp(r'^e-?mail( / [a-z -]*)?$');
  static final date = RegExp(r'^data / date$');
  static final followUp = RegExp(r'^data control recomandat( / [a-z -]*)?$');
  static final examiner = RegExp(
    r'^examinarea a fost inregistrata de( / [a-z -]*)?$',
  );
  static final examPatient = RegExp(r'^nume pacient:?$');
  static final examDate = RegExp(r'^data examinarii:?$');
  static final examPlace = RegExp(r'^locul examinarii:?$');

  /// Every label the forms print; a line that is one is never a value.
  static final labels = <RegExp>[
    store,
    address,
    patient,
    birthDate,
    patientId,
    phone,
    email,
    date,
    followUp,
    examiner,
    examPatient,
    examDate,
    examPlace,
    RegExp(r'^valoarea corectiei( / [a-z -]*)?$'),
    RegExp(r'^semnatura( / [a-z -]*)?$'),
    RegExp(r'^rezultate masuratori$'),
    RegExp(r'^pagina$'),
    RegExp(r'^retete$'),
    RegExp(r'^(sph|cyl|axis|add|pd)$'),
  ];

  static bool isLabel(String foldedLine) =>
      labels.any((label) => label.hasMatch(foldedLine));

  /// The index of the first line from [from] (before [to]) that is
  /// [label] or starts with it.
  int indexOf(RegExp label, {int from = 0, int? to}) {
    for (var i = from; i < (to ?? lines.length); i++) {
      if (label.hasMatch(folded[i]) || _labelEnd(lines[i], label) != null) {
        return i;
      }
    }
    return -1;
  }

  /// The value printed for [label]: the rest of its line when the line goes
  /// on after it ("Data examinării: 14.03.2024", columns on one line), else
  /// one of the next [lookahead] lines, up to the next label.
  String? valueAfter(
    RegExp label, {
    int from = 0,
    int? to,
    int lookahead = 3,
    bool Function(String line)? accept,
  }) {
    final at = indexOf(label, from: from, to: to);
    if (at < 0) {
      return _valueBelowColumn(label, from: from, to: to, accept: accept);
    }
    final rest = _restAfter(lines[at], label);
    if (rest != null && !isLabel(fold(rest)) && (accept?.call(rest) ?? true)) {
      return rest;
    }
    for (var i = at + 1; i <= at + lookahead && i < (to ?? lines.length); i++) {
      // The next label starts another field: its value is not this one's.
      if (isLabel(folded[i])) break;
      final line = _firstColumn(lines[i]);
      if (accept?.call(line) ?? true) return line;
    }
    return null;
  }

  /// A label printed in a later column of a line, as text laid out by
  /// columns prints it ("Pacient / Patient      Dată naștere / Date of
  /// Birth"): its value is in the same column of the next line.
  String? _valueBelowColumn(
    RegExp label, {
    required int from,
    int? to,
    bool Function(String line)? accept,
  }) {
    for (var i = from; i + 1 < (to ?? lines.length); i++) {
      final cells = lines[i].split(_columnGap);
      for (var c = 1; c < cells.length; c++) {
        if (!label.hasMatch(fold(cells[c].trim()))) continue;
        final below = lines[i + 1].split(_columnGap);
        if (below.length != cells.length) return null;
        final value = below[c].trim();
        return value.isEmpty ||
                isLabel(fold(value)) ||
                !(accept?.call(value) ?? true)
            ? null
            : value;
      }
    }
    return null;
  }

  /// What follows [label] on its own [line] (the longest start of the line
  /// that is the label), or null when nothing does.
  static String? _restAfter(String line, RegExp label) {
    final end = _labelEnd(line, label);
    if (end == null) return null;
    final rest = line.substring(end).replaceFirst(RegExp(r'^[\s:/]+'), '');
    return rest.trim().isEmpty ? null : _firstColumn(rest.trim());
  }

  /// Where the longest start of [line] that is [label] ends, by words and
  /// within its first column.
  static int? _labelEnd(String line, RegExp label) {
    final column = _columnGap.firstMatch(line)?.start ?? line.length;
    int? end;
    for (final word in RegExp(r'\S+').allMatches(line)) {
      if (word.end > column) break;
      if (label.hasMatch(fold(line.substring(0, word.end)))) end = word.end;
    }
    return end;
  }

  static final _columnGap = RegExp(r'\s{3,}');

  /// The first column of a line that prints two columns, separated by three
  /// or more spaces.
  static String _firstColumn(String line) =>
      line.split(RegExp(r'\s{3,}')).first.trim();

  static final _date = RegExp(
    r'(?<!\d)(\d{1,2})[./-](\d{1,2})[./-](\d{4})(?!\d)',
  );

  /// The first `DD.MM.YYYY` in [text] as `YYYY-MM-DD`; null when that day
  /// doesn't exist.
  static String? isoDate(String? text) {
    if (text == null) return null;
    final m = _date.firstMatch(text);
    if (m == null) return null;
    final day = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final year = int.parse(m.group(3)!);
    // 31.02 would roll over into March.
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return '${m.group(3)}-${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  static bool hasDate(String line) => _date.hasMatch(line);

  /// Whether [line] reads as a person's name: words of letters, no digits.
  static bool isName(String line) =>
      !line.contains(RegExp(r'\d')) &&
      RegExp(r'\p{L}{2,}', unicode: true).hasMatch(line);

  /// A decimal as printed ("+0,75", "1.75") in canonical form: two decimals,
  /// a sign when [signed] and the value is positive.
  static String decimal(String printed, {bool signed = true}) {
    final value = double.parse(printed.replaceAll(',', '.'));
    final text = value.toStringAsFixed(2);
    return signed && value > 0 ? '+$text' : text;
  }
}
