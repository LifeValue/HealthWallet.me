import 'package:health_wallet/features/processing/data/model/prompt_template/prompt_template.dart';

class PractitionerPrompt extends PromptTemplate {
  @override
  String get promptResourceType =>
      "healthcare practitioners like doctors or nurses";

  @override
  String get promptJsonStructure => '''
    {
      "resourceType": "Practitioner",
      "practitionerName": "string",
      "specialty": "string",
      "identifier": "string (e.g., NPI number)"
    }
  ''';

  @override
  String get promptExample => '''
    Medical Text: "The patient was seen by Dr. Emily Carter (Cardiology, NPI: 12345). Nurse John Davis assisted."

    [ { "resourceType": "Practitioner", "practitionerName": "Dr. Emily Carter", "specialty": "Cardiology", "identifier": "NPI: 12345" }, { "resourceType": "Practitioner", "practitionerName": "John Davis", "specialty": "Nurse", "identifier": "" } ]
  ''';
}
