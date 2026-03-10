class BasicInfoPrompt {
  String buildPrompt(String ocrText) {
    final truncated = ocrText.length > 1500 ? ocrText.substring(0, 1500) : ocrText;

    return '''Extract patient info from this text. Return ONLY a JSON array with 2 objects.
Text:
$truncated
---
Format: [Patient, Encounter or DiagnosticReport]
[{"resourceType":"Patient","familyName":"<the patient surname from the text>","givenName":"<the patient first name from the text>","dateOfBirth":"YYYY-MM-DD","gender":"male|female","patientMRN":"<ID number>","identifierLabel":"MRN","documentCategory":"visit"},{"resourceType":"Encounter","encounterType":"type","periodStart":"YYYY-MM-DD"}]
For lab results use DiagnosticReport instead: {"resourceType":"DiagnosticReport","reportName":"name","conclusion":"","issuedDate":"YYYY-MM-DD"}
Rules: familyName and givenName MUST be the actual patient name from the text, NOT placeholders. dateOfBirth=birth date ONLY, not visit date. CNP=Romanian 13-digit ID only. patientMRN=the CNP number (13 digits after "CNP:"), NOT "Cod prezentare", "Foie de observatie", or "Nr. fisa". Empty string for missing fields.''';
  }
}
