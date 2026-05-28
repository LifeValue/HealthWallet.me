import 'package:health_wallet/core/config/constants/country_identifier.dart';

class BasicInfoVisionPrompt {
  final String? ocrText;
  final String? countryCode;

  BasicInfoVisionPrompt({this.ocrText, this.countryCode});

  String buildPrompt() {
    final truncatedOcr = ocrText != null && ocrText!.isNotEmpty
        ? (ocrText!.length > 2000 ? ocrText!.substring(0, 2000) : ocrText!)
        : null;
    final ocrSection = truncatedOcr != null
        ? '\nOCR text from this document (use for exact values like names, dates, IDs):\n---\n$truncatedOcr\n---\n'
        : '';

    final profile = countryCode != null
        ? CountryIdentifier.forCountry(countryCode)
        : CountryIdentifier.forCurrentLocale();
    final countryHints = profile.promptHints.isNotEmpty
        ? '\n${profile.promptHints}'
        : '';

    return '''Extract patient info from this medical document image.$ocrSection
Return ONLY a JSON array with exactly 2 objects: Patient + either Encounter OR DiagnosticReport.

If this is a hospital visit, consultation, admission, or discharge document:
[
  {"resourceType":"Patient","familyName":"<the patient surname from the document>","givenName":"<the patient first name from the document>","dateOfBirth":"YYYY-MM-DD","gender":"male|female","patientIdentifier":"<ID number>","identifierLabel":"MRN","documentCategory":"visit"},
  {"resourceType":"Encounter","encounterType":"consultation or admission type","periodStart":"YYYY-MM-DD"}
]

If this is a lab test result or diagnostic report:
[
  {"resourceType":"Patient","familyName":"<the patient surname from the document>","givenName":"<the patient first name from the document>","dateOfBirth":"YYYY-MM-DD","gender":"male|female","patientIdentifier":"<ID number>","identifierLabel":"MRN","documentCategory":"lab_report"},
  {"resourceType":"DiagnosticReport","reportName":"test name","conclusion":"","issuedDate":"YYYY-MM-DD"}
]

Rules:
- Most documents are visits. Only use DiagnosticReport for actual lab/test results
- familyName and givenName MUST be the actual patient name found in the document, NOT placeholders
- dateOfBirth = BIRTH date only. NOT admission/discharge/visit date$countryHints
- identifierLabel: the type of patient ID found. Use the appropriate label for the country (CNP, KVNR, SVNr, CIP, NIR, CF, BSN, PESEL, PNR, AHV, NHS, MRN, SSN, or "Identifier")
- If no patient ID is found in the document, set patientIdentifier to "" and keep identifierLabel as "MRN"
- Use empty string for missing fields''';
  }
}
