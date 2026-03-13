import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';

class GenderMapper {
  static String mapFhirGenderToDisplay(
      String? fhirGender, AppLocalizations l10n) {
    if (fhirGender == null) return l10n.preferNotToSay;

    switch (fhirGender.toLowerCase()) {
      case 'male':
        return l10n.male;
      case 'female':
        return l10n.female;
      default:
        return l10n.preferNotToSay;
    }
  }

  static String mapFhirGenderToDisplayFallback(String? fhirGender) {
    if (fhirGender == null) return 'Prefer not to say';

    switch (fhirGender.toLowerCase()) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      default:
        return 'Prefer not to say';
    }
  }

  static fhir_r4.AdministrativeGender? mapDisplayGenderToFhir(
      String displayGender) {
    switch (displayGender.toLowerCase()) {
      case 'male':
        return fhir_r4.AdministrativeGender.male;
      case 'female':
        return fhir_r4.AdministrativeGender.female;
      case 'prefer not to say':
      case 'prefernottosay':
      case 'unknown':
      default:
        return fhir_r4.AdministrativeGender.unknown;
    }
  }
}
