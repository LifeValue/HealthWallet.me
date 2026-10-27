import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/attachment_sync_service.dart';

import '../../lww_sync_test_helpers.dart';

void main() {
  late TestDirs dirs;
  late AttachmentSyncService service;

  final pdfBytes = utf8.encode('%PDF-1.7 fake report');

  Map<String, dynamic> docRow(
    List<Map<String, dynamic>> attachments, {
    String id = 'doc-1',
  }) => {
    'id': id,
    'resource_type': 'DocumentReference',
    'resource_raw': documentReferenceRaw(attachments),
    'updated_at': ms(t0),
  };

  List<Map<String, dynamic>> attachmentsOf(Map<String, dynamic> row) {
    final json = jsonDecode(row['resource_raw'] as String) as Map;
    return [
      for (final item in json['content'] as List)
        Map<String, dynamic>.from((item as Map)['attachment'] as Map),
    ];
  }

  setUp(() async {
    dirs = await TestDirs.create();
    service = AttachmentSyncService(FakePathResolver(dirs.docs.path));
  });

  tearDown(() => dirs.dispose());

  group('embedAttachments', () {
    test('inlines a local file as base64 and drops its url', () async {
      await dirs.writeDoc('scans/report 1.pdf', pdfBytes);
      final row = docRow([
        {
          'url': 'file://scans/report%201.pdf',
          'title': 'report 1.pdf',
          'contentType': 'application/pdf',
        },
      ]);

      final result = await service.embedAttachments([row]);

      final attachment = attachmentsOf(result.single).single;
      expect(attachment.containsKey('url'), isFalse);
      expect(base64Decode(attachment['data'] as String), pdfBytes);
      expect(attachment['title'], 'report 1.pdf');
      expect(result.single['id'], 'doc-1');
      expect(
        attachmentsOf(row).single['url'],
        'file://scans/report%201.pdf',
        reason: 'the input row must not be mutated',
      );
    });

    test('leaves a row untouched when its file cannot be found', () async {
      final row = docRow([
        {'url': 'file://missing.pdf'},
        {'url': 'https://example.org/remote.pdf'},
      ]);

      final result = await service.embedAttachments([row]);

      expect(result.single, row);
      expect(attachmentsOf(result.single).map((a) => a['url']), [
        'file://missing.pdf',
        'https://example.org/remote.pdf',
      ]);
    });

    test('passes rows of other resource types through as-is', () async {
      final observation = {
        'id': 'obs-1',
        'resource_type': 'Observation',
        'resource_raw': '{"content":[{"attachment":{"url":"file://x.pdf"}}]}',
      };

      final result = await service.embedAttachments([observation]);

      expect(identical(result.single, observation), isTrue);
    });

    test('tolerates malformed DocumentReference rows', () async {
      final rows = [
        {'id': 'a', 'resource_type': 'DocumentReference'},
        {
          'id': 'b',
          'resource_type': 'DocumentReference',
          'resource_raw': '{not json',
        },
        {
          'id': 'c',
          'resource_type': 'DocumentReference',
          'resource_raw': '{"resourceType":"DocumentReference"}',
        },
        {
          'id': 'd',
          'resource_type': 'DocumentReference',
          'resource_raw': '{"content":["text", {"noAttachment":true}]}',
        },
      ];

      final result = await service.embedAttachments(rows);

      expect(result, rows);
    });
  });

  group('restoreAttachments', () {
    test('writes inline data to a uniquely named file and points the url at '
        'it', () async {
      final row = docRow([
        {
          'data': base64Encode(pdfBytes),
          'title': 'Lab report (1).pdf',
          'contentType': 'application/pdf',
        },
      ]);

      final first = await service.restoreAttachments([row]);
      final second = await service.restoreAttachments([row]);

      final a1 = attachmentsOf(first.single).single;
      final a2 = attachmentsOf(second.single).single;
      expect(a1.containsKey('data'), isFalse);
      expect(
        a1['url'],
        matches(RegExp(r'^file://Lab_report__1__[0-9a-f]{8}\.pdf$')),
      );
      expect(a2['url'], isNot(a1['url']), reason: 'no overwrite on re-sync');
      final name = (a1['url'] as String).substring('file://'.length);
      expect(await dirs.docFile(name).readAsBytes(), pdfBytes);
      expect(dirs.docNames(), hasLength(2));
    });

    for (final (contentType, ext) in [
      ('application/pdf', '.pdf'),
      ('image/jpeg', '.jpg'),
      ('image/png', '.png'),
      ('image/gif', '.gif'),
      ('text/plain', '.bin'),
      (null, '.bin'),
    ]) {
      test('derives $ext from content type $contentType for a title without '
          'extension', () async {
        final row = docRow([
          {
            'data': base64Encode([1, 2, 3]),
            'title': 'scan',
            'contentType': ?contentType,
          },
        ]);

        final result = await service.restoreAttachments([row]);

        expect(
          attachmentsOf(result.single).single['url'],
          matches(RegExp('^file://scan_[0-9a-f]{8}\\$ext\$')),
        );
      });
    }

    test('names an untitled attachment <uuid>_<8 hex>.bin', () async {
      final row = docRow([
        {
          'data': base64Encode([9]),
          'contentType': 'image/png',
        },
      ]);

      final result = await service.restoreAttachments([row]);

      expect(
        attachmentsOf(result.single).single['url'],
        matches(RegExp(r'^file://[0-9a-f-]{36}_[0-9a-f]{8}\.bin$')),
      );
    });

    test(
      'leaves rows without inline data and other resource types alone',
      () async {
        final withUrl = docRow([
          {'url': 'file://already-local.pdf'},
        ]);
        final observation = {
          'id': 'obs-1',
          'resource_type': 'Observation',
          'resource_raw': '{}',
        };
        final broken = {
          'id': 'b',
          'resource_type': 'DocumentReference',
          'resource_raw': '[]',
        };
        final noContent = {
          'id': 'c',
          'resource_type': 'DocumentReference',
          'resource_raw': '{"content":[1]}',
        };
        final noRaw = {'id': 'd', 'resource_type': 'DocumentReference'};

        final result = await service.restoreAttachments([
          withUrl,
          observation,
          broken,
          noContent,
          noRaw,
        ]);

        expect(result, [withUrl, observation, broken, noContent, noRaw]);
        expect(identical(result[1], observation), isTrue);
        expect(dirs.docNames(), isEmpty);
      },
    );

    test(
      'drops the whole row update when the base64 data is invalid',
      () async {
        final row = docRow([
          {'data': '***not base64***', 'title': 'x.pdf'},
        ]);

        final result = await service.restoreAttachments([row]);

        expect(result.single, row);
        expect(dirs.docNames(), isEmpty);
      },
    );

    test('embed then restore moves file bytes between two devices', () async {
      await dirs.writeDoc('report.pdf', pdfBytes);
      final source = docRow([
        {
          'url': 'file://report.pdf',
          'title': 'report.pdf',
          'contentType': 'application/pdf',
        },
      ]);
      final otherDocs = Directory('${dirs.root.path}/peer/Documents')
        ..createSync(recursive: true);
      final peer = AttachmentSyncService(FakePathResolver(otherDocs.path));

      final wire = jsonDecode(
        jsonEncode(await service.embedAttachments([source])),
      ) as List;
      final restored = await peer.restoreAttachments([
        for (final r in wire) Map<String, dynamic>.from(r as Map),
      ]);

      final url = attachmentsOf(restored.single).single['url'] as String;
      final file = File('${otherDocs.path}/${url.substring(7)}');
      expect(await file.readAsBytes(), pdfBytes);
    });
  });

  group('resolveFile', () {
    test('resolves a relative path against the documents directory', () async {
      final file = await dirs.writeDoc('a/b.pdf', pdfBytes);

      expect((await service.resolveFile('a/b.pdf'))?.path, file.path);
    });

    test('returns an existing absolute path as-is', () async {
      final outside = File('${dirs.root.path}/elsewhere/x.pdf')
        ..createSync(recursive: true);

      expect((await service.resolveFile(outside.path))?.path, outside.path);
    });

    test('falls back to the file name in the documents directory', () async {
      final file = await dirs.writeDoc('x.pdf', pdfBytes);

      expect(
        (await service.resolveFile('/old/device/path/x.pdf'))?.path,
        file.path,
      );
      expect((await service.resolveFile('moved/x.pdf'))?.path, file.path);
    });

    test(
      'treats a Windows drive path as absolute and falls back by name',
      () async {
        final file = await dirs.writeDoc('w.pdf', pdfBytes);

        expect(
          (await service.resolveFile(r'C:\Users\me\w.pdf'))?.path,
          isNull,
          reason: 'backslash paths keep the whole string as the file name',
        );
        expect(
          (await service.resolveFile('C:/Users/me/w.pdf'))?.path,
          file.path,
        );
      },
    );

    test('falls back to the temporary directory', () async {
      final cached = File('${dirs.temp.path}/cached.jpg')..createSync();

      expect(
        (await service.resolveFile('/gone/cached.jpg'))?.path,
        cached.path,
      );
    });

    test(
      'remaps a path from an old iOS app container to the current one',
      () async {
        final moved = File('${dirs.container.path}/Library/Caches/scan.jpg')
          ..createSync(recursive: true);

        final resolved = await service.resolveFile(
          '/var/mobile/Containers/Data/Application/OLD-UUID/Library/Caches/'
          'scan.jpg',
        );

        expect(resolved?.path, moved.path);
      },
    );

    test('returns null when nothing matches', () async {
      expect(await service.resolveFile('nope.pdf'), isNull);
      expect(
        await service.resolveFile(
          '/var/mobile/Containers/Data/Application/U/Documents/sub/nope.pdf',
        ),
        isNull,
      );
    });
  });
}
