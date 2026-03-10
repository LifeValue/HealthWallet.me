import 'package:health_wallet/features/scan/data/model/prompt_template/correction_template_loader.dart';

class RemainingResourcesVisionPrompt {
  final String? documentCategory;
  final String? ocrText;
  final String? fewShotExample;

  RemainingResourcesVisionPrompt({
    this.documentCategory,
    this.ocrText,
    this.fewShotExample,
  });

  static Future<RemainingResourcesVisionPrompt> create({
    String? documentCategory,
    String? ocrText,
  }) async {
    final example = await CorrectionTemplateLoader().getBestExample(
      documentCategory: documentCategory,
      ocrText: ocrText,
    );
    return RemainingResourcesVisionPrompt(
      documentCategory: documentCategory,
      ocrText: ocrText,
      fewShotExample: example,
    );
  }

  String buildPrompt() {
    final resourceSchemas = documentCategory == 'lab_report'
        ? _labReportSchemas
        : documentCategory == 'visit'
            ? _visitSchemas
            : _defaultSchemas;

    final truncatedOcr = ocrText != null && ocrText!.isNotEmpty
        ? (ocrText!.length > 2000 ? ocrText!.substring(0, 2000) : ocrText!)
        : null;
    final ocrSection = truncatedOcr != null
        ? '\nOCR text from this document (use for exact values):\n---\n$truncatedOcr\n---\n'
        : '';

    final exampleSection = fewShotExample != null
        ? '\n--- EXAMPLE OUTPUT (for structure reference only, do NOT copy this data) ---\n$fewShotExample\n--- END EXAMPLE ---\n'
        : '';

    return '''Extract all medical data from this document image.$ocrSection
Return ONLY a JSON array with these schemas:

$resourceSchemas
$exampleSection
Rules:
- Return ONLY a JSON array, no other text
- Use empty string for missing fields
- Only include resources clearly visible in the document
- For dates use YYYY-MM-DD format
- Each object must have a "resourceType" field
- Include ALL instances found (e.g. all lab results, all conditions)
- CRITICAL: Each test name MUST be paired with its own correct value. In tables, match values on the same row. In inline text (e.g. "Creatinina=0.71 mg/dl"), extract the value immediately after the test name. Never shift or swap values between different tests
- For vital signs: value must be numeric only (no units in value). BMI is a small number (15-50), Weight is in kg or lb. Do NOT confuse them''';
  }

  static const _observationSchema =
      '{"resourceType":"Observation","observationName":"string","value":"numeric string only (e.g. 98.5, 120, 27.56) - never include units in value","unit":"string","referenceRange":"string (e.g. 0.7 - 1.2)"}';

  static const _conditionSchema =
      '{"resourceType":"Condition","conditionName":"string","onsetDateTime":"YYYY-MM-DD","clinicalStatus":"active|resolved|inactive"}';

  static const _medicationSchema =
      '{"resourceType":"MedicationStatement","medicationName":"string","dosage":"string (e.g. 500mg twice daily)","reason":"string"}';

  static const _procedureSchema =
      '{"resourceType":"Procedure","procedureName":"string","performedDateTime":"YYYY-MM-DD","reason":"string"}';

  static const _allergySchema =
      '{"resourceType":"AllergyIntolerance","substance":"string","manifestation":"string","category":"food|medication|environment"}';

  static const _practitionerSchema =
      '{"resourceType":"Practitioner","practitionerName":"string","specialty":"string","identifier":"string"}';

  static const _organizationSchema =
      '{"resourceType":"Organization","organizationName":"string","address":"string","phone":"string"}';

  static const _labReportSchemas = '''Observation (lab results, vital signs):
$_observationSchema

Condition (diagnoses):
$_conditionSchema

Practitioner (doctors):
$_practitionerSchema

Organization (hospitals, labs):
$_organizationSchema''';

  static const _visitSchemas = '''Condition (diagnoses):
$_conditionSchema

MedicationStatement (medications):
$_medicationSchema

Procedure (surgeries, procedures):
$_procedureSchema

Practitioner (doctors):
$_practitionerSchema

Observation (vital signs, measurements):
$_observationSchema

AllergyIntolerance (allergies):
$_allergySchema

Organization (hospitals, clinics):
$_organizationSchema''';

  static const _defaultSchemas = '''Observation (lab results, vital signs):
$_observationSchema

Condition (diagnoses):
$_conditionSchema

MedicationStatement (medications):
$_medicationSchema

Procedure (surgeries, procedures):
$_procedureSchema

AllergyIntolerance (allergies):
$_allergySchema

Practitioner (doctors):
$_practitionerSchema

Organization (hospitals, clinics):
$_organizationSchema''';
}
