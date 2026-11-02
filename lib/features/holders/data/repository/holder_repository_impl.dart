import 'dart:convert';

import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/holders/domain/entity/holder_patient.dart';
import 'package:health_wallet/features/holders/domain/entity/holder_snapshot.dart';
import 'package:health_wallet/features/holders/domain/repository/holder_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: HolderRepository)
class HolderRepositoryImpl implements HolderRepository {
  HolderRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<bool> hasUnassigned() async {
    final row = await _db
        .customSelect(
          'SELECT EXISTS (SELECT 1 FROM sources '
          'WHERE deleted_at IS NULL AND holder_id IS NULL) '
          'OR EXISTS (SELECT 1 FROM fhir_resource f WHERE f.deleted_at IS NULL '
          "AND f.source_id IS NOT NULL AND f.source_id != '' "
          'AND NOT EXISTS (SELECT 1 FROM sources s WHERE s.id = f.source_id)) '
          'AS unassigned',
        )
        .getSingle();
    return row.read<int>('unassigned') == 1;
  }

  @override
  Future<HolderSnapshot> snapshot() async {
    final rows = await _db
        .customSelect('SELECT id, holder_id, deleted_at FROM sources')
        .get();
    final known = {for (final r in rows) r.read<String>('id')};
    final sources = [
      for (final r in rows)
        if (r.readNullable<int>('deleted_at') == null)
          HolderSource(
            r.read<String>('id'),
            holderId: r.readNullable<String>('holder_id'),
          ),
      // Provider sources get their row only when the provider's source list
      // is fetched; their records may already be here.
      for (final r
          in await _db
              .customSelect(
                'SELECT DISTINCT source_id FROM fhir_resource '
                "WHERE deleted_at IS NULL AND source_id IS NOT NULL AND source_id != ''",
              )
              .get())
        if (!known.contains(r.read<String>('source_id')))
          HolderSource(r.read<String>('source_id')),
    ];

    final patients = <HolderPatient>[];
    for (final r
        in await _db
            .customSelect(
              'SELECT id, source_id, resource_id, resource_raw FROM fhir_resource '
              "WHERE resource_type = 'Patient' AND deleted_at IS NULL "
              "AND source_id IS NOT NULL AND source_id != ''",
            )
            .get()) {
      try {
        patients.add(
          HolderPatient.fromRow(
            rowId: r.read<String>('id'),
            resourceId: r.readNullable<String>('resource_id'),
            sourceId: r.read<String>('source_id'),
            raw: jsonDecode(
              r.read<String>('resource_raw'),
            ) as Map<String, dynamic>,
          ),
        );
      } on FormatException catch (e) {
        logger.w('Patient ${r.read<String>('id')} is not valid JSON', e);
      }
    }

    // Records refer to their patient by `subject`, or by `patient` or
    // `beneficiary` (allergies, immunizations, coverage).
    final references = <String, Set<String>>{};
    for (final r
        in await _db
            .customSelect(
              'SELECT DISTINCT source_id, ref FROM ('
              "SELECT source_id, json_extract(resource_raw, '\$.subject.reference') AS ref "
              'FROM fhir_resource WHERE deleted_at IS NULL AND json_valid(resource_raw) '
              'UNION ALL '
              "SELECT source_id, json_extract(resource_raw, '\$.patient.reference') "
              'FROM fhir_resource WHERE deleted_at IS NULL AND json_valid(resource_raw) '
              'UNION ALL '
              "SELECT source_id, json_extract(resource_raw, '\$.beneficiary.reference') "
              'FROM fhir_resource WHERE deleted_at IS NULL AND json_valid(resource_raw)'
              ") WHERE ref LIKE 'Patient/%' AND source_id IS NOT NULL",
            )
            .get()) {
      (references[r.read<String>('source_id')] ??= {}).add(
        r.read<String>('ref'),
      );
    }

    return HolderSnapshot(
      sources: sources,
      patients: patients,
      references: references,
    );
  }

  @override
  Future<Map<String, String>> holderBySource() async => {
    for (final r
        in await _db
            .customSelect(
              'SELECT id, holder_id FROM sources '
              'WHERE deleted_at IS NULL AND holder_id IS NOT NULL',
            )
            .get())
      r.read<String>('id'): r.read<String>('holder_id'),
  };

  @override
  Future<void> assignHolders(Map<String, String> holderBySource) async {
    await _db.transaction(() async {
      for (final MapEntry(key: sourceId, value: holderId)
          in holderBySource.entries) {
        await _db.customStatement(
          'INSERT INTO sources (id, platform_type, holder_id) VALUES (?, ?, ?) '
          'ON CONFLICT(id) DO UPDATE SET holder_id = excluded.holder_id '
          'WHERE sources.holder_id IS NULL',
          [sourceId, _platformTypeOf(sourceId), holderId],
        );
      }
    });
  }

  /// The type `getSources` reports for a source without a row.
  static String _platformTypeOf(String sourceId) =>
      sourceId.startsWith(HolderSource.walletPrefix) ||
          sourceId == HolderSource.demoId
      ? 'wallet'
      : 'fasten';
}
