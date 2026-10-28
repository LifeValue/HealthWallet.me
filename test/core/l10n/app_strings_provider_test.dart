import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';

void main() {
  test('notifies listeners only when the language changes', () {
    final strings = AppStringsProvider();
    var notified = 0;
    strings.addListener(() => notified++);

    strings.update(lookupAppLocalizations(const Locale('en')));
    expect(notified, 0);

    strings.update(lookupAppLocalizations(const Locale('de')));
    strings.update(lookupAppLocalizations(const Locale('de')));
    expect(notified, 1);
    expect(strings.l10n.localeName, 'de');
  });
}
