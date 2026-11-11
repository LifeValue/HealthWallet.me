import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/attachment_file_cleaner.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/attachment_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/domain/entity/sync_batch.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Where this device stands with the paired peer: the last outbox entry the
/// peer acknowledged, and when rows last went either way.
class SyncPeerState {
  const SyncPeerState({
    required this.peerId,
    required this.ackedSeq,
    this.peerName,
    this.lastSyncAt,
  });

  final String peerId;
  final int ackedSeq;
  final String? peerName;
  final DateTime? lastSyncAt;

  SyncPeerState copyWith({
    int? ackedSeq,
    String? peerName,
    DateTime? lastSyncAt,
  }) => SyncPeerState(
    peerId: peerId,
    ackedSeq: ackedSeq ?? this.ackedSeq,
    peerName: peerName ?? this.peerName,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
  );

  Map<String, dynamic> toJson() => {
    'peer_id': peerId,
    'acked_seq': ackedSeq,
    'peer_name': peerName,
    'last_sync_at': lastSyncAt?.millisecondsSinceEpoch,
  };

  static SyncPeerState? fromJson(Map<String, dynamic> json) {
    final peerId = json['peer_id'];
    final acked = json['acked_seq'];
    if (peerId is! String || acked is! int) return null;
    final last = json['last_sync_at'];
    return SyncPeerState(
      peerId: peerId,
      ackedSeq: acked,
      peerName: json['peer_name'] as String?,
      lastSyncAt: last is int
          ? DateTime.fromMillisecondsSinceEpoch(last)
          : null,
    );
  }
}

/// What applying a batch changed: the keys of the rows written, by table.
class AppliedBatch {
  const AppliedBatch(this.rows);

  final Map<String, List<String>> rows;

  int get count => rows.values.fold(0, (sum, keys) => sum + keys.length);
}

/// One piece of an attachment file, sent in `sync.file_chunk`.
class FileChunk {
  const FileChunk({
    required this.path,
    required this.offset,
    required this.total,
    required this.bytes,
  });

  final String path;
  final int offset;
  final int total;
  final Uint8List bytes;

  bool get isLast => offset + bytes.length >= total;
}

@lazySingleton
class LwwSyncService {
  static const _peerStateKey = 'lww_sync_state';
  static const _deviceIdKey = 'lww_local_device_id';
  static const _tombstoneRetentionDays = 30;

  /// Applied in this order, so a note's source exists before the note.
  static const syncedTables = ['sources', 'fhir_resource', 'record_notes'];

  /// A batch stays well below the transport's frame limit.
  static const maxBatchRows = 200;
  static const maxBatchBytes = 2 * 1024 * 1024;

  static const fileChunkBytes = 256 * 1024;

  /// Larger attachments are not sent (a scan or a photo is far smaller).
  static const maxFileBytes = 200 * 1024 * 1024;

  final AppDatabase _db;
  final SharedPreferences _prefs;
  final AttachmentSyncService _attachmentSync;
  final AttachmentFileCleaner _fileCleaner;

  final _columns = <String, Set<String>>{};

  LwwSyncService(
    this._db,
    this._prefs,
    this._attachmentSync,
    this._fileCleaner,
  );

  /// The column that identifies a row on every device.
  static String keyColumn(String tableName) =>
      tableName == 'record_notes' ? 'uuid' : 'id';

  // ---------------------------------------------------------------------------
  // Peer state

  SyncPeerState? loadPeerState() {
    final raw = _prefs.getString(_peerStateKey);
    if (raw == null) return null;
    try {
      return SyncPeerState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      logger.w('[LwwSync] unreadable sync state, starting over', e);
      return null;
    }
  }

  Future<void> savePeerState(SyncPeerState state) =>
      _prefs.setString(_peerStateKey, jsonEncode(state.toJson()));

  /// The state for [peerId]. A different peer than last time (another
  /// desktop, a new phone, a re-pairing) starts from scratch: what was
  /// waiting for the old one is reconciled with the new one instead.
  Future<SyncPeerState> peerStateFor(String peerId, {String? peerName}) async {
    final current = loadPeerState();
    if (current != null && current.peerId == peerId) {
      if (peerName != null && peerName != current.peerName) {
        final renamed = current.copyWith(peerName: peerName);
        await savePeerState(renamed);
        return renamed;
      }
      return current;
    }
    final fresh = SyncPeerState(
      peerId: peerId,
      ackedSeq: await currentOutboxSeq(),
      peerName: peerName,
    );
    await savePeerState(fresh);
    await pruneOutbox(fresh.ackedSeq);
    return fresh;
  }

  /// Forgets the peer, after a restore or an unpairing; the next connection
  /// reconciles everything.
  Future<void> resetPeerState() async {
    await _prefs.remove(_peerStateKey);
    await pruneOutbox(await currentOutboxSeq());
  }

  Future<String> getLocalDeviceId() async {
    var deviceId = _prefs.getString(_deviceIdKey);
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await _prefs.setString(_deviceIdKey, deviceId);
    }
    return deviceId;
  }

  // ---------------------------------------------------------------------------
  // Outbox

  /// The last outbox position handed out, also after the entries were
  /// pruned (AUTOINCREMENT never reuses one).
  Future<int> currentOutboxSeq() async {
    final row = await _db
        .customSelect(
          "SELECT COALESCE((SELECT seq FROM sqlite_sequence WHERE name = 'sync_outbox'), 0) AS s",
        )
        .getSingle();
    return row.data['s'] as int;
  }

  /// Rows changed locally and not yet acknowledged by the peer.
  Future<int> pendingCount(int afterSeq) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM (SELECT DISTINCT synced_table, row_key '
          'FROM sync_outbox WHERE seq > ?)',
          variables: [Variable.withInt(afterSeq)],
        )
        .getSingle();
    return row.data['c'] as int;
  }

  Future<void> pruneOutbox(int upToSeq) => _db.customStatement(
    'DELETE FROM sync_outbox WHERE seq <= ?',
    [upToSeq],
  );

  /// The next rows to send after [afterSeq], oldest change first, or null
  /// when nothing is waiting. A batch whose rows were all deleted since has
  /// no tables; the caller can treat it as acknowledged.
  Future<SyncBatch?> nextBatch(int afterSeq) async {
    final entries = await _db
        .customSelect(
          'SELECT seq, synced_table, row_key FROM sync_outbox '
          'WHERE seq > ? ORDER BY seq LIMIT ?',
          variables: [
            Variable.withInt(afterSeq),
            Variable.withInt(maxBatchRows * 4),
          ],
        )
        .get();
    if (entries.isEmpty) return null;

    final tables = <String, List<Map<String, dynamic>>>{};
    final seen = <String>{};
    var bytes = 0;
    var rows = 0;
    var upTo = afterSeq;

    for (final entry in entries) {
      final seq = entry.data['seq'] as int;
      final table = entry.data['synced_table'] as String;
      final key = entry.data['row_key'] as String;
      if (!syncedTables.contains(table)) {
        upTo = seq;
        continue;
      }
      if (!seen.add('$table/$key')) {
        upTo = seq;
        continue;
      }
      final row = await _fetchRow(table, key);
      if (row != null) {
        final size = _approximateSize(row);
        // Always send at least one row, however large.
        if (rows > 0 &&
            (rows >= maxBatchRows || bytes + size > maxBatchBytes)) {
          break;
        }
        (tables[table] ??= []).add(row);
        bytes += size;
        rows++;
      }
      upTo = seq;
    }

    final more = await _db
        .customSelect(
          'SELECT EXISTS(SELECT 1 FROM sync_outbox WHERE seq > ?) AS more',
          variables: [Variable.withInt(upTo)],
        )
        .getSingle();
    return SyncBatch(
      id: upTo,
      deviceId: await getLocalDeviceId(),
      tables: tables,
      more: more.data['more'] == 1,
    );
  }

  Future<Map<String, dynamic>?> _fetchRow(String table, String key) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM $table WHERE ${keyColumn(table)} = ?',
          variables: [Variable.withString(key)],
        )
        .get();
    return rows.isEmpty ? null : rows.first.data;
  }

  static int _approximateSize(Map<String, dynamic> row) => row.values.fold(
    64,
    (sum, value) => sum + (value is String ? value.length : 8),
  );

  /// Queues every local row of [table] that the peer lacks or holds an older
  /// copy of, given the peer's key → `updated_at` [manifest]. Returns how
  /// many were queued.
  Future<int> queueRowsNewerThan(
    String table,
    Map<String, int> manifest,
  ) async {
    if (!syncedTables.contains(table)) return 0;
    final local = await this.manifest(table);
    final keys = [
      for (final MapEntry(:key, :value) in local.entries)
        if ((manifest[key] ?? -1) < value) key,
    ];
    await _db.transaction(() async {
      for (final key in keys) {
        await _db.customStatement(
          'INSERT INTO sync_outbox (synced_table, row_key) VALUES (?, ?)',
          [table, key],
        );
      }
    });
    return keys.length;
  }

  // ---------------------------------------------------------------------------
  // Reconciliation

  /// Every row's key with its `updated_at`, tombstones included.
  Future<Map<String, int>> manifest(String table) async {
    if (!syncedTables.contains(table)) return {};
    final key = keyColumn(table);
    final rows = await _db
        .customSelect('SELECT $key AS k, updated_at AS u FROM $table')
        .get();
    return {
      for (final row in rows)
        if (row.data['k'] != null)
          '${row.data['k']}': (row.data['u'] as int?) ?? 0,
    };
  }

  Future<Map<String, TableDigest>> computeDigest() async {
    final digests = <String, TableDigest>{};
    for (final table in syncedTables) {
      final entries = (await manifest(table)).entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final text = entries.map((e) => '${e.key}|${e.value}').join('\n');
      digests[table] = TableDigest(
        count: entries.length,
        hash: sha256.convert(utf8.encode(text)).toString(),
      );
    }
    return digests;
  }

  // ---------------------------------------------------------------------------
  // Applying

  /// Applies [batch] in one transaction and returns the rows written. The
  /// writes are the peer's, so they don't go back into the outbox and keep
  /// the peer's `updated_at`.
  Future<AppliedBatch> applyBatch(SyncBatch batch) async {
    final unknown = batch.tables.keys.where((t) => !syncedTables.contains(t));
    if (unknown.isNotEmpty) {
      logger.w(
        '[LwwSync] ignored rows of unknown tables: ${unknown.join(', ')}',
      );
    }
    final localDeviceId = await getLocalDeviceId();
    final rows = [
      for (final table in syncedTables)
        for (final row in batch.tables[table] ?? const <Map<String, dynamic>>[])
          (table: table, row: row),
    ];

    Future<String?> apply(({String table, Map<String, dynamic> row}) item) =>
        _applyRow(
          item.table,
          item.row,
          incomingDeviceId: batch.deviceId,
          localDeviceId: localDeviceId,
        );

    final applied = <String, List<String>>{};
    final documents = <String>[];
    void record(({String table, Map<String, dynamic> row}) item, String key) {
      (applied[item.table] ??= []).add(key);
      if (item.table == 'fhir_resource' &&
          item.row['resource_type'] == 'DocumentReference') {
        documents.add(key);
      }
    }

    try {
      await _withoutOutbox(() async {
        for (final item in rows) {
          final key = await apply(item);
          if (key != null) record(item, key);
        }
        if (documents.isNotEmpty) await _repairAttachmentUrls(documents);
      });
    } catch (e) {
      // One bad row (a constraint, a type it can't store) shouldn't hold
      // back the others: apply them one by one and skip what fails. A row
      // skipped here still differs at the next reconciliation.
      logger.w(
        '[LwwSync] batch ${batch.id} failed whole; applying row by row',
        e,
      );
      applied.clear();
      documents.clear();
      for (final item in rows) {
        try {
          final key = await _withoutOutbox(() => apply(item));
          if (key != null) record(item, key);
        } catch (e) {
          logger.w('[LwwSync] skipped a ${item.table} row', e);
        }
      }
      if (documents.isNotEmpty) await fixBrokenAttachmentUrls(documents);
    }
    return AppliedBatch(applied);
  }

  /// Runs [action] in a transaction and removes the outbox entries its writes
  /// logged: they are the peer's rows or device-local repairs, not edits.
  Future<T> _withoutOutbox<T>(Future<T> Function() action) =>
      _db.transaction(() async {
        final before = await currentOutboxSeq();
        final result = await action();
        await _db.customStatement('DELETE FROM sync_outbox WHERE seq > ?', [
          before,
        ]);
        return result;
      });

  /// Writes one incoming row if it wins, returning its key; null when it
  /// lost, matched the local row or couldn't be read.
  Future<String?> _applyRow(
    String table,
    Map<String, dynamic> incoming, {
    required String incomingDeviceId,
    required String localDeviceId,
  }) async {
    final columns = await _columnsOf(table);
    var row = <String, Object?>{
      for (final MapEntry(:key, :value) in incoming.entries)
        if (columns.contains(key)) key: _sqlValue(value),
    };
    final dropped = incoming.keys.where((k) => !columns.contains(k)).toList();
    if (dropped.isNotEmpty) {
      logger.w(
        '[LwwSync] $table: dropped unknown columns ${dropped.join(', ')}',
      );
    }

    if (table == 'record_notes' && row['uuid'] == null) {
      // From an app version before notes had a key of their own.
      row = {...row, 'uuid': 'legacy-${row['id']}'};
    }
    final keyCol = keyColumn(table);
    final key = row[keyCol]?.toString();
    if (key == null || key.isEmpty) return null;

    final incomingUpdatedAt = _parseTimestamp(row['updated_at']);
    if (incomingUpdatedAt == null) return null;
    row['updated_at'] = incomingUpdatedAt;

    final local = await _fetchRow(table, key);
    if (local != null) {
      final localUpdatedAt = _parseTimestamp(local['updated_at']);
      final sameContent = _sameContent(table, row, local);
      if (sameContent) {
        // Nothing to write; agree on the later stamp so both sides' digests
        // match.
        if (localUpdatedAt == null || incomingUpdatedAt > localUpdatedAt) {
          await _setUpdatedAt(table, key, incomingUpdatedAt);
        }
        return null;
      }
      if (localUpdatedAt != null) {
        if (incomingUpdatedAt < localUpdatedAt) {
          // A missing file only overrides LWW between two live rows; a
          // tombstone on either side is decided by updated_at alone.
          final bothLive =
              row['deleted_at'] == null && local['deleted_at'] == null;
          if (!(table == 'fhir_resource' &&
              bothLive &&
              await _localHasBrokenAttachment(local))) {
            return null;
          }
        } else if (incomingUpdatedAt == localUpdatedAt &&
            incomingDeviceId.compareTo(localDeviceId) <= 0) {
          // A tie goes to the larger device id, the same answer on both
          // devices.
          return null;
        }
      }
      if (table == 'fhir_resource') {
        row = await _keepLocalAttachmentUrls(row, local);
      }
    }

    await _upsert(table, row);
    // The update trigger stamps a write that leaves updated_at unchanged;
    // put the peer's stamp back.
    await _setUpdatedAt(table, key, incomingUpdatedAt);
    return key;
  }

  bool _sameContent(
    String table,
    Map<String, Object?> incoming,
    Map<String, dynamic> local,
  ) {
    for (final MapEntry(:key, :value) in incoming.entries) {
      if (key == 'updated_at') continue;
      // A note's integer id is per device.
      if (table == 'record_notes' && key == 'id') continue;
      if (local[key] != value) return false;
    }
    return true;
  }

  Future<void> _setUpdatedAt(
    String table,
    String key,
    int updatedAt,
  ) => _db.customStatement(
    'UPDATE $table SET updated_at = ? '
    'WHERE ${keyColumn(table)} = ? AND (updated_at IS NULL OR updated_at != ?)',
    [updatedAt, key, updatedAt],
  );

  Future<void> _upsert(String table, Map<String, Object?> row) async {
    final keyCol = keyColumn(table);
    // A note's id counts per device: a new note keeps the other device's id
    // only while no local note has it, and an existing note keeps its own.
    final isNote = table == 'record_notes';
    final columns = [
      for (final c in row.keys)
        if (!(isNote && c == 'id' && await _noteIdTaken(row['id']))) c,
    ];
    final updates = columns
        .where((c) => c != keyCol && !(isNote && c == 'id'))
        .map((c) => '"$c" = excluded."$c"')
        .join(', ');
    final sql =
        'INSERT INTO $table (${columns.map((c) => '"$c"').join(', ')}) '
        'VALUES (${columns.map((_) => '?').join(', ')}) '
        'ON CONFLICT("$keyCol") DO '
        '${updates.isEmpty ? 'NOTHING' : 'UPDATE SET $updates'}';
    await _db.customStatement(sql, [for (final c in columns) row[c]]);
  }

  Future<Set<String>> _columnsOf(String table) async {
    final cached = _columns[table];
    if (cached != null) return cached;
    final rows = await _db
        .customSelect("SELECT name FROM pragma_table_info('$table')")
        .get();
    return _columns[table] = {for (final r in rows) r.data['name'] as String};
  }

  Future<bool> _noteIdTaken(Object? id) async {
    if (id == null) return false;
    final rows = await _db
        .customSelect(
          'SELECT 1 FROM record_notes WHERE id = ?',
          variables: [Variable(id)],
        )
        .get();
    return rows.isNotEmpty;
  }

  static Object? _sqlValue(Object? value) {
    if (value == null || value is int || value is double || value is String) {
      return value;
    }
    if (value is bool) return value ? 1 : 0;
    return value.toString();
  }

  static int? _parseTimestamp(Object? value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ??
          DateTime.tryParse(value)?.millisecondsSinceEpoch;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Attachments

  static List<Map<String, dynamic>> _attachments(Object? raw) {
    if (raw is! String) return const [];
    try {
      final json = jsonDecode(raw);
      final content = json is Map<String, dynamic> ? json['content'] : null;
      if (content is! List) return const [];
      return [
        for (final item in content)
          if (item is Map<String, dynamic> &&
              item['attachment'] is Map<String, dynamic>)
            item['attachment'] as Map<String, dynamic>,
      ];
    } catch (e) {
      logger.w('[LwwSync] unreadable DocumentReference', e);
      return const [];
    }
  }

  /// The decoded path of a `file://` attachment url.
  static String? _filePath(Map<String, dynamic> attachment) {
    final url = attachment['url'];
    if (url is! String || !url.startsWith('file://')) return null;
    try {
      return Uri.decodeComponent(url.substring(7));
    } catch (_) {
      // Not percent-encoded, e.g. a literal '%' in a file name.
      return url.substring(7);
    }
  }

  Future<bool> _fileExists(String path) async =>
      await _attachmentSync.resolveFile(path) != null;

  Future<bool> _localHasBrokenAttachment(Map<String, dynamic> local) async {
    if (local['resource_type'] != 'DocumentReference') return false;
    for (final attachment in _attachments(local['resource_raw'])) {
      final path = _filePath(attachment);
      if (path != null && !await _fileExists(path)) return true;
    }
    return false;
  }

  /// Files live under device-local names. When an incoming DocumentReference
  /// replaces the local copy, an attachment the incoming url doesn't find
  /// here keeps the local url of the same attachment (same position and
  /// title), so the record doesn't lose a file this device already has.
  /// When the incoming attachment states its `size`, the local file must
  /// have it: another size is another file (a backup restore brings back an
  /// older file under a new name, for one), which this device then requests.
  Future<Map<String, Object?>> _keepLocalAttachmentUrls(
    Map<String, Object?> incoming,
    Map<String, dynamic> local,
  ) async {
    if (incoming['resource_type'] != 'DocumentReference') return incoming;
    final raw = incoming['resource_raw'];
    if (raw is! String) return incoming;
    final localAttachments = _attachments(local['resource_raw']);
    if (localAttachments.isEmpty) return incoming;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final content = json['content'];
      if (content is! List) return incoming;
      var changed = false;
      for (var i = 0; i < content.length && i < localAttachments.length; i++) {
        final item = content[i];
        if (item is! Map<String, dynamic>) continue;
        final attachment = item['attachment'];
        if (attachment is! Map<String, dynamic>) continue;
        final path = _filePath(attachment);
        if (path == null || await _fileExists(path)) continue;
        final mine = localAttachments[i];
        final minePath = _filePath(mine);
        if (minePath == null || mine['title'] != attachment['title']) continue;
        final myFile = await _attachmentSync.resolveFile(minePath);
        if (myFile == null) continue;
        final size = int.tryParse('${attachment['size']}');
        if (size != null && await myFile.length() != size) continue;
        attachment['url'] = mine['url'];
        changed = true;
      }
      return changed
          ? {...incoming, 'resource_raw': jsonEncode(json)}
          : incoming;
    } catch (e) {
      logger.w('[LwwSync] incoming DocumentReference kept as sent', e);
      return incoming;
    }
  }

  /// Attachment paths of [documentIds] (or of every DocumentReference) whose
  /// file is not on this device.
  Future<List<String>> missingAttachmentPaths([
    Iterable<String>? documentIds,
  ]) async {
    final missing = <String>{};
    for (final row in await _documentRows(documentIds)) {
      for (final attachment in _attachments(row['resource_raw'])) {
        final path = _filePath(attachment);
        if (path != null && !await _fileExists(path)) missing.add(path);
      }
    }
    return missing.toList();
  }

  Future<List<Map<String, dynamic>>> _documentRows([
    Iterable<String>? ids,
  ]) async {
    final idList = ids?.toList();
    if (idList != null && idList.isEmpty) return const [];
    final rows = await _db
        .customSelect(
          'SELECT id, resource_raw, updated_at FROM fhir_resource '
          "WHERE resource_type = 'DocumentReference' AND deleted_at IS NULL"
          '${idList == null ? '' : ' AND id IN (${idList.map((_) => '?').join(', ')})'}',
          variables: [
            if (idList != null)
              for (final id in idList) Variable.withString(id),
          ],
        )
        .get();
    return [for (final r in rows) r.data];
  }

  /// The file behind [path] when a live DocumentReference refers to it and
  /// it is small enough to send. The path comes from the peer, so nothing
  /// else in Documents (the AI models, logs, the database) is ever served.
  Future<File?> fileForRequest(String path) async {
    var referenced = false;
    for (final row in await _documentRows()) {
      if (_attachments(row['resource_raw']).any((a) => _filePath(a) == path)) {
        referenced = true;
        break;
      }
    }
    if (!referenced) return null;
    final file = await _attachmentSync.resolveFile(path);
    if (file == null) return null;
    final length = await file.length();
    if (length > maxFileBytes) {
      logger.w('[LwwSync] not sending an attachment of $length bytes');
      return null;
    }
    return file;
  }

  /// Reads [file] in chunks for `sync.file_chunk`.
  Stream<FileChunk> readChunks(String path, File file) async* {
    final total = await file.length();
    final handle = await file.open();
    try {
      var offset = 0;
      do {
        final bytes = await handle.read(fileChunkBytes);
        yield FileChunk(path: path, offset: offset, total: total, bytes: bytes);
        offset += bytes.length;
        if (bytes.isEmpty) break;
      } while (offset < total);
    } finally {
      await handle.close();
    }
  }

  /// Appends [chunk] to the file being received. When it is the last one,
  /// the file is moved into Documents under a free name and the records that
  /// point at [FileChunk.path] are repointed to it. Returns the saved name
  /// once the file is complete.
  Future<String?> saveChunk(FileChunk chunk) async {
    final docs = await _attachmentSync.documentsPath();
    final partial = File(p.join(docs, '.sync-${_partName(chunk.path)}.part'));
    if (chunk.offset == 0 && await partial.exists()) await partial.delete();
    final current = await partial.exists() ? await partial.length() : 0;
    if (current != chunk.offset) {
      throw StateError(
        'file chunk at ${chunk.offset}, expected $current: ${chunk.path}',
      );
    }
    if (chunk.offset + chunk.bytes.length > maxFileBytes) {
      await partial.delete();
      throw StateError('received file over the size limit: ${chunk.path}');
    }
    await partial.writeAsBytes(chunk.bytes, mode: FileMode.append, flush: true);
    if (!chunk.isLast) return null;

    final name = await _freeFileName(docs, chunk.path);
    await partial.rename(p.join(docs, name));
    await _withoutOutbox(() => _repointAttachment(chunk.path, name));
    return name;
  }

  /// Removes a half-received file, e.g. after the link dropped.
  Future<void> discardPartial(String path) async {
    final docs = await _attachmentSync.documentsPath();
    final partial = File(p.join(docs, '.sync-${_partName(path)}.part'));
    if (await partial.exists()) await partial.delete();
  }

  /// Removes every half-received file, left by a link that dropped or an
  /// app that was closed mid-transfer.
  Future<void> discardAllPartials() async {
    final docs = Directory(await _attachmentSync.documentsPath());
    if (!await docs.exists()) return;
    await for (final entity in docs.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (entity is File &&
          name.startsWith('.sync-') &&
          name.endsWith('.part')) {
        await entity.delete();
      }
    }
  }

  static String _partName(String path) =>
      sha256.convert(utf8.encode(path)).toString().substring(0, 16);

  /// A file name for [requestedPath] in [docsPath] that never replaces an
  /// existing file or the database: the sanitised base name, with a unique
  /// suffix when it is taken, reserved or empty.
  Future<String> _freeFileName(String docsPath, String requestedPath) async {
    final base = requestedPath
        .split(RegExp(r'[/\\]'))
        .last
        .replaceAll(RegExp(r'[^\p{L}\p{N}_.\-]', unicode: true), '_');
    final valid = base.replaceAll('.', '').isNotEmpty && !base.startsWith('.');
    final reserved = base.toLowerCase().startsWith('db.sqlite');
    if (valid && !reserved && !await _exists(p.join(docsPath, base))) {
      return base;
    }

    final dot = base.lastIndexOf('.');
    final hasExt = valid && dot > 0;
    final stem = !valid
        ? 'file'
        : hasExt
        ? base.substring(0, dot)
        : base;
    final ext = hasExt ? base.substring(dot) : '';
    while (true) {
      final name = '${stem}_${const Uuid().v4().substring(0, 8)}$ext';
      if (!await _exists(p.join(docsPath, name))) return name;
    }
  }

  static Future<bool> _exists(String path) async =>
      await FileSystemEntity.type(path, followLinks: false) !=
      FileSystemEntityType.notFound;

  /// Points every missing attachment whose decoded path is [oldPath] at
  /// [newName]. The url is device-local, so the row keeps its `updated_at`.
  Future<void> _repointAttachment(String oldPath, String newName) async {
    for (final row in await _documentRows()) {
      final raw = row['resource_raw'];
      if (raw is! String) continue;
      final json = _decode(raw);
      if (json == null) continue;
      var changed = false;
      for (final attachment in _attachmentsOf(json)) {
        if (_filePath(attachment) != oldPath) continue;
        attachment['url'] = 'file://$newName';
        changed = true;
      }
      if (changed) {
        await _writeRawKeepingStamp(row, jsonEncode(json));
      }
    }
  }

  /// Repoints attachments of [documentIds] (or of every DocumentReference)
  /// whose path doesn't exist to a file of the same name in Documents, as
  /// left by an older app version or another device's folder layout. Only an
  /// exact name counts: a partial match could be another patient's file.
  Future<int> fixBrokenAttachmentUrls([Iterable<String>? documentIds]) =>
      _withoutOutbox(() => _repairAttachmentUrls(documentIds));

  Future<int> _repairAttachmentUrls(Iterable<String>? documentIds) async {
    final docs = await _attachmentSync.documentsPath();
    var fixed = 0;
    for (final row in await _documentRows(documentIds)) {
      final raw = row['resource_raw'];
      if (raw is! String) continue;
      final json = _decode(raw);
      if (json == null) continue;
      var changed = false;
      for (final attachment in _attachmentsOf(json)) {
        final path = _filePath(attachment);
        if (path == null) continue;
        final name = path.split(RegExp(r'[/\\]')).last;
        if (name.isEmpty || name == path) continue;
        final literal = p.isAbsolute(path) ? path : p.join(docs, path);
        if (await File(literal).exists()) continue;
        if (await _attachmentSync.resolveFile(name) == null) continue;
        attachment['url'] = 'file://$name';
        changed = true;
      }
      if (changed) {
        await _writeRawKeepingStamp(row, jsonEncode(json));
        fixed++;
      }
    }
    if (fixed > 0) logger.i('[LwwSync] repointed $fixed attachments');
    return fixed;
  }

  static Map<String, dynamic>? _decode(String raw) {
    try {
      final json = jsonDecode(raw);
      return json is Map<String, dynamic> ? json : null;
    } catch (e) {
      logger.w('[LwwSync] unreadable DocumentReference', e);
      return null;
    }
  }

  static Iterable<Map<String, dynamic>> _attachmentsOf(
    Map<String, dynamic> json,
  ) sync* {
    final content = json['content'];
    if (content is! List) return;
    for (final item in content) {
      if (item is Map<String, dynamic> &&
          item['attachment'] is Map<String, dynamic>) {
        yield item['attachment'] as Map<String, dynamic>;
      }
    }
  }

  Future<void> _writeRawKeepingStamp(
    Map<String, dynamic> row,
    String raw,
  ) async {
    await _db.customStatement(
      'UPDATE fhir_resource SET resource_raw = ? WHERE id = ?',
      [raw, row['id']],
    );
    final stamp = row['updated_at'];
    if (stamp is int) {
      await _setUpdatedAt('fhir_resource', '${row['id']}', stamp);
    }
  }

  // ---------------------------------------------------------------------------
  // Housekeeping

  /// Purges tombstones older than 30 days, then deletes the attachment files
  /// of the purged records that no remaining row (live or deleted, or scan
  /// session) refers to, and starts the start-up sweep of older unreferenced
  /// files in the background. Returns how many rows were purged.
  Future<int> cleanupTombstones() async {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: _tombstoneRetentionDays))
        .millisecondsSinceEpoch;

    var totalDeleted = 0;
    final candidateUrls = <String>{};

    // Notes point at their source (a foreign key the app enforces), so they
    // go first, and a source stays while a newer note still points at it.
    const purges = {
      'record_notes': '',
      'fhir_resource': '',
      'sources':
          ' AND id NOT IN '
          '(SELECT source_id FROM record_notes WHERE source_id IS NOT NULL)',
    };
    assert(
      purges.keys.toSet().containsAll(syncedTables),
      'every synced table is purged',
    );

    // The urls are read in the same transaction as the purge, so they are
    // exactly the files of the rows it removes.
    await _db.transaction(() async {
      for (final MapEntry(key: table, value: guard) in purges.entries) {
        final where = 'deleted_at IS NOT NULL AND deleted_at < ?$guard';
        if (table == 'fhir_resource') {
          final rows = await _db
              .customSelect(
                'SELECT resource_raw FROM fhir_resource WHERE $where',
                variables: [Variable(cutoff)],
              )
              .get();
          for (final row in rows) {
            final raw = row.data['resource_raw'];
            if (raw is String) {
              candidateUrls.addAll(await _fileCleaner.fileUrlsOf(raw));
            }
          }
        }
        final result = await _db
            .customSelect(
              'SELECT COUNT(*) as count FROM $table WHERE $where',
              variables: [Variable(cutoff)],
            )
            .getSingle();
        final count = result.data['count'] as int? ?? 0;
        if (count > 0) {
          await _db.customStatement('DELETE FROM $table WHERE $where', [
            cutoff,
          ]);
          totalDeleted += count;
        }
      }
    });
    if (totalDeleted > 0) logger.i('[LwwSync] purged $totalDeleted tombstones');

    // Each file is checked against the remaining rows in its own
    // transaction, so a row brought back meanwhile keeps its file.
    if (candidateUrls.isNotEmpty) {
      await _fileCleaner.deleteUnreferenced(candidateUrls);
    }
    unawaited(_fileCleaner.sweep());
    return totalDeleted;
  }

  /// Stamps rows that predate the sync columns. Not an edit: reconciliation
  /// compares them like any other row.
  Future<int> backfillExistingRows() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var totalUpdated = 0;
    await _withoutOutbox(() async {
      for (final table in syncedTables) {
        final result = await _db
            .customSelect(
              'SELECT COUNT(*) as count FROM $table WHERE updated_at IS NULL',
            )
            .getSingle();
        final count = result.data['count'] as int? ?? 0;
        if (count == 0) continue;
        await _db.customStatement(
          'UPDATE $table SET updated_at = ? WHERE updated_at IS NULL',
          [now],
        );
        totalUpdated += count;
      }
    });
    return totalUpdated;
  }
}
