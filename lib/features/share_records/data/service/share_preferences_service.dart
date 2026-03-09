import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@lazySingleton
class SharePreferencesService {
  static const String _keyDefaultViewingDurationMinutes =
      'share_default_viewing_duration_minutes';
  static const int _fallbackDefaultMinutes = 30;

  Future<Duration> getDefaultViewingDuration() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes =
        prefs.getInt(_keyDefaultViewingDurationMinutes) ?? _fallbackDefaultMinutes;
    return Duration(minutes: minutes);
  }

  Future<void> setDefaultViewingDuration(Duration duration) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDefaultViewingDurationMinutes, duration.inMinutes);
  }
}
