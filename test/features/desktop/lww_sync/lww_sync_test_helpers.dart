import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart'
    as tcp;

/// Opens the real app database on an in-memory SQLite connection, so the
/// schema, the `updated_at` triggers and the constraints are the production
/// ones, foreign keys included (the app turns them on in `_openConnection`).
AppDatabase openTestDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    NativeDatabase.memory(
      setup: (database) => database.execute('PRAGMA foreign_keys = ON'),
    ),
  );
}

/// Fixed, millisecond-precise timestamps used across the LWW tests.
final t0 = DateTime.utc(2025, 1, 1, 12);
int ms(DateTime d) => d.millisecondsSinceEpoch;
DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

typedef SentMessage = ({String type, Map<String, dynamic> payload});

/// One end of an in-memory phone ↔ desktop link: what one side sends
/// arrives at the other as a `data` message, asynchronously and in order,
/// as JSON. [link] connects two ends, [unlink] drops the connection.
class LinkedTcpService extends Fake implements tcp.TcpService {
  LinkedTcpService(this.deviceId, this.name);

  final String deviceId;
  final String name;
  LinkedTcpService? _other;
  bool connected = false;

  /// While set, sent messages of these types are lost on the way.
  final dropTypes = <String>{};

  /// While set, sent messages of these types wait until [releaseHeld].
  final holdTypes = <String>{};
  final _held = <void Function()>[];

  /// Sent messages not yet delivered (held ones included).
  int get inFlight => _inFlight;
  int _inFlight = 0;

  /// How long a sent message takes to arrive, like a slow link or a busy
  /// device; by default it arrives on the next event-loop turn.
  Duration latency = Duration.zero;
  final sent = <SentMessage>[];

  final _messages = StreamController<tcp.TcpMessage>.broadcast();
  final _states = StreamController<tcp.ConnectionState>.broadcast();

  static void link(LinkedTcpService a, LinkedTcpService b) {
    a._other = b;
    b._other = a;
    a._setConnected(true);
    b._setConnected(true);
  }

  void unlink() {
    final other = _other;
    _setConnected(false);
    other?._setConnected(false);
  }

  void _setConnected(bool value) {
    connected = value;
    _states.add(
      value ? tcp.ConnectionState.connected : tcp.ConnectionState.disconnected,
    );
  }

  List<SentMessage> sentOfType(String type) =>
      sent.where((m) => m.type == type).toList();

  @override
  bool get isConnected => connected;

  @override
  tcp.ConnectionState get currentState => connected
      ? tcp.ConnectionState.connected
      : tcp.ConnectionState.disconnected;

  @override
  tcp.PeerInfo? get peer {
    final other = _other;
    return connected && other != null
        ? tcp.PeerInfo(deviceId: other.deviceId, name: other.name)
        : null;
  }

  @override
  Stream<tcp.TcpMessage> get messages => _messages.stream;

  @override
  Stream<tcp.ConnectionState> get connectionState => _states.stream;

  @override
  Future<void> sendData(String type, Map<String, dynamic> payload) async {
    if (!connected) throw const tcp.LinkNotConnectedException();
    final json = jsonEncode({'type': type, 'payload': payload});
    sent.add((type: type, payload: payload));
    if (dropTypes.contains(type)) return;
    final other = _other!;
    _inFlight++;
    void deliver() {
      // Delivered later, like bytes off a socket.
      Timer(latency, () {
        _inFlight--;
        if (other.connected && !other._messages.isClosed) {
          other._messages.add(
            tcp.TcpMessage.fromString(type: tcp.MessageType.data, data: json),
          );
        }
      });
    }

    if (holdTypes.contains(type)) {
      _held.add(deliver);
    } else {
      deliver();
    }
  }

  /// Delivers the messages held so far, in order, and stops holding.
  void releaseHeld() {
    holdTypes.clear();
    final held = [..._held];
    _held.clear();
    for (final deliver in held) {
      deliver();
    }
  }

  Future<void> close() async {
    await _messages.close();
    await _states.close();
  }
}

/// Waits until [condition] holds, checking again every few milliseconds.
///
/// It has no deadline of its own: only the test's timeout bounds it, so a
/// busy machine makes a test slower but never fails it. [reason] is printed
/// if the test then fails.
Future<void> eventually(
  FutureOr<bool> Function() condition, {
  String? reason,
}) async {
  if (reason != null) printOnFailure('waiting for $reason');
  while (!await condition()) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class FakePathResolver extends Fake implements PathResolver {
  FakePathResolver(this.documentsPath);

  final String documentsPath;

  @override
  Future<String> getDocumentsPath() async => documentsPath;
}

/// Temporary directories that stand in for the platform's documents, temp and
/// app-container directories, served through the path_provider channel.
class TestDirs {
  TestDirs._(this.root)
    : container = Directory('${root.path}/container'),
      docs = Directory('${root.path}/container/Documents'),
      temp = Directory('${root.path}/tmp');

  final Directory root;
  final Directory container;
  final Directory docs;
  final Directory temp;

  static const _channel = MethodChannel('plugins.flutter.io/path_provider');

  static Future<TestDirs> create() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final root = await Directory.systemTemp.createTemp('lww_sync_test_');
    final dirs = TestDirs._(root);
    await dirs.docs.create(recursive: true);
    await dirs.temp.create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          switch (call.method) {
            case 'getApplicationDocumentsDirectory':
              return dirs.docs.path;
            case 'getTemporaryDirectory':
              return dirs.temp.path;
          }
          return null;
        });
    return dirs;
  }

  Future<void> dispose() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    if (root.existsSync()) await root.delete(recursive: true);
  }

  File docFile(String name) => File('${docs.path}/$name');

  Future<File> writeDoc(String name, List<int> bytes) async {
    final file = docFile(name);
    await file.parent.create(recursive: true);
    return file.writeAsBytes(bytes);
  }

  List<String> docNames() =>
      docs
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toList()
        ..sort();
}

String documentReferenceRaw(List<Map<String, dynamic>> attachments) =>
    jsonEncode({
      'resourceType': 'DocumentReference',
      'content': [
        for (final a in attachments) {'attachment': a},
      ],
    });

Future<void> insertFhir(
  AppDatabase db, {
  required String id,
  int? updatedAt,
  String? deviceId,
  String resourceType = 'Observation',
  String? raw,
  int? deletedAt,
  String? title,
}) => db.customStatement(
  'INSERT INTO fhir_resource (id, resource_type, resource_raw, title, '
  'updated_at, device_id, deleted_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
  [
    id,
    resourceType,
    raw ?? jsonEncode({'resourceType': resourceType, 'id': id}),
    title,
    updatedAt,
    deviceId,
    deletedAt,
  ],
);

Future<void> insertSource(
  AppDatabase db, {
  required String id,
  int? updatedAt,
  String? label,
  int? deletedAt,
}) => db.customStatement(
  'INSERT INTO sources (id, label_source, updated_at, deleted_at) '
  'VALUES (?, ?, ?, ?)',
  [id, label, updatedAt, deletedAt],
);

Future<void> insertNote(
  AppDatabase db, {
  int? id,
  required String content,
  int? updatedAt,
  int? deletedAt,
  String resourceId = 'obs-1',
  String? sourceId,
}) => db.customStatement(
  'INSERT INTO record_notes (id, resource_id, source_id, content, timestamp, '
  'updated_at, deleted_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
  [id, resourceId, sourceId, content, ms(t0) ~/ 1000, updatedAt, deletedAt],
);

Future<void> insertProcessingSession(
  AppDatabase db, {
  required String id,
  int? updatedAt,
}) => db.customStatement(
  'INSERT INTO processing_sessions (id, status, updated_at) VALUES (?, ?, ?)',
  [id, 'pending', updatedAt],
);

/// Tells drift's listeners, the sync's change watcher among them, that the
/// synced tables were written, as the app's own writes do. The raw inserts
/// above don't: without it, an edit made after the sync started reaches it
/// only if the watcher's first run after starting hasn't happened yet.
void notifySyncedTablesWritten(AppDatabase db) => db.notifyUpdates({
  for (final table in ['fhir_resource', 'sources', 'record_notes'])
    TableUpdate(table, kind: UpdateKind.insert),
});

Future<Map<String, Object?>?> fetchRow(
  AppDatabase db,
  String table,
  Object id,
) async {
  final rows = await db
      .customSelect(
        'SELECT * FROM $table WHERE id = ?',
        variables: [
          if (id is int) Variable.withInt(id) else Variable.withString('$id'),
        ],
      )
      .get();
  return rows.isEmpty ? null : rows.single.data;
}

Future<int> countRows(AppDatabase db, String table) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS c FROM $table')
      .getSingle();
  return row.data['c'] as int;
}

/// Removes the `updated_at` triggers so a row can keep a NULL `updated_at`,
/// as rows written before schema v10 did.
Future<void> dropSyncTriggers(AppDatabase db) async {
  for (final table in [
    'fhir_resource',
    'sources',
    'record_notes',
    'processing_sessions',
  ]) {
    await db.customStatement(
      'DROP TRIGGER IF EXISTS ${table}_insert_updated_at',
    );
    await db.customStatement(
      'DROP TRIGGER IF EXISTS ${table}_update_updated_at',
    );
  }
}
