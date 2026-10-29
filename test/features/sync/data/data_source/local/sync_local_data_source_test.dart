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
      expect(row.updatedAt, DateTime(2024, 2));
    });
  });

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
        expect(
          sources['fasten-1'],
          Source(
            id: 'fasten-1',
            platformName: 'fasten-1',
            labelSource: 'Clinic',
            platformType: 'fasten',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024, 2),
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
    test('removes the source and only its resources', () async {
      await dataSource.cacheSources(const [Source(id: 'a'), Source(id: 'b')]);
      await dataSource.cacheFhirResources([
        resource('a1', sourceId: 'a'),
        resource('a2', sourceId: 'a'),
        resource('b1', sourceId: 'b'),
      ]);
      await dataSource.deleteSource('a');
      expect((await sourceRows()).map((s) => s.id), ['b']);
      expect((await resourceRows()).map((r) => r.id), ['b1']);
    });

    test('can delete the demo data source', () async {
      await dataSource.createDemoDataSource();
      await dataSource.cacheFhirResources([
        resource('d1', sourceId: 'demo_data'),
      ]);
      await dataSource.deleteSource('demo_data');
      expect(await sourceRows(), isEmpty);
      expect(await resourceRows(), isEmpty);
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

      expect((await sourceRows()).map((s) => s.id), ['b']);
      expect((await resourceRows()).map((r) => r.id), ['b1']);
      final notes = await database.select(database.recordNotes).get();
      expect(notes.map((n) => n.resourceId), ['b1']);
    });

    test('is a no-op for an unknown source', () async {
      await dataSource.cacheSources(const [Source(id: 'a')]);
      await dataSource.deleteSource('missing');
      expect((await sourceRows()).map((s) => s.id), ['a']);
    });
  });
}
