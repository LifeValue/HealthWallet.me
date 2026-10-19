import 'package:health_wallet/features/processing/data/model/prompt_template/prompt_template.dart';

class MedicationStatementPrompt extends PromptTemplate {
  @override
  String get promptResourceType => "patient's current or past medications";

  @override
  String get promptJsonStructure => '''
    {
      "resourceType": "MedicationStatement",
      "medicationName": "string",
      "dosage": "string (e.g., 500mg twice daily)",
      "reason": "string (the condition it treats)"
    }
  ''';

  @override
  String get promptExample => '''
    Medical Text: "The patient takes Metformin 500mg twice daily for diabetes. Also prescribed Lisinopril 10mg for blood pressure."

    [ { "resourceType": "MedicationStatement", "medicationName": "Metformin", "dosage": "500mg twice daily", "reason": "diabetes" }, { "resourceType": "MedicationStatement", "medicationName": "Lisinopril", "dosage": "10mg", "reason": "blood pressure" } ]
  ''';
}
