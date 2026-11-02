import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:health_wallet/core/data/local/app_database.steps.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/tables/sync_outbox.dart';
import 'package:health_wallet/features/processing/data/data_source/local/tables/processing_sessions.dart';
import 'package:health_wallet/features/records/data/data_source/tables/record_notes.dart';
import 'package:health_wallet/features/sync/data/data_source/local/tables/fhir_resource_table.dart';
import 'package:health_wallet/features/sync/data/data_source/local/tables/source_table.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    FhirResource,
    Sources,
    RecordNotes,
    ProcessingSessions,
    SyncOutbox,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createOptimizationIndexes();
      await _createSyncTriggers();
    },
    onUpgrade: (m, from, to) async {
      final schemaSteps = stepByStep(
        from1To2: (m, schema) async {
          await _createOptimizationIndexes();
          await m.createTable(schema.recordAttachments);
        },
        from2To3: (m, schema) async {
          await m.createTable(schema.recordNotes);
        },
        from3To5: (m, schema) async {
          await m.deleteTable('record_attachments');
          await customStatement(
            'ALTER TABLE sources RENAME COLUMN name TO platform_name',
          );
          await m.addColumn(schema.sources, schema.sources.labelSource);
          await m.addColumn(schema.sources, schema.sources.platformType);
          await m.addColumn(schema.sources, schema.sources.createdAt);
          await m.addColumn(schema.sources, schema.sources.updatedAt);
          await m.alterTable(
            TableMigration(
              schema.recordNotes,
              newColumns: [schema.recordNotes.sourceId],
            ),
          );
          await m.createTable(schema.processingSessions);
        },
        from5To6: (m, schema) async {},
        from6To7: (m, schema) async {
          await m.addColumn(
            schema.processingSessions,
            schema.processingSessions.patient,
          );
          await m.addColumn(
            schema.processingSessions,
            schema.processingSessions.encounter,
          );
        },
        from7To8: (m, schema) async {
          await m.addColumn(
            schema.processingSessions,
            schema.processingSessions.isDocumentAttached,
          );
        },
      );

      if (from < 8) {
        await schemaSteps(m, from, to < 8 ? to : 8);
      }

      if (from <= 8 && to >= 9) {
        await _migrateWalletSourceToPerPatient();
      }

      if (from <= 9 && to >= 10) {
        await _migrateToV10();
        await _createSyncTriggersV10();
      }

      if (from <= 10 && to >= 11) {
        await _migrateToV11();
      }

      if (from <= 11 && to >= 12) {
        await _migrateToV12();
      }

      if (from <= 12 && to >= 13) {
        await _migrateToV13();
      }

      if (from <= 13 && to >= 14) {
        await _migrateToV14();
      }
    },
  );

  Future<void> _migrateWalletSourceToPerPatient() async {
    final walletPatient = await customSelect(
      "SELECT id FROM fhir_resource WHERE source_id = 'wallet' AND resource_type = 'Patient' LIMIT 1",
    ).getSingleOrNull();

    if (walletPatient == null) {
      await customStatement("DELETE FROM sources WHERE id = 'wallet'");
      return;
    }

    final patientId = walletPatient.read<String>('id');
    final newSourceId = 'wallet-$patientId';

    await customStatement(
      'INSERT OR IGNORE INTO sources (id, platform_name, label_source, platform_type, created_at, updated_at) '
      "SELECT '$newSourceId', platform_name, "
      "CASE WHEN label_source = 'Wallet' THEN 'Wallet' ELSE label_source END, "
      "platform_type, created_at, updated_at FROM sources WHERE id = 'wallet'",
    );

    await customStatement(
      "UPDATE fhir_resource SET source_id = '$newSourceId' WHERE source_id = 'wallet'",
    );

    await customStatement(
      "UPDATE record_notes SET source_id = '$newSourceId' WHERE source_id = 'wallet'",
    );

    await customStatement("DELETE FROM sources WHERE id = 'wallet'");
  }

  Future<void> _migrateToV10() async {
    await customStatement(
      'ALTER TABLE fhir_resource ADD COLUMN updated_at INTEGER NULL',
    );
    await customStatement(
      'ALTER TABLE fhir_resource ADD COLUMN deleted_at INTEGER NULL',
    );
    await customStatement(
      'ALTER TABLE fhir_resource ADD COLUMN device_id TEXT NULL',
    );

    await customStatement(
      'ALTER TABLE sources ADD COLUMN deleted_at INTEGER NULL',
    );

    await customStatement(
      'ALTER TABLE processing_sessions ADD COLUMN updated_at INTEGER NULL',
    );
    await customStatement(
      'ALTER TABLE processing_sessions ADD COLUMN deleted_at INTEGER NULL',
    );
    await customStatement(
      'ALTER TABLE processing_sessions ADD COLUMN device_id TEXT NULL',
    );

    await customStatement(
      'ALTER TABLE record_notes ADD COLUMN updated_at INTEGER NULL',
    );
    await customStatement(
      'ALTER TABLE record_notes ADD COLUMN deleted_at INTEGER NULL',
    );
  }

  Future<void> _migrateToV11() async {
    try {
      await customStatement(
        'ALTER TABLE fhir_resource ADD COLUMN specialty_override TEXT NULL',
      );
    } catch (_) {
      // The column already exists when this step ran before (an interrupted
      // upgrade), so a failed ALTER leaves the schema as v11 expects it.
    }

    final rows = await customSelect(
      'SELECT id, resource_raw FROM fhir_resource '
      "WHERE resource_raw LIKE '%healthwallet.me/specialty%'",
    ).get();

    for (final row in rows) {
      final id = row.read<String>('id');
      final rawJson = row.read<String>('resource_raw');

      try {
        final resource = jsonDecode(rawJson) as Map<String, dynamic>;
        final meta = resource['meta'] as Map<String, dynamic>?;
        if (meta == null) continue;

        final tags = meta['tag'] as List<dynamic>?;
        if (tags == null) continue;

        String? specialtyCode;
        final updatedTags = <dynamic>[];

        for (final tag in tags) {
          if (tag is Map<String, dynamic> &&
              tag['system'] == 'http://healthwallet.me/specialty') {
            specialtyCode = tag['code'] as String?;
          } else {
            updatedTags.add(tag);
          }
        }

        if (specialtyCode == null) continue;

        if (updatedTags.isEmpty) {
          meta.remove('tag');
        } else {
          meta['tag'] = updatedTags;
        }

        if (meta.isEmpty) {
          resource.remove('meta');
        }

        final updatedRaw = jsonEncode(resource);

        await customStatement(
          'UPDATE fhir_resource SET specialty_override = ?, resource_raw = ? WHERE id = ?',
          [specialtyCode, updatedRaw, id],
        );
      } catch (_) {
        continue;
      }
    }
  }

  /// Notes get a key that is the same on every device. Existing notes get
  /// `legacy-<id>`, which is what the phone and the desktop each derive for a
  /// note they already share.
  Future<void> _migrateToV12() async {
    await customStatement('ALTER TABLE record_notes ADD COLUMN uuid TEXT NULL');
    // Before the backfill, so filling the key doesn't count as an edit.
    await _createNoteUuidTriggers();
    await customStatement(
      "UPDATE record_notes SET uuid = 'legacy-' || id WHERE uuid IS NULL",
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS record_notes_uuid '
      'ON record_notes (uuid)',
    );
  }

  /// A note written without a uuid (restored from an older backup, or
  /// received from an older app version) gets the legacy one. Filling it in
  /// is not an edit, so it keeps the note's `updated_at`; otherwise the note
  /// would look newer than the copy on the other device.
  Future<void> _createNoteUuidTriggers() async {
    await customStatement(
      'DROP TRIGGER IF EXISTS record_notes_update_updated_at',
    );
    await customStatement(
      'CREATE TRIGGER record_notes_update_updated_at '
      'AFTER UPDATE ON record_notes '
      'WHEN (NEW.updated_at = OLD.updated_at OR NEW.updated_at IS NULL) '
      'AND NOT (OLD.uuid IS NULL AND NEW.uuid IS NOT NULL) '
      'BEGIN UPDATE record_notes SET updated_at = '
      "CAST(strftime('%s', 'now') * 1000 AS INTEGER) "
      'WHERE rowid = NEW.rowid; END',
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS record_notes_insert_uuid '
      'AFTER INSERT ON record_notes '
      'WHEN NEW.uuid IS NULL '
      "BEGIN UPDATE record_notes SET uuid = 'legacy-' || NEW.id "
      'WHERE id = NEW.id; END',
    );
  }

  /// The desktop sync's outbox, and triggers that stamp milliseconds and
  /// log every write. Rows from before stay out of the outbox: the first
  /// connection after the upgrade reconciles both devices' tables.
  Future<void> _migrateToV13() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS sync_outbox ('
      'seq INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      'synced_table TEXT NOT NULL, '
      'row_key TEXT NOT NULL)',
    );
    await _createSyncTriggers();
  }

  /// Which holder each source belongs to. Filled in at start-up by
  /// `HolderLinker`, which needs the records, not by the migration.
  Future<void> _migrateToV14() async {
    await customStatement('ALTER TABLE sources ADD COLUMN holder_id TEXT NULL');
  }

  Future<void> _createOptimizationIndexes() async {
    await customStatement('PRAGMA journal_mode=WAL');
    await customStatement('PRAGMA synchronous=NORMAL');
    await customStatement('PRAGMA cache_size=10000');
    await customStatement('PRAGMA temp_store=MEMORY');
  }

  /// Unix time in milliseconds inside SQLite.
  static const _nowMs =
      "CAST((julianday('now') - 2440587.5) * 86400000.0 AS INTEGER)";

  static const _syncKeys = {
    'fhir_resource': 'NEW.id',
    'sources': 'NEW.id',
    // A note written without a uuid gets the legacy one (below).
    'record_notes': "COALESCE(NEW.uuid, 'legacy-' || NEW.id)",
  };

  /// `updated_at` stamps for every table that has one, and the outbox log
  /// for the synced tables. An edit is stamped later than the row's previous
  /// stamp even when the clock is behind it (a row received from a device
  /// whose clock runs ahead), so it still wins on the other device.
  Future<void> _createSyncTriggers() async {
    for (final table in const [
      'fhir_resource',
      'sources',
      'record_notes',
      'processing_sessions',
    ]) {
      await customStatement(
        'DROP TRIGGER IF EXISTS ${table}_insert_updated_at',
      );
      await customStatement(
        'DROP TRIGGER IF EXISTS ${table}_update_updated_at',
      );
      await customStatement(
        'CREATE TRIGGER ${table}_insert_updated_at '
        'AFTER INSERT ON $table '
        'WHEN NEW.updated_at IS NULL '
        'BEGIN UPDATE $table SET updated_at = $_nowMs '
        'WHERE rowid = NEW.rowid; END',
      );
      // Filling in a note's uuid is not an edit (see _migrateToV12).
      final notAnEdit = table == 'record_notes'
          ? 'AND NOT (OLD.uuid IS NULL AND NEW.uuid IS NOT NULL) '
          : '';
      await customStatement(
        'CREATE TRIGGER ${table}_update_updated_at '
        'AFTER UPDATE ON $table '
        'WHEN (NEW.updated_at = OLD.updated_at OR NEW.updated_at IS NULL) '
        '$notAnEdit'
        'BEGIN UPDATE $table SET updated_at = '
        'MAX($_nowMs, COALESCE(OLD.updated_at, 0) + 1) '
        'WHERE rowid = NEW.rowid; END',
      );
    }

    for (final MapEntry(key: table, value: key) in _syncKeys.entries) {
      for (final op in const ['insert', 'update']) {
        await customStatement('DROP TRIGGER IF EXISTS ${table}_${op}_outbox');
        await customStatement(
          'CREATE TRIGGER ${table}_${op}_outbox '
          'AFTER ${op.toUpperCase()} ON $table '
          'BEGIN INSERT INTO sync_outbox (synced_table, row_key) '
          "VALUES ('$table', $key); END",
        );
      }
    }

    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS record_notes_insert_uuid '
      'AFTER INSERT ON record_notes '
      'WHEN NEW.uuid IS NULL '
      "BEGIN UPDATE record_notes SET uuid = 'legacy-' || NEW.id "
      'WHERE id = NEW.id; END',
    );
  }

  /// The v10 triggers, kept for the steps from v10 to v12. They stamp
  /// whole seconds; [_createSyncTriggers] replaces them in v13.
  Future<void> _createSyncTriggersV10() async {
    final tables = [
      'fhir_resource',
      'sources',
      'record_notes',
      'processing_sessions',
    ];

    for (final table in tables) {
      final hasUpdatedAt = await customSelect(
        "SELECT COUNT(*) as cnt FROM pragma_table_info('$table') WHERE name='updated_at'",
      ).getSingle();
      if ((hasUpdatedAt.data['cnt'] as int? ?? 0) == 0) continue;

      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS ${table}_insert_updated_at '
        'AFTER INSERT ON $table '
        'WHEN NEW.updated_at IS NULL '
        'BEGIN UPDATE $table SET updated_at = '
        "CAST(strftime('%s', 'now') * 1000 AS INTEGER) "
        'WHERE rowid = NEW.rowid; END',
      );

      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS ${table}_update_updated_at '
        'AFTER UPDATE ON $table '
        'WHEN NEW.updated_at = OLD.updated_at OR NEW.updated_at IS NULL '
        'BEGIN UPDATE $table SET updated_at = '
        "CAST(strftime('%s', 'now') * 1000 AS INTEGER) "
        'WHERE rowid = NEW.rowid; END',
      );
    }
  }

  Future<List<FhirResourceLocalDto>> getEncounterWithReferences(
    String encounterId,
  ) {
    return customSelect(
      '''
      SELECT * FROM fhir_resource 
      WHERE id = ? 
         OR (resource_type != 'Encounter' AND resource LIKE ?)
      ORDER BY updated_at DESC
      ''',
      variables: [
        Variable.withString(encounterId),
        Variable.withString(
          '%"encounter":{"reference":"urn:uuid:$encounterId"}%',
        ),
      ],
      readsFrom: {fhirResource},
    ).map((row) => fhirResource.map(row.data)).get();
  }

  Future<List<FhirResourceLocalDto>> getPaginatedResourcesByType(
    String resourceType, {
    int offset = 0,
    int limit = 20,
    String? sourceId,
  }) {
    var query = 'SELECT * FROM fhir_resource WHERE resource_type = ?';
    final variables = <Variable>[Variable.withString(resourceType)];

    if (sourceId != null) {
      query += ' AND source_id = ?';
      variables.add(Variable.withString(sourceId));
    }

    query += ' ORDER BY updated_at DESC LIMIT ? OFFSET ?';
    variables.add(Variable.withInt(limit));
    variables.add(Variable.withInt(offset));

    return customSelect(
      query,
      variables: variables,
      readsFrom: {fhirResource},
    ).map((row) => fhirResource.map(row.data)).get();
  }

  Future<int> getResourceCountByType(String resourceType) async {
    final result = await customSelect(
      'SELECT COUNT(*) as count FROM fhir_resource WHERE resource_type = ?',
      variables: [Variable.withString(resourceType)],
      readsFrom: {fhirResource},
    ).getSingle();

    return result.data['count'] as int;
  }

  Future<List<String>> getAvailableResourceTypes() async {
    final results = await customSelect(
      'SELECT DISTINCT resource_type FROM fhir_resource ORDER BY resource_type',
      readsFrom: {fhirResource},
    ).get();

    return results.map((row) => row.data['resource_type'] as String).toList();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    // On its own isolate: a sync batch, an import or a search doesn't
    // freeze the UI.
    return NativeDatabase.createInBackground(
      file,
      setup: (database) {
        database.execute('PRAGMA foreign_keys = ON');
        database.execute('PRAGMA journal_mode = WAL');
        database.execute('PRAGMA synchronous = NORMAL');
        database.execute('PRAGMA cache_size = 10000');
        database.execute('PRAGMA temp_store = MEMORY');
      },
    );
  });
}
