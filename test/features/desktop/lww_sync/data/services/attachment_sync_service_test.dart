import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/attachment_sync_service.dart';

import '../../lww_sync_test_helpers.dart';

void main() {
  late TestDirs dirs;
  late AttachmentSyncService service;

  final pdfBytes = utf8.encode('%PDF-1.7 fake report');

  setUp(() async {
    dirs = await TestDirs.create();
    service = AttachmentSyncService(FakePathResolver(dirs.docs.path));
  });

  tearDown(() => dirs.dispose());

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

    test('resolves the demo report by its absolute url', () async {
      final demo = await dirs.writeDoc('demo_medical_report.pdf', pdfBytes);
      expect(
        (await service.resolveFile(demo.path))?.path,
        demo.resolveSymbolicLinksSync(),
      );
    });

    test('never resolves a file outside documents', () async {
      final outside = File('${dirs.root.path}/private.txt')
        ..writeAsStringSync('secret');
      expect(await service.resolveFile(outside.path), isNull);
      expect(await service.resolveFile('../private.txt'), isNull);
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
