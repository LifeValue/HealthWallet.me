import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/user/domain/utils/gender_mapper.dart';

void main() {
  test('a stored or scanned gender normalizes to a picker code', () {
    expect(GenderMapper.normalizeFhirGenderCode('male'), 'male');
    expect(GenderMapper.normalizeFhirGenderCode('Female'), 'female');
    for (final other in ['other', 'unknown', 'Unknown', '', null]) {
      expect(GenderMapper.normalizeFhirGenderCode(other), 'unknown');
    }
  });

  for (final code in ['en', 'es', 'de', 'ro']) {
    final l10n = lookupAppLocalizations(Locale(code));

    test('$code: a picked gender is saved as its FHIR code', () {
      fhir_r4.AdministrativeGender? saved(String label) =>
          GenderMapper.mapDisplayGenderToFhir(
            GenderMapper.mapLocalizedDisplayToFhirCode(label, l10n),
          );

      expect(saved(l10n.male), fhir_r4.AdministrativeGender.male);
      expect(saved(l10n.female), fhir_r4.AdministrativeGender.female);
      expect(saved(l10n.preferNotToSay), fhir_r4.AdministrativeGender.unknown);
    });

    test('$code: the stored code shows as a picker option', () {
      final options = [l10n.male, l10n.female, l10n.preferNotToSay];
      for (final fhir in ['male', 'female', 'unknown', 'other', null]) {
        expect(
          options,
          contains(GenderMapper.mapFhirGenderToDisplay(fhir, l10n)),
        );
      }
    });
  }
}
