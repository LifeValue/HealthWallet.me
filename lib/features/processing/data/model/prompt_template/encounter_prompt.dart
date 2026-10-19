import 'package:health_wallet/features/processing/data/model/prompt_template/prompt_template.dart';

class EncounterPrompt extends PromptTemplate {
  @override
  String get promptResourceType => "healthcare encounters or visits";

  @override
  String get promptJsonStructure => '''
    {
      "resourceType": "Encounter",
      "encounterType": "string (e.g., check-up, emergency, consultation)",
      "location": "string",
      "periodStart": "string in YYYY-MM-DD format"
    }
  ''';

  @override
  String get promptExample => '''
    Medical Text: "Patient had an annual check-up at General Hospital on April 2nd, 2024. Admitted to the ER at City Clinic on 2024-06-01."

    [ { "resourceType": "Encounter", "encounterType": "annual check-up", "location": "General Hospital", "periodStart": "2024-04-02" }, { "resourceType": "Encounter", "encounterType": "emergency admission", "location": "City Clinic", "periodStart": "2024-06-01" } ]
  ''';
}
