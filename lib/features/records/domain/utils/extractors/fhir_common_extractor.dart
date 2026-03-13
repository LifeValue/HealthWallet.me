import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;

class FhirCommonExtractor {
  static String? extractStatus(dynamic status) {
    return status?.toString();
  }

  static String? extractCodeableConceptText(dynamic codeableConcept) {
    if (codeableConcept == null) return null;

    if (codeableConcept.toString().contains('.')) {
      return codeableConcept.toString().split('.').last;
    }

    try {
      final text = codeableConcept.text?.toString();
      if (text != null && text.isNotEmpty) return text;
    } catch (e) {}

    try {
      final coding = codeableConcept.coding;
      if (coding?.isNotEmpty == true) {
        final display = coding!.first.display?.toString();
        if (display != null && display.isNotEmpty) return display;
      }
    } catch (e) {}

    return null;
  }

  static String? extractReferenceDisplay(dynamic reference) {
    if (reference is fhir_r4.Reference) {
      return reference.display?.toString();
    }
    return null;
  }

  static String? extractDate(dynamic date) {
    return date?.toString();
  }

  static String? extractFirstCodeableConceptFromArray(
      List<dynamic>? codeableConceptArray) {
    if (codeableConceptArray == null || codeableConceptArray.isEmpty) {
      return null;
    }

    final firstConcept = codeableConceptArray.first;
    return extractCodeableConceptText(firstConcept);
  }

  static String? joinNullable(List<String?> values, String separator) {
    final nonNullStrings =
        values.where((s) => s != null && s.isNotEmpty).toList();
    return nonNullStrings.isEmpty ? null : nonNullStrings.join(separator);
  }

  static String? extractCodingDisplay(dynamic coding) {
    if (coding == null) return null;

    if (coding is fhir_r4.Coding) {
      return coding.display?.toString() ?? coding.code?.toString();
    }

    return null;
  }

  static String? extractQuantity(fhir_r4.Quantity? quantity) {
    if (quantity == null) return null;
    if (quantity.value == null) return null;

    final value = quantity.value?.valueDouble?.toStringAsFixed(2);
    final unit = quantity.unit?.toString() ?? '';

    return '$value $unit'.trim();
  }

  static String? extractAllCodeableConceptsFromArray(
      List<dynamic>? codeableConceptArray) {
    if (codeableConceptArray == null || codeableConceptArray.isEmpty) {
      return null;
    }

    final texts = codeableConceptArray
        .map((concept) => extractCodeableConceptText(concept))
        .where((text) => text != null && text.isNotEmpty)
        .toList();

    return texts.isEmpty ? null : texts.join(', ');
  }

  static String? extractFirstAnnotation(List<dynamic>? annotations) {
    if (annotations == null || annotations.isEmpty) return null;

    for (final annotation in annotations) {
      if (annotation is fhir_r4.Annotation) {
        final text = annotation.text.toString();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  static String? extractAnnotations(List<dynamic>? annotations) {
    if (annotations == null || annotations.isEmpty) return null;

    final texts = annotations
        .whereType<fhir_r4.Annotation>()
        .map((a) => a.text.toString())
        .where((text) => text.isNotEmpty)
        .toList();

    return texts.isEmpty ? null : texts.join('; ');
  }

  static String? formatAddress(fhir_r4.Address? address) {
    if (address == null) return null;
    final city = address.city?.toString();
    final state = address.state?.toString();
    final country = address.country?.toString();
    return joinNullable([city, state, country], ', ');
  }

  static String? extractMultipleReferenceDisplays(List<dynamic>? references) {
    if (references == null || references.isEmpty) return null;

    final displays = references
        .where((r) => r is fhir_r4.Reference && r.display != null)
        .map((r) => r.display!)
        .join(', ');

    return displays.isNotEmpty ? displays : null;
  }

  static String? extractDosageInstructions(List<dynamic>? dosages) {
    if (dosages == null || dosages.isEmpty) return null;

    final instructions = <String>[];
    for (final dosage in dosages) {
      if (dosage is fhir_r4.Dosage) {
        if (dosage.text != null) {
          instructions.add(dosage.text.toString());
          continue;
        }

        final parts = <String>[];

        final route = extractCodeableConceptText(dosage.route);
        if (route != null) parts.add(route);

        if (dosage.timing?.code != null) {
          final timingCode = extractCodeableConceptText(dosage.timing!.code);
          if (timingCode != null) parts.add(timingCode);
        }

        if (dosage.doseAndRate != null && dosage.doseAndRate!.isNotEmpty) {
          final doseAndRate = dosage.doseAndRate!.first;
          final doseQuantity = doseAndRate.doseX?.isAs<fhir_r4.Quantity>();
          if (doseQuantity != null) {
            parts.add('${doseQuantity.value} ${doseQuantity.unit ?? ''}');
          }
        }

        if (parts.isNotEmpty) {
          instructions.add(parts.join(', '));
        }
      }
    }

    return instructions.isEmpty ? null : instructions.join('; ');
  }

  static String? extractDosage(List<fhir_r4.Dosage>? dosages) {
    if (dosages == null || dosages.isEmpty) return null;

    final dosage = dosages.first;

    if (dosage.text?.valueString != null) {
      return dosage.text!.valueString;
    }

    final parts = <String>[];

    if (dosage.doseAndRate != null && dosage.doseAndRate!.isNotEmpty) {
      final doseAndRate = dosage.doseAndRate!.first;
      final doseQuantity = doseAndRate.doseX?.isAs<fhir_r4.Quantity>();
      if (doseQuantity != null) {
        final value = doseQuantity.value?.valueDouble?.toStringAsFixed(0);
        final unit = doseQuantity.unit?.valueString;
        if (value != null) {
          parts.add('$value${unit != null ? ' $unit' : ''}');
        }
      }
    }

    final route = extractCodeableConceptText(dosage.route);
    if (route != null) parts.add(route);

    if (dosage.timing?.code != null) {
      final timing = extractCodeableConceptText(dosage.timing!.code);
      if (timing != null) parts.add(timing);
    }

    return parts.isEmpty ? null : parts.join(', ');
  }

  static String? extractReasonCodes(List<dynamic>? reasonCodes) {
    return extractAllCodeableConceptsFromArray(reasonCodes);
  }

  static String? extractReasonReferences(List<dynamic>? reasonReferences) {
    return extractMultipleReferenceDisplays(reasonReferences);
  }

  static String? extractFirstIdentifier(
      List<fhir_r4.Identifier>? identifiers) {
    if (identifiers == null || identifiers.isEmpty) return null;

    for (final identifier in identifiers) {
      if (identifier.value != null) {
        return identifier.value.toString();
      }
    }
    return null;
  }

  static String? extractServiceType(List<dynamic>? serviceTypes) {
    return extractFirstCodeableConceptFromArray(serviceTypes);
  }

  static String? extractPriority(dynamic priority) {
    if (priority == null) return null;
    return priority.toString().split('.').last;
  }

  static String? extractIntent(dynamic intent) {
    if (intent == null) return null;
    return intent.toString().split('.').last;
  }

  static String? extractPerformers(List<dynamic>? performers) {
    if (performers == null || performers.isEmpty) return null;

    final names = <String>[];
    for (final performer in performers) {
      if (performer is fhir_r4.Reference) {
        final display = performer.display?.toString();
        if (display != null && display.isNotEmpty) {
          names.add(display);
        }
      } else if (performer is fhir_r4.ProcedurePerformer) {
        final display = performer.actor.display?.toString();
        if (display != null && display.isNotEmpty) {
          names.add(display);
        }
      } else {
        try {
          final actor = (performer as dynamic).actor;
          if (actor is fhir_r4.Reference) {
            final display = actor.display?.toString();
            if (display != null && display.isNotEmpty) {
              names.add(display);
            }
          }
        } catch (_) {}
      }
    }

    return names.isEmpty ? null : names.join(', ');
  }

  static String? extractParticipants(List<dynamic>? participants) {
    if (participants == null || participants.isEmpty) return null;

    final names = <String>[];
    for (final participant in participants) {
      try {
        final individual = (participant as dynamic).individual;
        if (individual is fhir_r4.Reference) {
          final display = individual.display?.toString();
          if (display != null && display.isNotEmpty) {
            names.add(display);
          }
        }
      } catch (_) {}

      try {
        final member = (participant as dynamic).member;
        if (member is fhir_r4.Reference) {
          final display = member.display?.toString();
          if (display != null && display.isNotEmpty) {
            names.add(display);
          }
        }
      } catch (_) {}
    }

    return names.isEmpty ? null : names.join(', ');
  }

  static String? extractLocations(List<dynamic>? locations) {
    if (locations == null || locations.isEmpty) return null;

    final names = <String>[];
    for (final location in locations) {
      try {
        final loc = (location as dynamic).location;
        if (loc is fhir_r4.Reference) {
          final display = loc.display?.toString();
          if (display != null && display.isNotEmpty) {
            names.add(display);
          }
        }
      } catch (_) {}

      if (location is fhir_r4.Reference) {
        final display = location.display?.toString();
        if (display != null && display.isNotEmpty) {
          names.add(display);
        }
      }
    }

    return names.isEmpty ? null : names.join(', ');
  }

  static String? extractDiagnoses(List<dynamic>? diagnoses) {
    if (diagnoses == null || diagnoses.isEmpty) return null;

    final names = <String>[];
    for (final diagnosis in diagnoses) {
      try {
        final condition = (diagnosis as dynamic).condition;
        if (condition is fhir_r4.Reference) {
          final display = condition.display?.toString();
          if (display != null && display.isNotEmpty) {
            names.add(display);
          }
        }
      } catch (_) {}
    }

    return names.isEmpty ? null : names.join(', ');
  }
}
