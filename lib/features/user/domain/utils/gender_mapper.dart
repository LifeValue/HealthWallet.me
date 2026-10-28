import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';

class GenderMapper {
  static String mapFhirGenderToDisplay(
    String? fhirGender,
    AppLocalizations l10n,
  ) {
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

  /// The FHIR gender code for an option of the gender picker, whose options
  /// are [AppLocalizations.male], [AppLocalizations.female] and
  /// [AppLocalizations.preferNotToSay] in the active language. Save this code,
  /// never the localized label: [mapDisplayGenderToFhir] reads it back.
  static String mapLocalizedDisplayToFhirCode(
    String displayGender,
    AppLocalizations l10n,
  ) {
    if (displayGender == l10n.male) return 'male';
    if (displayGender == l10n.female) return 'female';
    return 'unknown';
  }

  static fhir_r4.AdministrativeGender? mapDisplayGenderToFhir(
    String displayGender,
  ) {
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
