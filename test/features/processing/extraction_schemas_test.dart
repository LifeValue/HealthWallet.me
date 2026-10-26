import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/country_identifier.dart';
import 'package:health_wallet/features/processing/data/model/structured_output/extraction_schemas.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:llamadart/llamadart.dart';

/// Every object in [schema] is closed, lists all its properties as required
/// in property order, every array has maxItems, and nothing uses $ref/$defs,
/// anyOf/oneOf/allOf.
void _expectFlat(Object? schema, String path) {
  if (schema is! Map) return;
  for (final banned in [r'$ref', r'$defs', 'definitions', 'anyOf', 'oneOf', 'allOf']) {
    expect(schema.containsKey(banned), isFalse, reason: '$path.$banned');
  }
  if (schema['type'] == 'object') {
    final props = schema['properties'] as Map;
    expect(schema['required'], props.keys.toList(), reason: '$path.required');
    expect(schema['additionalProperties'], isFalse, reason: '$path.additionalProperties');
    for (final e in props.entries) {
      _expectFlat(e.value, '$path.${e.key}');
    }
  }
  if (schema['type'] == 'array') {
    expect(schema['maxItems'], isA<int>(), reason: '$path.maxItems');
    _expectFlat(schema['items'], '$path[]');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('schemas', () {
    test("every schema converts with llamadart's own validator", () {
      final schemas = ExtractionSchemas.allSchemas();
      expect(schemas.keys, hasLength(5));
      for (final MapEntry(key: name, value: schema) in schemas.entries) {
        expect(
          () => LlamaStructuredOutput.jsonValueSchema(schema: schema, decoder: (v) => v),
          returnsNormally,
          reason: name,
        );
        // The response format the pipeline sends, too.
        final format = ExtractionSchemas.responseFormat(schema, name: name);
        expect(format['type'], 'json_schema');
        expect((format['json_schema'] as Map)['schema'], schema);
      }
    });

    test('every schema is flat, closed and bounded', () {
      for (final MapEntry(key: name, value: schema) in ExtractionSchemas.allSchemas().entries) {
        _expectFlat(schema, name);
      }
    });

    test('the date pattern accepts full and partial dates and nothing else', () {
      final output = LlamaStructuredOutput.jsonValueSchema(
        schema: ExtractionSchemas.basicInfoSchema(),
        decoder: (v) => v,
      );
      Map<String, dynamic> object(String date) => {
            'familyName': 'Müller',
            'givenName': 'Anna',
            'dateOfBirth': date,
            'gender': 'female',
            'patientIdentifier': 'A123456789',
            'identifierLabel': 'KVNR',
            'documentTitle': 'Laborbefund',
            'documentDate': '2025-03-14',
            'conclusion': '',
            'documentCategory': 'lab_report',
          };
      for (final ok in ['', '1960', '1960-04', '1960-04-02']) {
        expect(() => output.parse(jsonEncode(object(ok))), returnsNormally, reason: ok);
      }
      for (final bad in ['02.04.1960', '1960-4-2', '60-04-02', 'unknown']) {
        expect(() => output.parse(jsonEncode(object(bad))), throwsA(isA<LlamaInferenceException>()), reason: bad);
      }
    });

    test('phase-2 arrays per category; a lab report has no Condition', () {
      Set<String> keys(String? c) => ((ExtractionSchemas.remainingSchema(c)['properties']) as Map).keys.cast<String>().toSet();
      expect(keys('lab_report'), {'observations', 'practitioners', 'organizations'});
      expect(keys('visit'),
          {'conditions', 'medications', 'procedures', 'allergies', 'vitalSigns', 'practitioners', 'organizations'});
      expect(keys(null), ExtractionSchemas.allSections.map((s) => s.key).toSet());
      expect(keys('other'), keys(null));
      expect(jsonEncode(ExtractionSchemas.remainingSchema('lab_report')), isNot(contains('condition')));
      // The prompt lists the same arrays in the same order as the schema.
      final shape = ExtractionSchemas.remainingShape('visit');
      final order = [for (final k in keys('visit')) shape.indexOf('"$k":')];
      expect(order, everyElement(isNonNegative));
      expect([...order]..sort(), order);
    });
  });

  group('mappers', () {
    test('phase-1 object maps to Patient + DiagnosticReport for a lab report', () {
      final legacy = ExtractionSchemas.basicInfoToLegacy({
        'familyName': 'Müller',
        'givenName': 'Anna',
        'dateOfBirth': '1960-04-02',
        'gender': 'female',
        'patientIdentifier': 'A123456789',
        'identifierLabel': 'KVNR',
        'documentTitle': 'Laborbefund',
        'documentDate': '2025-03-14',
        'conclusion': 'Alle Werte im Referenzbereich.',
        'documentCategory': 'lab_report',
      });
      expect(legacy, [
        {
          'resourceType': 'Patient',
          'familyName': 'Müller',
          'givenName': 'Anna',
          'dateOfBirth': '1960-04-02',
          'gender': 'female',
          'patientIdentifier': 'A123456789',
          'identifierLabel': 'KVNR',
          'documentCategory': 'lab_report',
        },
        {
          'resourceType': 'DiagnosticReport',
          'reportName': 'Laborbefund',
          'issuedDate': '2025-03-14',
          'conclusion': 'Alle Werte im Referenzbereich.',
        },
      ]);
      for (final json in legacy) {
        expect(() => MappingResource.fromJson(json), returnsNormally);
      }
    });

    test('phase-1 object maps to an Encounter for a visit, and missing fields to empty strings', () {
      final legacy = ExtractionSchemas.basicInfoToLegacy({
        'familyName': 'Popescu',
        'documentTitle': 'Bilet de ieșire din spital',
        'documentDate': '2025-06-08',
        'documentCategory': 'visit',
      });
      expect(legacy[0]['givenName'], '');
      expect(legacy[0]['documentCategory'], 'visit');
      expect(legacy[1], {
        'resourceType': 'Encounter',
        'encounterType': 'Bilet de ieșire din spital',
        'periodStart': '2025-06-08',
      });
    });

    test('phase-2 object maps to a flat resourceType-tagged list', () {
      final legacy = ExtractionSchemas.remainingToLegacy({
        'conditions': [
          {'conditionName': 'Vorhofflimmern', 'onsetDateTime': '2019', 'clinicalStatus': 'active'},
        ],
        'vitalSigns': [
          {'observationName': 'Puls', 'value': '72', 'unit': '/min', 'referenceRange': ''},
        ],
        'medications': [
          {'medicationName': 'Apixaban 5 mg', 'dosage': '1-0-1', 'reason': ''},
        ],
        'practitioners': [],
        'unknown': [
          {'x': 1},
        ],
      });
      expect(legacy, [
        {'resourceType': 'Observation', 'observationName': 'Puls', 'value': '72', 'unit': '/min', 'referenceRange': ''},
        {'resourceType': 'Condition', 'conditionName': 'Vorhofflimmern', 'onsetDateTime': '2019', 'clinicalStatus': 'active'},
        {'resourceType': 'MedicationStatement', 'medicationName': 'Apixaban 5 mg', 'dosage': '1-0-1', 'reason': ''},
      ]);
    });

    test('truncated phase-2 output keeps the complete items', () {
      const raw = '{"observations":[{"observationName":"Hämoglobin","value":"13,5","unit":"g/dl","referenceRange":"12 - 16"},'
          '{"observationName":"Leukozyten","value":"6,2","unit":"G/l","referenceRange":"4 - 10"},'
          '{"observationName":"Thrombozyten","value":"2';
      final object = ExtractionSchemas.decodeObject(raw)!;
      final legacy = ExtractionSchemas.remainingToLegacy(object);
      expect(legacy.map((r) => r['observationName']), ['Hämoglobin', 'Leukozyten']);
    });

    test('output truncated after a closed array keeps that array', () {
      const raw = '{"observations":[{"observationName":"CRP","value":"3","unit":"mg/l","referenceRange":"< 5"}],'
          '"practitioners":[{"practitionerName":"Dr. med. Kla';
      final legacy = ExtractionSchemas.remainingToLegacy(ExtractionSchemas.decodeObject(raw)!);
      expect(legacy.single['observationName'], 'CRP');
    });

    test('a string holding brackets and escaped quotes does not confuse the salvage', () {
      const raw = r'{"observations":[{"observationName":"A [x] \"q\" }","value":"1","unit":"","referenceRange":""},{"obs';
      final legacy = ExtractionSchemas.remainingToLegacy(ExtractionSchemas.decodeObject(raw)!);
      expect(legacy.single['observationName'], 'A [x] "q" }');
    });

    test('unusable output decodes to null', () {
      for (final raw in [null, '', '[]', 'not json', '{"observations":[{"observationName":"x', '{"familyName":"Mü']) {
        expect(ExtractionSchemas.decodeObject(raw), isNull, reason: raw);
      }
    });

    test('legacy few-shot resources become the phase-2 object of the category', () {
      final resources = [
        {'resourceType': 'Patient', 'familyName': 'X'},
        {'resourceType': 'Observation', 'observationName': 'Hb', 'value': '13', 'unit': 'g/dL', 'referenceRange': '12-16'},
        {'resourceType': 'Condition', 'conditionName': 'Anemie'},
      ];
      expect(ExtractionSchemas.legacyToRemaining(resources, 'lab_report'), {
        'observations': [
          {'observationName': 'Hb', 'value': '13', 'unit': 'g/dL', 'referenceRange': '12-16'},
        ],
        'practitioners': [],
        'organizations': [],
      });
      final visit = ExtractionSchemas.legacyToRemaining(resources, 'visit');
      expect((visit['vitalSigns'] as List).single['observationName'], 'Hb');
      expect((visit['conditions'] as List).single,
          {'conditionName': 'Anemie', 'onsetDateTime': '', 'clinicalStatus': ''});
    });
  });

  group('output mode pref', () {
    test('parses the mode names and falls back to the default, schema', () {
      expect(ExtractionOutputMode.fromPref('grammar'), ExtractionOutputMode.grammar);
      expect(ExtractionOutputMode.fromPref('schema'), ExtractionOutputMode.schema);
      expect(ExtractionOutputMode.fromPref('schemaDraft'), ExtractionOutputMode.schemaDraft);
      for (final junk in [null, '', 'Schema', 'json', 'schema_draft']) {
        expect(ExtractionOutputMode.fromPref(junk), ExtractionOutputMode.defaultMode, reason: junk);
      }
      expect(ExtractionOutputMode.defaultMode, ExtractionOutputMode.schema);
      expect(ExtractionOutputMode.grammar.usesSchema, isFalse);
      expect(ExtractionOutputMode.schemaDraft.usesSchema, isTrue);
    });
  });

  group('document country', () {
    setUp(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.localeTestValue = const Locale('ro', 'RO');
    });
    tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.clearLocaleTestValue());

    test('a German document on a Romanian phone gets the KVNR hints', () {
      final profile = CountryIdentifier.forDocument('Laborbefund\nPatient: Müller, Anna\nGeburtsdatum: 02.04.1960');
      expect(profile.identifierLabel, 'KVNR');
      expect(profile.promptHints, isNot(contains('CNP')));
    });

    test('identifier names outweigh shared field labels', () {
      expect(CountryIdentifier.detectCountry('Geburtsdatum: 02.04.1960\nAHV-Nr: 756.1234.5678.97'), 'CH');
      expect(CountryIdentifier.detectCountry('Fecha de nacimiento: 14/03/1971\nDNI: 12345678Z'), 'ES');
      expect(CountryIdentifier.detectCountry('Data nașterii: 14.03.1971\nCNP: 1710314123456'), 'RO');
      expect(CountryIdentifier.detectCountry('Date of birth: 14 Mar 1971\nMRN: 12345678'), 'US');
    });

    test('markers match whole words only, ignoring case and diacritics', () {
      expect(CountryIdentifier.detectCountry('DATA NASTERII: 14.03.1971'), 'RO');
      // "cnp" inside a word is not the Romanian ID.
      expect(CountryIdentifier.detectCountry('acnpx'), isNull);
    });

    test('no marker, or a tie, falls back to the phone locale', () {
      expect(CountryIdentifier.detectCountry('Hemoglobin 13.5 g/dL'), isNull);
      expect(CountryIdentifier.forDocument('Hemoglobin 13.5 g/dL').identifierLabel, 'CNP');
      // One strong marker each: no unique best.
      expect(CountryIdentifier.detectCountry('PESEL 12345678901, BSN 123456789'), isNull);
      expect(CountryIdentifier.forDocument('').identifierLabel, 'CNP');
    });
  });
}
