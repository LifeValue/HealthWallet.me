import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/attachment_file_cleaner.dart';
import 'package:health_wallet/core/services/attachment_references.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/attachment_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/lww_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/domain/entity/sync_batch.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lww_sync_test_helpers.dart';

/// A cleaner that acts as on a phone, whatever the test runs on, and keeps
/// the sweeps it started so a test can wait for them. While [hold] is set, a
/// sweep starts only once it completes.
class _RecordingCleaner extends AttachmentFileCleaner {
  _RecordingCleaner(AppDatabase db, String docs, DateTime Function() now)
    : super.forTesting(
        db,
        FakePathResolver(docs),
        AttachmentReferences(db),
        operatingSystem: 'android',
        now: now,
      );

  final sweeps = <Future<int>>[];
  Completer<void>? hold;

  @override
  Future<int> sweep() {
    final gate = hold;
    final sweep = gate == null
        ? super.sweep()
        : gate.future.then((_) => super.sweep());
    sweeps.add(sweep);
    return sweep;
  }
}

void main() {
  late TestDirs dirs;
  late AppDatabase db;
  late LwwSyncService service;
  late AttachmentSyncService attachments;
  late _RecordingCleaner cleaner;

  /// The cleaner's clock. By default two hours ahead: files written by a
  /// test are past the purge's one hour but not the sweep's seven days, so
  /// every deletion seen comes from the purge.
  late DateTime Function() now;

  final daysAgo40 = ms(DateTime.now().subtract(const Duration(days: 40)));
  final daysAgo10 = ms(DateTime.now().subtract(const Duration(days: 10)));

  String docRef(String url) => documentReferenceRaw([
    {'url': url, 'contentType': 'application/pdf'},
  ]);

  Future<void> insertDoc(String id, String url, {int? deletedAt}) => insertFhir(
    db,
    id: id,
    resourceType: 'DocumentReference',
    raw: docRef(url),
    updatedAt: deletedAt ?? daysAgo40,
    deletedAt: deletedAt,
  );

  /// Purges, then waits for the sweep it started.
  Future<int> purge() async {
    final purged = await service.cleanupTombstones();
    await Future.wait(cleaner.sweeps);
    return purged;
  }

  setUp(() async {
    dirs = await TestDirs.create();
    db = openTestDatabase();
    SharedPreferences.setMockInitialValues({
      'lww_local_device_id': 'device-local',
    });
    now = () => DateTime.now().add(const Duration(hours: 2));
    cleaner = _RecordingCleaner(db, dirs.docs.path, () => now());
    attachments = AttachmentSyncService(FakePathResolver(dirs.docs.path));
    service = LwwSyncService(
      db,
      await SharedPreferences.getInstance(),
      attachments,
      cleaner,
    );
  });

  tearDown(() async {
    await Future.wait(cleaner.sweeps);
    await db.close();
    await dirs.dispose();
  });

  test('a purged record\'s file is deleted with it', () async {
    await dirs.writeDoc('scan.pdf', utf8.encode('%PDF'));
    await insertDoc('doc', 'file://scan.pdf', deletedAt: daysAgo40);

    expect(await purge(), 1);

    expect(await fetchRow(db, 'fhir_resource', 'doc'), isNull);
    expect(dirs.docFile('scan.pdf').existsSync(), isFalse);
  });

  test('a file another record still uses is kept', () async {
    await dirs.writeDoc('shared.pdf', utf8.encode('%PDF'));
    await insertDoc('purged', 'file://shared.pdf', deletedAt: daysAgo40);
    await insertDoc('live', 'file://SHARED.pdf');

    expect(await purge(), 1);

    expect(dirs.docFile('shared.pdf').existsSync(), isTrue);
  });

  test('a file a recent tombstone uses is kept', () async {
    await dirs.writeDoc('shared.pdf', utf8.encode('%PDF'));
    await insertDoc('purged', 'file://shared.pdf', deletedAt: daysAgo40);
    await insertDoc('recent', 'file://shared.pdf', deletedAt: daysAgo10);

    expect(await purge(), 1);

    expect(dirs.docFile('shared.pdf').existsSync(), isTrue);
  });

  test('a tombstone younger than 30 days keeps its row and its file', () async {
    await dirs.writeDoc('scan.pdf', utf8.encode('%PDF'));
    await insertDoc('doc', 'file://scan.pdf', deletedAt: daysAgo10);

    expect(await purge(), 0);

    expect(await fetchRow(db, 'fhir_resource', 'doc'), isNotNull);
    expect(dirs.docFile('scan.pdf').existsSync(), isTrue);
  });

  test('a purged record pointing into a subfolder deletes nothing', () async {
    await dirs.writeDoc('ai_models/x.gguf', utf8.encode('model'));
    await dirs.writeDoc('x.gguf', utf8.encode('model'));
    await insertDoc('doc', 'file://ai_models/x.gguf', deletedAt: daysAgo40);

    expect(await purge(), 1);

    expect(dirs.docFile('ai_models/x.gguf').existsSync(), isTrue);
    expect(dirs.docFile('x.gguf').existsSync(), isTrue);
  });

  test('a received tombstone deletes nothing', () async {
    await dirs.writeDoc('scan.pdf', utf8.encode('%PDF'));
    await insertDoc('doc', 'file://scan.pdf');
    final deletedAt = ms(DateTime.now());

    await service.applyBatch(
      SyncBatch(
        id: 1,
        deviceId: 'device-m',
        tables: {
          'fhir_resource': [
            {
              'id': 'doc',
              'resource_type': 'DocumentReference',
              'resource_raw': docRef('file://scan.pdf'),
              'updated_at': deletedAt,
              'deleted_at': deletedAt,
            },
          ],
        },
      ),
    );
    expect(
      (await fetchRow(db, 'fhir_resource', 'doc'))!['deleted_at'],
      deletedAt,
    );
    expect(dirs.docFile('scan.pdf').existsSync(), isTrue);

    expect(await purge(), 0);
    expect(dirs.docFile('scan.pdf').existsSync(), isTrue);
  });

  group('a record deleted and brought back within 30 days opens its file', () {
    setUp(() async {
      await dirs.writeDoc('scan.pdf', utf8.encode('%PDF'));
      // An older copy of the record, purged now: its file is a candidate.
      await insertDoc('old', 'file://scan.pdf', deletedAt: daysAgo40);
      await insertDoc('doc', 'file://scan.pdf', deletedAt: daysAgo10);
      // Past both the purge's and the sweep's minimum age.
      now = () => DateTime.now().add(const Duration(days: 8));
      expect(await purge(), 1);
    });

    test('by a re-sync', () async {
      await service.applyBatch(
        SyncBatch(
          id: 1,
          deviceId: 'device-m',
          tables: {
            'fhir_resource': [
              {
                'id': 'doc',
                'resource_type': 'DocumentReference',
                'resource_raw': docRef('file://scan.pdf'),
                'updated_at': ms(DateTime.now()),
                'deleted_at': null,
              },
            ],
          },
        ),
      );

      expect((await fetchRow(db, 'fhir_resource', 'doc'))!['deleted_at'], null);
      expect(await attachments.resolveFile('scan.pdf'), isNotNull);
    });

    test('by a restore', () async {
      await db.customStatement(
        "UPDATE fhir_resource SET deleted_at = NULL WHERE id = 'doc'",
      );

      expect(await attachments.resolveFile('scan.pdf'), isNotNull);
    });
  });

  test('a file only a scan session still uses is kept', () async {
    await dirs.writeDoc('scan.pdf', utf8.encode('%PDF'));
    await insertDoc('doc', 'file://scan.pdf', deletedAt: daysAgo40);
    await db.customStatement(
      'INSERT INTO processing_sessions (id, status, resources) '
      'VALUES (?, ?, ?)',
      [
        'session',
        'pending',
        jsonEncode([jsonDecode(docRef('file://Scan.pdf'))]),
      ],
    );

    expect(await purge(), 1);

    expect(dirs.docFile('scan.pdf').existsSync(), isTrue);
  });

  group('a Media record whose content is a single attachment', () {
    String media(String url) => jsonEncode({
      'resourceType': 'Media',
      'content': {'url': url, 'contentType': 'image/jpeg'},
    });

    test('has its file deleted when it is purged', () async {
      await dirs.writeDoc('photo.jpg', utf8.encode('jpeg'));
      await insertFhir(
        db,
        id: 'media',
        resourceType: 'Media',
        raw: media('file://photo.jpg'),
        updatedAt: daysAgo40,
        deletedAt: daysAgo40,
      );

      expect(await purge(), 1);

      expect(dirs.docFile('photo.jpg').existsSync(), isFalse);
    });

    test('keeps the file of a purged record it also uses', () async {
      await dirs.writeDoc('photo.jpg', utf8.encode('jpeg'));
      await insertDoc('doc', 'file://photo.jpg', deletedAt: daysAgo40);
      await insertFhir(
        db,
        id: 'media',
        resourceType: 'Media',
        raw: media('file://photo.jpg'),
      );

      expect(await purge(), 1);

      expect(dirs.docFile('photo.jpg').existsSync(), isTrue);
    });
  });

  test('a purge starts the sweep without waiting for it', () async {
    await dirs.writeDoc('orphan.pdf', utf8.encode('%PDF'));
    await dirs.writeDoc('used.pdf', utf8.encode('%PDF'));
    await insertDoc('live', 'file://used.pdf');
    now = () => DateTime.now().add(const Duration(days: 8));
    final hold = cleaner.hold = Completer<void>();

    await service.cleanupTombstones().timeout(const Duration(seconds: 5));

    expect(cleaner.sweeps, hasLength(1));
    expect(dirs.docFile('orphan.pdf').existsSync(), isTrue);

    hold.complete();
    expect(await cleaner.sweeps.single, 1);
    expect(dirs.docFile('orphan.pdf').existsSync(), isFalse);
    expect(dirs.docFile('.trash/orphan.pdf').existsSync(), isTrue);
    expect(dirs.docFile('used.pdf').existsSync(), isTrue);
  });
}
