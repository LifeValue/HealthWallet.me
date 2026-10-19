import 'package:health_wallet/features/processing/data/model/prompt_template/prompt_template.dart';

class AllergyIntolerancePrompt extends PromptTemplate {
  @override
  String get promptResourceType => "patient allergies or intolerances";

  @override
  String get promptJsonStructure => '''
    {
      "resourceType": "AllergyIntolerance",
      "substance": "string",
      "manifestation": "string (the symptom, e.g., hives, anaphylaxis)",
      "category": "string, one of: food, medication, environment"
    }
  ''';

  @override
  String get promptExample => '''
    Medical Text: "Patient is allergic to penicillin, which causes hives. Also has a lactose intolerance."

    [ { "resourceType": "AllergyIntolerance", "substance": "Penicillin", "manifestation": "Hives", "category": "medication" }, { "resourceType": "AllergyIntolerance", "substance": "Lactose", "manifestation": "Digestive upset", "category": "food" } ]
  ''';
}
