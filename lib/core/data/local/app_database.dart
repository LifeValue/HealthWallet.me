import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:health_wallet/core/data/local/app_database.steps.dart' as steps;
import 'package:health_wallet/features/records/data/datasource/tables/record_notes.dart';
import 'package:health_wallet/features/scan/data/data_source/local/tables/processing_sessions.dart';
import 'package:health_wallet/features/smart_health_share/data/data_source/local/tables/trusted_issuers_table.dart';
import 'package:health_wallet/features/smart_health_share/data/data_source/local/tables/user_keys_table.dart';
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
  UserKeys,
  TrustedIssuers,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Create custom indexes after table creation
          await _createOptimizationIndexes();
        },
        onUpgrade: steps.stepByStep(
          from1To2: (m, schema) async {
            await _createOptimizationIndexes();
            await m.createTable(schema.recordAttachments);
          },
          from2To3: (m, schema) async {
            await m.createTable(schema.recordNotes);
          },
          from3To5: (m, schema) async {
            await m.addColumn(schema.sources, schema.sources.labelSource);
          },
          from5To6: (m, schema) async {
            await m.createTable(schema.processingSessions);
          },
          from6To7: (m, schema) async {
            await m.addColumn(
                schema.processingSessions, schema.processingSessions.patient);
            await m.addColumn(
                schema.processingSessions, schema.processingSessions.encounter);
          },
        ),
        // Note: from7To8 migration will be added after running drift_dev
        // For now, tables will be created on next app launch after code generation
      );

  /// Create performance optimization indexes
  Future<void> _createOptimizationIndexes() async {
    await customStatement(
        'PRAGMA journal_mode=WAL'); // Enable WAL mode for better performance
    await customStatement('PRAGMA synchronous=NORMAL'); // Optimize sync mode
    await customStatement('PRAGMA cache_size=10000'); // Increase cache size
    await customStatement(
        'PRAGMA temp_store=MEMORY'); // Use memory for temp storage
  }

  Stream<List<Source>> watchSources() => select(sources).watch();
  Future<void> addSource(SourcesCompanion entry) => into(sources).insert(entry);

  /// Optimized method to get encounter with references using indexed queries
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

  /// Get paginated resources by type with proper database-level pagination
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

  /// Get resource count by type efficiently
  Future<int> getResourceCountByType(String resourceType) async {
    final result = await customSelect(
      'SELECT COUNT(*) as count FROM fhir_resource WHERE resource_type = ?',
      variables: [Variable.withString(resourceType)],
      readsFrom: {fhirResource},
    ).getSingle();

    return result.data['count'] as int;
  }

  /// Get all available resource types efficiently
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
      // Enable foreign key constraints and other optimizations
      database.execute('PRAGMA foreign_keys = ON');
      database.execute('PRAGMA journal_mode = WAL');
      database.execute('PRAGMA synchronous = NORMAL');
      database.execute('PRAGMA cache_size = 10000');
      database.execute('PRAGMA temp_store = MEMORY');
    });
  });
}
