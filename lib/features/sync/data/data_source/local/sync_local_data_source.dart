import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:health_wallet/core/data/local/app_database.dart' as db;
import 'package:health_wallet/core/data/local/soft_delete.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart'
    as domain;
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class SyncLocalDataSource {
  Future<void> cacheFhirResources(List<FhirResourceDto> fhirResources);
  Future<void> deleteAllFhirResources();
  Future<String?> getLastSyncTimestamp();
  Future<void> setLastSyncTimestamp(String timestamp);
  Future<void> cacheSources(List<domain.Source> sources);
  Future<List<domain.Source>> getSources({String? patientId});
  Future<void> deleteAllSources();
  Future<void> markResourcesAsDeleted(List<FhirResourceDto> deletions);
  Future<void> updateSourceLabel(String sourceId, String newLabel);
  Future<void> createWalletSource();
  Future<void> createDemoDataSource();
  Future<void> deleteSource(String sourceId);
}

@Injectable(as: SyncLocalDataSource)
class SyncLocalDataSourceImpl implements SyncLocalDataSource {
  final db.AppDatabase _appDatabase;
  final SharedPreferences _sharedPreferences;

  SyncLocalDataSourceImpl(this._appDatabase, this._sharedPreferences);

  /// The row id of each resource: its FHIR id, unless that id already
  /// belongs to a resource of another source or type, which would otherwise
  /// be replaced. Then it is `sourceId/type/id`. Rows keep the id they have,
  /// so a later sync updates them.
  Future<List<String>> _rowIds(List<FhirResourceDto> resources) async {
    String composite(FhirResourceDto e) =>
        '${e.sourceId}/${e.resourceType}/${e.resourceId}';

    final candidates = {
      for (final e in resources) ...[e.resourceId!, composite(e)],
    };
    final owners = <String, (String?, String?)>{
      for (final row in await (_appDatabase.select(
        _appDatabase.fhirResource,
      )..where((r) => r.id.isIn(candidates))).get())
        row.id: (row.sourceId, row.resourceType),
    };

    return [
      for (final e in resources)
        () {
          final owner = (e.sourceId, e.resourceType);
          final bare = e.resourceId!;
          final id =
              !owners.containsKey(composite(e)) &&
                  (owners[bare] == null || owners[bare] == owner)
              ? bare
              : composite(e);
          owners[id] = owner;
          return id;
        }(),
    ];
  }

  @override
  Future<void> cacheFhirResources(List<FhirResourceDto> fhirResources) async {
    final withId = fhirResources
        .where((e) => e.resourceId?.isNotEmpty ?? false)
        .toList();
    if (withId.length < fhirResources.length) {
      logger.w(
        'Skipped ${fhirResources.length - withId.length} resources without '
        'an id',
      );
    }
    final rowIds = await _rowIds(withId);

    final resources = withId.indexed.map((entry) {
      final (i, e) = entry;
      return db.FhirResourceCompanion.insert(
        id: rowIds[i],
        sourceId: Value(e.sourceId),
        resourceType: Value(e.resourceType),
        resourceId: Value(e.resourceId),
        title: Value(e.title),
        date: Value(e.date),
        resourceRaw: jsonEncode(e.resourceRaw),
        encounterId: e.encounterId != null
            ? Value(e.encounterId)
            : const Value.absent(),
        subjectId: e.subjectId != null
            ? Value(e.subjectId)
            : const Value.absent(),
      );
    }).toList();
    await _appDatabase.batch((batch) {
      batch.insertAll(
        _appDatabase.fhirResource,
        resources,
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  @override
  Future<void> deleteAllFhirResources() {
    return _appDatabase.delete(_appDatabase.fhirResource).go();
  }

  @override
  Future<String?> getLastSyncTimestamp() {
    return Future.value(_sharedPreferences.getString('lastSyncTimestamp'));
  }

  @override
  Future<void> setLastSyncTimestamp(String timestamp) {
    return _sharedPreferences.setString('lastSyncTimestamp', timestamp);
  }

  @override
  Future<void> cacheSources(List<domain.Source> sources) async {
    final sourceEntries = sources.map((e) {
      return db.SourcesCompanion.insert(
        id: e.id,
        platformName: Value(e.platformName),
        logo: Value(e.logo),
        labelSource: Value(e.labelSource),
        platformType: Value(e.platformType),
        createdAt: Value(e.createdAt),
        // updated_at is stamped by the trigger, in milliseconds like every
        // other synced row; drift would store seconds.
      );
    }).toList();
    await _appDatabase.batch((batch) {
      batch.insertAll(
        _appDatabase.sources,
        sourceEntries,
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  @override
  Future<void> deleteAllSources() {
    return _appDatabase.delete(_appDatabase.sources).go();
  }

  @override
  Future<List<domain.Source>> getSources({String? patientId}) async {
    // First get unique source IDs from FHIR resources
    final query = _appDatabase.select(_appDatabase.fhirResource)
      ..where((tbl) => tbl.deletedAt.isNull());

    if (patientId != null) {
      query.where((tbl) => tbl.sourceId.equals(patientId));
    } else {
      query.where((tbl) => tbl.sourceId.isNotNull());
    }

    final results = await query.get();
    final uniqueSourceIds = results
        .map((row) => row.sourceId)
        .where((sourceId) => sourceId != null && sourceId.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    // Get all sources from Sources table (including those without resources)
    final allSources = await (_appDatabase.select(
      _appDatabase.sources,
    )..where((s) => s.deletedAt.isNull())).get();
    final allSourceIds = allSources.map((source) => source.id).toSet();

    // Combine source IDs from both FHIR resources and Sources table
    final combinedSourceIds = {...uniqueSourceIds, ...allSourceIds}.toList();

    // Get source labels from Sources table
    final sourceLabelMap = {
      for (final source in allSources) source.id: source.labelSource,
    };

    final sources = combinedSourceIds.map(
      (sourceId) {
        final dbSource = allSources.cast<db.Source?>().firstWhere(
          (s) => s?.id == sourceId,
          orElse: () => null,
        );

        return domain.Source(
          id: sourceId,
          platformName: _getSourcePlatformName(sourceId),
          logo: null,
          labelSource:
              sourceLabelMap[sourceId] ??
              (sourceId == 'demo_data' ? 'Demo' : null),
          platformType: _getSourcePlatformType(sourceId, dbSource),
          createdAt: dbSource?.createdAt,
          updatedAt: _fromStamp(dbSource?.updatedAt),
        );
      },
    ).toList();

    return sources;
  }

  String? _getSourcePlatformName(String sourceId) {
    if (sourceId.startsWith('wallet-')) return 'wallet';
    if (sourceId == 'demo_data') return 'wallet-manual';
    return sourceId;
  }

  /// Determines the platform type based on source ID and database record
  /// Following the clean architecture:
  /// - WALLET sources (wallet, demo_data) are 'wallet' type
  /// - All other sources (from Fasten API) are 'fasten' type
  String _getSourcePlatformType(String sourceId, db.Source? dbSource) {
    // Check if database has explicit platformType
    if (dbSource?.platformType != null) {
      return dbSource!.platformType;
    }

    if (sourceId.startsWith('wallet-') || sourceId == 'demo_data') {
      return 'wallet';
    }
    return 'fasten';
  }

  @override
  Future<void> markResourcesAsDeleted(List<FhirResourceDto> deletions) async {
    // TODO: Implement proper deletion marking when database schema supports it
    // For now, we'll just log the deletions
    for (final deletion in deletions) {
      if (deletion.resourceId != null) {
        // Note: The current database schema doesn't support deletedAt field
        // We would need to either:
        // 1. Add a deletedAt field to the database schema
        // 2. Use an existing field to mark deletion status
        // 3. Remove the resource entirely
      }
    }
  }

  @override
  Future<void> updateSourceLabel(String sourceId, String newLabel) async {
    try {
      await _appDatabase
          .into(_appDatabase.sources)
          .insertOnConflictUpdate(
            db.SourcesCompanion(
              id: Value(sourceId),
              labelSource: Value(newLabel.isEmpty ? null : newLabel),
            ),
          );
    } catch (e) {
      logger.e('Error updating source label in database: $e');
      rethrow;
    }
  }

  @override
  Future<void> createWalletSource() async {
    try {
      // Check if wallet source already exists
      final existingWallet = await (_appDatabase.select(
        _appDatabase.sources,
      )..where((s) => s.id.equals('wallet'))).getSingleOrNull();

      if (existingWallet != null && existingWallet.deletedAt == null) {
        // Wallet source already exists, no need to create
        return;
      }

      // Create the Wallet source, replacing a deleted one. `updated_at` is
      // left to the trigger, which stamps it in milliseconds (drift would
      // store seconds), so the new row beats the older tombstone on the
      // peer.
      await _appDatabase
          .into(_appDatabase.sources)
          .insert(
            db.SourcesCompanion.insert(
              id: 'wallet',
              platformName: const Value('wallet'),
              labelSource: const Value('Wallet'),
              platformType: const Value('wallet'),
              createdAt: Value(DateTime.now()),
            ),
            mode: InsertMode.insertOrReplace,
          );
    } catch (e) {
      logger.e('Error creating wallet source: $e');
      rethrow;
    }
  }

  /// Create demo_data source in the database with proper name and label
  @override
  Future<void> createDemoDataSource() async {
    try {
      // Create demo_data source in sources table with correct name for
      // display logic. Replacing the row clears a tombstone; `updated_at` is
      // left to the trigger, in milliseconds, so the new row beats the
      // tombstone (see createWalletSource).
      await _appDatabase
          .into(_appDatabase.sources)
          .insert(
            db.SourcesCompanion.insert(
              id: 'demo_data',
              platformName: const Value('wallet-manual'), // Platform name
              labelSource: const Value('Demo Data'), // Custom display label
              platformType: const Value('wallet'),
              createdAt: Value(DateTime.now()),
            ),
            mode: InsertMode.insertOrReplace,
          );
    } catch (e) {
      logger.e('Error creating demo data source: $e');
      rethrow;
    }
  }

  /// Soft-deletes the source, its records and their notes, so the delete
  /// reaches the paired device (see [SoftDelete]).
  @override
  Future<void> deleteSource(String sourceId) =>
      _appDatabase.softDeleteSource(sourceId);

  /// `updated_at` holds the sync stamp in milliseconds, which drift's
  /// DateTime column reads as seconds.
  static DateTime? _fromStamp(DateTime? read) => read == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(
          read.millisecondsSinceEpoch ~/ 1000,
        );
}
