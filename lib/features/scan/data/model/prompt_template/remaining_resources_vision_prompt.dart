import 'package:health_wallet/features/scan/data/model/prompt_template/correction_template_loader.dart';

class RemainingResourcesVisionPrompt {
  final String? documentCategory;
  final String? ocrText;
  final String? fewShotExample;
  final int maxOcrLength;
  final bool includeFewShot;

  RemainingResourcesVisionPrompt({
    this.documentCategory,
    this.ocrText,
    this.fewShotExample,
    this.maxOcrLength = 2000,
    this.includeFewShot = true,
  });

  static Future<RemainingResourcesVisionPrompt> create({
    String? documentCategory,
    String? ocrText,
    int maxOcrLength = 2000,
    bool includeFewShot = true,
  }) async {
    String? example;
    if (includeFewShot) {
      example = await CorrectionTemplateLoader().getBestExample(
        documentCategory: documentCategory,
        ocrText: ocrText,
      );
    }
    return RemainingResourcesVisionPrompt(
      documentCategory: documentCategory,
      ocrText: ocrText,
      fewShotExample: example,
      maxOcrLength: maxOcrLength,
      includeFewShot: includeFewShot,
    );
  }

  String buildPrompt() {
    final resourceSchemas = documentCategory == 'lab_report'
        ? _labReportSchemas
        : documentCategory == 'visit'
            ? _visitSchemas
            : _defaultSchemas;

    final truncatedOcr = ocrText != null && ocrText!.isNotEmpty
        ? (ocrText!.length > maxOcrLength
            ? ocrText!.substring(0, maxOcrLength)
            : ocrText!)
        : null;
    final ocrSection = truncatedOcr != null
        ? '\nOCR text from this document (use for exact values):\n---\n$truncatedOcr\n---\n'
        : '';

    final exampleSection = includeFewShot && fewShotExample != null
        ? '\n--- EXAMPLE OUTPUT (for structure reference only, do NOT copy this data) ---\n$fewShotExample\n--- END EXAMPLE ---\n'
        : '';

    return '''Extract all medical data from this document image.$ocrSection
Return ONLY a JSON array with these schemas:

$resourceSchemas
$exampleSection
Rules:
- Return ONLY a JSON array, no other text
- Do NOT include Patient, Encounter, or DiagnosticReport resources (those are extracted separately)
- Use empty string for missing fields
- For dates use YYYY-MM-DD format
- Each object must have a "resourceType" field
- CRITICAL: Each test name MUST be paired with its own correct value. In tables, match values on the same row. Never shift or swap values between different tests
- Observations are ONLY for measurable numeric values (lab results, vital signs with numbers). Do NOT create Observations for clinical exam findings
- For vital signs: value must be numeric only (no units in value). BMI is a small number (15-50), Weight is in kg or lb
- Conditions = actual diagnoses ONLY (e.g. "Fracture", "Contusion", "Hypertension"). Do NOT create Conditions from section headers (Anamnèse, ATCD, Examen), exam findings, or history notes
- Keep it concise: extract only the key medical facts, not every sentence from the document
- Avoid duplicates: do not create multiple resources for the same finding''';
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
