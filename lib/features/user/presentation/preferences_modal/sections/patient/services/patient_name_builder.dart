import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;

class PatientNameBuilder {
  static List<fhir_r4.HumanName>? buildHumanName({
    List<String>? given,
    String? family,
    fhir_r4.HumanName? existingName,
  }) {
    if (given == null && family == null) {
      return existingName != null ? [existingName] : null;
    }

    final finalGiven = given ??
        (existingName?.given?.isNotEmpty == true
            ? existingName!.given!.map((g) => g.toString()).toList()
            : <String>[]);

    final finalFamily = family ??
        (existingName?.family != null
            ? existingName!.family!.toString()
            : null);

    String? displayName;
    if (finalGiven.isNotEmpty &&
        finalFamily != null &&
        finalFamily.isNotEmpty) {
      final givenStr = finalGiven.join(' ');
      displayName = '$finalFamily, $givenStr';
    } else if (finalGiven.isNotEmpty) {
      displayName = finalGiven.join(' ');
    } else if (finalFamily != null && finalFamily.isNotEmpty) {
      displayName = finalFamily;
    }

    return [
      fhir_r4.HumanName(
        text: displayName != null && displayName.isNotEmpty
            ? fhir_r4.FhirString(displayName)
            : null,
        family: finalFamily != null && finalFamily.isNotEmpty
            ? fhir_r4.FhirString(finalFamily)
            : null,
        given: finalGiven.isNotEmpty
            ? finalGiven.map((n) => fhir_r4.FhirString(n)).toList()
            : null,
      ),
    ];
  }

  static List<fhir_r4.HumanName>? buildHumanNameFromPatient({
    List<String>? given,
    String? family,
    List<fhir_r4.HumanName>? existingNames,
  }) {
    final existingName =
        existingNames?.isNotEmpty == true ? existingNames!.first : null;
    return buildHumanName(
      given: given,
      family: family,
      existingName: existingName,
    );
  }
}
