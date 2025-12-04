import 'package:health_wallet/features/scan/data/model/prompt_template/prompt_template.dart';

class PatientPrompt extends PromptTemplate {
  @override
  String get promptResourceType => "patient demographic information";

  @override
  String get promptJsonStructure => '''
    {
      "resourceType": "Patient",
      "familyName": "string",
      "givenName": "string",
      "dateOfBirth": "string in YYYY-MM-DD format",
      "gender": "string, one of: male, female, other",
      "patientMRN": "string"
    }
  ''';

  @override
  String get promptExample => '''
    Medical Text: "Patient: Smith, John. DOB: 1985-02-20. Gender: Male. Pt is here for a checkup."

    [{ "resourceType": "Patient", "givenName": "John", "familyName": "Smith", "dateOfBirth": "1985-02-20", "gender": "male" }]
  ''';
}
