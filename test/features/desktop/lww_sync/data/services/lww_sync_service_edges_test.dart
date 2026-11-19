import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/attachment_file_cleaner.dart';
import 'package:health_wallet/core/services/attachment_references.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/attachment_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/lww_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/domain/entity/sync_batch.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/log_capture.dart';
import '../../lww_sync_test_helpers.dart';

/// An attachment over the size limit, without writing 200 MB to disk.
class _HugeFile extends Fake implements File {
  _HugeFile(this.path);

  @override
  final String path;

  @override
  Future<int> length() async => LwwSyncService.maxFileBytes + 1;
}

/// Finds every attachment as a file over the size limit.
class _HugeAttachments extends Fake implements AttachmentSyncService {
  _HugeAttachments(this.docs);

  final String docs;

  @override
  Future<String> documentsPath() async => docs;

  @override
  Future<File?> resolveFile(String storedPath) async => _HugeFile(storedPath);
}

/// A partially received file that already holds the most a file may have.
class _FullPartial extends Fake implements File {
  _FullPartial(this.path);

  @override
  final String path;
  bool deleted = false;

  @override
  Future<bool> exists() async => !deleted;

  @override
  Future<int> length() async => LwwSyncService.maxFileBytes;

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    deleted = true;
    return this;
  }
}

void main() {
  final logs = captureLogs();
  late TestDirs dirs;
  late AppDatabase db;
  late SharedPreferences prefs;
  late LwwSyncService service;

  LwwSyncService serviceWith(AttachmentSyncService attachments) =>
      LwwSyncService(
        db,
        prefs,
        attachments,
        AttachmentFileCleaner(
          db,
          FakePathResolver(dirs.docs.path),
          AttachmentReferences(db),
          LegacyAttachmentFolders(FakePathResolver(dirs.docs.path)),
        ),
      );

  Future<void> useService({Map<String, Object> prefsValues = const {}}) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    prefs = await SharedPreferences.getInstance();
    service = serviceWith(
      AttachmentSyncService(FakePathResolver(dirs.docs.path)),
    );
  }

  SyncBatch fhirBatch(List<Map<String, dynamic>> rows) => SyncBatch(
    id: 1,
    deviceId: 'device-m',
    tables: {'fhir_resource': rows},
  );

  Map<String, dynamic> fhirRow(
    String id, {
    required Object? updatedAt,
    Object? title = 'remote',
    String resourceType = 'Observation',
    String? raw,
  }) => {
    'id': id,
    'resource_type': resourceType,
    'resource_raw': raw ?? jsonEncode({'resourceType': resourceType}),
    'title': title,
    'updated_at': updatedAt,
    'deleted_at': null,
  };

  setUp(() async {
    dirs = await TestDirs.create();
    db = openTestDatabase();
    await useService(prefsValues: {'lww_local_device_id': 'device-local'});
  });

  tearDown(() async {
    await db.close();
    await dirs.dispose();
  });

  group('peer state', () {
    test('an unreadable saved state is logged and starts over', () async {
      await useService(prefsValues: {'lww_sync_state': 'not json'});

      expect(service.loadPeerState(), isNull);
      expect(logs, loggedWarning('unreadable sync state'));
    });

    test('the same peer under a new name keeps its position and saves the '
        'name', () async {
      await service.savePeerState(
        const SyncPeerState(peerId: 'desk', ackedSeq: 4, peerName: 'Old'),
      );

      final same = await service.peerStateFor('desk', peerName: 'Old');
      expect((same.ackedSeq, same.peerName), (4, 'Old'));

      final renamed = await service.peerStateFor('desk', peerName: 'New');
      expect((renamed.ackedSeq, renamed.peerName), (4, 'New'));
      expect(service.loadPeerState()?.peerName, 'New');

      final unnamed = await service.peerStateFor('desk');
      expect(unnamed.peerName, 'New');
    });

    test('a device without an id gets one, kept from then on', () async {
      await useService();

      final id = await service.getLocalDeviceId();

      expect(id, isNotEmpty);
      expect(prefs.getString('lww_local_device_id'), id);
      expect(await service.getLocalDeviceId(), id);
    });
  });

  group('applying rows', () {
    test('a note from an app version without note keys gets a legacy '
        'key', () async {
      final applied = await service.applyBatch(
        const SyncBatch(
          id: 1,
          deviceId: 'device-m',
          tables: {
            'record_notes': [
              {
                'id': 9,
                'resource_id': 'obs-1',
                'content': 'old note',
                'timestamp': 0,
                'updated_at': 1000,
              },
            ],
          },
        ),
      );

      expect(applied.rows['record_notes'], ['legacy-9']);
      final row = await fetchRow(db, 'record_notes', 9);
      expect(row?['uuid'], 'legacy-9');
      expect(row?['content'], 'old note');
    });

    test('timestamps sent as decimals, digit strings or dates are read; '
        'anything else skips the row', () async {
      final applied = await service.applyBatch(
        fhirBatch([
          fhirRow('double', updatedAt: 1735732800000.0),
          fhirRow('digits', updatedAt: '1735732800001'),
          fhirRow('date', updatedAt: '2025-01-01T12:00:00.002Z'),
          fhirRow('garbled', updatedAt: 'yesterday'),
          fhirRow('list', updatedAt: [1]),
        ]),
      );

      expect(applied.rows['fhir_resource'], ['double', 'digits', 'date']);
      expect(
        (await fetchRow(db, 'fhir_resource', 'double'))?['updated_at'],
        1735732800000,
      );
      expect(
        (await fetchRow(db, 'fhir_resource', 'digits'))?['updated_at'],
        1735732800001,
      );
      expect(
        (await fetchRow(db, 'fhir_resource', 'date'))?['updated_at'],
        1735732800002,
      );
      expect(await fetchRow(db, 'fhir_resource', 'garbled'), isNull);
    });

    test('values SQLite cannot store are stored as numbers or text', () async {
      await service.applyBatch(
        fhirBatch([
          fhirRow('yes', updatedAt: 1000, title: true),
          fhirRow('no', updatedAt: 1000, title: false),
          fhirRow('map', updatedAt: 1000, title: {'a': 1}),
        ]),
      );

      expect((await fetchRow(db, 'fhir_resource', 'yes'))?['title'], '1');
      expect((await fetchRow(db, 'fhir_resource', 'no'))?['title'], '0');
      expect((await fetchRow(db, 'fhir_resource', 'map'))?['title'], '{a: 1}');
    });

    test('an unreadable incoming DocumentReference replacing one with '
        'files is saved as sent', () async {
      await insertFhir(
        db,
        id: 'doc',
        resourceType: 'DocumentReference',
        updatedAt: ms(at(1)),
        raw: documentReferenceRaw([
          {'url': 'file://report.pdf', 'title': 'Report'},
        ]),
      );

      final applied = await service.applyBatch(
        fhirBatch([
          fhirRow(
            'doc',
            updatedAt: ms(at(2)),
            resourceType: 'DocumentReference',
            raw: '{not json',
          ),
        ]),
      );

      expect(applied.rows['fhir_resource'], ['doc']);
      expect(
        (await fetchRow(db, 'fhir_resource', 'doc'))?['resource_raw'],
        '{not json',
      );
      expect(logs, loggedWarning('incoming DocumentReference kept as sent'));
      // The repair that follows can't read it either, and leaves it.
      expect(logs, loggedWarning('unreadable DocumentReference'));
    });
  });

  group('attachments', () {
    test('a DocumentReference that cannot be read has no files to '
        'fetch', () async {
      await insertFhir(
        db,
        id: 'doc',
        resourceType: 'DocumentReference',
        raw: '{not json',
      );

      expect(await service.missingAttachmentPaths(), isEmpty);
      expect(logs, loggedWarning('unreadable DocumentReference'));
    });

    test('a file over the size limit is not sent', () async {
      await insertFhir(
        db,
        id: 'doc',
        resourceType: 'DocumentReference',
        raw: documentReferenceRaw([
          {'url': 'file://video.mov', 'title': 'Video'},
        ]),
      );
      final huge = serviceWith(_HugeAttachments(dirs.docs.path));

      expect(await huge.fileForRequest('video.mov'), isNull);
      expect(
        logs,
        loggedWarning(
          'not sending an attachment of ${LwwSyncService.maxFileBytes + 1}',
        ),
      );
    });

    test('a received file growing over the size limit is dropped', () async {
      final partials = <_FullPartial>[];

      final saving = IOOverrides.runZoned(
        () => service.saveChunk(
          FileChunk(
            path: 'video.mov',
            offset: LwwSyncService.maxFileBytes,
            total: LwwSyncService.maxFileBytes + 1,
            bytes: Uint8List(1),
          ),
        ),
        createFile: (path) {
          final partial = _FullPartial(path);
          partials.add(partial);
          return partial;
        },
      );

      await expectLater(
        saving,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('over the size limit'),
          ),
        ),
      );
      expect(partials.single.deleted, isTrue);
    });

    test('discardPartial removes a half-received file and is harmless '
        'without one', () async {
      final saved = await service.saveChunk(
        FileChunk(
          path: 'scans/a.pdf',
          offset: 0,
          total: 8,
          bytes: Uint8List.fromList([1, 2, 3, 4]),
        ),
      );
      expect(saved, isNull);
      List<String> partials() => [
        for (final f in dirs.docs.listSync())
          if (f.path.endsWith('.part')) f.path,
      ];
      expect(partials(), hasLength(1));

      await service.discardPartial('scans/a.pdf');
      expect(partials(), isEmpty);

      await service.discardPartial('scans/a.pdf');
      expect(partials(), isEmpty);
    });
  });
}
