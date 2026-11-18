import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';

/// The `SharedPreferences` keys holding AI settings that earlier versions
/// saved by mistake, which are removed once so the defaults apply again.
///
/// Preferences defaulted the token limit to 500 and saved every value on
/// Save, so one Save capped scans at 500 tokens. Its dialog also defaulted
/// Deep Scan off, which turned it off on the desktop, where it defaults on.
List<String> mistakenAiSettings({
  required int? savedMaxTokens,
  required bool? savedUseVision,
  required bool isDesktop,
}) => [
  if (savedMaxTokens == 500) SharedPrefsConstants.aiMaxTokens,
  if (isDesktop && savedUseVision == false) SharedPrefsConstants.aiUseVision,
];
