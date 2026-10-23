import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;

/// Centralized utility for extracting dates from FHIR resources
/// Moves date extraction logic out of entities and into a dedicated utility
class FhirDateExtractor {
  /// Extract date from FhirDateTime
  static DateTime? extractFromFhirDateTime(dynamic fhirDateTime) {
    if (fhirDateTime == null) return null;

    try {
      if (fhirDateTime is fhir_r4.FhirDateTime) {
        return DateTime.parse(fhirDateTime.toString());
      } else if (fhirDateTime is fhir_r4.FhirDate) {
        return DateTime.parse(fhirDateTime.toString());
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Extract date from Period (prefers start date, falls back to end date)
  static DateTime? extractFromPeriod(dynamic period) {
    if (period == null) return null;

    try {
      if (period is fhir_r4.Period) {
        // Try start date first
        if (period.start != null) {
          return DateTime.parse(period.start!.toString());
        }
        // Fall back to end date
        if (period.end != null) {
          return DateTime.parse(period.end!.toString());
        }
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Extract date from union types (effectiveX, performedX, occurrenceX, etc.)
  static DateTime? extractFromUnionType(dynamic unionType) {
    if (unionType == null) return null;

    try {
      if (unionType is fhir_r4.FhirDateTime) {
        return DateTime.parse(unionType.toString());
      } else if (unionType is fhir_r4.FhirDate) {
        return DateTime.parse(unionType.toString());
      } else if (unionType is fhir_r4.Period) {
        return extractFromPeriod(unionType);
      } else if (unionType is fhir_r4.FhirString) {
        // Some union types might be strings
        return DateTime.parse(unionType.toString());
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Extract date from multiple possible sources with fallback
  static DateTime? extractWithFallback({
    dynamic primary,
    dynamic secondary,
    DateTime? fallback,
  }) {
    // Try primary source first
    DateTime? extractedDate = extractFromUnionType(primary);
    if (extractedDate != null) return extractedDate;

    // Try secondary source
    extractedDate = extractFromUnionType(secondary);
    if (extractedDate != null) return extractedDate;

    // Return fallback
    return fallback;
  }

  /// Extract date from specific FHIR resource types
  static DateTime? extractFromResource(
    String resourceType,
    Map<String, dynamic> resourceData,
  ) {
    switch (resourceType) {
      case 'Patient':
        return extractFromFhirDateTime(resourceData['birthDate']);

      case 'Observation':
        return extractWithFallback(
          primary: resourceData['effectiveX'],
          secondary: resourceData['issued'],
        );

      case 'Encounter':
        return extractFromPeriod(resourceData['period']);

      case 'Procedure':
        return extractFromUnionType(resourceData['performedX']);

      case 'Immunization':
        return extractFromUnionType(resourceData['occurrenceX']);

      case 'DiagnosticReport':
        return extractWithFallback(
          primary: resourceData['effectiveX'],
          secondary: resourceData['issued'],
        );

      case 'Claim':
        return extractFromFhirDateTime(resourceData['created']);

      case 'Condition':
        return extractWithFallback(
          primary: resourceData['onsetX'],
          secondary: resourceData['abatementX'],
        );

      case 'MedicationRequest':
        return extractFromFhirDateTime(resourceData['authoredOn']);

      case 'MedicationStatement':
        return extractFromFhirDateTime(resourceData['dateAsserted']);

      case 'ServiceRequest':
        return extractFromUnionType(resourceData['occurrenceX']);

      default:
        return null;
    }
  }
}
