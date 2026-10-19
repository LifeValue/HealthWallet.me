import 'package:health_wallet/features/processing/data/model/prompt_template/prompt_template.dart';

class DiagnosticReportPrompt extends PromptTemplate {
  @override
  String get promptResourceType =>
      "diagnostic reports like lab results or imaging studies";

  @override
  String get promptJsonStructure => '''
    {
      "resourceType": "DiagnosticReport",
      "reportName": "string",
      "conclusion": "string (the summary or key finding)",
      "issuedDate": "string in YYYY-MM-DD format"
    }
  ''';

  @override
  String get promptExample => '''
    Medical Text: "Chest X-Ray from 2024-01-15 shows no signs of pneumonia. Conclusion: Lungs are clear. A complete blood count was also performed."

    [ { "resourceType": "DiagnosticReport", "reportName": "Chest X-Ray", "conclusion": "Lungs are clear", "issuedDate": "2024-01-15" }, { "resourceType": "DiagnosticReport", "reportName": "Complete Blood Count", "conclusion": "", "issuedDate": "" } ]
  ''';
}
