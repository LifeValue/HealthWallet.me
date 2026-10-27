import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/utils/country_names.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/utils/country_names_cldr.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/utils/phone_input_field.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

void main() {
  group('countryName', () {
    test('looks names up in the app language', () {
      expect(countryName(IsoCode.DE, 'ro'), 'Germania');
      expect(countryName(IsoCode.DE, 'de'), 'Deutschland');
      expect(countryName(IsoCode.DE, 'es'), 'Alemania');
      expect(countryName(IsoCode.RO, 'de'), 'Rumänien');
    });

    test('keeps the English names exactly as before', () {
      for (final entry in countryNames.entries) {
        expect(countryName(entry.key, 'en'), entry.value);
      }
      expect(countryName(IsoCode.AX, 'en'), 'Aland Islands');
    });

    test('falls back to English for an unsupported language', () {
      expect(countryName(IsoCode.DE, 'fr'), 'Germany');
      expect(countryName(IsoCode.RO, 'xx'), 'Romania');
    });

    test('has a CLDR name for every country in es, de and ro', () {
      for (final language in ['es', 'de', 'ro']) {
        final names = cldrCountryNames[language]!;
        final missing = countryNames.keys.where(
          (iso) => !names.containsKey(iso),
        );
        expect(missing, isEmpty, reason: '$language falls back to English');
      }
    });
  });

  group('buildCountryList', () {
    test('sorts by the localized name, ignoring diacritics', () {
      final names = buildCountryList('de').map((c) => c.name).toList();
      final austria = names.indexOf('Österreich');
      expect(names[austria - 1].compareTo('O') >= 0, isTrue);
      expect(names.last.startsWith('Z'), isTrue);
    });

    test('keeps English sorting unchanged', () {
      final names = buildCountryList('en').map((c) => c.name).toList();
      expect(names, [...names]..sort());
    });
  });
}
