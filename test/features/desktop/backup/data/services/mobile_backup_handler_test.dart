import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/backup/data/services/desktop_backup_receiver.dart';
import 'package:health_wallet/features/desktop/backup/data/services/mobile_backup_handler.dart';
import 'package:health_wallet/features/desktop/communication/data/services/message_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../desktop_test_fakes.dart';

const chunkSize = 64 * 1024;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory tempDir;
  late AppDatabase db;
  late FakeTcpService tcp;
  late MessageRouter router;
  late MobileBackupHandler handler;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mobile_backup_test');
    mockPathProvider(tempDir);
    db = AppDatabase(NativeDatabase.memory());
    // A large row so the snapshot spans several chunks.
    await db.customStatement(
      'INSERT INTO fhir_resource (id, resource_raw) VALUES (?, ?)',
      ['big', base64Encode(randomBytes(200 * 1024))],
    );
    for (var i = 0; i < 4; i++) {
      await db.customStatement(
        'INSERT INTO fhir_resource (id, resource_raw) VALUES (?, ?)',
        ['r$i', '{}'],
      );
    }
    tcp = FakeTcpService();
    router = MessageRouter(tcp);
    handler = MobileBackupHandler(router, tcp, db)..start();
  });

  tearDown(() async {
    handler.dispose();
    router.dispose();
    await tcp.close();
    await db.close();
    clearPathProviderMock();
    await tempDir.delete(recursive: true);
  });

  /// Completes when the handler has sent `backup.complete`.
  Future<void> completeSent() {
    final done = Completer<void>();
    tcp.onSend = (type, _) async {
      if (type == 'backup.complete' && !done.isCompleted) done.complete();
    };
    return done.future.timeout(const Duration(seconds: 20));
  }

  /// Completes once the handler is idle again after a failed send.
  Future<void> snapshotsGone() async {
    for (var i = 0; i < 200; i++) {
      if (tempDir.listSync().isEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('snapshot was not cleaned up');
  }

  test(
    'answers backup.request with meta, ordered chunks and complete',
    () async {
      final done = completeSent();
      tcp.deliver('backup.request', {});
      await done;

      expect(tcp.sent.first.type, 'backup.meta');
      expect(tcp.sent.last.type, 'backup.complete');
      expect(tcp.sent.last.payload, isEmpty);

      final meta = tcp.sent.first.payload;
      final chunks = tcp.sentOf('backup.chunk');
      expect(chunks.length, greaterThan(3));
      expect(
        chunks.map((c) => c['seq']),
        List.generate(chunks.length, (i) => i),
      );
      expect(chunks.map((c) => c['total']).toSet(), {chunks.length});

      final bytes = [
        for (final c in chunks) ...base64Decode(c['data'] as String),
      ];
      for (final c in chunks.take(chunks.length - 1)) {
        expect(base64Decode(c['data'] as String), hasLength(chunkSize));
      }
      expect(bytes, hasLength(meta['sizeBytes']));
      expect(meta['checksum'], crypto.sha256.convert(bytes).toString());
      expect(meta['recordCount'], 5);
      expect(DateTime.tryParse(meta['timestamp'] as String), isNotNull);

      // The bytes are a valid copy of the database.
      final copy = File('${tempDir.path}/copy.db')..writeAsBytesSync(bytes);
      final restored = AppDatabase(NativeDatabase(copy));
      final count = await restored
          .customSelect('SELECT COUNT(*) AS c FROM fhir_resource')
          .getSingle();
      await restored.close();
      copy.deleteSync();
      expect(count.data['c'], 5);
    },
  );

  test('deletes its snapshot after sending', () async {
    final done = completeSent();
    tcp.deliver('backup.request', {});
    await done;

    await snapshotsGone();
  });

  test('ignores a second request while one is being sent', () async {
    final done = completeSent();
    tcp
      ..deliver('backup.request', {})
      ..deliver('backup.request', {});
    await done;
    await flushEvents();

    expect(tcp.sentOf('backup.meta'), hasLength(1));
    expect(tcp.sentOf('backup.complete'), hasLength(1));
  });

  test('a send failure aborts without complete and cleans up', () async {
    final failed = Completer<void>();
    tcp.onSend = (type, _) async {
      if (type == 'backup.chunk') {
        failed.complete();
        throw const SocketException('link down');
      }
    };
    tcp.deliver('backup.request', {});

    await failed.future.timeout(const Duration(seconds: 20));
    await snapshotsGone();
    expect(tcp.sentOf('backup.chunk'), hasLength(1));
    expect(tcp.sentOf('backup.complete'), isEmpty);

    // Idle again: the next request is served.
    final done = completeSent();
    tcp.deliver('backup.request', {});
    await done;
  });

  test('after dispose, requests are ignored', () async {
    handler.dispose();
    tcp.deliver('backup.request', {});
    await flushEvents();

    expect(tcp.sent, isEmpty);
  });

  group('phone to desktop', () {
    late Directory backupDir;
    late AppDatabase desktopDb;
    late FakeTcpService desktopTcp;
    late MessageRouter desktopRouter;
    late DesktopBackupReceiver receiver;

    setUp(() async {
      backupDir = await Directory.systemTemp.createTemp('desktop_backups');
      SharedPreferences.setMockInitialValues({
        'backupDirectory': backupDir.path,
      });
      desktopDb = AppDatabase(NativeDatabase.memory());
      desktopTcp = FakeTcpService();
      desktopRouter = MessageRouter(desktopTcp);
      receiver = DesktopBackupReceiver(
        desktopRouter,
        desktopTcp,
        BackupService(desktopDb),
      )..start();
    });

    tearDown(() async {
      receiver.dispose();
      desktopRouter.dispose();
      await desktopTcp.close();
      await desktopDb.close();
      await backupDir.delete(recursive: true);
    });

    test('a slow link delivers an identical, listed backup', () async {
      // Each chunk is handed over only after the desktop wrote the previous.
      tcp.onSend = (type, payload) async {
        final written = type == 'backup.chunk'
            ? receiver.progress.first
            : Future<void>.value();
        desktopTcp.deliver(type, payload);
        await written;
      };
      final result = receiver.status.firstWhere(
        (s) =>
            s == BackupReceiveStatus.complete ||
            s == BackupReceiveStatus.failed,
      );
      desktopTcp.onSend = (type, payload) async => tcp.deliver(type, payload);

      await receiver.requestBackup();

      expect(
        await result.timeout(const Duration(seconds: 20)),
        BackupReceiveStatus.complete,
      );
      final listed = await BackupService(desktopDb).listBackups();
      final stored = File(listed.single.filePath).readAsBytesSync();
      expect(crypto.sha256.convert(stored).toString(), listed.single.checksum);
      expect(listed.single.recordCount, 5);
      expect(listed.single.sizeBytes, stored.length);
    });
  });
}
