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

    test(
      'passes a tombstoned DocumentReference through without its file',
      () async {
        await dirs.writeDoc('report.pdf', pdfBytes);
        final row = {
          ...docRow([
            {'url': 'file://report.pdf'},
          ]),
          'deleted_at': ms(t0),
        };

        final result = await service.embedAttachments([row]);

        expect(identical(result.single, row), isTrue);
      },
    );
  });

  group('restoreAttachments', () {
    test('drops inline data of a tombstoned DocumentReference without '
        'writing a file', () async {
      final row = {
        ...docRow([
          {'data': base64Encode(pdfBytes), 'title': 'scan.pdf'},
          {'url': 'https://example.org/remote.pdf'},
        ]),
        'deleted_at': ms(t0),
      };

      final result = await service.restoreAttachments([row]);

      expect(dirs.docNames(), isEmpty);
      expect(attachmentsOf(result.single), [
        {'title': 'scan.pdf'},
        {'url': 'https://example.org/remote.pdf'},
      ]);
      expect(result.single['deleted_at'], ms(t0));
      expect(attachmentsOf(row).first['data'], isNotNull);
    });

    test('passes a tombstone without inline data through as-is', () async {
      final row = {
        ...docRow([
          {'url': 'file://report.pdf'},
        ]),
        'deleted_at': ms(t0),
      };
      Map<String, dynamic> tombstone(String? raw) => {
        'id': 'bad',
        'resource_type': 'DocumentReference',
        'resource_raw': raw,
        'deleted_at': ms(t0),
      };
      final odd = [
        tombstone(null),
        tombstone('{not json "data"'),
        tombstone('["data"]'),
        tombstone('{"content": "data"}'),
        tombstone('{"content": ["data", {"attachment": "data"}]}'),
        tombstone('{"content": [{"attachment": {"title": "data"}}]}'),
      ];

      final result = await service.restoreAttachments([row, ...odd]);

      expect(identical(result.first, row), isTrue);
      for (var i = 0; i < odd.length; i++) {
        expect(identical(result[i + 1], odd[i]), isTrue, reason: '$i');
      }
    });

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

    test('two attachments titled alike reach the peer as two files, each '
        'with its own bytes', () async {
      final firstBytes = utf8.encode('%PDF-1.7 first report');
      final secondBytes = utf8.encode('%PDF-1.7 second report');
      // The phone stores each pick under a unique name but keeps the title
      // the user picked.
      await dirs.writeDoc('report_aaaa1111.pdf', firstBytes);
      await dirs.writeDoc('report_bbbb2222.pdf', secondBytes);
      final sources = [
        docRow(id: 'doc-a', [
          {
            'url': 'file://report_aaaa1111.pdf',
            'title': 'report.pdf',
            'contentType': 'application/pdf',
          },
        ]),
        docRow(id: 'doc-b', [
          {
            'url': 'file://report_bbbb2222.pdf',
            'title': 'report.pdf',
            'contentType': 'application/pdf',
          },
        ]),
      ];
      final otherDocs = Directory('${dirs.root.path}/peer/Documents')
        ..createSync(recursive: true);
      final peer = AttachmentSyncService(FakePathResolver(otherDocs.path));

      final wire = jsonDecode(
        jsonEncode(await service.embedAttachments(sources)),
      ) as List;
      final restored = await peer.restoreAttachments([
        for (final r in wire) Map<String, dynamic>.from(r as Map),
      ]);

      final a = attachmentsOf(restored[0]).single;
      final b = attachmentsOf(restored[1]).single;
      expect(a['title'], 'report.pdf');
      expect(b['title'], 'report.pdf');
      expect(a['url'], isNot(b['url']));
      Future<List<int>> bytesOf(Map<String, dynamic> attachment) => File(
        '${otherDocs.path}/${(attachment['url'] as String).substring(7)}',
      ).readAsBytes();
      expect(await bytesOf(a), firstBytes);
      expect(await bytesOf(b), secondBytes);
    });
  });

  group('resolveFile', () {
    // resolveFile returns the real path; on macOS the temp directory sits
    // behind the /var -> /private/var link, so compare with the real path.
    test('resolves a relative path against the documents directory', () async {
      final file = await dirs.writeDoc('a/b.pdf', pdfBytes);

      expect(
        (await service.resolveFile('a/b.pdf'))?.path,
        file.resolveSymbolicLinksSync(),
      );
    });

    test('returns an absolute path inside the documents directory', () async {
      final file = await dirs.writeDoc('in/docs.pdf', pdfBytes);

      expect(
        (await service.resolveFile(file.path))?.path,
        file.resolveSymbolicLinksSync(),
      );
    });

    test('never resolves a path outside the documents directory', () async {
      final outside = File('${dirs.root.path}/elsewhere/x.pdf')
        ..createSync(recursive: true);
      File('${dirs.container.path}/secret.db').writeAsStringSync('db');

      expect(await service.resolveFile(outside.path), isNull);
      expect(await service.resolveFile('/etc/passwd'), isNull);
      expect(await service.resolveFile('../secret.db'), isNull);
      expect(await service.resolveFile('a/../../secret.db'), isNull);
      expect(await service.resolveFile('..'), isNull);
      expect(await service.resolveFile(''), isNull);
      expect(await service.resolveFile('/'), isNull);
    });

    test(
      'a symbolic link inside documents pointing outside is refused',
      () async {
        final outside = File('${dirs.root.path}/outside.txt')
          ..writeAsStringSync('secret');
        Link('${dirs.docs.path}/link.pdf').createSync(outside.path);

        expect(await service.resolveFile('link.pdf'), isNull);
        expect(await service.resolveFile('/old/path/link.pdf'), isNull);
      },
    );

    test('falls back to the file name in the documents directory', () async {
      final file = await dirs.writeDoc('x.pdf', pdfBytes);

      expect(
        (await service.resolveFile('/old/device/path/x.pdf'))?.path,
        file.resolveSymbolicLinksSync(),
      );
      expect(
        (await service.resolveFile('moved/x.pdf'))?.path,
        file.resolveSymbolicLinksSync(),
      );
      expect(
        (await service.resolveFile('../x.pdf'))?.path,
        file.resolveSymbolicLinksSync(),
      );
    });

    test('a Windows drive path falls back by file name', () async {
      final file = await dirs.writeDoc('w.pdf', pdfBytes);

      // Both separators split the name, so a path from a Windows desktop
      // finds the same file in the documents directory.
      expect(
        (await service.resolveFile(r'C:\Users\me\w.pdf'))?.path,
        file.resolveSymbolicLinksSync(),
      );
      expect(
        (await service.resolveFile('C:/Users/me/w.pdf'))?.path,
        file.resolveSymbolicLinksSync(),
      );
    });

    test('does not look in the temporary directory', () async {
      File('${dirs.temp.path}/cached.jpg').createSync();

      expect(await service.resolveFile('/gone/cached.jpg'), isNull);
    });

    test(
      'remaps a path from an old iOS app container to the current one',
      () async {
        final moved = await dirs.writeDoc('scans/scan.jpg', pdfBytes);

        final resolved = await service.resolveFile(
          '/var/mobile/Containers/Data/Application/OLD-UUID/Documents/scans/'
          'scan.jpg',
        );

        expect(resolved?.path, moved.resolveSymbolicLinksSync());
      },
    );

    test('an old container path outside Documents is not remapped', () async {
      File(
        '${dirs.container.path}/Library/Caches/sub/scan.jpg',
      ).createSync(recursive: true);

      expect(
        await service.resolveFile(
          '/var/mobile/Containers/Data/Application/OLD-UUID/Library/Caches/'
          'sub/scan.jpg',
        ),
        isNull,
      );
    });

    test('an absolute path that climbs out of documents is refused', () async {
      File('${dirs.container.path}/secret.db').writeAsStringSync('db');

      expect(
        await service.resolveFile('${dirs.docs.path}/../secret.db'),
        isNull,
      );
      expect(
        await service.resolveFile('${dirs.docs.path}/a/../../secret.db'),
        isNull,
      );
    });

    test(
      'a Windows drive path whose file is not in documents is refused',
      () async {
        File('${dirs.root.path}/w.pdf').writeAsStringSync('x');

        expect(await service.resolveFile(r'C:\Windows\w.pdf'), isNull);
        expect(await service.resolveFile(r'C:\..\..\w.pdf'), isNull);
      },
    );

    test('the demo report, stored with an absolute path under documents, '
        'resolves', () async {
      final demo = await dirs.writeDoc('demo_medical_report.pdf', pdfBytes);

      expect(
        (await service.resolveFile(demo.path))?.path,
        demo.resolveSymbolicLinksSync(),
      );
      // The same record synced from another device carries that device's
      // documents path, which falls back to the local copy by name.
      expect(
        (await service.resolveFile(
          '/Users/other/Library/Containers/app/Data/Documents/'
          'demo_medical_report.pdf',
        ))?.path,
        demo.resolveSymbolicLinksSync(),
      );
    });

    test('never resolves the database or its journal files', () async {
      for (final name in ['db.sqlite', 'db.sqlite-wal', 'db.sqlite-shm']) {
        await dirs.writeDoc(name, utf8.encode('database'));
      }

      expect(await service.resolveFile('db.sqlite'), isNull);
      expect(
        await service.resolveFile('${dirs.docs.path}/db.sqlite-wal'),
        isNull,
      );
      expect(await service.resolveFile('DB.SQLITE'), isNull);
      expect(await service.resolveFile('/other/device/db.sqlite-shm'), isNull);
    });

    test(
      'a link inside documents pointing at the database is refused',
      () async {
        await dirs.writeDoc('db.sqlite', utf8.encode('database'));
        Link('${dirs.docs.path}/innocent.pdf').createSync(
          '${dirs.docs.path}/db.sqlite',
        );

        expect(await service.resolveFile('innocent.pdf'), isNull);
      },
    );

    test('returns the real file behind a link inside documents', () async {
      final real = await dirs.writeDoc('real.pdf', pdfBytes);
      Link('${dirs.docs.path}/alias.pdf').createSync(real.path);

      final resolved = await service.resolveFile('alias.pdf');

      expect(resolved?.path, real.resolveSymbolicLinksSync());
    });

    test('a directory is not resolved as a file', () async {
      Directory('${dirs.docs.path}/folder').createSync();

      expect(await service.resolveFile('folder'), isNull);
    });

    test(
      'embedAttachments inlines the demo report by its absolute url',
      () async {
        final demo = await dirs.writeDoc('demo_medical_report.pdf', pdfBytes);
        final row = docRow([
          {'url': 'file://${demo.path}', 'contentType': 'application/pdf'},
        ]);

        final result = await service.embedAttachments([row]);

        expect(
          base64Decode(attachmentsOf(result.single).single['data'] as String),
          pdfBytes,
        );
      },
    );

    test('embedAttachments never inlines a file outside documents', () async {
      final outside = File('${dirs.root.path}/private.txt')
        ..writeAsStringSync('secret');
      final row = docRow([
        {'url': 'file://${outside.path}'},
        {'url': 'file://../private.txt'},
      ]);

      final result = await service.embedAttachments([row]);

      expect(result.single, row);
    });

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
