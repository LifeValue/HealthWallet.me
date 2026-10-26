import 'dart:ui';

import 'package:fhir_r4/fhir_r4.dart' as fhir;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/utils/extractors/fhir_patient_extractor.dart';

import '../../../../../fixtures/fhir/fhir_fixtures.dart';

Patient _patient(Map<String, dynamic> json) => entityFromJson(json) as Patient;

Patient _withIds(List<Map<String, dynamic>> identifiers) =>
    _patient(patientJson(identifiers: identifiers));

fhir.HumanName _name(Map<String, dynamic> json) =>
    fhir.HumanName.fromJson(json);

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('human names', () {
    final full = _name({
      'family': 'Doe',
      'given': ['Jane', 'Marie'],
      'prefix': ['Dr.'],
    });
    final givenOnly = _name({
      'given': ['Jane'],
    });
    final familyOnly = _name({
      'family': 'Doe',
      'prefix': ['Mrs.'],
    });
    final textOnly = _name({'text': 'Jane Doe'});

    final cases =
        <(String, String? Function(dynamic), Map<fhir.HumanName?, String?>)>[
          (
            'extractHumanName',
            FhirPatientExtractor.extractHumanName,
            {
              full: 'Dr. Jane Marie, Doe',
              givenOnly: 'Jane',
              familyOnly: 'Mrs. Doe',
              textOnly: null,
              null: null,
            },
          ),
          (
            'extractHumanNameForHome',
            FhirPatientExtractor.extractHumanNameForHome,
            {
              full: 'Dr. Jane Marie Doe',
              givenOnly: 'Jane',
              familyOnly: 'Mrs. Doe',
              textOnly: null,
              null: null,
            },
          ),
          (
            'extractHumanNameFamilyFirst',
            FhirPatientExtractor.extractHumanNameFamilyFirst,
            {
              full: 'Doe, Jane Marie',
              givenOnly: 'Jane',
              familyOnly: 'Doe',
              textOnly: null,
              null: null,
            },
          ),
        ];

    for (final (name, fn, expectations) in cases) {
      for (final MapEntry(key: input, value: expected)
          in expectations.entries) {
        test('$name(${input?.toJson()}) -> $expected', () {
          expect(fn(input), expected);
        });
      }
    }

    test('extractFirstHumanNameFromArray uses the first HumanName', () {
      expect(
        FhirPatientExtractor.extractFirstHumanNameFromArray([full, givenOnly]),
        'Dr. Jane Marie, Doe',
      );
      expect(
        FhirPatientExtractor.extractFirstHumanNameFromArray(['Jane Doe']),
        isNull,
      );
      expect(
        FhirPatientExtractor.extractFirstHumanNameFromArray(const []),
        isNull,
      );
      expect(FhirPatientExtractor.extractFirstHumanNameFromArray(null), isNull);
    });
  });

  group('patient given / family / id / gender', () {
    test('reads the first name of the patient', () {
      final patient = _patient(patientJson());
      expect(FhirPatientExtractor.extractPatientGiven(patient), 'Jane Marie');
      expect(FhirPatientExtractor.extractPatientFamily(patient), 'Doe');
      expect(FhirPatientExtractor.extractPatientGender(patient), 'female');
    });

    test('returns empty strings for missing name parts', () {
      final noName = _patient(patientJson(names: []));
      expect(FhirPatientExtractor.extractPatientGiven(noName), '');
      expect(FhirPatientExtractor.extractPatientFamily(noName), '');

      final familyOnly = _patient(
        patientJson(
          names: [
            {'family': 'Doe'},
          ],
        ),
      );
      expect(FhirPatientExtractor.extractPatientGiven(familyOnly), '');

      final givenOnly = _patient(
        patientJson(
          names: [
            {
              'given': ['Jane'],
            },
          ],
        ),
      );
      expect(FhirPatientExtractor.extractPatientFamily(givenOnly), '');
    });

    test('gender defaults to Unknown', () {
      expect(
        FhirPatientExtractor.extractPatientGender(
          _patient(patientJson(gender: null)),
        ),
        'Unknown',
      );
    });

    test('extractPatientId uses the first identifier with a value', () {
      expect(
        FhirPatientExtractor.extractPatientId(_patient(patientJson())),
        'syn-1',
      );
      expect(
        FhirPatientExtractor.extractPatientId(
          _withIds([
            {'system': 'urn:x'},
            identifier(value: 'MRN-7', typeCode: 'MR'),
          ]),
        ),
        'MRN-7',
      );
    });

    test('extractPatientId falls back to the resource id', () {
      expect(FhirPatientExtractor.extractPatientId(_withIds([])), 'pat-1');
      expect(
        FhirPatientExtractor.extractPatientId(
          _withIds([
            {'system': 'urn:x'},
          ]),
        ),
        'pat-1',
      );
    });
  });

  group('birth date and age', () {
    test('parses full birth dates', () {
      final patient = _patient(patientJson(birthDate: '1985-07-14'));
      expect(
        FhirPatientExtractor.extractPatientBirthDate(patient),
        DateTime(1985, 7, 14),
      );
    });

    test('returns null / N/A without a full birth date', () {
      for (final birthDate in [null, '1985', '1985-07']) {
        final patient = _patient(patientJson(birthDate: birthDate));
        expect(
          FhirPatientExtractor.extractPatientBirthDate(patient),
          isNull,
          reason: 'birthDate $birthDate',
        );
        expect(
          FhirPatientExtractor.extractPatientAge(patient),
          'N/A',
          reason: 'birthDate $birthDate',
        );
      }
    });

    test('counts full years, before and after the birthday', () {
      final today = DateTime.now();
      final hadBirthday = DateTime(today.year - 30, today.month, today.day);
      final birthdayTomorrow = DateTime(
        today.year - 30,
        today.month,
        today.day + 1,
      );
      final birthdayNextMonth = DateTime(today.year - 30, today.month + 1, 1);

      expect(
        FhirPatientExtractor.extractPatientAge(
          _patient(patientJson(birthDate: _isoDate(hadBirthday))),
        ),
        '30 years',
      );
      expect(FhirPatientExtractor.calculateAge(hadBirthday), 30);

      if (birthdayTomorrow.year == hadBirthday.year) {
        expect(
          FhirPatientExtractor.extractPatientAge(
            _patient(patientJson(birthDate: _isoDate(birthdayTomorrow))),
          ),
          '29 years',
        );
        expect(FhirPatientExtractor.calculateAge(birthdayTomorrow), 29);
      }
      if (birthdayNextMonth.year == hadBirthday.year) {
        expect(
          FhirPatientExtractor.extractPatientAge(
            _patient(patientJson(birthDate: _isoDate(birthdayNextMonth))),
          ),
          '29 years',
        );
        expect(FhirPatientExtractor.calculateAge(birthdayNextMonth), 29);
      }
    });

    test('calculateAge returns null for null', () {
      expect(FhirPatientExtractor.calculateAge(null), isNull);
    });
  });

  group('extractPatientIdentifierLabel', () {
    final cases = <(String, List<Map<String, dynamic>>, String)>[
      ('no identifiers', [], 'ID'),
      ('MR', [identifier(value: '1', typeCode: 'MR')], 'MRN'),
      (
        'SS with CNP text',
        [identifier(value: '1', typeCode: 'SS', typeText: 'CNP')],
        'CNP',
      ),
      (
        'SS with Romanian display',
        [
          identifier(
            value: '1',
            typeCode: 'SS',
            typeDisplay: 'Cod Numeric Personal',
          ),
        ],
        'CNP',
      ),
      (
        'SS SVNr',
        [identifier(value: '1', typeCode: 'SS', typeText: 'SVNR')],
        'SVNr',
      ),
      (
        'SS Sozialversicherungsnummer',
        [
          identifier(
            value: '1',
            typeCode: 'SS',
            typeText: 'Sozialversicherungsnummer',
          ),
        ],
        'SVNr',
      ),
      (
        'SS KVNR',
        [identifier(value: '1', typeCode: 'SS', typeText: 'KVNR')],
        'KVNR',
      ),
      (
        'SS Krankenversichertennummer',
        [
          identifier(
            value: '1',
            typeCode: 'SS',
            typeDisplay: 'Krankenversichertennummer',
          ),
        ],
        'KVNR',
      ),
      (
        'SS NHS',
        [identifier(value: '1', typeCode: 'SS', typeText: 'NHS Number')],
        'NHS',
      ),
      (
        'SS CIP',
        [identifier(value: '1', typeCode: 'SS', typeText: 'CIP')],
        'CIP',
      ),
      (
        'SS Spanish display',
        [
          identifier(
            value: '1',
            typeCode: 'SS',
            typeDisplay: 'Código de Identificación Personal',
          ),
        ],
        'CIP',
      ),
      (
        'SS NIR',
        [identifier(value: '1', typeCode: 'SS', typeText: 'NIR')],
        'NIR',
      ),
      (
        'SS French text',
        [
          identifier(
            value: '1',
            typeCode: 'SS',
            typeText: 'Numéro de Sécurité Sociale',
          ),
        ],
        'NIR',
      ),
      (
        'SS Codice Fiscale',
        [identifier(value: '1', typeCode: 'SS', typeText: 'Codice Fiscale')],
        'CF',
      ),
      (
        'SS CF display only',
        [identifier(value: '1', typeCode: 'SS', typeDisplay: 'CF')],
        'CF',
      ),
      (
        'SS BSN',
        [identifier(value: '1', typeCode: 'SS', typeText: 'BSN')],
        'BSN',
      ),
      (
        'SS Burgerservicenummer',
        [
          identifier(
            value: '1',
            typeCode: 'SS',
            typeText: 'Burgerservicenummer',
          ),
        ],
        'BSN',
      ),
      (
        'SS PESEL',
        [identifier(value: '1', typeCode: 'SS', typeText: 'PESEL')],
        'PESEL',
      ),
      (
        'SS Personnummer',
        [identifier(value: '1', typeCode: 'SS', typeText: 'Personnummer')],
        'PNR',
      ),
      (
        'SS PNR',
        [identifier(value: '1', typeCode: 'SS', typeDisplay: 'PNR')],
        'PNR',
      ),
      (
        'SS AHV',
        [identifier(value: '1', typeCode: 'SS', typeText: 'AHV')],
        'AHV',
      ),
      (
        'SS Hinterlassenenversicherung',
        [
          identifier(
            value: '1',
            typeCode: 'SS',
            typeText: 'Alters- und Hinterlassenenversicherung',
          ),
        ],
        'AHV',
      ),
      (
        'SS with a known system',
        [
          identifier(
            value: '1',
            typeCode: 'SS',
            system: 'http://fhir.nl/fhir/NamingSystem/bsn',
          ),
        ],
        'BSN',
      ),
      (
        'SS unknown in an en_US locale',
        [
          identifier(
            value: '123-45-6789',
            typeCode: 'SS',
            typeText: 'Social Security Number',
            system: 'http://hl7.org/fhir/sid/us-ssn',
          ),
        ],
        'ID',
      ),
      (
        'NI with DNI text',
        [identifier(value: '1', typeCode: 'NI', typeText: 'DNI')],
        'DNI',
      ),
      (
        'NI',
        [identifier(value: '1', typeCode: 'NI', typeText: 'National ID')],
        'NI',
      ),
      ('NH', [identifier(value: '1', typeCode: 'NH')], 'NHS'),
      ('DL', [identifier(value: '1', typeCode: 'DL')], 'DL'),
      ('PPN', [identifier(value: '1', typeCode: 'PPN')], 'Passport'),
      (
        'first coded identifier wins',
        [
          {'value': 'no-type'},
          identifier(value: '1', typeCode: 'DL'),
          identifier(value: '2', typeCode: 'MR'),
        ],
        'DL',
      ),
      (
        'unknown code falls back to type text',
        [
          identifier(value: '1', typeCode: 'TAX', typeText: 'Tax ID'),
          identifier(value: '2', typeText: 'Insurance'),
        ],
        'Tax ID',
      ),
      (
        'type text needs a value',
        [
          {
            'type': {'text': 'Empty'},
            'system': 'urn:x',
          },
          identifier(value: '2', typeText: 'Insurance'),
        ],
        'Insurance',
      ),
      (
        'no type at all',
        [
          {'value': 'x'},
        ],
        'ID',
      ),
    ];

    for (final (name, ids, expected) in cases) {
      test('$name -> $expected', () {
        expect(
          FhirPatientExtractor.extractPatientIdentifierLabel(_withIds(ids)),
          expected,
        );
      });
    }

    testWidgets('unknown SS identifiers use the locale profile', (
      tester,
    ) async {
      tester.platformDispatcher.localeTestValue = const Locale('ro', 'RO');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      expect(
        FhirPatientExtractor.extractPatientIdentifierLabel(
          _withIds([identifier(value: '1', typeCode: 'SS')]),
        ),
        'CNP',
      );
    });
  });

  group('extractPatientIdentifierValue', () {
    final cases = <(String, List<Map<String, dynamic>>, String)>[
      ('no identifiers', [], ''),
      (
        'default Synthea patient',
        patientJson()['identifier'] as List<Map<String, dynamic>>,
        'MRN-0042',
      ),
      (
        'national id with label',
        [
          identifier(value: 'MRN-1', typeCode: 'MR', typeText: 'later'),
          identifier(value: '1850714123456', typeCode: 'SS', typeText: 'CNP'),
        ],
        'MRN-1',
      ),
      (
        'SS before MR',
        [
          identifier(value: '1850714123456', typeCode: 'SS', typeText: 'CNP'),
          identifier(value: 'MRN-1', typeCode: 'MR'),
        ],
        '1850714123456',
      ),
      (
        'NHS',
        [identifier(value: '943 476 5919', typeCode: 'NH')],
        '943 476 5919',
      ),
      (
        'DNI',
        [identifier(value: '12345678Z', typeCode: 'NI', typeText: 'DNI')],
        '12345678Z',
      ),
      (
        'driver license falls back to MR',
        [
          identifier(value: 'D-1', typeCode: 'DL'),
          identifier(value: 'MRN-2', typeCode: 'MR'),
        ],
        'MRN-2',
      ),
      (
        'MR without value falls back to MRN text',
        [
          {
            'type': {
              'coding': [coding(identifierTypeSystem, 'MR')],
            },
            'system': 'urn:x',
          },
          identifier(value: 'L-1', typeText: 'Legacy MRN'),
        ],
        'L-1',
      ),
      (
        'falls back to the first value',
        [
          {'system': 'urn:x'},
          identifier(value: 'P-1', typeCode: 'PPN'),
        ],
        'P-1',
      ),
      (
        'no values at all',
        [
          {'system': 'urn:x'},
        ],
        '',
      ),
    ];

    for (final (name, ids, expected) in cases) {
      test('$name -> "$expected"', () {
        expect(
          FhirPatientExtractor.extractPatientIdentifierValue(_withIds(ids)),
          expected,
        );
      });
    }
  });

  group('extractMultipleBirth', () {
    dynamic multipleBirth(Map<String, dynamic> json) =>
        fhir.Patient.fromJson({...patientJson(), ...json}).multipleBirthX;

    test('handles boolean and integer forms', () {
      expect(
        FhirPatientExtractor.extractMultipleBirth(
          multipleBirth({'multipleBirthBoolean': true}),
        ),
        'Yes',
      );
      expect(
        FhirPatientExtractor.extractMultipleBirth(
          multipleBirth({'multipleBirthBoolean': false}),
        ),
        'No',
      );
      expect(
        FhirPatientExtractor.extractMultipleBirth(
          multipleBirth({'multipleBirthInteger': 2}),
        ),
        'Yes (Birth order: 2)',
      );
    });

    test('returns null for null and unsupported types', () {
      expect(FhirPatientExtractor.extractMultipleBirth(null), isNull);
      expect(
        FhirPatientExtractor.extractMultipleBirth(fhir.FhirString('twin')),
        isNull,
      );
    });
  });

  group('extractCommunicationLanguages', () {
    test('joins text or display of every language', () {
      final patient = fhir.Patient.fromJson(patientJson());
      expect(
        FhirPatientExtractor.extractCommunicationLanguages(
          patient.communication,
        ),
        'English, Spanish',
      );
    });

    test('returns null when nothing is readable', () {
      expect(FhirPatientExtractor.extractCommunicationLanguages(null), isNull);
      expect(
        FhirPatientExtractor.extractCommunicationLanguages(const []),
        isNull,
      );
      final patient = fhir.Patient.fromJson({
        ...patientJson(),
        'communication': [
          {
            'language': codeableConcept(
              codings: [coding('urn:ietf:bcp:47', 'fr')],
            ),
          },
        ],
      });
      expect(
        FhirPatientExtractor.extractCommunicationLanguages(
          patient.communication,
        ),
        isNull,
      );
    });
  });

  group('identifiers and telecom', () {
    final patient = fhir.Patient.fromJson(patientJson());

    test('extractIdentifierByType', () {
      expect(
        FhirPatientExtractor.extractIdentifierByType(patient.identifier, 'MR'),
        'MRN-0042',
      );
      expect(
        FhirPatientExtractor.extractIdentifierByType(patient.identifier, 'SS'),
        isNull,
      );
      expect(FhirPatientExtractor.extractIdentifierByType(null, 'MR'), isNull);
    });

    test('extractTelecomBySystem', () {
      expect(
        FhirPatientExtractor.extractTelecomBySystem(patient.telecom, 'phone'),
        '555-0100',
      );
      expect(
        FhirPatientExtractor.extractTelecomBySystem(
          patient.telecom,
          'phone',
          use: 'mobile',
        ),
        '555-0199',
      );
      expect(
        FhirPatientExtractor.extractTelecomBySystem(
          patient.telecom,
          'email',
          use: 'work',
        ),
        isNull,
      );
      expect(
        FhirPatientExtractor.extractTelecomBySystem(patient.telecom, 'fax'),
        isNull,
      );
      expect(
        FhirPatientExtractor.extractTelecomBySystem(null, 'phone'),
        isNull,
      );
    });

    test('extractAllTelecomBySystem', () {
      final telecom = [
        ...patient.telecom!,
        fhir.ContactPoint.fromJson({'system': 'phone', 'use': 'work'}),
      ];
      expect(FhirPatientExtractor.extractAllTelecomBySystem(telecom, 'phone'), [
        {'value': '555-0100', 'use': 'home'},
        {'value': '555-0199', 'use': 'mobile'},
      ]);
      expect(FhirPatientExtractor.extractAllTelecomBySystem(telecom, 'email'), [
        {'value': 'jane@example.org', 'use': ''},
      ]);
      expect(FhirPatientExtractor.extractAllTelecomBySystem(null, 'phone'), []);
    });

    test('extractTelecom formats the first contact with a value', () {
      expect(
        FhirPatientExtractor.extractTelecom(patient.telecom),
        '555-0100 (home)',
      );
      expect(
        FhirPatientExtractor.extractTelecom([
          fhir.ContactPoint.fromJson({'system': 'phone'}),
          fhir.ContactPoint.fromJson({'system': 'email', 'value': 'a@b.org'}),
        ]),
        'email: a@b.org',
      );
      expect(
        FhirPatientExtractor.extractTelecom([
          fhir.ContactPoint.fromJson({'value': '555-0000'}),
        ]),
        '555-0000',
      );
      expect(
        FhirPatientExtractor.extractTelecom([
          fhir.ContactPoint.fromJson({'system': 'phone'}),
        ]),
        isNull,
      );
      expect(FhirPatientExtractor.extractTelecom(null), isNull);
      expect(FhirPatientExtractor.extractTelecom(const []), isNull);
    });
  });

  group('formatFullAddress', () {
    test('formats lines, city/state/zip and country on separate lines', () {
      final address = fhir.Patient.fromJson(patientJson()).address!.first;
      expect(
        FhirPatientExtractor.formatFullAddress(address),
        '12 Main St\nApt 3\nSpringfield, MA, 01101\nUS',
      );
    });

    test('skips missing parts', () {
      expect(
        FhirPatientExtractor.formatFullAddress(
          fhir.Address.fromJson({'postalCode': '010101', 'country': 'RO'}),
        ),
        '010101\nRO',
      );
      expect(
        FhirPatientExtractor.formatFullAddress(fhir.Address.fromJson(const {})),
        isNull,
      );
      expect(FhirPatientExtractor.formatFullAddress(null), isNull);
    });
  });

  group('raw extensions', () {
    final raw = patientJson();

    test('extractRaceOrEthnicity prefers text, then ombCategory', () {
      expect(
        FhirPatientExtractor.extractRaceOrEthnicity(raw, usCoreRaceUrl),
        'White',
      );
      expect(
        FhirPatientExtractor.extractRaceOrEthnicity(raw, usCoreEthnicityUrl),
        'Not Hispanic or Latino',
      );
    });

    test('extractRaceOrEthnicity returns null when absent', () {
      expect(
        FhirPatientExtractor.extractRaceOrEthnicity(const {}, usCoreRaceUrl),
        isNull,
      );
      expect(
        FhirPatientExtractor.extractRaceOrEthnicity(raw, 'urn:other'),
        isNull,
      );
      expect(
        FhirPatientExtractor.extractRaceOrEthnicity({
          'extension': [
            'garbage',
            {'url': usCoreRaceUrl},
            {
              'url': usCoreRaceUrl,
              'extension': [
                'garbage',
                {'url': 'detailed', 'valueCoding': coding('urn:x', '1')},
              ],
            },
          ],
        }, usCoreRaceUrl),
        isNull,
      );
    });

    test('extractExtensionValue reads code, string and concepts', () {
      const url = 'urn:test';
      final cases = <(Map<String, dynamic>, String?)>[
        ({'valueCode': 'F'}, 'F'),
        ({'valueString': 'Romanian'}, 'Romanian'),
        ({'valueCodeableConcept': codeableConcept(text: 'Married')}, 'Married'),
        (
          {
            'valueCodeableConcept': codeableConcept(
              codings: [coding('urn:x', 'M', 'Married')],
            ),
          },
          'Married',
        ),
        (const {}, null),
      ];
      for (final (ext, expected) in cases) {
        expect(
          FhirPatientExtractor.extractExtensionValue({
            'extension': [
              {'url': url, ...ext},
            ],
          }, url),
          expected,
          reason: '$ext',
        );
      }
      expect(
        FhirPatientExtractor.extractExtensionValue(raw, usCoreBirthSexUrl),
        'F',
      );
      expect(
        FhirPatientExtractor.extractExtensionValue(raw, 'urn:missing'),
        isNull,
      );
      expect(
        FhirPatientExtractor.extractExtensionValue(const {}, 'urn:missing'),
        isNull,
      );
    });

    test('extractBirthPlace', () {
      expect(
        FhirPatientExtractor.extractBirthPlace(raw),
        'Boston, Massachusetts, US',
      );
      expect(
        FhirPatientExtractor.extractBirthPlace({
          'extension': [
            {
              'url': birthPlaceUrl,
              'valueAddress': {'city': 'Cluj-Napoca'},
            },
          ],
        }),
        'Cluj-Napoca',
      );
      expect(
        FhirPatientExtractor.extractBirthPlace({
          'extension': [
            {'url': birthPlaceUrl, 'valueAddress': <String, dynamic>{}},
          ],
        }),
        isNull,
      );
      expect(
        FhirPatientExtractor.extractBirthPlace({
          'extension': [
            'garbage',
            {'url': birthPlaceUrl},
          ],
        }),
        isNull,
      );
      expect(FhirPatientExtractor.extractBirthPlace(const {}), isNull);
    });
  });
}
