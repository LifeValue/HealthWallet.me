import 'dart:convert';

import 'package:health_wallet/features/processing/data/utils/patient_post_processor.dart';

export 'package:health_wallet/features/processing/domain/entity/extraction_output_mode.dart';

/// One phase-2 array of the schema output: its key, the `resourceType` its
/// items map to, the item fields in prompt order and the item limit.
class RemainingSection {
  const RemainingSection._(
    this.key,
    this.resourceType,
    this.description,
    this.fields,
    this.maxItems,
  );

  final String key;
  final String resourceType;

  /// What goes in the array, for the prompt.
  final String description;

  /// Field name → (JSON schema, prompt hint), in output order.
  final List<(String, Map<String, dynamic>, String)> fields;
  final int maxItems;

  Map<String, dynamic> get itemSchema => ExtractionSchemas._object({
        for (final (name, schema, _) in fields) name: schema,
      });

  /// `{"field":"hint",…}` for the prompt.
  String get itemShape =>
      '{${[for (final (name, _, hint) in fields) '"$name":"$hint"'].join(',')}}';
}

/// Flat per-phase JSON schemas for llamadart `responseFormat`, the prompt text
/// describing each shape, and the mappers from the schema output back to the
/// `resourceType`-tagged maps `MappingResource.fromJson` reads.
///
/// Every schema is flat: no `$defs`/`$ref`/`anyOf`, every property required
/// and listed in prompt order, enums for closed sets, dates as a partial-date
/// pattern, `maxItems` on every array and `additionalProperties: false`.
class ExtractionSchemas {
  ExtractionSchemas._();

  /// `YYYY`, `YYYY-MM`, `YYYY-MM-DD` or empty. llamadart's pattern subset has
  /// no `\d`, so the digits are a class.
  static const datePattern = r'^([0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?)?$';

  static const documentCategories = ['visit', 'lab_report'];
  static const genders = ['male', 'female', 'other', 'unknown', ''];

  /// The labels `PatientPostProcessor` knows, in its order.
  static final List<String> identifierLabels = PatientPostProcessor.knownLabels.toList();
  static const clinicalStatuses = ['active', 'resolved', 'inactive', ''];
  static const allergyCategories = ['food', 'medication', 'environment', 'biologic', ''];

  static Map<String, dynamic> _string() => {'type': 'string'};
  static Map<String, dynamic> _date() => {'type': 'string', 'pattern': datePattern};
  static Map<String, dynamic> _enum(List<String> values) => {'type': 'string', 'enum': values};

  static Map<String, dynamic> _object(Map<String, Map<String, dynamic>> properties) => {
        'type': 'object',
        'properties': properties,
        'required': properties.keys.toList(),
        'additionalProperties': false,
      };

  static Map<String, dynamic> _array(Map<String, dynamic> items, int maxItems) =>
      {'type': 'array', 'items': items, 'maxItems': maxItems};

  /// llamadart `responseFormat` for [schema].
  static Map<String, dynamic> responseFormat(Map<String, dynamic> schema, {String name = 'extraction'}) => {
        'type': 'json_schema',
        'json_schema': {'name': name, 'strict': true, 'schema': schema},
      };

  // ---------------------------------------------------------------------------
  // Phase 1 and container-only
  // ---------------------------------------------------------------------------

  static List<(String, Map<String, dynamic>, String)> get _patientFields => [
        ('familyName', _string(), '<the patient surname from the document>'),
        ('givenName', _string(), '<the patient first name from the document>'),
        ('dateOfBirth', _date(), 'YYYY-MM-DD'),
        ('gender', _enum(genders), 'male|female'),
        ('patientIdentifier', _string(), '<ID number>'),
        ('identifierLabel', _enum(identifierLabels), '<type of the ID>'),
      ];

  static List<(String, Map<String, dynamic>, String)> get _documentFields => [
        ('documentTitle', _string(), '<the document heading/title>'),
        ('documentDate', _date(), 'YYYY-MM-DD'),
        ('conclusion', _string(), '<the report conclusion, or empty>'),
        ('documentCategory', _enum(documentCategories), 'visit|lab_report'),
      ];

  static Map<String, dynamic> basicInfoSchema() => _object({
        for (final (name, schema, _) in [..._patientFields, ..._documentFields]) name: schema,
      });

  static Map<String, dynamic> containerSchema() => _object({
        for (final (name, schema, _) in _documentFields) name: schema,
      });

  static String _shape(List<(String, Map<String, dynamic>, String)> fields) =>
      '{${[for (final (name, _, hint) in fields) '"$name":"$hint"'].join(',')}}';

  /// The phase-1 object as the prompt shows it.
  static String get basicInfoShape => _shape([..._patientFields, ..._documentFields]);

  /// The container-only object as the prompt shows it.
  static String get containerShape => _shape(_documentFields);

  // ---------------------------------------------------------------------------
  // Phase 2
  // ---------------------------------------------------------------------------

  static const _observationValueHint = 'numeric string only (e.g. 98.5, 120, 27.56) - never include units in value';

  static final observations = RemainingSection._(
    'observations',
    'Observation',
    'lab test results',
    [
      ('observationName', _string(), 'string'),
      ('value', _string(), _observationValueHint),
      ('unit', _string(), 'string'),
      ('referenceRange', _string(), 'string (e.g. 0.7 - 1.2)'),
    ],
    40,
  );

  static final vitalSigns = RemainingSection._(
    'vitalSigns',
    'Observation',
    'vital signs and body measurements (blood pressure, heart rate, temperature, weight, height, BMI, SpO2)',
    [
      ('observationName', _string(), 'string'),
      ('value', _string(), _observationValueHint),
      ('unit', _string(), 'string'),
      ('referenceRange', _string(), 'string'),
    ],
    10,
  );

  static final conditions = RemainingSection._(
    'conditions',
    'Condition',
    'diagnoses',
    [
      ('conditionName', _string(), 'string'),
      ('onsetDateTime', _date(), 'YYYY-MM-DD'),
      ('clinicalStatus', _enum(clinicalStatuses), 'active|resolved|inactive'),
    ],
    10,
  );

  static final medications = RemainingSection._(
    'medications',
    'MedicationStatement',
    'medications',
    [
      ('medicationName', _string(), 'string'),
      ('dosage', _string(), 'string (e.g. 500mg twice daily)'),
      ('reason', _string(), 'string'),
    ],
    15,
  );

  static final procedures = RemainingSection._(
    'procedures',
    'Procedure',
    'surgeries and procedures',
    [
      ('procedureName', _string(), 'string'),
      ('performedDateTime', _date(), 'YYYY-MM-DD'),
      ('reason', _string(), 'string'),
    ],
    8,
  );

  static final allergies = RemainingSection._(
    'allergies',
    'AllergyIntolerance',
    'allergies',
    [
      ('substance', _string(), 'string'),
      ('manifestation', _string(), 'string'),
      ('category', _enum(allergyCategories), 'food|medication|environment'),
    ],
    8,
  );

  static final practitioners = RemainingSection._(
    'practitioners',
    'Practitioner',
    'doctors',
    [
      ('practitionerName', _string(), 'string'),
      ('specialty', _string(), 'string'),
      ('identifier', _string(), 'string'),
    ],
    4,
  );

  static final organizations = RemainingSection._(
    'organizations',
    'Organization',
    'hospitals, clinics and labs',
    [
      ('organizationName', _string(), 'string'),
      ('address', _string(), 'string'),
      ('phone', _string(), 'string'),
    ],
    3,
  );

  /// Every phase-2 section, in the order of the union schema.
  static List<RemainingSection> get allSections => [
        observations,
        vitalSigns,
        conditions,
        medications,
        procedures,
        allergies,
        practitioners,
        organizations,
      ];

  /// The arrays of [documentCategory]: lab reports carry no Condition,
  /// medication or visit data; an unknown category gets the union.
  static List<RemainingSection> sectionsFor(String? documentCategory) => switch (documentCategory) {
        'lab_report' => [observations, practitioners, organizations],
        'visit' => [conditions, medications, procedures, allergies, vitalSigns, practitioners, organizations],
        _ => allSections,
      };

  static Map<String, dynamic> remainingSchema(String? documentCategory) => _object({
        for (final s in sectionsFor(documentCategory)) s.key: _array(s.itemSchema, s.maxItems),
      });

  /// Prompt text describing the phase-2 object of [documentCategory].
  static String remainingShape(String? documentCategory) => [
        for (final s in sectionsFor(documentCategory))
          '"${s.key}": ${s.description}, at most ${s.maxItems}: [${s.itemShape}]',
      ].join('\n');

  /// Every schema the pipeline can send, for validation in tests.
  static Map<String, Map<String, dynamic>> allSchemas() => {
        'basicInfo': basicInfoSchema(),
        'container': containerSchema(),
        'remaining:lab_report': remainingSchema('lab_report'),
        'remaining:visit': remainingSchema('visit'),
        'remaining:union': remainingSchema(null),
      };

  // ---------------------------------------------------------------------------
  // Mappers
  // ---------------------------------------------------------------------------

  static final _fence = RegExp(r'```(?:json)?\s*');

  static String _str(Object? v) => switch (v) {
        null => '',
        String s => s,
        Map m => _str(m['value']),
        _ => '$v',
      };

  /// Decodes a schema output object. Output cut off mid-JSON (token limit) is
  /// salvaged up to the last complete array item or array; null when nothing
  /// usable is left.
  static Map<String, dynamic>? decodeObject(String? raw) {
    final text = (raw ?? '').replaceAll(_fence, '').trim();
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      final salvaged = salvageTruncatedObject(text);
      if (salvaged == null) return null;
      try {
        final decoded = jsonDecode(salvaged);
        return decoded is Map<String, dynamic> ? decoded : null;
      } on FormatException {
        return null;
      }
    }
  }

  /// [text] cut after the last complete item of an array (or the last
  /// complete array of an object), with the open containers closed; null when
  /// there is no such point.
  static String? salvageTruncatedObject(String text) {
    if (!text.startsWith('{')) return null;
    final stack = <String>[];
    var inString = false;
    var escaped = false;
    int? cut;
    var closers = '';
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (inString) {
        if (c == '\\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      if (c == '"') {
        inString = true;
      } else if (c == '{' || c == '[') {
        stack.add(c);
      } else if (c == '}' || c == ']') {
        if (stack.isEmpty) break;
        stack.removeLast();
        if (stack.isEmpty) return text.substring(0, i + 1);
        final parent = stack.last;
        if ((parent == '[' && c == '}') || (parent == '{' && c == ']')) {
          cut = i + 1;
          closers = [for (final open in stack.reversed) open == '{' ? '}' : ']'].join();
        }
      }
    }
    return cut == null ? null : '${text.substring(0, cut)}$closers';
  }

  /// Phase-1 object → `[Patient, DiagnosticReport | Encounter]`, the maps the
  /// legacy array output holds.
  static List<Map<String, dynamic>> basicInfoToLegacy(Map<String, dynamic> object) {
    final category = _str(object['documentCategory']).toLowerCase();
    return [
      {
        'resourceType': 'Patient',
        'familyName': _str(object['familyName']),
        'givenName': _str(object['givenName']),
        'dateOfBirth': _str(object['dateOfBirth']),
        'gender': _str(object['gender']),
        'patientIdentifier': _str(object['patientIdentifier']),
        'identifierLabel': _str(object['identifierLabel']),
        'documentCategory': category,
      },
      containerToLegacy(object),
    ];
  }

  /// Document fields → a DiagnosticReport for `lab_report`, else an Encounter.
  static Map<String, dynamic> containerToLegacy(Map<String, dynamic> object) {
    final category = _str(object['documentCategory']).toLowerCase();
    final title = _str(object['documentTitle']);
    final date = _str(object['documentDate']);
    return category == 'lab_report'
        ? {
            'resourceType': 'DiagnosticReport',
            'reportName': title,
            'issuedDate': date,
            'conclusion': _str(object['conclusion']),
          }
        : {'resourceType': 'Encounter', 'encounterType': title, 'periodStart': date};
  }

  /// Phase-2 object → flat list of `resourceType`-tagged maps, in section
  /// order. Unknown keys and non-object items are dropped.
  static List<Map<String, dynamic>> remainingToLegacy(Map<String, dynamic> object) => [
        for (final s in allSections)
          if (object[s.key] case final List items)
            for (final item in items)
              if (item is Map)
                {
                  'resourceType': s.resourceType,
                  for (final (name, _, _) in s.fields) name: _str(item[name]),
                },
      ];

  /// Legacy `resourceType`-tagged maps (few-shot templates) → the phase-2
  /// object of [documentCategory]. Types the category has no array for are
  /// dropped; an Observation goes to `vitalSigns` on a visit, else to
  /// `observations`.
  static Map<String, dynamic> legacyToRemaining(List<Map<String, dynamic>> resources, String? documentCategory) {
    final sections = sectionsFor(documentCategory);
    final out = {for (final s in sections) s.key: <Map<String, dynamic>>[]};
    for (final r in resources) {
      final type = r['resourceType'];
      final section = type == 'Observation'
          ? sections.firstWhere((s) => s.key == 'observations',
              orElse: () => sections.firstWhere((s) => s.key == 'vitalSigns', orElse: () => _none))
          : sections.firstWhere((s) => s.resourceType == type, orElse: () => _none);
      if (identical(section, _none)) continue;
      out[section.key]!.add({for (final (name, _, _) in section.fields) name: _str(r[name])});
    }
    return out;
  }

  static const _none = RemainingSection._('', '', '', [], 0);
}
