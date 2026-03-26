import 'package:health_wallet/core/config/constants/country_identifier.dart';

class BasicInfoPrompt {
  final String? countryCode;

  BasicInfoPrompt({this.countryCode});

  String buildPrompt(String ocrText) {
    final truncated = ocrText.length > 1500 ? ocrText.substring(0, 1500) : ocrText;

    final profile = countryCode != null
        ? CountryIdentifier.forCountry(countryCode)
        : CountryIdentifier.forCurrentLocale();
    final countryRules = profile.promptHints.isNotEmpty
        ? ' ${profile.promptHints.replaceAll('\n- ', '. ').replaceAll('\n', '. ').replaceAll('- ', '')}'
        : '';

    return '''Extract patient info from this text. Return ONLY a JSON array with 2 objects.
Text:
$truncated
---
Format: [Patient, Encounter or DiagnosticReport]
[{"resourceType":"Patient","familyName":"<the patient surname from the text>","givenName":"<the patient first name from the text>","dateOfBirth":"YYYY-MM-DD","gender":"male|female","patientIdentifier":"<ID number>","identifierLabel":"MRN","documentCategory":"visit"},{"resourceType":"Encounter","encounterType":"type","periodStart":"YYYY-MM-DD"}]
For lab results use DiagnosticReport instead: {"resourceType":"DiagnosticReport","reportName":"name","conclusion":"","issuedDate":"YYYY-MM-DD"}
Rules: familyName and givenName MUST be the actual patient name from the text, NOT placeholders. dateOfBirth=birth date ONLY, not visit date.$countryRules identifierLabel=type of patient ID (CNP, KVNR, SVNr, CIP, NIR, CF, BSN, PESEL, PNR, AHV, NHS, MRN, SSN, or Identifier). If no patient ID found, set patientIdentifier="" and identifierLabel="MRN". Empty string for missing fields.''';
  }
}
