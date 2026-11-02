import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/holders/data/repository/holder_repository_impl.dart';
import 'package:health_wallet/features/holders/domain/services/holder_linking_service.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late HolderRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    repository = HolderRepositoryImpl(db);
  });

  tearDown(() => db.close());

  Future<void> source(String id, {String? holderId, int? deletedAt}) =>
      db.customStatement(
        'INSERT INTO sources (id, platform_type, holder_id, deleted_at) '
        'VALUES (?, ?, ?, ?)',
        [id, 'fasten', holderId, deletedAt],
      );

  Future<void> record(
    String id,
    String sourceId,
    String type,
    Object raw, {
    String? resourceId,
  }) => db.customStatement(
    'INSERT INTO fhir_resource (id, source_id, resource_type, resource_id, '
    'resource_raw) VALUES (?, ?, ?, ?, ?)',
    [
      id,
      sourceId,
      type,
      resourceId ?? id,
      raw is String ? raw : jsonEncode(raw),
    ],
  );

  Future<Map<String, Object?>> sourceRow(String id) async =>
      (await db
              .customSelect(
                'SELECT * FROM sources WHERE id = ?',
                variables: [
                  Variable(id),
                ],
              )
              .get())
          .single
          .data;

  test('the snapshot reads live sources, sources that only have records, '
      'Patient rows and the patients records refer to', () async {
    await source('epic', holderId: 'jane');
    await source('gone', deletedAt: 1);
    await record('p1', 'epic', 'Patient', {
      'resourceType': 'Patient',
      'identifier': [
        {
          'system': 'http://hl7.org/fhir/sid/us-ssn',
          'value': '123456789',
          'type': {
            'coding': [
              {'code': 'SS'},
            ],
          },
        },
      ],
      'name': [
        {
          'use': 'usual',
          'given': ['Janie'],
        },
        {
          'use': 'official',
          'family': 'Doe',
          'given': ['Jane', 'Q'],
        },
      ],
      'birthDate': '1980-04-02',
    });
    await record('broken', 'epic', 'Patient', '{not json');
    await record('o1', 'labs', 'Observation', {
      'subject': {'reference': 'Patient/p1'},
    });
    await record('a1', 'labs', 'AllergyIntolerance', {
      'patient': {'reference': 'Patient/p2'},
    });
    await record('c1', 'labs', 'Coverage', {
      'beneficiary': {'reference': 'Group/x'},
    });

    final snapshot = await repository.snapshot();

    expect(
      snapshot.sources.map((s) => '${s.id}:${s.holderId}'),
      unorderedEquals(['epic:jane', 'labs:null']),
    );
    final p1 = snapshot.patients.single;
    expect(p1.rowId, 'p1');
    expect(p1.family, 'Doe');
    expect(p1.given, 'Jane Q');
    expect(p1.birthDate, '1980-04-02');
    expect(p1.identifiers.single.typeCodes, {'SS'});
    expect(snapshot.references, {
      'labs': {'Patient/p1', 'Patient/p2'},
    });
  });

  test('there is something to link while a source, or a source with only '
      'records, has no holder', () async {
    expect(await repository.hasUnassigned(), isFalse);
    await source('epic', holderId: 'jane');
    await source('gone', deletedAt: 1);
    expect(await repository.hasUnassigned(), isFalse);
    await record('o1', 'labs', 'Observation', {});
    expect(await repository.hasUnassigned(), isTrue);
    await repository.assignHolders({'labs': 'jane'});
    expect(await repository.hasUnassigned(), isFalse);
    await source('kaiser');
    expect(await repository.hasUnassigned(), isTrue);
  });

  test('assigning adds a row for a source with only records and keeps a '
      'holder already set', () async {
    await source('epic', holderId: 'jane');
    await repository.assignHolders({'epic': 'john', 'labs': 'jane'});

    expect((await sourceRow('epic'))['holder_id'], 'jane');
    final labs = await sourceRow('labs');
    expect(labs['holder_id'], 'jane');
    expect(labs['platform_type'], 'fasten');
    expect(labs['updated_at'], isNotNull);

    await repository.assignHolders({'wallet-p1': 'p1'});
    expect((await sourceRow('wallet-p1'))['platform_type'], 'wallet');
  });

  test('linking at start-up links the default holder and the first provider '
      'patient, and is a no-op the second time', () async {
    await db.customStatement(
      "INSERT INTO sources (id, platform_type) VALUES ('wallet-default_patient', 'wallet')",
    );
    await record('default_patient', 'wallet-default_patient', 'Patient', {
      'resourceType': 'Patient',
      'name': [
        {
          'use': 'official',
          'given': ['Health Wallet'],
          'family': 'Holder',
        },
      ],
    }, resourceId: 'f3a1');
    await record('p1', 'epic', 'Patient', {'resourceType': 'Patient'});

    final service = HolderLinkingService(repository);
    await service.linkUnassigned();

    expect(
      (await sourceRow('wallet-default_patient'))['holder_id'],
      'default_patient',
    );
    expect((await sourceRow('epic'))['holder_id'], 'default_patient');

    final stamp = (await sourceRow('epic'))['updated_at'];
    await service.linkUnassigned();
    expect((await sourceRow('epic'))['updated_at'], stamp);
  });
}
