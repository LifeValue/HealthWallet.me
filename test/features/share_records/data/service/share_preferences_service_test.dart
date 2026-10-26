import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/share_records/data/service/share_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'share_default_viewing_duration_minutes';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to 30 minutes', () async {
    expect(
      await SharePreferencesService().getDefaultViewingDuration(),
      const Duration(minutes: 30),
    );
  });

  test('reads a stored duration', () async {
    SharedPreferences.setMockInitialValues({key: 5});
    expect(
      await SharePreferencesService().getDefaultViewingDuration(),
      const Duration(minutes: 5),
    );
  });

  test('stores whole minutes and reads them back', () async {
    final service = SharePreferencesService();

    await service.setDefaultViewingDuration(
      const Duration(minutes: 15, seconds: 59),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(key), 15);
    expect(
      await service.getDefaultViewingDuration(),
      const Duration(minutes: 15),
    );
  });
}
