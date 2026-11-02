import 'package:drift/drift.dart';
import 'package:health_wallet/core/data/local/app_database.dart';

/// User deletes of the tables that sync between mobile and desktop
/// (`fhir_resource`, `sources`, `record_notes`).
///
/// A delete keeps the row and sets `deleted_at` and `updated_at` to now in
/// milliseconds (at least one past the row's `updated_at`, so the stamp
/// never goes back), so the tombstone travels in the next sync batch and
/// wins over older copies on the other device. The values are written with raw
/// SQL because drift stores a `DateTime` in seconds. Rows that are already
/// tombstoned keep their stamp. Deleting records also tombstones their
/// notes. See the LWW sync section of `architecture.md`.
extension SoftDelete on AppDatabase {
  /// Tombstones the `fhir_resource` rows with these ids and their notes.
  /// Returns the number of records deleted.
  Future<int> softDeleteResources(Iterable<String> ids) {
    final list = ids.toSet().toList();
    if (list.isEmpty) return Future.value(0);
    final placeholders = List.filled(list.length, '?').join(', ');
    return _softDeleteResourcesWhere('id IN ($placeholders)', [
      for (final id in list) Variable.withString(id),
    ]);
  }

  /// Tombstones the records of [sourceId] and their notes. Returns the
  /// number of records deleted.
  Future<int> softDeleteResourcesOfSource(String sourceId) =>
      _softDeleteResourcesWhere('source_id = ?', [
        Variable.withString(sourceId),
      ]);

  /// Tombstones the DocumentReferences of [sourceId] linked to
  /// [encounterId], and their notes. Returns the number deleted.
  Future<int> softDeleteDocumentReferences({
    required String sourceId,
    required String encounterId,
  }) => _softDeleteResourcesWhere(
    "source_id = ? AND resource_type = 'DocumentReference' "
    'AND encounter_id = ?',
    [Variable.withString(sourceId), Variable.withString(encounterId)],
  );

  /// Tombstones the source row, its records and their notes.
  Future<void> softDeleteSource(String sourceId) => transaction(() async {
    final now = _nowMs();
    await customUpdate(
      'UPDATE sources SET deleted_at = MAX(?, COALESCE(updated_at, 0) + 1), updated_at = MAX(?, COALESCE(updated_at, 0) + 1) '
      'WHERE id = ? AND deleted_at IS NULL',
      variables: [..._stamp(now), Variable.withString(sourceId)],
      updates: {sources},
      updateKind: UpdateKind.update,
    );
    await _softDeleteResourcesWhere(
      'source_id = ?',
      [Variable.withString(sourceId)],
      now: now,
    );
  });

  /// Tombstones one note. Returns 1, or 0 when it is missing or already
  /// deleted.
  Future<int> softDeleteNote(int id) => customUpdate(
    'UPDATE record_notes SET deleted_at = MAX(?, COALESCE(updated_at, 0) + 1), updated_at = MAX(?, COALESCE(updated_at, 0) + 1) '
    'WHERE id = ? AND deleted_at IS NULL',
    variables: [..._stamp(_nowMs()), Variable.withInt(id)],
    updates: {recordNotes},
    updateKind: UpdateKind.update,
  );

  Future<int> _softDeleteResourcesWhere(
    String where,
    List<Variable> args, {
    int? now,
  }) => transaction(() async {
    final stamp = _stamp(now ?? _nowMs());
    await customUpdate(
      'UPDATE record_notes SET deleted_at = MAX(?, COALESCE(updated_at, 0) + 1), updated_at = MAX(?, COALESCE(updated_at, 0) + 1) '
      'WHERE deleted_at IS NULL '
      'AND resource_id IN (SELECT id FROM fhir_resource WHERE $where)',
      variables: [...stamp, ...args],
      updates: {recordNotes},
      updateKind: UpdateKind.update,
    );
    return customUpdate(
      'UPDATE fhir_resource SET deleted_at = MAX(?, COALESCE(updated_at, 0) + 1), updated_at = MAX(?, COALESCE(updated_at, 0) + 1) '
      'WHERE deleted_at IS NULL AND $where',
      variables: [...stamp, ...args],
      updates: {fhirResource},
      updateKind: UpdateKind.update,
    );
  });

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  static List<Variable> _stamp(int now) => [
    Variable.withInt(now),
    Variable.withInt(now),
  ];
}
