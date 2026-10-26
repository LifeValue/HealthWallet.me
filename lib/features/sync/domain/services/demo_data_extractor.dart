import 'package:health_wallet/core/utils/logger.dart';

/// Helper class for extracting meaningful titles and dates from raw FHIR demo data
class DemoDataExtractor {
  /// Safely extract title from demo resource
  static String extractTitle(Map<String, dynamic> resource) {
    String title = '';
    final resourceType = resource['resourceType'] as String? ?? 'Unknown';

    // Resource-specific title extraction
    switch (resourceType) {
      case 'Patient':
        title = _extractPatientTitle(resource);
        break;
      case 'Organization':
        title = _extractOrganizationTitle(resource);
        break;
      case 'Practitioner':
        title = _extractPractitionerTitle(resource);
        break;
      case 'Observation':
        title = _extractObservationTitle(resource);
        break;
      case 'Encounter':
        title = _extractEncounterTitle(resource);
        break;
      case 'Condition':
        title = _extractConditionTitle(resource);
        break;
      case 'Medication':
        title = _extractMedicationTitle(resource);
        break;
      case 'Procedure':
        title = _extractProcedureTitle(resource);
        break;
      default:
        title = _extractGenericTitle(resource);
    }

    // Fallback title if none extracted
    if (title.isEmpty) {
      final resourceId = resource['id'] as String? ?? 'Unknown';
      title = '$resourceType $resourceId';
    }

    return title;
  }

  /// Safely extract date from demo resource
  static DateTime? extractDate(Map<String, dynamic> resource) {
    final dateFields = [
      'effectiveDateTime',
      'issued',
      'performedDateTime',
      'occurrenceDateTime',
      'created',
      'recordedDate',
      'onsetDateTime',
    ];

    for (final field in dateFields) {
      try {
        if (resource[field] != null && resource[field] is String) {
          try {
            final date = DateTime.parse(resource[field] as String);
            return date;
          } catch (e) {
            logger.w(
              '⚠️ Failed to parse date from $field: ${resource[field]} - $e',
            );
          }
        }
      } catch (e) {
        logger.w('⚠️ Error accessing date field $field: $e');
      }
    }

    return null;
  }

  /// Extract title for Patient resources
  static String _extractPatientTitle(Map<String, dynamic> resource) {
    if (resource['name'] != null && resource['name'] is List) {
      try {
        final nameList = resource['name'] as List;
        if (nameList.isNotEmpty && nameList[0] != null) {
          final name = nameList[0];
          if (name is Map<String, dynamic>) {
            if (name['text'] != null && name['text'] is String) {
              final title = name['text'] as String;
              return title;
            } else if (name['family'] != null &&
                name['given'] != null &&
                name['family'] is String &&
                name['given'] is List) {
              final given = name['given'] as List;
              final family = name['family'] as String;
              if (given.isNotEmpty && given[0] != null && given[0] is String) {
                final title = '${given[0]} $family';
                return title;
              }
            }
          }
        }
      } catch (e) {
        logger.w('⚠️ Error processing Patient name field: $e');
      }
    }
    return '';
  }

  /// Extract title for Organization resources
  static String _extractOrganizationTitle(Map<String, dynamic> resource) {
    if (resource['name'] != null && resource['name'] is String) {
      final title = resource['name'] as String;
      return title;
    }
    return '';
  }

  /// Extract title for Practitioner resources
  static String _extractPractitionerTitle(Map<String, dynamic> resource) {
    if (resource['name'] != null && resource['name'] is List) {
      try {
        final nameList = resource['name'] as List;
        if (nameList.isNotEmpty && nameList[0] != null) {
          final name = nameList[0];
          if (name is Map<String, dynamic>) {
            final prefix =
                name['prefix'] != null &&
                    name['prefix'] is List &&
                    (name['prefix'] as List).isNotEmpty
                ? '${(name['prefix'] as List)[0]} '
                : '';
            final given =
                name['given'] != null &&
                    name['given'] is List &&
                    (name['given'] as List).isNotEmpty
                ? '${(name['given'] as List)[0]} '
                : '';
            final family = name['family'] ?? '';
            if (family.isNotEmpty) {
              final title = '$prefix$given$family'.trim();
              return title;
            }
          }
        }
      } catch (e) {
        logger.w('⚠️ Error processing Practitioner name field: $e');
      }
    }
    return '';
  }

  /// Extract title for Observation resources
  static String _extractObservationTitle(Map<String, dynamic> resource) {
    // Try code.text first
    if (resource['code'] != null && resource['code'] is Map<String, dynamic>) {
      final code = resource['code'] as Map<String, dynamic>;
      if (code['text'] != null && code['text'] is String) {
        final title = code['text'] as String;
        return title;
      }
      // Try code.coding[].display
      if (code['coding'] != null && code['coding'] is List) {
        final coding = code['coding'] as List;
        if (coding.isNotEmpty &&
            coding[0] != null &&
            coding[0] is Map<String, dynamic>) {
          final firstCoding = coding[0] as Map<String, dynamic>;
          if (firstCoding['display'] != null &&
              firstCoding['display'] is String) {
            final title = firstCoding['display'] as String;
            return title;
          }
        }
      }
    }
    return '';
  }

  /// Extract title for Encounter resources
  static String _extractEncounterTitle(Map<String, dynamic> resource) {
    // Try type[].text first
    if (resource['type'] != null && resource['type'] is List) {
      final typeList = resource['type'] as List;
      if (typeList.isNotEmpty &&
          typeList[0] != null &&
          typeList[0] is Map<String, dynamic>) {
        final type = typeList[0] as Map<String, dynamic>;
        if (type['text'] != null && type['text'] is String) {
          final title = type['text'] as String;
          return title;
        }
        // Try type[].coding[].display
        if (type['coding'] != null && type['coding'] is List) {
          final coding = type['coding'] as List;
          if (coding.isNotEmpty &&
              coding[0] != null &&
              coding[0] is Map<String, dynamic>) {
            final firstCoding = coding[0] as Map<String, dynamic>;
            if (firstCoding['display'] != null &&
                firstCoding['display'] is String) {
              final title = firstCoding['display'] as String;
              return title;
            }
          }
        }
      }
    }
    return '';
  }

  /// Extract title for Condition resources
  static String _extractConditionTitle(Map<String, dynamic> resource) {
    // Try code.text first
    if (resource['code'] != null && resource['code'] is Map<String, dynamic>) {
      final code = resource['code'] as Map<String, dynamic>;
      if (code['text'] != null && code['text'] is String) {
        final title = code['text'] as String;
        return title;
      }
      // Try code.coding[].display
      if (code['coding'] != null && code['coding'] is List) {
        final coding = code['coding'] as List;
        if (coding.isNotEmpty &&
            coding[0] != null &&
            coding[0] is Map<String, dynamic>) {
          final firstCoding = coding[0] as Map<String, dynamic>;
          if (firstCoding['display'] != null &&
              firstCoding['display'] is String) {
            final title = firstCoding['display'] as String;
            return title;
          }
        }
      }
    }
    return '';
  }

  /// Extract title for Medication resources
  static String _extractMedicationTitle(Map<String, dynamic> resource) {
    // Try code.text first
    if (resource['code'] != null && resource['code'] is Map<String, dynamic>) {
      final code = resource['code'] as Map<String, dynamic>;
      if (code['text'] != null && code['text'] is String) {
        final title = code['text'] as String;
        return title;
      }
      // Try code.coding[].display
      if (code['coding'] != null && code['coding'] is List) {
        final coding = code['coding'] as List;
        if (coding.isNotEmpty &&
            coding[0] != null &&
            coding[0] is Map<String, dynamic>) {
          final firstCoding = coding[0] as Map<String, dynamic>;
          if (firstCoding['display'] != null &&
              firstCoding['display'] is String) {
            final title = firstCoding['display'] as String;
            return title;
          }
        }
      }
    }
    return '';
  }

  /// Extract title for Procedure resources
  static String _extractProcedureTitle(Map<String, dynamic> resource) {
    // Try code.text first
    if (resource['code'] != null && resource['code'] is Map<String, dynamic>) {
      final code = resource['code'] as Map<String, dynamic>;
      if (code['text'] != null && code['text'] is String) {
        final title = code['text'] as String;
        return title;
      }
      // Try code.coding[].display
      if (code['coding'] != null && code['coding'] is List) {
        final coding = code['coding'] as List;
        if (coding.isNotEmpty &&
            coding[0] != null &&
            coding[0] is Map<String, dynamic>) {
          final firstCoding = coding[0] as Map<String, dynamic>;
          if (firstCoding['display'] != null &&
              firstCoding['display'] is String) {
            final title = firstCoding['display'] as String;
            return title;
          }
        }
      }
    }
    return '';
  }

  /// Extract title for generic resources
  static String _extractGenericTitle(Map<String, dynamic> resource) {
    // Try to extract from text.div first
    if (resource['text'] != null && resource['text'] is Map<String, dynamic>) {
      try {
        final textMap = resource['text'] as Map<String, dynamic>;
        if (textMap['div'] != null && textMap['div'] is String) {
          final title = _extractTextFromHtml(textMap['div'] as String);
          if (title.isNotEmpty) {
            return title;
          }
        }
      } catch (e) {
        logger.w('⚠️ Error processing text field: $e');
      }
    }

    // Try to extract from title field
    if (resource['title'] != null && resource['title'] is String) {
      try {
        final title = resource['title'] as String;
        return title;
      } catch (e) {
        logger.w('⚠️ Error processing title field: $e');
      }
    }

    return '';
  }

  /// Extract text content from HTML div
  static String _extractTextFromHtml(String html) {
    // Simple HTML tag removal - in production you might want a proper HTML parser
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}
