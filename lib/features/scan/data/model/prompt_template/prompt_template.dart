import 'package:health_wallet/features/scan/data/model/prompt_template/allergy_intolerance_prompt.dart';
import 'package:health_wallet/features/scan/data/model/prompt_template/condition_prompt.dart';
import 'package:health_wallet/features/scan/data/model/prompt_template/diagnostic_report_prompt.dart';
import 'package:health_wallet/features/scan/data/model/prompt_template/encounter_prompt.dart';
import 'package:health_wallet/features/scan/data/model/prompt_template/medication_statement_prompt.dart';
import 'package:health_wallet/features/scan/data/model/prompt_template/observation_prompt.dart';
import 'package:health_wallet/features/scan/data/model/prompt_template/organization_prompt.dart';
import 'package:health_wallet/features/scan/data/model/prompt_template/patient_prompt.dart';
import 'package:health_wallet/features/scan/data/model/prompt_template/practitioner_prompt.dart';
import 'package:health_wallet/features/scan/data/model/prompt_template/procedure_prompt.dart';

abstract class PromptTemplate {
  String buildPrompt(String medicalText) {
    return '''
      <start_of_turn>user
      You are a specialized AI medical data extractor. Your primary function is to meticulously parse clinical documents and extract all present $promptResourceType with high precision. Structure the output as a clean, simple list of JSON objects. Adhere strictly to the provided schema and value formats. Ignore all information not related to $promptResourceType. Your work is inspired by FHIR principles for data interoperability.

      The output must be a list of JSON objects. The JSON in the list objects must follow this exact structure:

      $promptJsonStructure

      ---
      ### EXAMPLE OF FORMATTING
      This example demonstrates the required JSON structure and style.
      $promptExample

      ### CRITICAL INSTRUCTION
      The example above is for structure ONLY. Do not use the data from the example in your final response. Base your output exclusively on the "Medical Text" provided in the task section below. Do not return any additional text or markdown other than the list of JSON objects. If no $promptResourceType is found in the medical text, return an empty list: []
      ---

      ### TASK
      From the medical text provided below, extract the details for all occurences of $promptResourceType found.

      Medical Text: "$medicalText"<end_of_turn> <start_of_turn>model
    ''';
  }

  String get promptResourceType;
  String get promptJsonStructure;
  String get promptExample;

  static supportedPrompts() => [
        AllergyIntolerancePrompt(),
        ConditionPrompt(),
        DiagnosticReportPrompt(),
        MedicationStatementPrompt(),
        ObservationPrompt(),
        OrganizationPrompt(),
        PractitionerPrompt(),
        ProcedurePrompt(),
      ];
}
