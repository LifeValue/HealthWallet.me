import 'package:health_wallet/features/processing/data/model/prompt_template/prompt_template.dart';

class ProcedurePrompt extends PromptTemplate {
  @override
  String get promptResourceType => "medical procedures or surgeries";

  @override
  String get promptJsonStructure => '''
    {
      "resourceType": "Procedure",
      "procedureName": "string",
      "performedDateTime": "string in YYYY-MM-DD format",
      "reason": "string (the condition it was performed for)"
    }
  ''';

  @override
  String get promptExample => '''
    Medical Text: "An appendectomy was performed on 2024-07-21 due to acute appendicitis. Patient also had a routine colonoscopy last year."

    [ { "resourceType": "Procedure", "procedureName": "Appendectomy", "performedDateTime": "2024-07-21", "reason": "acute appendicitis" }, { "resourceType": "Procedure", "procedureName": "Colonoscopy", "performedDateTime": "", "reason": "routine" } ]
  ''';
}
