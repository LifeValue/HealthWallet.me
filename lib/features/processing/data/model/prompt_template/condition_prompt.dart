import 'package:health_wallet/features/processing/data/model/prompt_template/prompt_template.dart';

class ConditionPrompt extends PromptTemplate {
  @override
  String get promptResourceType => "patient's medical conditions or diagnoses";

  @override
  String get promptJsonStructure => '''
    {
      "resourceType": "Condition",
      "conditionName": "string",
      "onsetDateTime": "string in YYYY-MM-DD format",
      "clinicalStatus": "string, one of: active, resolved, inactive"
    }
  ''';

  @override
  String get promptExample => '''
    Medical Text: "Diagnosed with Type 2 Diabetes on 2023-05-10. Hypertension is ongoing. History of asthma, now resolved."

    [ { "resourceType": "Condition", "conditionName": "Type 2 Diabetes", "onsetDateTime": "2023-05-10", "clinicalStatus": "active" }, { "resourceType": "Condition", "conditionName": "Hypertension", "onsetDateTime": "", "clinicalStatus": "active" }, { "resourceType": "Condition", "conditionName": "Asthma", "onsetDateTime": "", "clinicalStatus": "resolved" } ]
  ''';
}
