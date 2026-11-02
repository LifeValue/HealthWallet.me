import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart' as db;
import 'package:health_wallet/features/sync/data/data_source/local/sync_local_data_source.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late db.AppDatabase database;
  late SharedPreferences prefs;
  late SyncLocalDataSourceImpl dataSource;

  setUp(() async {
    database = db.AppDatabase(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    dataSource = SyncLocalDataSourceImpl(database, prefs);
  });

  tearDown(() => database.close());

  Future<List<db.FhirResourceLocalDto>> resourceRows() => (database.select(
    database.fhirResource,
  )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  Future<List<db.Source>> sourceRows() => (database.select(
    database.sources,
  )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  FhirResourceDto resource(String id, {String? sourceId}) => FhirResourceDto(
    resourceId: id,
    sourceId: sourceId,
    resourceType: 'Observation',
    resourceRaw: {'resourceType': 'Observation', 'id': id},
  );

  group('cacheFhirResources with ids shared across sources or types', () {
    FhirResourceDto typed(String id, String type, String sourceId) =>
        FhirResourceDto(
          resourceId: id,
          sourceId: sourceId,
          resourceType: type,
          resourceRaw: {'resourceType': type, 'id': id},
        );

    Future<List<String>> rows() async => [
      for (final r in await resourceRows())
        '${r.id} ${r.sourceId} ${r.resourceType}',
    ];

    test('two sources with the same patient id keep both patients', () async {
      await dataSource.cacheFhirResources([typed('12345', 'Patient', 'epic')]);
      await dataSource.cacheFhirResources([
        typed('12345', 'Patient', 'cerner'),
      ]);

      expect(await rows(), [
        '12345 epic Patient',
        'cerner/Patient/12345 cerner Patient',
      ]);
    });

    test('one source with an encounter and an observation sharing an id '
        'keeps both', () async {
      await dataSource.cacheFhirResources([
        typed('100', 'Encounter', 'hapi'),
        typed('100', 'Observation', 'hapi'),
      ]);

      expect(await rows(), [
        '100 hapi Encounter',
        'hapi/Observation/100 hapi Observation',
      ]);
    });

    test('a later sync updates the same rows instead of adding more', () async {
      final batch = [
        typed('100', 'Encounter', 'hapi'),
        typed('100', 'Observation', 'hapi'),
      ];
      await dataSource.cacheFhirResources(batch);
      await dataSource.cacheFhirResources(batch.reversed.toList());

      expect(await rows(), [
        '100 hapi Encounter',
        'hapi/Observation/100 hapi Observation',
      ]);
    });

    test('resources without an id are skipped, not merged into one', () async {
      await dataSource.cacheFhirResources([
        typed('ok', 'Observation', 'a'),
        const FhirResourceDto(sourceId: 'a', resourceType: 'Observation'),
        const FhirResourceDto(sourceId: 'a', resourceType: 'Condition'),
      ]);

      expect(await rows(), ['ok a Observation']);
    });
  });

  group('cacheFhirResources', () {
    test('stores each DTO keyed by its resource id', () async {
      await dataSource.cacheFhirResources([
        FhirResourceDto(
          id: 'backend-row',
          sourceId: 'src-1',
          resourceType: 'Encounter',
          resourceId: 'enc-1',
          title: 'Visit',
          date: DateTime(2024, 5, 6),
          resourceRaw: const {'resourceType': 'Encounter', 'id': 'enc-1'},
          encounterId: 'enc-1',
          subjectId: 'pat-1',
        ),
      ]);
      final row = (await resourceRows()).single;
      expect(row.id, 'enc-1');
      expect(row.resourceId, 'enc-1');
      expect(row.sourceId, 'src-1');
      expect(row.resourceType, 'Encounter');
      expect(row.title, 'Visit');
      expect(row.date, DateTime(2024, 5, 6));
      expect(jsonDecode(row.resourceRaw), {
        'resourceType': 'Encounter',
        'id': 'enc-1',
      });
      expect(row.encounterId, 'enc-1');
      expect(row.subjectId, 'pat-1');
    });

    test('leaves encounter and subject null when the DTO has none', () async {
      await dataSource.cacheFhirResources([resource('obs-1')]);
      final row = (await resourceRows()).single;
      expect(row.encounterId, isNull);
      expect(row.subjectId, isNull);
      expect(row.sourceId, isNull);
    });

    test('the sync trigger stamps updated_at on insert', () async {
      await dataSource.cacheFhirResources([resource('obs-1')]);
      expect((await resourceRows()).single.updatedAt, isNotNull);
    });

    test('replaces the row of the same resource', () async {
      await dataSource.cacheFhirResources([resource('obs-1', sourceId: 'a')]);
      await dataSource.cacheFhirResources([
        resource('obs-1', sourceId: 'a').copyWith(title: 'new'),
      ]);
      final row = (await resourceRows()).single;
      expect(row.sourceId, 'a');
      expect(row.title, 'new');
    });

    test('stores a null resourceRaw as the JSON literal null', () async {
      await dataSource.cacheFhirResources([
        const FhirResourceDto(resourceId: 'x'),
      ]);
      expect((await resourceRows()).single.resourceRaw, 'null');
    });

    test('accepts an empty list', () async {
      await dataSource.cacheFhirResources(const []);
      expect(await resourceRows(), isEmpty);
    });
  });

  test('deleteAllFhirResources empties the table', () async {
    await dataSource.cacheFhirResources([resource('a'), resource('b')]);
    await dataSource.deleteAllFhirResources();
    expect(await resourceRows(), isEmpty);
  });

  test('markResourcesAsDeleted does not touch stored rows', () async {
    await dataSource.cacheFhirResources([resource('a'), resource('b')]);
    await dataSource.markResourcesAsDeleted([
      resource('a').copyWith(changeType: 'deleted'),
      const FhirResourceDto(changeType: 'deleted'),
    ]);
    expect((await resourceRows()).map((r) => r.id), ['a', 'b']);
  });

  group('last sync timestamp', () {
    test('is null until set', () async {
      expect(await dataSource.getLastSyncTimestamp(), isNull);
    });

    test('is persisted in SharedPreferences', () async {
      await dataSource.setLastSyncTimestamp('2024-05-06T07:08:09.000');
      expect(
        await dataSource.getLastSyncTimestamp(),
        '2024-05-06T07:08:09.000',
      );
      expect(prefs.getString('lastSyncTimestamp'), '2024-05-06T07:08:09.000');
    });
  });

  group('cacheSources', () {
    test('upserts every field', () async {
      final source = Source(
        id: 'src-1',
        platformName: 'Fasten',
        logo: 'logo',
        labelSource: 'Clinic',
        platformType: 'fasten',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024, 2),
      );
      await dataSource.cacheSources([source]);
      await dataSource.cacheSources([source.copyWith(labelSource: 'Renamed')]);
      final row = (await sourceRows()).single;
      expect(row.id, 'src-1');
      expect(row.platformName, 'Fasten');
      expect(row.logo, 'logo');
      expect(row.labelSource, 'Renamed');
      expect(row.platformType, 'fasten');
      expect(row.createdAt, DateTime(2024));
      // Stamped by the trigger for the desktop sync, not the provider's date.
      expect(row.updatedAt, isNotNull);
    });

    test('keeps the holder of a source fetched again', () async {
      const source = Source(id: 'src-1', platformType: 'fasten');
      await dataSource.cacheSources([source.copyWith(holderId: 'jane')]);
      await dataSource.cacheSources([source]);
      expect((await sourceRows()).single.holderId, 'jane');

      await dataSource.cacheSources([source.copyWith(holderId: 'john')]);
      expect((await sourceRows()).single.holderId, 'john');
    });

    test('brings back a deleted source', () async {
      const source = Source(id: 'wallet-p1');
      await dataSource.cacheSources([source]);
      await dataSource.deleteSource('wallet-p1');
      await dataSource.cacheSources([source]);
      expect((await sourceRows()).single.deletedAt, isNull);
    });
  });

  group('cacheProviderSources', () {
    const fetched = Source(
      id: 'src-1',
      platformName: 'Epic',
      labelSource: 'City Hospital',
      platformType: 'fasten',
    );

    test("adds a new source with the provider's name", () async {
      await dataSource.cacheProviderSources([fetched]);
      expect((await sourceRows()).single.labelSource, 'City Hospital');
    });

    test("keeps the user's name for it, its holder and its delete", () async {
      await dataSource.cacheProviderSources([fetched]);
      await dataSource.updateSourceLabel('src-1', 'My GP');
      await database.customStatement(
        "UPDATE sources SET holder_id = 'jane' WHERE id = 'src-1'",
      );
      await dataSource.deleteSource('src-1');
      final before = (await sourceRows()).single;

      await dataSource.cacheProviderSources([
        fetched.copyWith(logo: 'https://logo'),
      ]);

      final row = (await sourceRows()).single;
      expect(row.labelSource, 'My GP');
      expect(row.holderId, 'jane');
      expect(row.deletedAt, before.deletedAt);
      expect(row.logo, 'https://logo');
    });

    test('writes nothing for a source that did not change', () async {
      await dataSource.cacheProviderSources([fetched]);
      final stamp = (await sourceRows()).single.updatedAt;
      await database.customStatement('DELETE FROM sync_outbox');

      await dataSource.cacheProviderSources([fetched]);

      expect((await sourceRows()).single.updatedAt, stamp);
      expect(
        await database.customSelect('SELECT * FROM sync_outbox').get(),
        isEmpty,
      );
    });
  });

  test('records of a source the user deleted are not stored again', () async {
    await dataSource.cacheSources(const [Source(id: 'src-1')]);
    await dataSource.cacheFhirResources([resource('o1', sourceId: 'src-1')]);
    await dataSource.deleteSource('src-1');

    await dataSource.cacheFhirResources([
      resource('o1', sourceId: 'src-1'),
      resource('o2', sourceId: 'src-1'),
      resource('o3', sourceId: 'src-2'),
    ]);

    final live = [
      for (final r in await resourceRows())
        if (r.deletedAt == null) r.id,
    ];
    expect(live, ['o3']);
  });

  test(
    'records of the wallet source of versions before 9 are the wallet',
    () async {
      await dataSource.cacheFhirResources([resource('o1', sourceId: 'wallet')]);
      final source = (await dataSource.getSources()).single;
      expect(source.platformType, 'wallet');
    },
  );

  test('deleteAllSources empties the sources table', () async {
    await dataSource.cacheSources(const [Source(id: 'a'), Source(id: 'b')]);
    await dataSource.deleteAllSources();
    expect(await sourceRows(), isEmpty);
  });

  group('getSources', () {
    test('is empty for an empty database', () async {
      expect(await dataSource.getSources(), isEmpty);
    });

    test(
      'combines stored sources with sources referenced by resources',
      () async {
        await dataSource.cacheSources([
          Source(
            id: 'fasten-1',
            labelSource: 'Clinic',
            platformType: 'fasten',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024, 2),
          ),
        ]);
        await dataSource.cacheFhirResources([
          resource('r1', sourceId: 'fasten-1'),
          resource('r2', sourceId: 'wallet-abc'),
          resource('r3', sourceId: 'demo_data'),
          resource('r4', sourceId: 'remote-9'),
          resource('r5', sourceId: ''),
          resource('r6'),
        ]);

        final sources = {
          for (final s in await dataSource.getSources()) s.id: s,
        };

        expect(
          sources.keys,
          unorderedEquals(['fasten-1', 'wallet-abc', 'demo_data', 'remote-9']),
        );
        final stamp = sources['fasten-1']!.updatedAt!;
        expect(
          stamp.difference(DateTime.now()).inMinutes.abs(),
          lessThan(5),
          reason: 'the sync stamp, read back in milliseconds',
        );
        expect(
          sources['fasten-1'],
          Source(
            id: 'fasten-1',
            platformName: 'fasten-1',
            labelSource: 'Clinic',
            platformType: 'fasten',
            createdAt: DateTime(2024),
            updatedAt: stamp,
          ),
        );
        expect(
          sources['wallet-abc'],
          const Source(
            id: 'wallet-abc',
            platformName: 'wallet',
            platformType: 'wallet',
          ),
        );
        expect(
          sources['demo_data'],
          const Source(
            id: 'demo_data',
            platformName: 'wallet-manual',
            labelSource: 'Demo',
            platformType: 'wallet',
          ),
        );
        expect(
          sources['remote-9'],
          const Source(
            id: 'remote-9',
            platformName: 'remote-9',
            platformType: 'fasten',
          ),
        );
      },
    );

    test('prefers the stored platformType and label', () async {
      await dataSource.cacheSources(const [
        Source(id: 'wallet-1', platformType: 'fasten', labelSource: 'Mine'),
        Source(id: 'demo_data', platformType: 'custom', labelSource: 'Demo X'),
      ]);
      final sources = {for (final s in await dataSource.getSources()) s.id: s};
      expect(sources['wallet-1']!.platformType, 'fasten');
      expect(sources['wallet-1']!.platformName, 'wallet');
      expect(sources['wallet-1']!.labelSource, 'Mine');
      expect(sources['demo_data']!.platformType, 'custom');
      expect(sources['demo_data']!.labelSource, 'Demo X');
    });

    test('a stored source without a label falls back to null', () async {
      await dataSource.cacheSources(const [Source(id: 'plain')]);
      final source = (await dataSource.getSources()).single;
      expect(source.labelSource, isNull);
      expect(source.logo, isNull);
      expect(source.platformType, 'wallet');
    });

    test(
      'patientId narrows resource-derived ids, not stored sources',
      () async {
        await dataSource.cacheSources(const [Source(id: 'stored')]);
        await dataSource.cacheFhirResources([
          resource('r1', sourceId: 'match'),
          resource('r2', sourceId: 'other'),
        ]);
        final ids = (await dataSource.getSources(patientId: 'match'))
            .map((s) => s.id);
        expect(ids, unorderedEquals(['match', 'stored']));
      },
    );
  });

  group('updateSourceLabel', () {
    test('creates the source when it does not exist', () async {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      await dataSource.updateSourceLabel('new-src', 'Label');
      final row = (await sourceRows()).single;
      expect(row.id, 'new-src');
      expect(row.labelSource, 'Label');
      expect(row.platformType, 'wallet');
      expect(row.updatedAt!.isAfter(before), isTrue);
    });

    test('only changes the label of an existing source', () async {
      await dataSource.cacheSources([
        Source(
          id: 'src',
          platformName: 'Fasten',
          labelSource: 'Old',
          platformType: 'fasten',
          createdAt: DateTime(2020),
        ),
      ]);
      await dataSource.updateSourceLabel('src', 'New');
      final row = (await sourceRows()).single;
      expect(row.labelSource, 'New');
      expect(row.platformName, 'Fasten');
      expect(row.platformType, 'fasten');
      expect(row.createdAt, DateTime(2020));
    });

    test('an empty label clears it', () async {
      await dataSource.cacheSources(const [
        Source(id: 'src', labelSource: 'X'),
      ]);
      await dataSource.updateSourceLabel('src', '');
      expect((await sourceRows()).single.labelSource, isNull);
    });

    test('rethrows database errors', () async {
      await database.customStatement('DROP TABLE sources');
      await expectLater(
        dataSource.updateSourceLabel('src', 'x'),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('createWalletSource', () {
    test('creates the wallet source', () async {
      await dataSource.createWalletSource();
      final row = (await sourceRows()).single;
      expect(row.id, 'wallet');
      expect(row.platformName, 'wallet');
      expect(row.labelSource, 'Wallet');
      expect(row.platformType, 'wallet');
      expect(row.createdAt, isNotNull);
      expect(row.updatedAt, isNotNull);
    });

    test('keeps an existing wallet source untouched', () async {
      await dataSource.cacheSources(const [
        Source(id: 'wallet', labelSource: 'Renamed by user'),
      ]);
      await dataSource.createWalletSource();
      expect((await sourceRows()).single.labelSource, 'Renamed by user');
    });

    test('rethrows database errors', () async {
      await database.customStatement('DROP TABLE sources');
      await expectLater(
        dataSource.createWalletSource(),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('createDemoDataSource', () {
    test('creates or resets the demo source', () async {
      await dataSource.cacheSources(const [
        Source(id: 'demo_data', labelSource: 'Renamed'),
      ]);
      await dataSource.createDemoDataSource();
      final row = (await sourceRows()).single;
      expect(row.id, 'demo_data');
      expect(row.platformName, 'wallet-manual');
      expect(row.labelSource, 'Demo Data');
      expect(row.platformType, 'wallet');
      expect(row.createdAt, isNotNull);
    });

    test('rethrows database errors', () async {
      await database.customStatement('DROP TABLE sources');
      await expectLater(
        dataSource.createDemoDataSource(),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('deleteSource', () {
    Future<Map<String, Object?>> raw(String table, Object id) async =>
        (await database
                .customSelect(
                  'SELECT * FROM $table WHERE id = ?',
                  variables: [
                    if (id is int)
                      Variable.withInt(id)
                    else
                      Variable.withString('$id'),
                  ],
                )
                .getSingle())
            .data;

    test('tombstones the source, only its resources and their notes, in '
        'ms', () async {
      await dataSource.cacheSources(const [Source(id: 'a'), Source(id: 'b')]);
      await dataSource.cacheFhirResources([
        resource('a1', sourceId: 'a'),
        resource('a2', sourceId: 'a'),
        resource('b1', sourceId: 'b'),
      ]);
      await database.customStatement(
        'INSERT INTO record_notes (id, resource_id, content, timestamp) '
        "VALUES (1, 'a1', 'n', 0), (2, 'b1', 'n', 0)",
      );
      final before = DateTime.now().millisecondsSinceEpoch;

      await dataSource.deleteSource('a');

      for (final row in [
        await raw('sources', 'a'),
        await raw('fhir_resource', 'a1'),
        await raw('fhir_resource', 'a2'),
        await raw('record_notes', 1),
      ]) {
        expect(row['deleted_at'] as int, greaterThanOrEqualTo(before));
        expect(row['updated_at'], row['deleted_at']);
      }
      expect((await raw('sources', 'b'))['deleted_at'], isNull);
      expect((await raw('fhir_resource', 'b1'))['deleted_at'], isNull);
      expect((await raw('record_notes', 2))['deleted_at'], isNull);
      expect((await dataSource.getSources()).map((s) => s.id), ['b']);
    });

    test('can delete the demo data source', () async {
      await dataSource.createDemoDataSource();
      await dataSource.cacheFhirResources([
        resource('d1', sourceId: 'demo_data'),
      ]);
      await dataSource.deleteSource('demo_data');
      expect(await dataSource.getSources(), isEmpty);
      expect((await raw('fhir_resource', 'd1'))['deleted_at'], isNotNull);
    });

    test('removes the notes on its records too', () async {
      await dataSource.cacheSources(const [Source(id: 'a'), Source(id: 'b')]);
      await dataSource.cacheFhirResources([
        resource('a1', sourceId: 'a'),
        resource('b1', sourceId: 'b'),
      ]);
      for (final (resourceId, sourceId) in [('a1', 'a'), ('b1', 'b')]) {
        await database
            .into(database.recordNotes)
            .insert(
              db.RecordNotesCompanion.insert(
                resourceId: resourceId,
                sourceId: Value(sourceId),
                content: 'note on $resourceId',
                timestamp: DateTime(2024),
              ),
            );
      }

      await dataSource.deleteSource('a');

      // Tombstoned for the paired device, and hidden here.
      expect((await dataSource.getSources()).map((s) => s.id), ['b']);
      final notes = await database.select(database.recordNotes).get();
      expect(
        {
          for (final n in notes) n.resourceId: n.deletedAt != null,
        },
        {'a1': true, 'b1': false},
      );
    });

    test('is a no-op for an unknown source', () async {
      await dataSource.cacheSources(const [Source(id: 'a')]);
      await dataSource.deleteSource('missing');
      expect((await sourceRows()).map((s) => s.id), ['a']);
      expect((await raw('sources', 'a'))['deleted_at'], isNull);
    });
  });

  group('tombstones', () {
    Future<void> tombstone(String table, String id) => database.customStatement(
      'UPDATE $table SET deleted_at = 1, updated_at = 1 WHERE id = ?',
      [id],
    );

    Future<Object?> deletedAt(String table, String id) async =>
        (await database
                .customSelect(
                  'SELECT deleted_at FROM $table WHERE id = ?',
                  variables: [Variable.withString(id)],
                )
                .getSingle())
            .data['deleted_at'];

    test('getSources hides deleted sources and sources whose resources are '
        'all deleted', () async {
      await dataSource.cacheSources(const [
        Source(id: 'gone'),
        Source(id: 'kept'),
      ]);
      await dataSource.cacheFhirResources([
        resource('r1', sourceId: 'gone-res'),
        resource('r2', sourceId: 'live-res'),
      ]);
      await tombstone('sources', 'gone');
      await tombstone('fhir_resource', 'r1');

      expect(
        (await dataSource.getSources()).map((s) => s.id),
        unorderedEquals(['kept', 'live-res']),
      );
    });

    test(
      'cacheFhirResources and cacheSources bring deleted rows back',
      () async {
        await dataSource.cacheSources(const [Source(id: 's')]);
        await dataSource.cacheFhirResources([resource('r', sourceId: 's')]);
        await tombstone('sources', 's');
        await tombstone('fhir_resource', 'r');

        await dataSource.cacheSources(const [Source(id: 's')]);
        await dataSource.cacheFhirResources([resource('r', sourceId: 's')]);

        expect(await deletedAt('sources', 's'), isNull);
        expect(await deletedAt('fhir_resource', 'r'), isNull);
      },
    );

    test('createDemoDataSource brings a deleted demo source back with an ms '
        'stamp', () async {
      await dataSource.createDemoDataSource();
      await tombstone('sources', 'demo_data');

      await dataSource.createDemoDataSource();

      expect(await deletedAt('sources', 'demo_data'), isNull);
      final updatedAt =
          (await database
                      .customSelect(
                        "SELECT updated_at FROM sources WHERE id = 'demo_data'",
                      )
                      .getSingle())
                  .data['updated_at']
              as int;
      expect(updatedAt, greaterThan(1e12));
      expect((await dataSource.getSources()).single.labelSource, 'Demo Data');
    });

    test('createWalletSource brings a deleted wallet source back with an ms '
        'stamp', () async {
      await dataSource.createWalletSource();
      await tombstone('sources', 'wallet');

      await dataSource.createWalletSource();

      expect(await deletedAt('sources', 'wallet'), isNull);
      final updatedAt =
          (await database
                      .customSelect(
                        "SELECT updated_at FROM sources WHERE id = 'wallet'",
                      )
                      .getSingle())
                  .data['updated_at']
              as int;
      expect(updatedAt, greaterThan(1e12));
      expect((await dataSource.getSources()).single.labelSource, 'Wallet');
    });
  });
}
