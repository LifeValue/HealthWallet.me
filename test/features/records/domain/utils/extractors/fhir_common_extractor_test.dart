import 'package:fhir_r4/fhir_r4.dart' as fhir;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/records/domain/utils/extractors/fhir_common_extractor.dart';

import '../../../../../fixtures/fhir/fhir_fixtures.dart';

enum _LegacyCode { active }

fhir.CodeableConcept _cc(Map<String, dynamic> json) =>
    fhir.CodeableConcept.fromJson(json);

fhir.Dosage _dosage(Map<String, dynamic> json) => fhir.Dosage.fromJson(json);

void main() {
  group('extractStatus / extractDate', () {
    test('return null for null', () {
      expect(FhirCommonExtractor.extractStatus(null), isNull);
      expect(FhirCommonExtractor.extractDate(null), isNull);
    });

    test('use the FHIR code / date string', () {
      expect(
        FhirCommonExtractor.extractStatus(fhir.ObservationStatus.final_),
        'final',
      );
      expect(
        FhirCommonExtractor.extractStatus(fhir.AdministrativeGender.female),
        'female',
      );
      expect(
        FhirCommonExtractor.extractDate(
          fhir.FhirDateTime.fromString('2024-03'),
        ),
        '2024-03',
      );
    });
  });

  group('extractCodeableConceptText', () {
    test('returns null for null', () {
      expect(FhirCommonExtractor.extractCodeableConceptText(null), isNull);
    });

    test('prefers text over coding display', () {
      final concept = _cc(
        codeableConcept(
          text: 'Hemoglobin',
          codings: [loinc('718-7', 'Hemoglobin [Mass/volume] in Blood')],
        ),
      );
      expect(
        FhirCommonExtractor.extractCodeableConceptText(concept),
        'Hemoglobin',
      );
    });

    test('falls back to the first coding display when text is missing', () {
      final concept = _cc(
        codeableConcept(
          codings: [
            coding(snomedSystem, '44054006', 'Diabetes mellitus type 2'),
            coding('http://hl7.org/fhir/sid/icd-10-cm', 'E11.9', 'T2DM'),
          ],
        ),
      );
      expect(
        FhirCommonExtractor.extractCodeableConceptText(concept),
        'Diabetes mellitus type 2',
      );
    });

    test('falls back to coding display when text is empty', () {
      final concept = _cc({
        'text': '',
        'coding': [loinc('8867-4', 'Heart rate')],
      });
      expect(
        FhirCommonExtractor.extractCodeableConceptText(concept),
        'Heart rate',
      );
    });

    test('returns null when there is neither text nor a display', () {
      expect(
        FhirCommonExtractor.extractCodeableConceptText(
          _cc(codeableConcept(codings: [loinc('8867-4')])),
        ),
        isNull,
      );
      expect(
        FhirCommonExtractor.extractCodeableConceptText(_cc(const {})),
        isNull,
      );
    });

    test(
      'uses a later coding display when the first coding has none',
      () {
        final concept = _cc(
          codeableConcept(
            codings: [
              coding('urn:oid:1.2.840.114350', '12345'),
              loinc('2339-0', 'Glucose [Mass/volume] in Blood'),
            ],
          ),
        );
        expect(
          FhirCommonExtractor.extractCodeableConceptText(concept),
          'Glucose [Mass/volume] in Blood',
        );
      },
      skip:
          'BUG: only coding.first is inspected; later codings with a '
          'display are ignored',
    );

    test('strips the enum prefix of dotted toString values', () {
      expect(
        FhirCommonExtractor.extractCodeableConceptText(_LegacyCode.active),
        'active',
      );
    });

    test('returns null for objects without text/coding', () {
      expect(FhirCommonExtractor.extractCodeableConceptText(42), isNull);
    });
  });

  group('extractReferenceDisplay', () {
    test('returns the display of a Reference', () {
      final ref = fhir.Reference.fromJson({
        'reference': 'Practitioner/1',
        'display': 'Dr. Jane Smith',
      });
      expect(
        FhirCommonExtractor.extractReferenceDisplay(ref),
        'Dr. Jane Smith',
      );
    });

    test('returns null when the display or the Reference is missing', () {
      expect(
        FhirCommonExtractor.extractReferenceDisplay(
          fhir.Reference.fromJson({'reference': 'Practitioner/1'}),
        ),
        isNull,
      );
      expect(
        FhirCommonExtractor.extractReferenceDisplay('Practitioner/1'),
        isNull,
      );
      expect(FhirCommonExtractor.extractReferenceDisplay(null), isNull);
    });
  });

  group('extractFirstCodeableConceptFromArray / extractServiceType', () {
    test('return null for null or empty lists', () {
      expect(
        FhirCommonExtractor.extractFirstCodeableConceptFromArray(null),
        isNull,
      );
      expect(
        FhirCommonExtractor.extractFirstCodeableConceptFromArray(const []),
        isNull,
      );
      expect(FhirCommonExtractor.extractServiceType(null), isNull);
    });

    test('use only the first concept', () {
      final concepts = [
        _cc(codeableConcept(text: 'Cardiology')),
        _cc(codeableConcept(text: 'Oncology')),
      ];
      expect(
        FhirCommonExtractor.extractFirstCodeableConceptFromArray(concepts),
        'Cardiology',
      );
      expect(FhirCommonExtractor.extractServiceType(concepts), 'Cardiology');
    });
  });

  group('joinNullable', () {
    const cases = <(List<String?>, String, String?)>[
      ([], ', ', null),
      ([null, ''], ', ', null),
      (['Boston'], ', ', 'Boston'),
      (['Boston', null, '', 'US'], ', ', 'Boston, US'),
      (['a', 'b', 'c'], ' / ', 'a / b / c'),
    ];
    for (final (values, separator, expected) in cases) {
      test('$values joined by "$separator" -> $expected', () {
        expect(FhirCommonExtractor.joinNullable(values, separator), expected);
      });
    }
  });

  group('extractCodingDisplay', () {
    test('prefers display, falls back to code', () {
      expect(
        FhirCommonExtractor.extractCodingDisplay(
          fhir.Coding.fromJson(loinc('8867-4', 'Heart rate')),
        ),
        'Heart rate',
      );
      expect(
        FhirCommonExtractor.extractCodingDisplay(
          fhir.Coding.fromJson(loinc('8867-4')),
        ),
        '8867-4',
      );
    });

    test('returns null for null and non-Coding values', () {
      expect(FhirCommonExtractor.extractCodingDisplay(null), isNull);
      expect(FhirCommonExtractor.extractCodingDisplay('8867-4'), isNull);
    });
  });

  group('extractQuantity', () {
    final cases = <(Map<String, dynamic>, String?)>[
      (quantity(120, unit: 'mmHg', code: 'mm[Hg]'), '120.00 mmHg'),
      (quantity(36.65, unit: '°C'), '36.65 °C'),
      (quantity(5.5), '5.50'),
      (quantity(null, unit: 'mg'), null),
    ];
    for (final (json, expected) in cases) {
      test('$json -> $expected', () {
        expect(
          FhirCommonExtractor.extractQuantity(fhir.Quantity.fromJson(json)),
          expected,
        );
      });
    }

    test('returns null for null', () {
      expect(FhirCommonExtractor.extractQuantity(null), isNull);
    });

    test(
      'keeps significant digits of small lab values',
      () {
        expect(
          FhirCommonExtractor.extractQuantity(
            fhir.Quantity.fromJson(quantity(0.004, unit: 'ng/mL')),
          ),
          '0.004 ng/mL',
        );
      },
      skip:
          'BUG: values are rounded to 2 decimals, so a troponin of '
          '0.004 ng/mL is shown as "0.00 ng/mL"',
    );
  });

  group('extractAllCodeableConceptsFromArray / extractReasonCodes', () {
    test('return null for null, empty or text-less lists', () {
      expect(
        FhirCommonExtractor.extractAllCodeableConceptsFromArray(null),
        isNull,
      );
      expect(
        FhirCommonExtractor.extractAllCodeableConceptsFromArray(const []),
        isNull,
      );
      expect(FhirCommonExtractor.extractReasonCodes([_cc(const {})]), isNull);
    });

    test('join every concept with text, skipping empty ones', () {
      final reasons = [
        _cc(codeableConcept(text: 'Hypertension')),
        _cc(const {}),
        _cc(
          codeableConcept(
            codings: [coding(snomedSystem, '195967001', 'Asthma')],
          ),
        ),
      ];
      expect(
        FhirCommonExtractor.extractAllCodeableConceptsFromArray(reasons),
        'Hypertension, Asthma',
      );
      expect(
        FhirCommonExtractor.extractReasonCodes(reasons),
        'Hypertension, Asthma',
      );
    });
  });

  group('annotations', () {
    final first = fhir.Annotation.fromJson({
      'authorString': 'Dr. A',
      'text': 'Patient reports dizziness.',
    });
    final second = fhir.Annotation.fromJson({'text': 'Follow up in 2 weeks.'});

    test('extractFirstAnnotation returns the first Annotation text', () {
      expect(FhirCommonExtractor.extractFirstAnnotation(null), isNull);
      expect(FhirCommonExtractor.extractFirstAnnotation(const []), isNull);
      expect(
        FhirCommonExtractor.extractFirstAnnotation([
          'not an annotation',
          first,
        ]),
        'Patient reports dizziness.',
      );
      expect(
        FhirCommonExtractor.extractFirstAnnotation(['nothing useful']),
        isNull,
      );
    });

    test('extractAnnotations joins all texts with "; "', () {
      expect(FhirCommonExtractor.extractAnnotations(null), isNull);
      expect(FhirCommonExtractor.extractAnnotations(const []), isNull);
      expect(FhirCommonExtractor.extractAnnotations(['x']), isNull);
      expect(
        FhirCommonExtractor.extractAnnotations([first, 'x', second]),
        'Patient reports dizziness.; Follow up in 2 weeks.',
      );
    });
  });

  group('formatAddress', () {
    test('joins city, state and country', () {
      final address = fhir.Address.fromJson({
        'line': ['12 Main St'],
        'city': 'Springfield',
        'state': 'MA',
        'postalCode': '01101',
        'country': 'US',
      });
      expect(FhirCommonExtractor.formatAddress(address), 'Springfield, MA, US');
    });

    test('skips missing parts and returns null when nothing is left', () {
      expect(
        FhirCommonExtractor.formatAddress(
          fhir.Address.fromJson({'country': 'RO'}),
        ),
        'RO',
      );
      expect(
        FhirCommonExtractor.formatAddress(
          fhir.Address.fromJson({
            'line': ['12 Main St'],
          }),
        ),
        isNull,
      );
      expect(FhirCommonExtractor.formatAddress(null), isNull);
    });
  });

  group('extractMultipleReferenceDisplays / extractReasonReferences', () {
    test('join displays and ignore references without one', () {
      final refs = [
        fhir.Reference.fromJson({
          'reference': 'Condition/1',
          'display': 'Asthma',
        }),
        fhir.Reference.fromJson({'reference': 'Condition/2'}),
        'Condition/3',
        fhir.Reference.fromJson({'display': 'Hypertension'}),
      ];
      expect(
        FhirCommonExtractor.extractMultipleReferenceDisplays(refs),
        'Asthma, Hypertension',
      );
      expect(
        FhirCommonExtractor.extractReasonReferences(refs),
        'Asthma, Hypertension',
      );
    });

    test('return null when there is no display', () {
      expect(
        FhirCommonExtractor.extractMultipleReferenceDisplays(null),
        isNull,
      );
      expect(
        FhirCommonExtractor.extractMultipleReferenceDisplays(const []),
        isNull,
      );
      expect(
        FhirCommonExtractor.extractMultipleReferenceDisplays([
          fhir.Reference.fromJson({'reference': 'Condition/2'}),
        ]),
        isNull,
      );
    });
  });

  group('extractDosageInstructions', () {
    test('returns null for null, empty or non-Dosage lists', () {
      expect(FhirCommonExtractor.extractDosageInstructions(null), isNull);
      expect(FhirCommonExtractor.extractDosageInstructions(const []), isNull);
      expect(FhirCommonExtractor.extractDosageInstructions(['x']), isNull);
      expect(
        FhirCommonExtractor.extractDosageInstructions([_dosage(const {})]),
        isNull,
      );
    });

    test('prefers the free-text instruction', () {
      expect(
        FhirCommonExtractor.extractDosageInstructions([
          _dosage({
            'text': 'Take one tablet daily',
            'route': codeableConcept(text: 'Oral'),
          }),
        ]),
        'Take one tablet daily',
      );
    });

    test('builds route, timing and dose from structured dosages', () {
      final dosages = (medicationRequestJson()['dosageInstruction'] as List)
          .map((d) => _dosage(d as Map<String, dynamic>))
          .toList();
      expect(
        FhirCommonExtractor.extractDosageInstructions(dosages),
        'Oral route, Twice a day, 500 mg',
      );
    });

    test('joins several dosages with "; "', () {
      final dosages = [
        _dosage({'text': 'Morning: 1 tablet'}),
        _dosage({
          'timing': {'code': codeableConcept(text: 'At bedtime')},
          'doseAndRate': [
            {'doseQuantity': quantity(2)},
          ],
        }),
        _dosage({
          'doseAndRate': [
            {
              'doseRange': {
                'low': quantity(1, unit: 'tablet'),
                'high': quantity(2, unit: 'tablet'),
              },
            },
          ],
        }),
      ];
      expect(
        FhirCommonExtractor.extractDosageInstructions(dosages),
        'Morning: 1 tablet; At bedtime, 2 ',
      );
    });
  });

  group('extractDosage', () {
    test('returns null for null or empty lists', () {
      expect(FhirCommonExtractor.extractDosage(null), isNull);
      expect(FhirCommonExtractor.extractDosage(const []), isNull);
      expect(FhirCommonExtractor.extractDosage([_dosage(const {})]), isNull);
    });

    test('prefers text of the first dosage', () {
      expect(
        FhirCommonExtractor.extractDosage([
          _dosage({'text': 'Take one tablet by mouth daily'}),
          _dosage({'text': 'ignored'}),
        ]),
        'Take one tablet by mouth daily',
      );
    });

    test('formats dose, route and timing', () {
      final dosages = (medicationRequestJson()['dosageInstruction'] as List)
          .map((d) => _dosage(d as Map<String, dynamic>))
          .toList();
      expect(
        FhirCommonExtractor.extractDosage(dosages),
        '500 mg, Oral route, Twice a day',
      );
    });

    test('omits a missing unit and non-quantity doses', () {
      expect(
        FhirCommonExtractor.extractDosage([
          _dosage({
            'doseAndRate': [
              {'doseQuantity': quantity(2)},
            ],
          }),
        ]),
        '2',
      );
      expect(
        FhirCommonExtractor.extractDosage([
          _dosage({
            'doseAndRate': [
              {'doseQuantity': quantity(null, unit: 'mg')},
            ],
            'route': codeableConcept(text: 'IV'),
          }),
        ]),
        'IV',
      );
      expect(
        FhirCommonExtractor.extractDosage([
          _dosage({
            'doseAndRate': [
              {
                'doseRange': {'low': quantity(1), 'high': quantity(2)},
              },
            ],
          }),
        ]),
        isNull,
      );
    });
  });

  group('extractFirstIdentifier', () {
    test('returns the first identifier with a value', () {
      final ids = [
        fhir.Identifier.fromJson({'system': 'urn:x'}),
        fhir.Identifier.fromJson({'value': 'A-1'}),
        fhir.Identifier.fromJson({'value': 'B-2'}),
      ];
      expect(FhirCommonExtractor.extractFirstIdentifier(ids), 'A-1');
    });

    test('returns null when no identifier has a value', () {
      expect(FhirCommonExtractor.extractFirstIdentifier(null), isNull);
      expect(FhirCommonExtractor.extractFirstIdentifier(const []), isNull);
      expect(
        FhirCommonExtractor.extractFirstIdentifier([
          fhir.Identifier.fromJson({'system': 'urn:x'}),
        ]),
        isNull,
      );
    });
  });

  group('extractPriority / extractIntent', () {
    test('return the code and strip enum prefixes', () {
      expect(FhirCommonExtractor.extractPriority(null), isNull);
      expect(
        FhirCommonExtractor.extractPriority(fhir.RequestPriority.urgent),
        'urgent',
      );
      expect(FhirCommonExtractor.extractPriority(_LegacyCode.active), 'active');
      expect(FhirCommonExtractor.extractIntent(null), isNull);
      expect(
        FhirCommonExtractor.extractIntent(fhir.MedicationRequestIntent.order),
        'order',
      );
    });
  });

  group('extractPerformers', () {
    test('handles References, ProcedurePerformer and other actor holders', () {
      final procedure = fhir.Procedure.fromJson(procedureJson());
      final immunization = fhir.Immunization.fromJson({
        ...immunizationJson(),
        'performer': [
          {
            'actor': {'display': 'Nurse Joy'},
          },
          {
            'actor': {'reference': 'Practitioner/x'},
          },
        ],
      });
      final performers = <dynamic>[
        fhir.Reference.fromJson({'display': 'Lab Corp'}),
        fhir.Reference.fromJson({'reference': 'Organization/1'}),
        ...procedure.performer!,
        ...immunization.performer!,
        'unexpected',
      ];

      expect(
        FhirCommonExtractor.extractPerformers(performers),
        'Lab Corp, Dr. Who, Nurse Joy',
      );
    });

    test('returns null when nobody has a display', () {
      expect(FhirCommonExtractor.extractPerformers(null), isNull);
      expect(FhirCommonExtractor.extractPerformers(const []), isNull);
      expect(
        FhirCommonExtractor.extractPerformers([
          fhir.ProcedurePerformer.fromJson({
            'actor': {'reference': 'Practitioner/1'},
          }),
        ]),
        isNull,
      );
    });
  });

  group('extractParticipants', () {
    test('reads Encounter individuals and CareTeam members', () {
      final encounter = fhir.Encounter.fromJson(encounterJson());
      final careTeam = fhir.CareTeam.fromJson({
        'resourceType': 'CareTeam',
        'participant': [
          {
            'member': {'display': 'Nurse Ratched'},
          },
          {
            'member': {'reference': 'Practitioner/3'},
          },
        ],
      });

      expect(
        FhirCommonExtractor.extractParticipants([
          ...encounter.participant!,
          ...careTeam.participant!,
          42,
        ]),
        'Dr. Gregory House, Nurse Ratched',
      );
    });

    test('returns null when nobody has a display', () {
      expect(FhirCommonExtractor.extractParticipants(null), isNull);
      expect(FhirCommonExtractor.extractParticipants(const []), isNull);
      expect(FhirCommonExtractor.extractParticipants(['x']), isNull);
    });
  });

  group('extractLocations', () {
    test('reads EncounterLocation and bare References', () {
      final encounter = fhir.Encounter.fromJson(encounterJson());
      expect(
        FhirCommonExtractor.extractLocations([
          ...encounter.location!,
          fhir.Reference.fromJson({'display': 'Room 12'}),
          fhir.Reference.fromJson({'reference': 'Location/2'}),
          fhir.EncounterLocation.fromJson({
            'location': {'reference': 'Location/3'},
          }),
        ]),
        'Springfield Clinic, Room 12',
      );
    });

    test('returns null when nothing has a display', () {
      expect(FhirCommonExtractor.extractLocations(null), isNull);
      expect(FhirCommonExtractor.extractLocations(const []), isNull);
      expect(FhirCommonExtractor.extractLocations(['x']), isNull);
    });
  });

  group('extractDiagnoses', () {
    test('reads the condition display of each diagnosis', () {
      final encounter = fhir.Encounter.fromJson(encounterJson());
      expect(
        FhirCommonExtractor.extractDiagnoses([
          ...encounter.diagnosis!,
          fhir.EncounterDiagnosis.fromJson({
            'condition': {'reference': 'Condition/2'},
          }),
          'not a diagnosis',
        ]),
        'Diabetes',
      );
    });

    test('returns null when nothing has a display', () {
      expect(FhirCommonExtractor.extractDiagnoses(null), isNull);
      expect(FhirCommonExtractor.extractDiagnoses(const []), isNull);
      expect(FhirCommonExtractor.extractDiagnoses(['x']), isNull);
    });
  });
}
