import 'package:health_wallet/features/scan/data/model/prompt_template/prompt_template.dart';

class BasicInfoPrompt extends PromptTemplate {
  @override
  String get promptResourceType =>
      "basic patient demographic information, encounter details, and diagnostic report details";

  @override
  String get promptJsonStructure => '''
    [
      {
        "resourceType": "Patient",
        "familyName": "string",
        "givenName": "string",
        "dateOfBirth": "string (YYYY-MM-DD, actual date not age)",
        "gender": "male | female | other | unknown",
        "patientMRN": "string (the actual numeric value of the patient identifier, e.g. 2530926454117 or 0395-22-95, NOT the label name, empty if not found)",
        "identifierLabel": "string (the type of identifier found: CNP if Romanian, MRN if American, SSN, NHS, etc.)",
        "documentCategory": "visit | lab_report (visit for hospital visits, discharge summaries, consultations; lab_report for laboratory test results, blood tests, diagnostic studies)"
      },
      {
        "resourceType": "Encounter",
        "encounterType": "string (type of visit or hospital/clinic name, empty if not a clinical visit)",
        "periodStart": "string (YYYY-MM-DD, empty if not found)"
      },
      {
        "resourceType": "DiagnosticReport",
        "reportName": "string (lab test or report name, empty if not a lab report)",
        "conclusion": "string (empty if not found)",
        "issuedDate": "string (YYYY-MM-DD, empty if not found)"
      }
    ]
  ''';

  @override
  String get promptExample => '''
    Medical Text: "Patient Smith, John (DOB: 1985-02-20, Male, CNP: 1850220123456) visited General Hospital on April 2nd, 2024."

    [{"resourceType":"Patient","givenName":"John","familyName":"Smith","dateOfBirth":"1985-02-20","gender":"male","patientMRN":"1850220123456","identifierLabel":"CNP","documentCategory":"visit"},{"resourceType":"Encounter","encounterType":"General Hospital","periodStart":"2024-04-02"},{"resourceType":"DiagnosticReport","reportName":"","conclusion":"","issuedDate":""}]
  ''';
}
