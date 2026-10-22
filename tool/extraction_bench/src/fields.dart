/// The scored fields of each resource type: where to read them (candidate JSON
/// paths, first non-empty wins) and how to compare them.
///
/// Only fields the pipeline's `toFhirResource` can fill are scored. The gold
/// is fixed FHIR truth, coded concepts included: the app emits codes only for
/// the patient identifier type, the encounter specialty and vital signs, so a
/// text-only prediction earns at most 0.5 on a coded concept and even a
/// perfect pipeline stays below F1 = 1. The oracle's 1.0 only checks that the
/// scorer agrees with itself.
library;

import 'comparators.dart';
import 'codes.dart' show alternativeCodingUrl;

enum FieldKind { text, exact, identifier, date, quantity, set, concept }

class FieldSpec {
  const FieldSpec(this.key, this.kind, this.paths);
  final String key;
  final FieldKind kind;

  /// Paths such as `name[0].family` or `period.start`, tried in order.
  final List<String> paths;
}

const fieldSpecs = <String, List<FieldSpec>>{
  'Patient': [
    FieldSpec('family', FieldKind.text, ['name[0].family']),
    FieldSpec('given', FieldKind.set, ['name[0].given']),
    FieldSpec('birthDate', FieldKind.date, ['birthDate']),
    FieldSpec('gender', FieldKind.exact, ['gender']),
    FieldSpec('identifier', FieldKind.identifier, ['identifier[0].value']),
  ],
  'Encounter': [
    FieldSpec('type', FieldKind.concept, ['type[0]']),
    FieldSpec('serviceType', FieldKind.concept, ['serviceType']),
    FieldSpec('periodStart', FieldKind.date, ['period.start']),
  ],
  'DiagnosticReport': [
    FieldSpec('code', FieldKind.concept, ['code']),
    FieldSpec('date', FieldKind.date, ['effectiveDateTime', 'effectivePeriod.start', 'issued']),
    FieldSpec('conclusion', FieldKind.text, ['conclusion']),
  ],
  'Observation': [
    FieldSpec('code', FieldKind.concept, ['code']),
    FieldSpec('value', FieldKind.quantity, ['valueQuantity', 'valueString', 'valueInteger']),
  ],
  'Condition': [
    FieldSpec('code', FieldKind.concept, ['code']),
    FieldSpec('onset', FieldKind.date, ['onsetDateTime', 'onsetPeriod.start']),
  ],
  'MedicationStatement': [
    FieldSpec('medication', FieldKind.concept, ['medicationCodeableConcept']),
    FieldSpec('dosage', FieldKind.text, ['dosage[0].text']),
  ],
  'AllergyIntolerance': [
    FieldSpec('substance', FieldKind.concept, ['code']),
    FieldSpec('category', FieldKind.exact, ['category[0]']),
    FieldSpec('manifestation', FieldKind.concept, ['reaction[0].manifestation[0]']),
  ],
  'Procedure': [
    FieldSpec('code', FieldKind.concept, ['code']),
    FieldSpec('performed', FieldKind.date, ['performedDateTime', 'performedPeriod.start']),
  ],
  'Practitioner': [
    FieldSpec('name', FieldKind.text, ['name[0].text']),
    FieldSpec('qualification', FieldKind.concept, ['qualification[0].code']),
    FieldSpec('identifier', FieldKind.identifier, ['identifier[0].value']),
  ],
  'Organization': [
    FieldSpec('name', FieldKind.text, ['name']),
    FieldSpec('address', FieldKind.text, ['address[0].text']),
    FieldSpec('phone', FieldKind.identifier, ['telecom[0].value']),
  ],
};

final _segment = RegExp(r'^([A-Za-z_]+)(?:\[(\d+)\])?$');

/// The raw JSON value at [path] in [json], or null.
Object? readPath(Object? json, String path) {
  Object? current = json;
  for (final part in path.split('.')) {
    final m = _segment.firstMatch(part);
    if (m == null) throw ArgumentError.value(path, 'path');
    if (current is! Map) return null;
    current = current[m.group(1)];
    final index = m.group(2);
    if (index != null) {
      if (current is! List) return null;
      final i = int.parse(index);
      if (i >= current.length) return null;
      current = current[i];
    }
  }
  return current;
}

String? _asString(Object? v) {
  if (v is String) return v.trim().isEmpty ? null : v.trim();
  if (v is num || v is bool) return '$v';
  return null;
}

/// The normalized value of [spec] in [resource], or null when it is absent
/// or empty. Text kinds give a String, `set` a List<String>, `quantity` a
/// [QuantityValue], `concept` a [ConceptValue].
Object? extractField(Map<String, dynamic> resource, FieldSpec spec) {
  for (final path in spec.paths) {
    final raw = readPath(resource, path);
    final value = switch (spec.kind) {
      FieldKind.text || FieldKind.exact || FieldKind.identifier || FieldKind.date => _asString(raw),
      FieldKind.set => switch (raw) {
          List l when l.whereType<String>().any((s) => s.trim().isNotEmpty) =>
            [for (final s in l.whereType<String>()) if (s.trim().isNotEmpty) s.trim()],
          String s when s.trim().isNotEmpty => [s.trim()],
          _ => null,
        },
      FieldKind.quantity => toQuantity(raw),
      FieldKind.concept => toConcept(raw, alternativeUrl: alternativeCodingUrl),
    };
    if (value != null) return value;
  }
  return null;
}

/// Score in [0, 1] for two non-null values of [kind].
double compareField(FieldKind kind, Object gold, Object pred) => switch (kind) {
      FieldKind.text => compareText(gold as String, pred as String),
      FieldKind.exact => compareExact(gold as String, pred as String),
      FieldKind.identifier => compareIdentifier(gold as String, pred as String),
      FieldKind.date => compareDate(gold as String, pred as String),
      FieldKind.quantity => compareQuantity(gold as QuantityValue, pred as QuantityValue),
      FieldKind.set => compareSet(gold as List<String>, pred as List<String>),
      FieldKind.concept => compareConcept(gold as ConceptValue, pred as ConceptValue),
    };
