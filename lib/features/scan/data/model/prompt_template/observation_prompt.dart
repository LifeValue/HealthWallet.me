import 'package:health_wallet/features/scan/data/model/prompt_template/prompt_template.dart';

class ObservationPrompt extends PromptTemplate {
  @override
  String get promptResourceType =>
      "clinical observations like vital signs or lab results";

  @override
  String get promptJsonStructure => '''
    {
      "resourceType": "Observation",
      "observationName": "string",
      "value": "string",
      "unit": "string",
      "referenceRange": "string (e.g., < 35, 8.8 - 10.2, > 3.5, empty if not available)"
    }
  ''';

  @override
  String get promptExample => '''
    Medical Text: "Lab Results - Creatinine: 2.06 mg/dL (ref: 0.7-1.2). Glucose: 95 mg/dL (ref: 70-100). Heart rate is 78 bpm."

    [ { "resourceType": "Observation", "observationName": "Creatinine", "value": "2.06", "unit": "mg/dL", "referenceRange": "0.7 - 1.2" }, { "resourceType": "Observation", "observationName": "Glucose", "value": "95", "unit": "mg/dL", "referenceRange": "70 - 100" }, { "resourceType": "Observation", "observationName": "Heart rate", "value": "78", "unit": "bpm", "referenceRange": "" } ]
  ''';
}
