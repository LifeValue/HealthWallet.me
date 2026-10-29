import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/backup/domain/utils/backup_name_date.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  final time = DateTime(2026, 10, 28, 14, 5);

  setUpAll(() async {
    for (final locale in ['en', 'ro', 'de', 'es']) {
      await initializeDateFormatting(locale);
    }
  });

  test('uses the short-month date of the app language, like the history', () {
    expect(backupNameDate(time, 'en'), 'Oct 28, 2026');
    expect(backupNameDate(time, 'ro'), '28 oct. 2026');
    expect(backupNameDate(time, 'de'), '28. Okt. 2026');
    expect(backupNameDate(time, 'es'), '28 oct 2026');
  });

  test('adds the 24-hour time when asked', () {
    expect(backupNameDate(time, 'en', withTime: true), 'Oct 28, 2026 14:05');
    expect(backupNameDate(time, 'ro', withTime: true), '28 oct. 2026 14:05');
  });

  test('never uses the English month order in other languages', () {
    for (final locale in ['ro', 'de', 'es']) {
      expect(backupNameDate(time, locale), startsWith('28'));
    }
  });
}
