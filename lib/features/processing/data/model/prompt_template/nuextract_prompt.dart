import 'dart:convert';

import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/features/processing/data/model/structured_output/extraction_schemas.dart';

/// The chat-template kwargs of a NuExtract extraction call: the NuExtract
/// template built from the phase's flat JSON schema and, for NuExtract3 (2.0
/// has no instructions slot), the phase's rules. The OCR text goes in the user
/// message, which the template renders as the document.
class NuExtractPrompt {
  NuExtractPrompt._();

  static Map<String, dynamic> kwargs(
    PromptFamily family,
    Map<String, dynamic> schema, {
    required String schemaName,
    String? documentCategory,
  }) => {
    'template': template(schema),
    if (family == PromptFamily.nuExtract3)
      'instructions': instructions(
        schemaName,
        documentCategory: documentCategory,
      ),
  };

  /// [schema] as a NuExtract template: an object maps to its properties, an
  /// array to a one-item list, an enum to its non-empty values, a partial
  /// date to `date-time`, any other string to `string`.
  static String template(Map<String, dynamic> schema) =>
      const JsonEncoder.withIndent('  ').convert(_node(schema));

  static Object _node(Map<String, dynamic> schema) {
    switch (schema['type']) {
      case 'object':
        final properties = schema['properties'] as Map<String, dynamic>;
        return {
          for (final e in properties.entries)
            e.key: _node(e.value as Map<String, dynamic>),
        };
      case 'array':
        return [_node(schema['items'] as Map<String, dynamic>)];
    }
    final values = schema['enum'];
    if (values is List) {
      return [
        for (final v in values)
          if (v != '') v,
      ];
    }
    if (schema['pattern'] == ExtractionSchemas.datePattern) return 'date-time';
    return 'string';
  }

  static const _common =
      '- Dates as YYYY-MM-DD, or YYYY-MM / YYYY when only that is printed.\n'
      '- Empty string for a field the document does not contain.';

  static const _documentRules =
      '- documentCategory: "lab_report" only for standalone lab test results (blood, urine, imaging reports); '
      '"visit" for discharge letters, admission and consultation notes, referrals, prescriptions and any other visit document.\n'
      '- documentTitle: the document heading at the top, not a diagnosis.\n'
      '- documentDate: the date the document was issued.\n'
      '- conclusion: the lab report\'s conclusion; empty for visits.';

  static String instructions(String schemaName, {String? documentCategory}) {
    switch (schemaName) {
      case 'basic_info':
        return '- Extract the patient and the document, not the doctor or the hospital.\n'
            '- patientIdentifier: the patient\'s national or insurance ID number; identifierLabel: its type.\n'
            '$_documentRules\n$_common';
      case 'container':
        return '$_documentRules\n$_common';
    }
    final sections = ExtractionSchemas.sectionsFor(documentCategory);
    return [
      for (final s in sections)
        '- ${s.key}: ${s.description}, at most ${s.maxItems}.',
      if (sections.any((s) => s.resourceType == 'Observation')) '- Observation value: the number only (e.g. 98.5); the unit goes in unit.',
      _common,
    ].join('\n');
  }
}
