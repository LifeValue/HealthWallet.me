/// Prompts for the unconstrained draft call of `schemaDraft` mode: the model
/// first writes short notes in free text, then a constrained call turns the
/// notes and the OCR text into the schema object.
class DraftPrompt {
  DraftPrompt._();

  /// Draft call token limit.
  static const maxTokens = 384;

  static String _ocrSection(String ocrText, int maxLength) {
    if (ocrText.trim().isEmpty) return '';
    final truncated = ocrText.length > maxLength
        ? ocrText.substring(0, maxLength)
        : ocrText;
    return '\nOCR text from this document:\n---\n$truncated\n---\n';
  }

  static String _source(bool vision) =>
      vision ? 'this medical document image' : 'this medical document';

  /// Phase 1 and container-only: the patient and the document.
  static String basicInfo(String ocrText, {bool vision = false}) =>
      '''Read ${_source(vision)} and write short notes, one fact per line, copying values exactly as printed.${_ocrSection(ocrText, 1500)}
Note: the patient's surname and first name, birth date, gender, the patient ID number and what kind of ID it is, the document heading, the document or visit date, whether it is a lab test report or a visit document, and the report's conclusion if there is one.
Write plain text lines, no JSON.''';

  /// Phase 2: the medical facts of a [documentCategory] document.
  static String remaining(
    String ocrText, {
    String? documentCategory,
    bool vision = false,
  }) {
    final what = switch (documentCategory) {
      'lab_report' => 'every lab test with its value, unit and reference range on one line each (keep each value on the row of its own test), then the doctors and the laboratory or hospital with address and phone',
      'visit' => 'the diagnoses with their dates, medications with dosage, procedures with dates, allergies, vital signs with values and units, then the doctors and the hospital or clinic with address and phone',
      _ => 'lab tests with value, unit and reference range, diagnoses with dates, medications with dosage, procedures, allergies, vital signs, doctors, and hospitals or labs with address and phone',
    };
    return '''Read ${_source(vision)} and write short notes, one fact per line, copying names, values and dates exactly as printed.${_ocrSection(ocrText, 2000)}
Note $what.
Leave out the patient's personal details. Write plain text lines, no JSON.''';
  }

  /// Draft characters a constrained prompt carries: the drafts of several
  /// vision batches are joined, and the whole prompt must fit a 4096 context.
  static const maxSectionLength = 1600;

  /// The draft section of a constrained prompt, capped at
  /// [maxSectionLength]; empty without a draft.
  static String section(String? draft) {
    final text = draft?.trim() ?? '';
    if (text.isEmpty) return '';
    final capped = text.length > maxSectionLength
        ? text.substring(0, maxSectionLength)
        : text;
    return '\nNotes from a first reading of this document (check every value against the OCR text):\n---\n$capped\n---\n';
  }
}
