import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart' hide Source;
import 'package:health_wallet/features/holders/data/repository/holder_repository_impl.dart';
import 'package:health_wallet/features/holders/domain/services/holder_linking_service.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/records/data/repository/records_repository_impl.dart';
import 'package:health_wallet/features/sync/data/data_source/local/sync_local_data_source.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../records/records_test_helpers.dart';

/// The sources part of the real repository, on the test database.
class _LocalSyncRepository extends Fake implements SyncRepository {
  _LocalSyncRepository(this._local);

  final SyncLocalDataSource _local;

  @override
  Future<List<Source>> getSources() => _local.getSources();

  @override
  Future<void> cacheSources(List<Source> sources) =>
      _local.cacheSources(sources);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late RecordsRepositoryImpl records;
  late HolderService service;

  setUp(() async {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    records = await openRepository(db);
    final prefs = await SharedPreferences.getInstance();
    final holders = HolderRepositoryImpl(db);
    service = HolderService(
      HolderLinkingService(holders),
      holders,
      records,
      _LocalSyncRepository(SyncLocalDataSourceImpl(db, prefs)),
    );
  });

  tearDown(() => db.close());

  Future<void> source(String id, {String? holderId}) => db.customStatement(
    'INSERT INTO sources (id, platform_type, holder_id) VALUES (?, ?, ?)',
    [
      id,
      id.startsWith('wallet-') || id == 'demo_data' ? 'wallet' : 'fasten',
      holderId,
    ],
  );

  Future<void> patient(
    String id,
    String sourceId, {
    String? given,
    String? family,
    String? birthDate,
    String? identifier,
  }) => insertResource(
    db,
    id: id,
    type: 'Patient',
    sourceId: sourceId,
    title: '${given ?? ''} ${family ?? ''}'.trim(),
    raw: {
      if (given != null || family != null)
        'name': [
          {
            'use': 'official',
            'given': ?(given == null ? null : [given]),
            'family': ?family,
          },
        ],
      'birthDate': ?birthDate,
      if (identifier != null)
        'identifier': [
          {'system': 'http://hospital/mrn', 'value': identifier},
        ],
    },
  );

  Future<String?> holderOf(String sourceId) async =>
      (await db
              .customSelect(
                'SELECT holder_id FROM sources WHERE id = ?',
                variables: [Variable(sourceId)],
              )
              .getSingle())
          .read<String?>('holder_id');

  Future<void> placeholder() async {
    await source('wallet-default_patient');
    await patient(
      'default_patient',
      'wallet-default_patient',
      given: 'Health Wallet',
      family: 'Holder',
    );
  }

  test('next to the default holder, a provider patient who matches no one '
      'is asked about and stays out until answered', () async {
    await placeholder();
    await patient('p1', 'epic', given: 'Jane', family: 'Doe');

    final directory = await service.load();

    expect(directory.holders.single.id, 'default_patient');
    expect(directory.questions.single.patient.id, 'p1');
    expect(directory.ofSource('epic'), isNull);
  });

  test('of two copies of the default patient, the one with details is '
      'shown, edited and written', () async {
    await placeholder();
    // Another device's copy, under its own random id, already filled in.
    await insertResource(
      db,
      id: '0a1b2c',
      type: 'Patient',
      sourceId: 'wallet-default_patient',
      title: 'Pop, Mihai',
      raw: {
        'name': [
          {
            'use': 'official',
            'given': ['Mihai'],
            'family': 'Pop',
          },
        ],
        'identifier': [
          {'value': '1990824313713'},
        ],
      },
    );

    final holder = (await service.load()).holders.single;
    expect(holder.representativePatient.id, '0a1b2c');
    expect(holder.getPatientForSource('wallet-default_patient')!.id, '0a1b2c');
    expect(service.isUnnamed(holder), isFalse);
    expect(
      (await service.walletPatientOf('default_patient')).patient.id,
      '0a1b2c',
    );
  });

  test('with several people a newcomer is asked about, stays out of every '
      'holder until answered, and the answer is kept', () async {
    await source('wallet-jane', holderId: 'jane');
    await patient('jane', 'wallet-jane', given: 'Jane');
    await source('wallet-tom', holderId: 'tom');
    await patient('tom', 'wallet-tom', given: 'Tom');
    await patient('p1', 'kaiser', given: 'Anna');

    var directory = await service.load();
    expect(
      directory.holders.map((h) => h.id),
      unorderedEquals(['jane', 'tom']),
    );
    final ask = directory.questions.single;
    expect(ask.patient.id, 'p1');
    expect(directory.ofSource('kaiser'), isNull);

    await service.answer(ask.question, holderId: 'jane');
    directory = await service.load();
    expect(directory.questions, isEmpty);
    expect(directory.byId('jane')!.sourceIds, ['kaiser', 'wallet-jane']);
  });

  test('someone else becomes a holder of their own', () async {
    await source('wallet-jane', holderId: 'jane');
    await patient('jane', 'wallet-jane');
    await source('wallet-tom', holderId: 'tom');
    await patient('tom', 'wallet-tom');
    await patient('p1', 'kaiser');

    final ask = (await service.load()).questions.single;
    await service.answer(ask.question);

    expect(await holderOf('kaiser'), 'p1');
    expect((await service.load()).holders, hasLength(3));
  });

  group('wallet source', () {
    test("a provider patient's records go to their holder's wallet source, "
        'not one named after the provider row', () async {
      await placeholder();
      await source('epic', holderId: 'default_patient');
      await patient('p1', 'epic');

      final wallet = await service.walletSourceForPatient('p1');
      expect(wallet.id, 'wallet-default_patient');
    });

    test('a holder without one gets wallet-<holder id>, linked to them, and '
        'keeps it', () async {
      await source('epic', holderId: 'p1');
      await patient('p1', 'epic', given: 'Jane');

      final made = await service.walletSourceOf('p1');
      expect(made.id, 'wallet-p1');
      expect(await holderOf('wallet-p1'), 'p1');
      expect(
        (await service.walletSourceOf('p1')).id,
        'wallet-p1',
      );
    });

    test('a wallet source made under another name before is reused', () async {
      await source('epic', holderId: 'p1');
      await patient('p1', 'epic');
      await source('wallet-fhir-1', holderId: 'p1');

      expect(
        (await service.walletSourceOf('p1')).id,
        'wallet-fhir-1',
      );
    });
  });

  group('a scanned patient', () {
    MappingPatient scanned({
      String given = '',
      String family = '',
      String birthDate = '',
      String identifier = '',
    }) => MappingPatient(
      id: 'draft',
      givenName: MappedProperty(value: given),
      familyName: MappedProperty(value: family),
      dateOfBirth: MappedProperty(value: birthDate),
      patientIdentifier: MappedProperty(value: identifier),
    );

    Future<void> twoPeople() async {
      await source('wallet-jane', holderId: 'jane');
      await patient(
        'jane',
        'wallet-jane',
        given: 'Jane',
        family: 'Doe',
        birthDate: '1980-04-02',
      );
      await source('epic', holderId: 'jane');
      await patient('p1', 'epic', identifier: 'MRN-55501');
      await source('wallet-tom', holderId: 'tom');
      await patient('tom', 'wallet-tom', given: 'Tom', family: 'Doe');
    }

    test(
      'matches a holder by identifier or by name and full birth date',
      () async {
        await twoPeople();
        final directory = await service.load();

        expect(
          service.matchScanned(scanned(identifier: 'mrn 55501'), directory)?.id,
          'jane',
        );
        expect(
          service
              .matchScanned(
                scanned(given: 'jane', family: 'DOE', birthDate: '1980-04-02'),
                directory,
              )
              ?.id,
          'jane',
        );
      },
    );

    test('a name without a birth date on both sides matches no one', () async {
      await twoPeople();
      final directory = await service.load();

      expect(
        service.matchScanned(scanned(given: 'Tom', family: 'Doe'), directory),
        isNull,
      );
    });

    test('with only the unnamed default holder, it is proposed', () async {
      await placeholder();
      await source('demo_data');
      await patient('demo-patient', 'demo_data', given: 'Demo');
      final directory = await service.load();

      expect(
        service.matchScanned(scanned(given: 'Ana'), directory)?.id,
        'default_patient',
      );
    });
  });

  group("the person's wallet Patient", () {
    Future<Map<String, dynamic>> rawOf(String id) async => jsonDecode(
      (await db
              .customSelect(
                'SELECT resource_raw FROM fhir_resource WHERE id = ?',
                variables: [Variable(id)],
              )
              .getSingle())
          .read<String>('resource_raw'),
    ) as Map<String, dynamic>;

    test('a provider-only person gets a copy in their wallet source, and the '
        "provider's row is left as it is", () async {
      await source('epic', holderId: 'p1');
      await patient('p1', 'epic', given: 'Jane', family: 'Doe');
      final before = await rawOf('p1');

      final first = await service.walletPatientOf('p1');
      expect(first.holderId, 'p1');
      expect(first.patient.sourceId, 'wallet-p1');
      expect(first.patient.id, isNot('p1'));
      expect((await rawOf(first.patient.id))['name'], before['name']);
      expect(await rawOf('p1'), before);

      final again = await service.walletPatientOf('p1');
      expect(again.patient.id, first.patient.id);
    });

    test('scanned details fill only what the row leaves empty', () async {
      await source('wallet-jane', holderId: 'jane');
      await patient('jane', 'wallet-jane', given: 'Jane', family: 'Doe');

      final written = await service.walletPatientOf(
        'jane',
        scanned: const MappingPatient(
          id: 'draft',
          givenName: MappedProperty(value: 'Janet'),
          familyName: MappedProperty(value: 'Smith'),
          dateOfBirth: MappedProperty(value: '1980-04-02'),
        ),
      );

      final raw = await rawOf(written.patient.id);
      expect(written.patient.id, 'jane');
      expect(raw['birthDate'], '1980-04-02');
      expect((raw['name'] as List).single['family'], 'Doe');
    });

    test('the default holder takes the scanned name and identifier', () async {
      await placeholder();
      await db.customStatement(
        'UPDATE fhir_resource SET resource_raw = json_set(resource_raw, '
        "'\$.identifier', json('[{\"value\":\"default_patient\"}]')) "
        "WHERE id = 'default_patient'",
      );

      final written = await service.walletPatientOf(
        'default_patient',
        scanned: const MappingPatient(
          id: 'draft',
          givenName: MappedProperty(value: 'Ana'),
          familyName: MappedProperty(value: 'Pop'),
          patientIdentifier: MappedProperty(value: '1800402123456'),
        ),
      );

      final raw = await rawOf('default_patient');
      expect(written.patient.title, 'Pop, Ana');
      expect((raw['name'] as List).single['given'], ['Ana']);
      expect((raw['identifier'] as List).single['value'], '1800402123456');
    });
  });

  group('the same person linked on two devices', () {
    Future<void> person(
      String id, {
      required String given,
      required String family,
      required String system,
      required String code,
    }) async {
      await source('wallet-$id', holderId: id);
      await insertResource(
        db,
        id: id,
        type: 'Patient',
        sourceId: 'wallet-$id',
        raw: {
          'name': [
            {
              'use': 'official',
              'given': [given],
              'family': family,
            },
          ],
          'birthDate': '1980-04-02',
          'identifier': [
            {
              'system': system,
              'value': '1800402123456',
              'type': {
                'coding': [
                  {'code': code},
                ],
              },
            },
          ],
        },
      );
    }

    test('is one person once both are here, under the same holder on both '
        'devices', () async {
      // Each device linked its own copy before they synced; the names were
      // typed the other way round on one of them.
      await person(
        'phone-1',
        given: 'Ion',
        family: 'Popescu',
        system: 'urn:oid:2.16.840.1.113883.4.40',
        code: 'SS',
      );
      await person(
        'desktop-1',
        given: 'Popescu',
        family: 'Ion',
        system: 'urn:oid:2.16.840.1.113883.4.40',
        code: 'SS',
      );

      final holder = (await service.load()).holders.single;
      expect(holder.id, 'desktop-1', reason: 'the smaller id, on any device');
      expect(holder.sourceIds, ['wallet-desktop-1', 'wallet-phone-1']);
      expect(await holderOf('wallet-phone-1'), 'desktop-1');
    });

    test('is one person when the ID was typed under two regions', () async {
      await person(
        'phone-1',
        given: 'Ion',
        family: 'Popescu',
        system: 'urn:oid:2.16.840.1.113883.4.40',
        code: 'SS',
      );
      await person(
        'desktop-1',
        given: 'Ion',
        family: 'Popescu',
        system: 'http://healthwallet.me/id',
        code: 'MR',
      );

      expect((await service.load()).holders, hasLength(1));
    });
  });
}
