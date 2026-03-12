class BasicInfoVisionPrompt {
  final String? ocrText;

  BasicInfoVisionPrompt({this.ocrText});

  String buildPrompt() {
    final truncatedOcr = ocrText != null && ocrText!.isNotEmpty
        ? (ocrText!.length > 2000 ? ocrText!.substring(0, 2000) : ocrText!)
        : null;
    final ocrSection = truncatedOcr != null
        ? '\nOCR text from this document (use for exact values like names, dates, IDs):\n---\n$truncatedOcr\n---\n'
        : '';

    return '''Extract patient info from this medical document image.$ocrSection
Return ONLY a JSON array with exactly 2 objects: Patient + either Encounter OR DiagnosticReport.

If this is a hospital visit, consultation, admission, or discharge document:
[
  {"resourceType":"Patient","familyName":"<the patient surname from the document>","givenName":"<the patient first name from the document>","dateOfBirth":"YYYY-MM-DD","gender":"male|female","patientMRN":"<ID number>","identifierLabel":"MRN","documentCategory":"visit"},
  {"resourceType":"Encounter","encounterType":"consultation or admission type","periodStart":"YYYY-MM-DD"}
]

If this is a lab test result or diagnostic report:
[
  {"resourceType":"Patient","familyName":"<the patient surname from the document>","givenName":"<the patient first name from the document>","dateOfBirth":"YYYY-MM-DD","gender":"male|female","patientMRN":"<ID number>","identifierLabel":"MRN","documentCategory":"lab_report"},
  {"resourceType":"DiagnosticReport","reportName":"test name","conclusion":"","issuedDate":"YYYY-MM-DD"}
]

Rules:
- Most documents are visits. Only use DiagnosticReport for actual lab/test results
- familyName and givenName MUST be the actual patient name found in the document, NOT placeholders
- dateOfBirth = BIRTH date only. NOT admission/discharge/visit date
- Romanian: "Data nasterii" = birth date. "Data internarii" = NOT birth date
- identifierLabel: the type of patient ID found. Use "CNP" only for Romanian 13-digit IDs. Otherwise use "MRN", "SSN", "NHS", or "Identifier"
- patientMRN = the CNP number (13 digits after "CNP:"), NOT "Cod prezentare", "Foie de observatie", or "Nr. fisa"
- If no patient ID or MRN is found in the document, set patientMRN to "" and keep identifierLabel as "MRN"
- Use empty string for missing fields''';
  }
}
