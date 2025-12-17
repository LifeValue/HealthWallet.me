import 'package:health_wallet/features/scan/data/model/prompt_template/prompt_template.dart';

class BasicInfoPrompt extends PromptTemplate {
  @override
  String get promptResourceType =>
      "basic patient demographic information and encounter details";

  @override
  String get promptJsonStructure => '''
    [
      {
        "resourceType": "Patient",
        "familyName": "string",
        "givenName": "string",
        "dateOfBirth": "string (YYYY-MM-DD)",
        "gender": "male | female | other | unknown",
      },
      {
        "resourceType": "Encounter",
        "location": "string",
        "periodStart": "string (YYYY-MM-DD)"
      }
    ]
  ''';

  @override
  String get promptExample => '''
    Medical Text: "Patient Smith, John (DOB: 1985-02-20, Gender: Male) visited General Hospital for an annual check-up on April 2nd, 2024."

    [
      {
        "resourceType": "Patient",
        "givenName": "John",
        "familyName": "Smith",
        "dateOfBirth": "1985-02-20",
        "gender": "male"
      },
      {
        "resourceType": "Encounter",
        "location": "General Hospital",
        "periodStart": "2024-04-02"
      }
    ]
  ''';
}
