import 'package:health_wallet/features/processing/data/model/prompt_template/prompt_template.dart';

class OrganizationPrompt extends PromptTemplate {
  @override
  String get promptResourceType =>
      "healthcare organizations like hospitals or clinics";

  @override
  String get promptJsonStructure => '''
    {
      "resourceType": "Organization",
      "organizationName": "string",
      "address": "string",
      "phone": "string"
    }
  ''';

  @override
  String get promptExample => '''
    Medical Text: "Patient was treated at Mercy General Hospital, located at 123 Health St. Their phone is 555-1234. Follow up at the Downtown Clinic."

    [ { "resourceType": "Organization", "organizationName": "Mercy General Hospital", "address": "123 Health St", "phone": "555-1234" }, { "resourceType": "Organization", "organizationName": "Downtown Clinic", "address": "", "phone": "" } ]
  ''';
}
