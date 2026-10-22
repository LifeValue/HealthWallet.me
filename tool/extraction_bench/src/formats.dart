/// Localized printing of values on generated documents. The gold-on-document
/// test uses the same functions to find each gold value on its page.
library;

const benchLangs = ['en', 'es', 'de', 'ro'];

const _monthsEn = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int v) => v.toString().padLeft(2, '0');

/// Prints a FHIR date (`YYYY`, `YYYY-MM` or `YYYY-MM-DD`) the way a document
/// in [lang] would: `14 Mar 2025`, `14/03/2025`, `14.03.2025`.
String formatDate(String fhirDate, String lang) {
  final parts = fhirDate.split('T').first.split('-');
  final year = parts[0];
  final month = parts.length > 1 ? int.parse(parts[1]) : null;
  final day = parts.length > 2 ? int.parse(parts[2]) : null;
  if (month == null) return year;
  switch (lang) {
    case 'en':
      final m = _monthsEn[month - 1];
      return day == null ? '$m $year' : '$day $m $year';
    case 'es':
      return day == null ? '${_two(month)}/$year' : '${_two(day)}/${_two(month)}/$year';
    case 'de':
      return day == null ? '${_two(month)}/$year' : '${_two(day)}.${_two(month)}.$year';
    case 'ro':
      return day == null ? '${_two(month)}.$year' : '${_two(day)}.${_two(month)}.$year';
  }
  throw ArgumentError.value(lang, 'lang');
}

/// The shortest decimal form of [value] with [lang]'s separator
/// (decimal comma for es/de/ro). `13.0` prints as `13`.
String formatDecimal(num value, String lang) {
  var s = value.toString();
  if (s.contains('e') || s.contains('E')) s = value.toStringAsFixed(6);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  }
  return lang == 'en' ? s : s.replaceAll('.', ',');
}

/// Rounds [value] to [decimals] places without binary noise.
double roundTo(double value, int decimals) =>
    double.parse(value.toStringAsFixed(decimals));
