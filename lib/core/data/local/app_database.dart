import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:health_wallet/core/data/local/app_database.steps.dart';
import 'package:health_wallet/features/records/data/data_source/tables/record_notes.dart';
import 'package:health_wallet/features/processing/data/data_source/local/tables/processing_sessions.dart';
import 'package:health_wallet/features/sync/data/data_source/local/tables/fhir_resource_table.dart';
import 'package:health_wallet/features/sync/data/data_source/local/tables/source_table.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  FhirResource,
  Sources,
  RecordNotes,
  ProcessingSessions,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 11;

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
                  'ALTER TABLE sources RENAME COLUMN name TO platform_name');
              await m.addColumn(schema.sources, schema.sources.labelSource);
              await m.addColumn(schema.sources, schema.sources.platformType);
              await m.addColumn(schema.sources, schema.sources.createdAt);
              await m.addColumn(schema.sources, schema.sources.updatedAt);
              await m.alterTable(TableMigration(schema.recordNotes));
              await m.createTable(schema.processingSessions);
            },
            from5To6: (m, schema) async {},
            from6To7: (m, schema) async {
              await m.addColumn(
                  schema.processingSessions, schema.processingSessions.patient);
              await m.addColumn(schema.processingSessions,
                  schema.processingSessions.encounter);
            },
            from7To8: (m, schema) async {
              await m.addColumn(schema.processingSessions,
                  schema.processingSessions.isDocumentAttached);
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
            await _createSyncTriggers();
          }

          if (from <= 10 && to >= 11) {
            await _migrateToV11();
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
      "INSERT OR IGNORE INTO sources (id, platform_name, label_source, platform_type, created_at, updated_at) "
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
        'ALTER TABLE fhir_resource ADD COLUMN updated_at INTEGER');
    await customStatement(
        'ALTER TABLE fhir_resource ADD COLUMN deleted_at INTEGER');
    await customStatement(
        'ALTER TABLE fhir_resource ADD COLUMN device_id TEXT');

    await customStatement(
        'ALTER TABLE sources ADD COLUMN deleted_at INTEGER');

    await customStatement(
        'ALTER TABLE processing_sessions ADD COLUMN updated_at INTEGER');
    await customStatement(
        'ALTER TABLE processing_sessions ADD COLUMN deleted_at INTEGER');
    await customStatement(
        'ALTER TABLE processing_sessions ADD COLUMN device_id TEXT');

    await customStatement(
        'ALTER TABLE record_notes ADD COLUMN updated_at INTEGER');
    await customStatement(
        'ALTER TABLE record_notes ADD COLUMN deleted_at INTEGER');
  }


  Future<void> _migrateToV11() async {
    try {
      await customStatement(
          'ALTER TABLE fhir_resource ADD COLUMN specialty_override TEXT');
    } catch (_) {}

    final rows = await customSelect(
      "SELECT id, resource_raw FROM fhir_resource "
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

  Future<void> _createOptimizationIndexes() async {
    await customStatement('PRAGMA journal_mode=WAL');
    await customStatement('PRAGMA synchronous=NORMAL');
    await customStatement('PRAGMA cache_size=10000');
    await customStatement('PRAGMA temp_store=MEMORY');
  }

  Future<void> _createSyncTriggers() async {
    final tables = ['fhir_resource', 'sources', 'record_notes', 'processing_sessions'];

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

  Stream<List<Source>> watchSources() => select(sources).watch();
  Future<void> addSource(SourcesCompanion entry) => into(sources).insert(entry);

  Future<List<FhirResourceLocalDto>> getEncounterWithReferences(
      String encounterId) {
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
            '%"encounter":{"reference":"urn:uuid:$encounterId"}%')
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
    return NativeDatabase(file, setup: (database) {
      database.execute('PRAGMA foreign_keys = ON');
      database.execute('PRAGMA journal_mode = WAL');
      database.execute('PRAGMA synchronous = NORMAL');
      database.execute('PRAGMA cache_size = 10000');
      database.execute('PRAGMA temp_store = MEMORY');
    });
  });
}
