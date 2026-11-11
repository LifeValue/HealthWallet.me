import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/data/local/app_database.dart'
    show AppDatabase;
import 'package:health_wallet/core/services/attachment_file_cleaner.dart';
import 'package:health_wallet/core/services/attachment_references.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/attachment_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/lww_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/domain/entity/sync_batch.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../lww_sync/lww_sync_test_helpers.dart';
import 'data/services/backup_test_support.dart';

/// One device: its database, documents folder and LWW service.
class _Device {
  _Device(this.db, this.docs, this.sync);

  final AppDatabase db;
  final Directory docs;
  final LwwSyncService sync;

  /// The outbox position the other device acknowledged.
  int acked = 0;

  File file(String name) => File(p.join(docs.path, name));

  Future<List<Map<String, dynamic>>> attachmentsOf(String id) async {
    final raw = (await fetchRow(db, 'fhir_resource', id))!['resource_raw'];
    return [
      for (final item in (jsonDecode(raw as String)['content'] as List))
        (item as Map<String, dynamic>)['attachment'] as Map<String, dynamic>,
    ];
  }

  Future<String> urlOf(String id) async =>
      (await attachmentsOf(id)).single['url'] as String;
}

void main() {
  late TestDirs dirs;
  late _Device phone;
  late _Device desktop;
  late BackupService backups;

  Future<_Device> device(String name) async {
    final db = openTestDatabase();
    final docs = Directory(p.join(dirs.root.path, name))..createSync();
    final paths = DocsPathResolver(docs.path);
    return _Device(
      db,
      docs,
      LwwSyncService(
        db,
        await SharedPreferences.getInstance(),
        AttachmentSyncService(paths),
        AttachmentFileCleaner(
          db,
          paths,
          AttachmentReferences(db),
          LegacyAttachmentFolders(paths),
        ),
      ),
    );
  }

  setUp(() async {
    dirs = await TestDirs.create();
    final backupDir = Directory(p.join(dirs.root.path, 'backups'))
      ..createSync();
    SharedPreferences.setMockInitialValues({
      'lww_local_device_id': 'device-local',
      SharedPrefsConstants.backupDirectory: backupDir.path,
    });
    phone = await device('phone');
    desktop = await device('desktop');
    final paths = DocsPathResolver(desktop.docs.path);
    backups = BackupService(
      desktop.db,
      FakeFolderAccess(),
      paths,
      AttachmentReferences(desktop.db),
      AttachmentSyncService(paths),
      LegacyAttachmentFolders(paths),
    );
  });

  tearDown(() async {
    await phone.db.close();
    await desktop.db.close();
    await dirs.dispose();
  });

  /// Sends what [from] has waiting in its outbox to [to] through the JSON
  /// wire format, one acknowledged batch at a time, as `sync.batch` does.
  Future<void> send(_Device from, _Device to) async {
    while (true) {
      final batch = await from.sync.nextBatch(from.acked);
      if (batch == null) break;
      final wire = jsonDecode(jsonEncode(batch.toJson()));
      await to.sync.applyBatch(
        SyncBatch.fromJson(wire as Map<String, dynamic>),
      );
      from.acked = batch.id;
    }
  }

  /// [from] serves [path] to [to] in chunks, as `sync.file_request` does.
  Future<void> transfer(_Device from, _Device to, String path) async {
    final file = await from.sync.fileForRequest(path);
    expect(file, isNotNull, reason: '$path is served');
    await for (final chunk in from.sync.readChunks(path, file!)) {
      await to.sync.saveChunk(chunk);
    }
  }

  /// A scan's DocumentReference, as `DocumentReferenceService` writes it:
  /// the file's url, the document's title and the file's size.
  Future<void> writeDocument(
    _Device device,
    String id,
    String url, {
    required String title,
    required String content,
    required int updatedAt,
  }) => device.db.customStatement(
    'INSERT OR REPLACE INTO fhir_resource '
    '(id, resource_type, resource_raw, updated_at) VALUES (?, ?, ?, ?)',
    [
      id,
      'DocumentReference',
      jsonEncode({
        'resourceType': 'DocumentReference',
        'id': id,
        'content': [
          {
            'attachment': {
              'contentType': 'application/pdf',
              'url': url,
              'title': title,
              'size': '${utf8.encode(content).length}',
            },
          },
        ],
      }),
      updatedAt,
    ],
  );

  test('the phone fetches the file a restore put under a new name, rather '
      'than keep its newer one', () async {
    // Backed up: the scan d1 as first saved.
    for (final d in [phone, desktop]) {
      d.file('scan.pdf').writeAsStringSync('first save');
      await writeDocument(
        d,
        'd1',
        'file://scan.pdf',
        title: 'Lab report',
        content: 'first save',
        updatedAt: ms(at(0)),
      );
    }
    final backup = await backups.createSnapshot();

    // Since then, on both devices: d1 was saved again from its scan session
    // (same id and title, a new file), its first file was swept away, and a
    // new scan d2 took the free name `scan.pdf`.
    for (final d in [phone, desktop]) {
      d.file('scan_2.pdf').writeAsStringSync('saved again, newer');
      await writeDocument(
        d,
        'd1',
        'file://scan_2.pdf',
        title: 'Lab report',
        content: 'saved again, newer',
        updatedAt: ms(at(10)),
      );
      d.file('scan.pdf').writeAsStringSync('another scan');
      await writeDocument(
        d,
        'd2',
        'file://scan.pdf',
        title: 'X-ray',
        content: 'another scan',
        updatedAt: ms(at(20)),
      );
    }
    await send(desktop, phone);

    await backups.restoreFromFile(backup.filePath);
    final restoredUrl = await desktop.urlOf('d1');
    expect(restoredUrl, matches(RegExp(r'^file://scan_[0-9a-f]{8}\.pdf$')));
    await send(desktop, phone);

    final restoredPath = restoredUrl.substring('file://'.length);
    expect(await phone.urlOf('d1'), restoredUrl);
    expect(await phone.sync.missingAttachmentPaths(['d1']), [restoredPath]);
    await transfer(desktop, phone, restoredPath);
    final shown = await AttachmentSyncService(
      DocsPathResolver(phone.docs.path),
    ).resolveFile(AttachmentRef(await phone.urlOf('d1')).path);
    expect(shown!.readAsStringSync(), 'first save');
  });

  test('a received DocumentReference still keeps the local file of the same '
      'attachment when it is the same file under another name', () async {
    phone.file('scan.pdf').writeAsStringSync('the scan');
    await writeDocument(
      phone,
      'd1',
      'file://scan.pdf',
      title: 'Lab report',
      content: 'the scan',
      updatedAt: ms(at(0)),
    );
    // The desktop holds it as `scan_1.pdf` and edits the record.
    desktop.file('scan_1.pdf').writeAsStringSync('the scan');
    await writeDocument(
      desktop,
      'd1',
      'file://scan_1.pdf',
      title: 'Lab report',
      content: 'the scan',
      updatedAt: ms(at(5)),
    );

    await send(desktop, phone);

    expect(await phone.urlOf('d1'), 'file://scan.pdf');
    expect(await phone.sync.missingAttachmentPaths(['d1']), isEmpty);
  });
}
