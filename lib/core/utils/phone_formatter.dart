import 'package:phone_numbers_parser/phone_numbers_parser.dart';

class PhoneDisplayFormatter {
  static String format(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    try {
      final phone = PhoneNumber.parse(raw);
      return '+${phone.countryCode} ${phone.formatNsn()}';
    } catch (_) {
      return raw;
    }
  }
}
