import 'package:flutter/widgets.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:injectable/injectable.dart';

/// Holds the `AppLocalizations` of the active locale for code that has no
/// `BuildContext`: BLoCs, services and notifications get it through their
/// constructor and read [l10n] when they build a message.
///
/// `App` updates it from the locale `MaterialApp` resolved, so it follows both
/// the device language and the in-app language setting. Until then it holds
/// English. A message keeps the language that was active when it was built;
/// code that shows text for a long time (the desktop tray menu) listens for
/// language changes.
@lazySingleton
class AppStringsProvider extends ChangeNotifier {
  AppStringsProvider();

  /// Starts with the given locale's strings; for tests.
  AppStringsProvider.forLocale(Locale locale)
    : _l10n = lookupAppLocalizations(locale);

  AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

  AppLocalizations get l10n => _l10n;

  /// Notifies listeners only when the language changes, since `App` calls
  /// this on every build.
  void update(AppLocalizations l10n) {
    if (l10n.localeName == _l10n.localeName) return;
    _l10n = l10n;
    notifyListeners();
  }
}
