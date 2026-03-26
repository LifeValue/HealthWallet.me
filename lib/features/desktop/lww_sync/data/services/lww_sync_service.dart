import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/attachment_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/domain/entity/sync_delta.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

@lazySingleton
class LwwSyncService {
  static const _lastSyncKey = 'lww_last_sync_timestamp';
  static const _deviceIdKey = 'lww_local_device_id';
  static const _tombstoneRetentionDays = 30;
  static const _tablesWithDeviceId = ['fhir_resource', 'processing_sessions'];

  static const syncedTables = [
    'fhir_resource',
    'sources',
    'record_notes',
    'processing_sessions',
  ];

  final AppDatabase _db;
  final SharedPreferences _prefs;
  final AttachmentSyncService _attachmentSync;

  LwwSyncService(this._db, this._prefs, this._attachmentSync);

  Future<SyncDelta> computeDelta(String tableName, DateTime since) async {
    final sinceMs = since.millisecondsSinceEpoch;
    final deviceId = await getLocalDeviceId();

    final results = await _db.customSelect(
      'SELECT * FROM $tableName WHERE updated_at >= ?',
      variables: [Variable.withInt(sinceMs)],
    ).get();

    var rows = results.map((row) => row.data).toList();

    if (tableName == 'fhir_resource' && rows.isNotEmpty) {
      rows = await _attachmentSync.embedAttachments(rows);
    }

    return SyncDelta(
      tableName: tableName,
      rows: rows,
      deviceId: deviceId,
      timestamp: DateTime.now(),
    );
  }

  Future<List<SyncDelta>> computeAllDeltas(DateTime since) async {
    final deltas = <SyncDelta>[];
    for (final table in syncedTables) {
      final delta = await computeDelta(table, since);
      if (delta.rows.isNotEmpty) {
        deltas.add(delta);
      }
    }
    return deltas;
  }

  Future<int> applyDelta(SyncDelta delta) async {
    final tableName = delta.tableName;
    if (!syncedTables.contains(tableName)) {
      return 0;
    }

    var appliedCount = 0;
    var incomingRows = delta.rows;

    if (tableName == 'fhir_resource' && incomingRows.isNotEmpty) {
      incomingRows = await _attachmentSync.restoreAttachments(incomingRows);
    }

    for (final incomingRow in incomingRows) {
      final id = _extractId(tableName, incomingRow);
      if (id == null) continue;

      final incomingUpdatedAt = _parseTimestamp(incomingRow['updated_at']);
      if (incomingUpdatedAt == null) continue;

      var shouldApply = await _shouldApplyIncoming(
        tableName: tableName,
        id: id,
        incomingUpdatedAt: incomingUpdatedAt,
        incomingDeviceId: delta.deviceId,
      );

      if (!shouldApply && tableName == 'fhir_resource') {
        shouldApply = await _localHasBrokenAttachment(id);
      }

      if (shouldApply) {
        await _upsertRow(tableName, incomingRow, id);
        appliedCount++;
      }
    }

    return appliedCount;
  }

  Future<bool> _shouldApplyIncoming({
    required String tableName,
    required String id,
    required DateTime incomingUpdatedAt,
    required String incomingDeviceId,
  }) async {
    final idColumn = _getIdColumn(tableName);
    final hasDeviceId = _tablesWithDeviceId.contains(tableName);
    final selectCols = hasDeviceId ? 'updated_at, device_id' : 'updated_at';

    final localRows = await _db.customSelect(
      'SELECT $selectCols FROM $tableName WHERE $idColumn = ?',
      variables: [Variable.withString(id)],
    ).get();

    if (localRows.isEmpty) return true;

    final localRow = localRows.first;
    final localUpdatedAt = _parseTimestamp(localRow.data['updated_at']);

    if (localUpdatedAt == null) return true;

    if (incomingUpdatedAt.isAfter(localUpdatedAt)) return true;
    if (incomingUpdatedAt.isBefore(localUpdatedAt)) return false;

    final localDeviceId = hasDeviceId
        ? (localRow.data['device_id'] as String? ?? '')
        : '';
    return incomingDeviceId.compareTo(localDeviceId) > 0;
  }

  Future<bool> _localHasBrokenAttachment(String id) async {
    final rows = await _db.customSelect(
      "SELECT resource_raw, resource_type FROM fhir_resource WHERE id = ?",
      variables: [Variable.withString(id)],
    ).get();

    if (rows.isEmpty) return false;
    final row = rows.first;
    if (row.data['resource_type'] != 'DocumentReference') return false;

    final raw = row.data['resource_raw'] as String?;
    if (raw == null) return false;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final content = json['content'] as List?;
      if (content == null) return false;

      final docsDir = await getApplicationDocumentsDirectory();

      for (final item in content) {
        if (item is! Map<String, dynamic>) continue;
        final attachment = item['attachment'] as Map<String, dynamic>?;
        final url = attachment?['url'] as String?;
        if (url == null || !url.startsWith('file://')) continue;

        final rawPath = url.substring(7);
        final absolutePath = rawPath.startsWith('/')
            ? rawPath
            : '${docsDir.path}/$rawPath';

        if (!await File(absolutePath).exists()) {
          final fileName = rawPath.split('/').last;
          final byName = File('${docsDir.path}/$fileName');
          if (!await byName.exists()) return true;
        }
      }
    } catch (_) {}

    return false;
  }

  Future<void> _upsertRow(
    String tableName,
    Map<String, dynamic> row,
    String id,
  ) async {
    final columns = row.keys.toList();
    final placeholders = columns.map((_) => '?').join(', ');
    final columnNames = columns.join(', ');
    final updateClauses = columns
        .where((c) => c != _getIdColumn(tableName))
        .map((c) => '$c = excluded.$c')
        .join(', ');

    final idColumn = _getIdColumn(tableName);

    final sql = 'INSERT INTO $tableName ($columnNames) VALUES ($placeholders) '
        'ON CONFLICT($idColumn) DO UPDATE SET $updateClauses';

    final values = columns.map((col) {
      final value = row[col];
      if (value == null) return null;
      if (value is int || value is double || value is bool || value is String) return value;
      return value.toString();
    }).toList();

    await _db.customStatement(sql, values);
  }

  String? _extractId(String tableName, Map<String, dynamic> row) {
    final idColumn = _getIdColumn(tableName);
    final value = row[idColumn];
    if (value == null) return null;
    return value.toString();
  }

  String _getIdColumn(String tableName) {
    return 'id';
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return DateTime.fromMillisecondsSinceEpoch(parsed);
      return DateTime.tryParse(value);
    }
    return null;
  }

  Future<DateTime?> getLastSyncTimestamp() async {
    final ms = _prefs.getInt(_lastSyncKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastSyncTimestamp(DateTime timestamp) async {
    await _prefs.setInt(_lastSyncKey, timestamp.millisecondsSinceEpoch);
  }

  Future<void> resetLastSyncTimestamp() async {
    await _prefs.remove(_lastSyncKey);
  }

  Future<List<String>> getMissingAttachmentPaths() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final missing = <String>[];

    final results = await _db.customSelect(
      "SELECT resource_raw FROM fhir_resource WHERE resource_type = 'DocumentReference' AND deleted_at IS NULL",
    ).get();

    for (final row in results) {
      final raw = row.data['resource_raw'] as String?;
      if (raw == null) continue;

      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final content = json['content'] as List?;
        if (content == null) continue;

        for (final item in content) {
          if (item is! Map<String, dynamic>) continue;
          final attachment = item['attachment'] as Map<String, dynamic>?;
          final url = attachment?['url'] as String?;
          if (url != null && url.startsWith('file://')) {
            final relativePath = url.substring(7);
            final absolutePath = relativePath.startsWith('/')
                ? relativePath
                : '${docsDir.path}/$relativePath';
            if (!await File(absolutePath).exists()) {
              missing.add(relativePath);
            }
          }
        }
      } catch (_) {}
    }

    return missing;
  }

  Future<Map<String, String>> resolveFileRequests(
    List<String> requestedPaths,
  ) async {
    final resolved = <String, String>{};

    for (final relativePath in requestedPaths) {
      final file = await _attachmentSync.resolveFile(relativePath);
      if (file != null) {
        final bytes = await file.readAsBytes();
        resolved[relativePath] = base64Encode(bytes);
      }
    }

    return resolved;
  }

  Future<int> saveReceivedFiles(Map<String, String> fileData) async {
    final docsDir = await getApplicationDocumentsDirectory();
    var saved = 0;

    for (final entry in fileData.entries) {
      try {
        final bytes = base64Decode(entry.value);
        final fileName = entry.key.split('/').last;
        final sanitized = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
        final file = File('${docsDir.path}/$sanitized');
        await file.writeAsBytes(bytes);
        saved++;

        await _updateAttachmentUrls(entry.key, sanitized);
      } catch (_) {}
    }

    return saved;
  }

  Future<void> _updateAttachmentUrls(
    String oldPath,
    String newRelativePath,
  ) async {
    final rows = await _db.customSelect(
      "SELECT id, resource_raw FROM fhir_resource WHERE resource_type = 'DocumentReference' AND deleted_at IS NULL",
    ).get();

    for (final row in rows) {
      final id = row.data['id'] as String?;
      final raw = row.data['resource_raw'] as String?;
      if (id == null || raw == null) continue;
      if (!raw.contains(oldPath)) continue;

      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final content = json['content'] as List?;
        if (content == null) continue;

        var updated = false;
        for (final item in content) {
          if (item is! Map<String, dynamic>) continue;
          final attachment = item['attachment'] as Map<String, dynamic>?;
          final url = attachment?['url'] as String?;
          if (url == null) continue;

          final urlPath = url.startsWith('file://') ? url.substring(7) : url;
          if (urlPath == oldPath || urlPath.endsWith('/$oldPath') || urlPath.split('/').last == oldPath.split('/').last) {
            attachment!['url'] = 'file://$newRelativePath';
            updated = true;
          }
        }

        if (updated) {
          await _db.customStatement(
            'UPDATE fhir_resource SET resource_raw = ? WHERE id = ?',
            [jsonEncode(json), id],
          );
        }
      } catch (_) {}
    }
  }

  Future<int> fixBrokenAttachmentUrls() async {
    final docsDir = await getApplicationDocumentsDirectory();
    var fixed = 0;

    final rows = await _db.customSelect(
      "SELECT id, resource_raw FROM fhir_resource WHERE resource_type = 'DocumentReference' AND deleted_at IS NULL",
    ).get();

    for (final row in rows) {
      final id = row.data['id'] as String?;
      final raw = row.data['resource_raw'] as String?;
      if (id == null || raw == null) continue;

      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final content = json['content'] as List?;
        if (content == null) continue;

        var updated = false;
        for (final item in content) {
          if (item is! Map<String, dynamic>) continue;
          final attachment = item['attachment'] as Map<String, dynamic>?;
          final url = attachment?['url'] as String?;
          if (url == null || !url.startsWith('file://')) continue;

          final rawPath = url.substring(7);
          final absolutePath = rawPath.startsWith('/')
              ? rawPath
              : '${docsDir.path}/$rawPath';

          if (await File(absolutePath).exists()) continue;

          final fileName = rawPath.split('/').last;
          final localFile = File('${docsDir.path}/$fileName');
          if (await localFile.exists()) {
            attachment!['url'] = 'file://$fileName';
            updated = true;
            continue;
          }

          final dir = Directory(docsDir.path);
          final matches = dir.listSync().whereType<File>().where(
            (f) => f.path.split('/').last.contains(
              fileName.replaceAll('.pdf', '').replaceAll('.', '_'),
            ),
          );
          if (matches.isNotEmpty) {
            final match = matches.first.path.split('/').last;
            attachment!['url'] = 'file://$match';
            updated = true;
          }
        }

        if (updated) {
          await _db.customStatement(
            'UPDATE fhir_resource SET resource_raw = ? WHERE id = ?',
            [jsonEncode(json), id],
          );
          fixed++;
        }
      } catch (_) {}
    }

    return fixed;
  }

  Future<Map<String, int>> getTableRowCounts() async {
    final counts = <String, int>{};
    for (final table in syncedTables) {
      final result = await _db.customSelect(
        'SELECT COUNT(*) as count FROM $table WHERE deleted_at IS NULL',
      ).getSingle();
      counts[table] = result.data['count'] as int? ?? 0;
    }
    return counts;
  }

  Future<String> getLocalDeviceId() async {
    var deviceId = _prefs.getString(_deviceIdKey);
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await _prefs.setString(_deviceIdKey, deviceId);
    }
    return deviceId;
  }

  Future<int> cleanupTombstones() async {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: _tombstoneRetentionDays))
        .millisecondsSinceEpoch;

    var totalDeleted = 0;

    for (final table in syncedTables) {
      final result = await _db.customSelect(
        'SELECT COUNT(*) as count FROM $table WHERE deleted_at IS NOT NULL AND deleted_at < ?',
        variables: [Variable(cutoff)],
      ).getSingle();

      final count = result.data['count'] as int? ?? 0;

      if (count > 0) {
        await _db.customStatement(
          'DELETE FROM $table WHERE deleted_at IS NOT NULL AND deleted_at < ?',
          [cutoff],
        );
        totalDeleted += count;
      }
    }

    return totalDeleted;
  }

  Future<int> backfillExistingRows() async {
    final deviceId = await getLocalDeviceId();
    final now = DateTime.now().millisecondsSinceEpoch;
    var totalUpdated = 0;

    for (final table in syncedTables) {
      final result = await _db.customSelect(
        'SELECT COUNT(*) as count FROM $table WHERE updated_at IS NULL',
      ).getSingle();

      final count = result.data['count'] as int? ?? 0;

      if (count > 0) {
        final hasDeviceId = _tablesWithDeviceId.contains(table);
        if (hasDeviceId) {
          await _db.customStatement(
            'UPDATE $table SET updated_at = ?, device_id = ? WHERE updated_at IS NULL',
            [now, deviceId],
          );
        } else {
          await _db.customStatement(
            'UPDATE $table SET updated_at = ? WHERE updated_at IS NULL',
            [now],
          );
        }
        totalUpdated += count;
      }
    }

    return totalUpdated;
  }
}
