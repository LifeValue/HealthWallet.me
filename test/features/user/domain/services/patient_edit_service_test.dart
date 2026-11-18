import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/utils/blood_observation_utils.dart';
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/holders/domain/entity/holder_patient.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';
import 'package:health_wallet/features/user/domain/services/default_patient_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_edit_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/log_capture.dart';
import 'patient_edit_service_fakes.dart';

const _walletSource = Source(id: 'wallet-ana');
const _epicSource = Source(id: 'epic', platformType: 'epic');

const _identifierTypes = 'http://terminology.hl7.org/CodeSystem/v2-0203';

Map<String, dynamic> _identifier(String code, String value) => {
  'type': {
    'coding': [
      {'system': _identifierTypes, 'code': code},
    ],
  },
  'value': value,
};

const _emergencyContact = {
  'relationship': [
    {
      'coding': [
        {
          'system': 'http://terminology.hl7.org/CodeSystem/v2-0131',
          'code': 'C',
        },
      ],
    },
  ],
  'telecom': [
    {'system': 'phone', 'value': '+40700000000'},
  ],
};

const _nextOfKin = {
  'relationship': [
    {
      'coding': [
        {'code': 'N'},
      ],
    },
  ],
  'name': {'text': 'Next of kin'},
};

const _noRelationship = {
  'name': {'text': 'Neighbour'},
};

const _relationshipWithoutCoding = {
  'relationship': [
    {'text': 'Friend'},
  ],
  'name': {'text': 'Friend'},
};

/// A Patient row whose fields are read from [raw], as the database does.
Patient _patient({
  String id = 'ana',
  String sourceId = 'wallet-ana',
  String resourceId = 'ana-r',
  String title = '',
  Map<String, dynamic> raw = const {},
}) {
  final rawResource = {'resourceType': 'Patient', 'id': resourceId, ...raw};
  final fhir = fhir_r4.Patient.fromJson(rawResource);
  return Patient(
    id: id,
    sourceId: sourceId,
    resourceId: resourceId,
    title: title,
    rawResource: rawResource,
    identifier: fhir.identifier,
    name: fhir.name,
    telecom: fhir.telecom,
    gender: fhir.gender,
    birthDate: fhir.birthDate,
    address: fhir.address,
    contact: fhir.contact,
  );
}

/// The provider's copy of Ana, which the app can't change.
Patient _anaAtEpic({Map<String, dynamic> raw = const {}}) => _patient(
  id: 'epic_ana',
  sourceId: 'epic',
  resourceId: 'epic-r',
  title: 'Pop, Ana',
  raw: {
    'name': [
      {
        'family': 'Pop',
        'given': ['Ana'],
      },
    ],
    'gender': 'female',
    'birthDate': '1985-05-14',
    'telecom': [
      {'system': 'phone', 'value': '+40711111111'},
    ],
    'address': [
      {'city': 'Cluj'},
    ],
    ...raw,
  },
);

List<Map<String, dynamic>> _identifiersOf(Patient patient) => [
  for (final id in patient.rawResource['identifier'] as List? ?? const [])
    Map<String, dynamic>.from(id as Map),
];

String? _codeOf(Map<String, dynamic> identifier) =>
    ((identifier['type'] as Map)['coding'] as List).first['code'] as String?;

List<Map<String, dynamic>> _contactsOf(Patient patient) => [
  for (final contact in patient.rawResource['contact'] as List? ?? const [])
    Map<String, dynamic>.from(contact as Map),
];

String? _contactName(Map<String, dynamic> contact) =>
    (contact['name'] as Map?)?['text'] as String?;

String? _contactPhone(Map<String, dynamic> contact) =>
    ((contact['telecom'] as List?)?.first as Map?)?['value'] as String?;

Observation _bloodType(String bloodType, {String id = 'blood'}) =>
    BloodObservationUtils.createBloodTypeObservation(
      bloodType: bloodType,
      patientSourceId: 'wallet-ana',
      patientResourceId: 'ana-r',
      customId: id,
    ).copyWith(date: DateTime(2024));

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final logs = captureLogs();

  late FakeEditRecords records;
  late FakeEditHolders holders;
  late PatientEditService service;

  Future<Patient> save(
    Patient patient, {
    List<String>? given,
    String? family,
    DateTime? birthDate,
    String? gender,
    String? identifierValue,
    String? contactPhone,
    List<Source> sources = const [_walletSource, _epicSource],
  }) => service.savePatientEdits(
    currentPatient: patient,
    given: given,
    family: family,
    birthDate: birthDate,
    gender: gender,
    identifierValue: identifierValue,
    contactPhone: contactPhone,
    availableSources: sources,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      SharedPrefsConstants.countryCode: 'RO',
    });
    records = FakeEditRecords();
    holders = FakeEditHolders();
    service = PatientEditService(records, const SourceTypeService(), holders);
  });

  group('savePatientEdits', () {
    test('fails, writing nothing, when the patient\'s source is not '
        'among the available ones', () async {
      final orphan = _patient(sourceId: 'gone');

      await expectLater(
        save(orphan, given: ['Ana'], sources: [_walletSource]),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            contains('Source not found for gone'),
          ),
        ),
      );
      expect(records.updated, isEmpty);
      expect(holders.walletSourceRequests, isEmpty);
    });

    test('takes the identifier type of the device\'s country when no '
        'country was chosen', () async {
      SharedPreferences.setMockInitialValues({});
      binding.platformDispatcher.localeTestValue = const Locale('en', 'GB');
      addTearDown(binding.platformDispatcher.clearLocaleTestValue);

      final saved = await save(_patient(), identifierValue: '9434765919');

      final identifier = _identifiersOf(saved).single;
      expect(_codeOf(identifier), 'NH');
      expect(identifier['system'], 'https://fhir.nhs.uk/Id/nhs-number');
    });

    group('on a wallet patient, edits the row in place', () {
      final ana = _patient(
        title: 'Pop, Ana',
        raw: {
          'name': [
            {
              'family': 'Pop',
              'given': ['Ana'],
            },
          ],
          'gender': 'female',
          'birthDate': '1985-05-14',
          'identifier': [_identifier('SS', '2850514123456')],
          'contact': [_emergencyContact],
        },
      );

      test('changes nothing when no field is given', () async {
        final saved = await save(ana);

        expect(saved.id, ana.id);
        expect(saved.sourceId, ana.sourceId);
        expect(saved.title, 'Pop, Ana');
        expect(saved.rawResource['name'], ana.rawResource['name']);
        expect(saved.rawResource['gender'], 'female');
        expect(saved.rawResource['birthDate'], '1985-05-14');
        expect(saved.rawResource['identifier'], ana.rawResource['identifier']);
        expect(saved.rawResource['contact'], ana.rawResource['contact']);
        expect(records.updated.single, saved);
        expect(holders.walletSourceRequests, isEmpty);
      });

      test('renames the patient and their title, family name first', () async {
        final saved = await save(
          ana,
          given: ['Ana', 'Maria'],
          family: 'Ionescu',
        );

        expect(saved.rawResource['name'], [
          {
            'text': 'Ionescu, Ana Maria',
            'family': 'Ionescu',
            'given': ['Ana', 'Maria'],
          },
        ]);
        expect(saved.title, 'Ionescu, Ana Maria');
        expect(saved.name!.single.family?.valueString, 'Ionescu');
        expect(records.updated.single.title, 'Ionescu, Ana Maria');
      });

      test('keeps the given names when only the family name changes', () async {
        final saved = await save(ana, family: 'Ionescu');

        expect(saved.title, 'Ionescu, Ana');
        expect(saved.name!.single.given!.single.valueString, 'Ana');
      });

      test('keeps the title when the new name is empty', () async {
        final saved = await save(ana, given: [], family: '');

        expect(saved.title, 'Pop, Ana');
        expect(saved.rawResource['name'], isNull);
      });

      test('maps the gender picker\'s choice to the FHIR code', () async {
        expect(
          (await save(ana, gender: 'Male')).gender,
          fhir_r4.AdministrativeGender.male,
        );
        expect(
          (await save(ana, gender: 'Female')).rawResource['gender'],
          'female',
        );
        expect(
          (await save(ana, gender: 'Prefer not to say')).rawResource['gender'],
          'unknown',
        );
      });

      test('sets the birth date as a FHIR date', () async {
        final saved = await save(ana, birthDate: DateTime(1990, 2, 3));

        expect(saved.rawResource['birthDate'], '1990-02-03');
        expect(
          FhirFieldExtractor.extractPatientBirthDate(saved),
          DateTime(1990, 2, 3),
        );
      });

      group('the identifier', () {
        test(
          'replaces the main ID, under the chosen country\'s type',
          () async {
            final saved = await save(ana, identifierValue: '1900203123456');

            final identifier = _identifiersOf(saved).single;
            expect(identifier['value'], '1900203123456');
            expect(_codeOf(identifier), 'SS');
            expect(identifier['system'], 'urn:oid:2.16.840.1.113883.4.40');
            expect(
              saved.identifier!.single.value?.valueString,
              '1900203123456',
            );
          },
        );

        test('is added after the IDs of other kinds, which stay', () async {
          final withOthers = _patient(
            raw: {
              'identifier': [
                _identifier('XX', 'X-1'),
                {'system': 'urn:loose', 'value': 'loose'},
              ],
            },
          );

          final saved = await save(withOthers, identifierValue: '42');

          expect(_identifiersOf(saved).map((id) => id['value']), [
            'X-1',
            'loose',
            '42',
          ]);
          expect(_codeOf(_identifiersOf(saved).last), 'SS');
        });

        test('is added to a patient with none', () async {
          final saved = await save(_patient(), identifierValue: '42');

          expect(_identifiersOf(saved).single['value'], '42');
        });

        test('emptied, removes only the main ID', () async {
          final withOthers = _patient(
            raw: {
              'identifier': [
                _identifier('XX', 'X-1'),
                _identifier('MR', 'MRN-1'),
              ],
            },
          );

          final saved = await save(withOthers, identifierValue: '');

          expect(_identifiersOf(saved).single['value'], 'X-1');
        });

        test('emptied on a patient with none stays absent', () async {
          final saved = await save(_patient(), identifierValue: '');

          expect(saved.rawResource['identifier'], isNull);
          expect(saved.identifier, isNull);
        });

        test('emptied leaves IDs of other kinds alone', () async {
          final saved = await save(
            _patient(
              raw: {
                'identifier': [_identifier('XX', 'X-1')],
              },
            ),
            identifierValue: '',
          );

          expect(_identifiersOf(saved).single['value'], 'X-1');
        });
      });

      group('the emergency contact', () {
        test('is added to a patient with no contacts', () async {
          final saved = await save(_patient(), contactPhone: '+40722222222');

          final contact = _contactsOf(saved).single;
          expect(_contactPhone(contact), '+40722222222');
          expect(
            ((contact['relationship'] as List).single['coding'] as List)
                .single['code'],
            'C',
          );
          expect(saved.contact, hasLength(1));
        });

        test(
          'replaces the old one, first, keeping the other contacts',
          () async {
            final family = _patient(
              raw: {
                'contact': [
                  _nextOfKin,
                  _emergencyContact,
                  _noRelationship,
                  _relationshipWithoutCoding,
                ],
              },
            );

            final saved = await save(family, contactPhone: '+40722222222');

            final contacts = _contactsOf(saved);
            expect(contacts, hasLength(4));
            expect(_contactPhone(contacts.first), '+40722222222');
            expect(contacts.skip(1).map(_contactName), [
              'Next of kin',
              'Neighbour',
              'Friend',
            ]);
          },
        );

        test('emptied, is removed and the other contacts stay', () async {
          final family = _patient(
            raw: {
              'contact': [_emergencyContact, _nextOfKin, _noRelationship],
            },
          );

          final saved = await save(family, contactPhone: '');

          expect(_contactsOf(saved).map(_contactName), [
            'Next of kin',
            'Neighbour',
          ]);
        });

        test(
          'emptied, leaves no contact list when it was the only one',
          () async {
            final saved = await save(ana, contactPhone: '');

            expect(saved.rawResource['contact'], isNull);
            expect(saved.contact, isNull);
          },
        );

        test('emptied on a patient with no contacts changes nothing', () async {
          final saved = await save(_patient(), contactPhone: '');

          expect(saved.rawResource['contact'], isNull);
          expect(saved.contact, isNull);
        });
      });
    });

    group('the default holder\'s placeholder identifier', () {
      Future<Patient> placeholder() => DefaultPatientService(
        records,
        FakeEditSyncLocalDataSource(),
        holders,
      ).createDefaultWalletHolder();

      const defaultSource = Source(id: 'wallet-default_patient');

      test('stays as it is when the ID is not edited', () async {
        final holder = await placeholder();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(SharedPrefsConstants.countryCode, 'GB');

        final saved = await save(
          holder,
          given: ['Ana'],
          family: 'Pop',
          sources: [defaultSource],
        );

        final identifier = _identifiersOf(saved).single;
        expect(identifier['value'], HolderPatient.placeholderRowId);
        // Still the Romanian type it was made with.
        expect(_codeOf(identifier), 'SS');
        expect(saved.title, 'Pop, Ana');
      });

      test('is kept when it follows IDs of other kinds', () async {
        final holder = await placeholder();
        final raw = Map<String, dynamic>.from(holder.rawResource);
        raw['identifier'] = [
          _identifier('XX', 'X-1'),
          ...raw['identifier'] as List,
        ];
        final withOthers = _patient(
          id: holder.id,
          sourceId: holder.sourceId,
          resourceId: holder.resourceId,
          raw: raw,
        );

        final saved = await save(
          withOthers,
          identifierValue: '',
          sources: [defaultSource],
        );

        expect(_identifiersOf(saved).map((id) => id['value']), [
          'X-1',
          HolderPatient.placeholderRowId,
        ]);
        expect(FhirFieldExtractor.extractPatientIdentifierValue(saved), '');
      });

      test('only counts on an ID of a known type', () async {
        final saved = await save(
          _patient(
            raw: {
              'identifier': [
                _identifier('XX', HolderPatient.placeholderRowId),
              ],
            },
          ),
          identifierValue: '',
        );

        // Left as it was, and no placeholder ID added.
        expect(_identifiersOf(saved).single['value'], 'default_patient');
        expect(_codeOf(_identifiersOf(saved).single), 'XX');
      });
    });

    group('on a provider\'s patient, writes to the person\'s wallet copy', () {
      test('makes the copy in their wallet source the first time, '
          'leaving the provider\'s row as it was', () async {
        final ana = _anaAtEpic();

        final saved = await save(
          ana,
          given: ['Ana'],
          family: 'Ionescu',
          birthDate: DateTime(1990, 2, 3),
          gender: 'Male',
          identifierValue: '1900203123456',
          contactPhone: '+40722222222',
        );

        // Not linked to a holder yet: a holder of their own.
        expect(holders.walletSourceRequests, ['epic_ana']);
        expect(saved.sourceId, 'wallet-new');
        expect(saved.resourceId, isNot('epic-r'));
        expect(saved.id, 'wallet-new_${saved.resourceId}');
        expect(saved.rawResource['id'], saved.resourceId);
        expect(saved.title, 'Ionescu, Ana');
        expect(saved.rawResource['name'], [
          {
            'text': 'Ionescu, Ana',
            'family': 'Ionescu',
            'given': ['Ana'],
          },
        ]);
        expect(saved.rawResource['gender'], 'male');
        expect(saved.gender, fhir_r4.AdministrativeGender.male);
        expect(saved.rawResource['birthDate'], '1990-02-03');
        expect(_identifiersOf(saved).single['value'], '1900203123456');
        expect(saved.identifier!.single.value?.valueString, '1900203123456');
        expect(_contactPhone(_contactsOf(saved).single), '+40722222222');
        expect(saved.contact, hasLength(1));
        // What the edit didn't touch comes along.
        expect(saved.rawResource['telecom'], ana.rawResource['telecom']);
        expect(saved.rawResource['address'], ana.rawResource['address']);
        expect(saved.telecom, ana.telecom);
        expect(saved.address, ana.address);

        expect(records.updated.single, saved);
        expect(ana.rawResource['name'], [
          {
            'family': 'Pop',
            'given': ['Ana'],
          },
        ]);
      });

      test('copies the provider\'s details as they are when nothing is '
          'edited', () async {
        final ana = _anaAtEpic(
          raw: {
            'identifier': [_identifier('MR', 'MRN-1')],
            'contact': [_emergencyContact],
          },
        );

        final saved = await save(ana);

        expect(saved.title, 'Pop, Ana');
        expect(saved.rawResource['name'], ana.rawResource['name']);
        expect(saved.rawResource['gender'], 'female');
        expect(saved.rawResource['birthDate'], '1985-05-14');
        expect(saved.rawResource['identifier'], ana.rawResource['identifier']);
        expect(saved.rawResource['contact'], ana.rawResource['contact']);
      });

      test('keeps the provider\'s title for a copy with no name', () async {
        final nameless = _patient(
          id: 'epic_x',
          sourceId: 'epic',
          title: 'Patient from Epic',
          raw: {'gender': 'female'},
        );

        final saved = await save(nameless, gender: 'Female');

        expect(saved.title, 'Patient from Epic');
        expect(saved.rawResource['name'], isNull);
      });

      test('keeps the provider\'s title when the new name is empty', () async {
        final saved = await save(_anaAtEpic(), given: [], family: '');

        expect(saved.title, 'Pop, Ana');
        expect(saved.rawResource['name'], isNull);
      });

      test('the copy drops a cleared emergency contact', () async {
        final ana = _anaAtEpic(
          raw: {
            'contact': [_emergencyContact],
          },
        );

        final saved = await save(ana, contactPhone: '');

        expect(saved.rawResource['contact'], isNull);
      });

      test('edits the copy made earlier rather than making another', () async {
        final ana = _anaAtEpic();
        final copy = _patient(
          id: 'wallet-ana_copy',
          sourceId: 'wallet-ana',
          resourceId: 'copy',
          title: 'Pop, Ana',
          raw: {
            'name': [
              {
                'family': 'Pop',
                'given': ['Ana'],
              },
            ],
          },
        );
        holders
          ..walletSource = _walletSource
          ..directory = HolderDirectory(
            holders: [
              Holder(
                id: 'ana',
                representativePatient: copy,
                sourceIds: const ['epic', 'wallet-ana'],
                allPatientInstances: [copy, ana],
              ),
            ],
          );

        final saved = await save(ana, family: 'Ionescu');

        expect(holders.walletSourceRequests, ['ana']);
        expect(saved.id, 'wallet-ana_copy');
        expect(saved.resourceId, 'copy');
        expect(saved.title, 'Ionescu, Ana');
        expect(records.updated.single.id, 'wallet-ana_copy');
      });

      test('makes the copy in the holder\'s wallet source when they have '
          'none there yet', () async {
        final ana = _anaAtEpic();
        holders
          ..walletSource = _walletSource
          ..directory = HolderDirectory(
            holders: [
              Holder(
                id: 'ana',
                representativePatient: ana,
                sourceIds: const ['epic'],
                allPatientInstances: [ana],
              ),
            ],
          );

        final saved = await save(ana, gender: 'Male');

        expect(holders.walletSourceRequests, ['ana']);
        expect(saved.sourceId, 'wallet-ana');
        expect(saved.id, 'wallet-ana_${saved.resourceId}');
        expect(saved.rawResource['gender'], 'male');
      });
    });
  });

  group('getCurrentBloodType', () {
    test(
      'reads the newest blood type of the patient, in their source',
      () async {
        records.bloodTypeObservations = [
          _bloodType('A+', id: 'old').copyWith(date: DateTime(2020)),
          _bloodType('O-', id: 'new').copyWith(date: DateTime(2024)),
        ];

        expect(await service.getCurrentBloodType(_patient()), 'O-');
        expect(records.bloodTypeReads.single, (
          patientId: 'ana',
          sourceId: 'wallet-ana',
        ));
      },
    );

    test('reads every source for a patient with none', () async {
      await service.getCurrentBloodType(_patient(sourceId: ''));

      expect(records.bloodTypeReads.single.sourceId, isNull);
    });

    test('is null when there is none', () async {
      expect(await service.getCurrentBloodType(_patient()), isNull);
    });

    test('is null when it can\'t be read', () async {
      records.bloodTypeReadError = Exception('database closed');

      expect(await service.getCurrentBloodType(_patient()), isNull);
    });
  });

  group('updateBloodTypeObservation', () {
    final anaAtEpic = _anaAtEpic();

    setUp(() => holders.walletPatient = _patient());

    test('changes the blood type the person has', () async {
      records.bloodTypeObservations = [_bloodType('A+')];

      await service.updateBloodTypeObservation(anaAtEpic, 'B-');

      expect(holders.walletPatientRequests, ['epic_ana']);
      expect(records.bloodTypeReads.single, (
        patientId: 'ana',
        sourceId: 'wallet-ana',
      ));
      final saved = records.saved.single as Observation;
      expect(saved.id, 'blood');
      expect(saved.date!.isAfter(DateTime(2024)), isTrue);
      expect(
        FhirFieldExtractor.extractBloodTypeFromObservations([saved]),
        'B-',
      );
      expect(
        (saved.rawResource['valueCodeableConcept'] as Map)['text'],
        'B-',
      );
      expect(
        saved.rawResource['code'],
        _bloodType('A+').rawResource['code'],
      );
    });

    test('adds one on the wallet Patient when the person has none', () async {
      holders.walletPatient = _patient(sourceId: '');

      await service.updateBloodTypeObservation(anaAtEpic, 'AB+');

      expect(records.bloodTypeReads.single.sourceId, isNull);
      final saved = records.saved.single as Observation;
      expect(saved.rawResource['subject']?['reference'], 'Patient/ana-r');
      expect(
        FhirFieldExtractor.extractBloodTypeFromObservations([saved]),
        'AB+',
      );
    });

    test('N/A clears the value of the one the person has', () async {
      records.bloodTypeObservations = [_bloodType('A+')];

      await service.updateBloodTypeObservation(anaAtEpic, 'N/A');

      final cleared = records.saved.single as Observation;
      expect(cleared.id, 'blood');
      expect(cleared.valueX, isNull);
      expect(cleared.rawResource.containsKey('valueCodeableConcept'), isFalse);
      expect(cleared.rawResource['code'], isNotNull);
      expect(cleared.date!.isAfter(DateTime(2024)), isTrue);
    });

    test('N/A saves nothing when the person has none', () async {
      await service.updateBloodTypeObservation(anaAtEpic, 'N/A');

      expect(records.saved, isEmpty);
    });

    test('saves nothing for a value that is not a blood type', () async {
      records.bloodTypeObservations = [_bloodType('A+')];

      await service.updateBloodTypeObservation(anaAtEpic, 'Z+');

      expect(records.saved, isEmpty);
      expect(logs, loggedWarning('Invalid blood type: Z+'));
    });

    test('logs and passes on a failure', () async {
      holders.walletPatientError = StateError('no wallet');

      await expectLater(
        service.updateBloodTypeObservation(anaAtEpic, 'A+'),
        throwsStateError,
      );
      expect(records.saved, isEmpty);
      expect(logs, loggedWarning('Error updating blood type observation'));
    });
  });

  group('hasPatientChanges', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final ana = _patient(
      raw: {
        'gender': 'female',
        'birthDate': '1985-05-14',
        'identifier': [_identifier('SS', '2850514123456')],
      },
    );

    setUp(() => records.bloodTypeObservations = [_bloodType('A+')]);

    Future<bool> changed({
      DateTime? birthDate,
      String? gender,
      String bloodType = 'A+',
      String? identifier = '2850514123456',
      Patient? patient,
    }) => service.hasPatientChanges(
      currentPatient: patient ?? ana,
      newBirthDate: birthDate ?? DateTime(1985, 5, 14),
      newGender: gender ?? l10n.female,
      newBloodType: bloodType,
      newIdentifierValue: identifier,
      l10n: l10n,
    );

    test('is false when every field is as stored', () async {
      expect(await changed(), isFalse);
    });

    test('is true when the birth date changes', () async {
      expect(await changed(birthDate: DateTime(1985, 5, 15)), isTrue);
    });

    test('is true when the gender changes', () async {
      expect(await changed(gender: l10n.male), isTrue);
    });

    test('is true when the blood type changes', () async {
      expect(await changed(bloodType: 'O+'), isTrue);
    });

    test('is true when the identifier changes', () async {
      expect(await changed(identifier: '1900203123456'), isTrue);
    });

    test('reads no identifier and no gender as unchanged', () async {
      final bare = _patient(raw: {'birthDate': '1985-05-14'});

      expect(
        await changed(
          patient: bare,
          gender: l10n.preferNotToSay,
          identifier: null,
        ),
        isFalse,
      );
      expect(
        await changed(patient: bare, gender: l10n.preferNotToSay),
        isTrue,
      );
    });

    test('counts N/A as a change when no blood type is stored', () async {
      records.bloodTypeObservations = [];

      expect(await changed(bloodType: 'N/A'), isTrue);
    });
  });

  group('validatePatientData', () {
    bool valid(DateTime? birthDate) => service.validatePatientData(
      birthDate: birthDate,
      gender: 'female',
      bloodType: 'A+',
    );

    test('needs a birth date', () => expect(valid(null), isFalse));

    test('refuses a birth date in the future', () {
      expect(valid(DateTime.now().add(const Duration(days: 1))), isFalse);
    });

    test('takes a birth date in the past', () {
      expect(valid(DateTime(1985, 5, 14)), isTrue);
    });
  });
}
