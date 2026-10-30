// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  // The following template shows how to write tests ensuring your migrations
  // preserve existing data.
  // Testing this can be useful for migrations that change existing columns
  // (e.g. by alterating their type or constraints). Migrations that only add
  // tables or columns typically don't need these advanced tests. For more
  // information, see https://drift.simonbinder.eu/migrations/tests/#verifying-data-integrity
  // TODO: This generated template shows how these tests could be written. Adopt
  // it to your own needs when testing migrations with data integrity.
  test('migration from v1 to v2 does not corrupt data', () async {
    // Add data to insert into the old database, and the expected rows after the
    // migration.
    // TODO: Fill these lists
    final oldFhirResourceData = <v1.FhirResourceData>[];
    final expectedNewFhirResourceData = <v2.FhirResourceData>[];

    final oldSourcesData = <v1.SourcesData>[];
    final expectedNewSourcesData = <v2.SourcesData>[];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.fhirResource, oldFhirResourceData);
        batch.insertAll(oldDb.sources, oldSourcesData);
      },
      validateItems: (newDb) async {
        expect(
          expectedNewFhirResourceData,
          await newDb.select(newDb.fhirResource).get(),
        );
        expect(expectedNewSourcesData, await newDb.select(newDb.sources).get());
      },
    );
  });

  // Data migrations for v9 (production 1.2.x) → v11. These steps are
  // hand-written SQL in AppDatabase, so they are seeded with raw rows at the
  // old version and checked after migrating to the current schema.
  group('v8+ data migrations', () {
    // Production opens the database with foreign keys enabled.
    final fkVerifier = SchemaVerifier(
      GeneratedHelper(),
      setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
    );

    Future<AppDatabase> migrateFrom(
      int fromVersion,
      void Function(InitializedSchema schema) seed,
    ) async {
      final schema = await fkVerifier.schemaAt(fromVersion);
      seed(schema);
      final db = AppDatabase(schema.newConnection());
      await fkVerifier.migrateAndValidate(db, db.schemaVersion);
      return db;
    }

    Future<List<QueryRow>> rows(AppDatabase db, String sql) =>
        db.customSelect(sql).get();

    String fhirJson(String id, {List<Map<String, String>>? tags}) =>
        jsonEncode({
          'resourceType': 'Observation',
          'id': id,
          if (tags != null) 'meta': {'tag': tags},
        });

    const specialtyTag = {
      'system': 'http://healthwallet.me/specialty',
      'code': 'cardiology',
    };
    const otherTag = {'system': 'http://example.org/tags', 'code': 'keep-me'};

    test(
      '9 → 11 keeps existing rows and moves specialty tags to a column',
      () async {
        final db = await migrateFrom(9, (schema) {
          final raw = schema.rawDatabase;
          raw.execute(
            'INSERT INTO sources (id, platform_name, platform_type) '
            "VALUES ('src-1', 'Epic', 'ehr')",
          );
          final insert = raw.prepare(
            'INSERT INTO fhir_resource (id, source_id, resource_type, resource_raw) '
            "VALUES (?, 'src-1', 'Observation', ?)",
          );
          insert.execute([
            'mixed-tags',
            fhirJson('mixed-tags', tags: [specialtyTag, otherTag]),
          ]);
          insert.execute([
            'only-specialty',
            fhirJson('only-specialty', tags: [specialtyTag]),
          ]);
          insert.execute(['untagged', fhirJson('untagged')]);
          // Matches the LIKE filter but is not valid JSON: must be skipped.
          insert.execute([
            'malformed',
            '{"broken": "healthwallet.me/specialty"',
          ]);
          insert.close();
          raw.execute(
            'INSERT INTO record_notes (resource_id, source_id, content, timestamp) '
            "VALUES ('untagged', 'src-1', 'note', 1700000000)",
          );
          raw.execute(
            'INSERT INTO processing_sessions (id, status, created_at) '
            "VALUES ('session-1', 'done', 1700000000)",
          );
        });

        final resources = {
          for (final row in await rows(
            db,
            'SELECT id, resource_raw, specialty_override FROM fhir_resource',
          ))
            row.read<String>('id'): row,
        };
        expect(resources.keys, hasLength(4));

        final mixed = resources['mixed-tags']!;
        expect(mixed.read<String?>('specialty_override'), 'cardiology');
        expect(
          jsonDecode(mixed.read<String>('resource_raw'))['meta'],
          {
            'tag': [otherTag],
          },
        );

        final onlySpecialty = resources['only-specialty']!;
        expect(onlySpecialty.read<String?>('specialty_override'), 'cardiology');
        expect(
          (jsonDecode(onlySpecialty.read<String>('resource_raw')) as Map)
              .containsKey('meta'),
          isFalse,
        );

        expect(
          resources['untagged']!.read<String?>('specialty_override'),
          isNull,
        );
        expect(
          resources['untagged']!.read<String>('resource_raw'),
          fhirJson('untagged'),
        );
        expect(
          resources['malformed']!.read<String?>('specialty_override'),
          isNull,
        );
        expect(
          resources['malformed']!.read<String>('resource_raw'),
          '{"broken": "healthwallet.me/specialty"',
        );

        expect(await rows(db, 'SELECT id FROM sources'), hasLength(1));
        final notes = await rows(
          db,
          'SELECT content, updated_at, deleted_at FROM record_notes',
        );
        expect(notes.single.read<String>('content'), 'note');
        expect(notes.single.read<int?>('deleted_at'), isNull);
        expect(
          await rows(db, 'SELECT id FROM processing_sessions'),
          hasLength(1),
        );

        await db.close();
      },
    );

    test(
      '9 → 11 installs triggers that stamp updated_at on new rows',
      () async {
        final db = await migrateFrom(9, (_) {});

        await db.customStatement(
          'INSERT INTO fhir_resource (id, resource_raw) '
          "VALUES ('new', '{}')",
        );
        final row = (await rows(
          db,
          "SELECT updated_at FROM fhir_resource WHERE id = 'new'",
        )).single;
        expect(row.read<int?>('updated_at'), isNotNull);

        await db.close();
      },
    );

    test(
      '8 → 11 moves the shared wallet source to a per-patient source',
      () async {
        final db = await migrateFrom(8, (schema) {
          final raw = schema.rawDatabase;
          raw.execute(
            'INSERT INTO sources (id, platform_name, label_source, platform_type) '
            "VALUES ('wallet', 'Wallet', 'Wallet', 'wallet')",
          );
          raw.execute(
            'INSERT INTO fhir_resource (id, source_id, resource_type, resource_raw) '
            "VALUES ('pat-1', 'wallet', 'Patient', '{}'), "
            "('obs-1', 'wallet', 'Observation', '{}')",
          );
          raw.execute(
            'INSERT INTO record_notes (resource_id, source_id, content, timestamp) '
            "VALUES ('obs-1', 'wallet', 'note', 1700000000)",
          );
        });

        final sources = await rows(db, 'SELECT id, label_source FROM sources');
        expect(sources.map((r) => r.read<String>('id')), ['wallet-pat-1']);
        expect(sources.single.read<String?>('label_source'), 'Wallet');
        expect(
          (await rows(
            db,
            'SELECT DISTINCT source_id FROM fhir_resource',
          )).map((r) => r.read<String?>('source_id')),
          ['wallet-pat-1'],
        );
        expect(
          (await rows(
            db,
            'SELECT source_id FROM record_notes',
          )).single.read<String?>('source_id'),
          'wallet-pat-1',
        );

        await db.close();
      },
    );

    test('8 → 11 drops a wallet source that has no patient', () async {
      final db = await migrateFrom(8, (schema) {
        final raw = schema.rawDatabase;
        raw.execute(
          'INSERT INTO sources (id, platform_name, platform_type) '
          "VALUES ('wallet', 'Wallet', 'wallet'), ('src-1', 'Epic', 'ehr')",
        );
      });

      expect(
        (await rows(
          db,
          'SELECT id FROM sources',
        )).map((r) => r.read<String>('id')),
        ['src-1'],
      );

      await db.close();
    });

    test(
      '11 → 12 gives every note the key the other device derives too',
      () async {
        final db = await migrateFrom(11, (schema) {
          schema.rawDatabase.execute(
            'INSERT INTO record_notes '
            '(id, resource_id, content, timestamp, updated_at) '
            "VALUES (7, 'obs-1', 'note', 0, 1000), "
            "(9, 'obs-2', 'other', 0, 2000)",
          );
        });

        expect(
          (await rows(
            db,
            'SELECT id, uuid, updated_at FROM record_notes ORDER BY id',
          )).map(
            (r) => '${r.data['id']}:${r.data['uuid']}:${r.data['updated_at']}',
          ),
          ['7:legacy-7:1000', '9:legacy-9:2000'],
          reason: 'the key is filled in without counting as an edit',
        );

        // A note written without one, as an older backup or app version does.
        await db.customStatement(
          'INSERT INTO record_notes (id, resource_id, content, timestamp) '
          "VALUES (12, 'obs-3', 'old format', 0)",
        );
        expect(
          (await rows(
            db,
            'SELECT uuid FROM record_notes WHERE id = 12',
          )).single.data['uuid'],
          'legacy-12',
        );

        await expectLater(
          db.customStatement(
            'INSERT INTO record_notes (resource_id, content, timestamp, uuid) '
            "VALUES ('obs-4', 'clash', 0, 'legacy-7')",
          ),
          throwsA(isA<Exception>()),
          reason: 'one note per key',
        );

        await db.close();
      },
    );

    test(
      '12 → 13 logs every local write for the desktop sync and stamps '
      'milliseconds that never go back',
      () async {
        final db = await migrateFrom(12, (schema) {
          schema.rawDatabase.execute(
            'INSERT INTO sources (id, platform_name, platform_type, updated_at) '
            "VALUES ('src-1', 'Epic', 'ehr', 1000)",
          );
        });

        expect(
          await rows(db, 'SELECT * FROM sync_outbox'),
          isEmpty,
          reason: 'rows from before the upgrade are reconciled, not logged',
        );

        final before = DateTime.now().millisecondsSinceEpoch;
        await db.customStatement(
          'INSERT INTO fhir_resource (id, source_id, resource_type, resource_raw) '
          "VALUES ('obs-1', 'src-1', 'Observation', '{}')",
        );
        await db.customStatement(
          'INSERT INTO record_notes (resource_id, content, timestamp) '
          "VALUES ('obs-1', 'note', 0)",
        );
        await db.customStatement(
          "UPDATE sources SET label_source = 'Clinic' WHERE id = 'src-1'",
        );

        final logged = await rows(
          db,
          'SELECT DISTINCT synced_table, row_key FROM sync_outbox ORDER BY seq',
        );
        expect(
          logged.map((r) => '${r.data['synced_table']}/${r.data['row_key']}'),
          ['fhir_resource/obs-1', 'record_notes/legacy-1', 'sources/src-1'],
        );

        final inserted =
            (await rows(
                  db,
                  "SELECT updated_at FROM fhir_resource WHERE id = 'obs-1'",
                )).single.data['updated_at']
                as int;
        // julianday() can round down by a millisecond; a whole-second stamp
        // is up to 999 ms behind.
        expect(inserted, greaterThanOrEqualTo(before - 10));

        // Two edits in the same millisecond still order, and an edit after a
        // row arrived stamped in the future (a peer whose clock runs ahead)
        // stays newer than it.
        await db.customStatement(
          "UPDATE fhir_resource SET title = 'a' WHERE id = 'obs-1'",
        );
        final first =
            (await rows(
                  db,
                  "SELECT updated_at FROM fhir_resource WHERE id = 'obs-1'",
                )).single.data['updated_at']
                as int;
        await db.customStatement(
          "UPDATE fhir_resource SET title = 'b' WHERE id = 'obs-1'",
        );
        final second =
            (await rows(
                  db,
                  "SELECT updated_at FROM fhir_resource WHERE id = 'obs-1'",
                )).single.data['updated_at']
                as int;
        expect(second, greaterThan(first));

        const future = 99999999999999;
        await db.customStatement(
          'UPDATE fhir_resource SET updated_at = $future '
          "WHERE id = 'obs-1'",
        );
        await db.customStatement(
          "UPDATE fhir_resource SET title = 'c' WHERE id = 'obs-1'",
        );
        expect(
          (await rows(
            db,
            "SELECT updated_at FROM fhir_resource WHERE id = 'obs-1'",
          )).single.data['updated_at'],
          future + 1,
        );

        await db.close();
      },
    );

    test(
      '10 → 11 tolerates specialty_override left by an interrupted run',
      () async {
        // A previous attempt added the column but crashed before the schema
        // version was bumped, so the v11 step runs again on top of it.
        final db = await migrateFrom(10, (schema) {
          schema.rawDatabase.execute(
            'ALTER TABLE fhir_resource ADD COLUMN specialty_override TEXT NULL',
          );
        });

        expect(await rows(db, 'SELECT id FROM fhir_resource'), isEmpty);

        await db.close();
      },
    );
  });
}
