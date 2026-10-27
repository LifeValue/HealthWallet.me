import 'package:health_wallet/core/config/constants/country_identifier.dart';
import 'package:health_wallet/features/processing/data/model/prompt_template/draft_prompt.dart';
import 'package:health_wallet/features/processing/data/model/structured_output/extraction_schemas.dart';

class BasicInfoPrompt {
  final String? countryCode;

  BasicInfoPrompt({this.countryCode});

  /// [outputMode] picks the legacy array format or the schema object; a
  /// [draft] (schemaDraft mode) is added before the format.
  String buildPrompt(
    String ocrText, {
    ExtractionOutputMode outputMode = ExtractionOutputMode.grammar,
    String? draft,
  }) {
    final truncated = ocrText.length > 1500
        ? ocrText.substring(0, 1500)
        : ocrText;

    final profile = countryCode != null
        ? CountryIdentifier.forCountry(countryCode)
        : CountryIdentifier.forDocument(ocrText);
    final countryRules = profile.promptHints.isNotEmpty
        ? ' ${profile.promptHints.replaceAll('\n- ', '. ').replaceAll('\n', '. ').replaceAll('- ', '')}'
        : '';

    if (outputMode.usesSchema) {
      return '''Extract patient and document info from this text. Return ONLY one JSON object.
Text:
$truncated
---
${DraftPrompt.section(draft)}Format:
${ExtractionSchemas.basicInfoShape}
Rules: familyName and givenName MUST be the actual patient name from the text, NOT placeholders. dateOfBirth=birth date ONLY, not visit date.$countryRules identifierLabel=type of patient ID (CNP, KVNR, SVNr, CIP, DNI, NIR, CF, BSN, PESEL, PNR, AHV, NHS, MRN, SSN, or Identifier). If no patient ID found, set patientIdentifier="" and identifierLabel="MRN". documentTitle=the heading at the top of the document. documentDate=the report or visit date, not the birth date. documentCategory=lab_report ONLY for standalone lab test results, visit for everything else (discharge letters, consultations, admissions). conclusion=the report's conclusion or interpretation, empty if none. Dates as YYYY-MM-DD. Empty string for missing fields.''';
    }

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
