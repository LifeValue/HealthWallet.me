import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';

const _id = '3f2b8c1e-9a4d-4e6f-8b7a-1c2d3e4f5a6b';

void main() {
  late Directory root;
  late Directory temp;
  late Directory docs;

  setUp(() {
    root = Directory.systemTemp.createTempSync('hw_sweeper_test_');
    temp = Directory('${root.path}/tmp')..createSync();
    docs = Directory('${root.path}/Documents')..createSync();
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  TempFileSweeper sweeper({required bool deleteDebugLogs}) => TempFileSweeper(
    temporaryDirectory: () async => temp,
    documentsDirectory: () async => docs,
    deleteDebugLogs: deleteDebugLogs,
  );

  File tempFile(String name) => File('${temp.path}/$name')
    ..createSync(recursive: true)
    ..writeAsStringSync('health data');

  File docsFile(String name) =>
      File('${docs.path}/$name')..writeAsStringSync('log');

  group('sweep', () {
    test('deletes the health-data temp files the app leaves behind', () async {
      final shareJson = tempFile('share_$_id.json');
      final sessionFile = tempFile('share_session_$_id/scan.png');
      final ips = tempFile('Jane Doe - IPS Summary - 28-10-2026.pdf');
      final unnamedIps = tempFile(' - IPS Summary - 10-28-2026.pdf');
      final pass = tempFile('HealthWallet_Emergency.pkpass');

      await sweeper(deleteDebugLogs: false).sweep();

      expect(shareJson.existsSync(), isFalse);
      expect(sessionFile.parent.existsSync(), isFalse);
      expect(ips.existsSync(), isFalse);
      expect(unnamedIps.existsSync(), isFalse);
      expect(pass.existsSync(), isFalse);
    });

    test('keeps the temp directory and every other file in it', () async {
      final kept = [
        tempFile('pdf_page_1.png'),
        tempFile('resized_photo.jpg'),
        tempFile('other_app.json'),
        tempFile('share_not-a-uuid.json'),
        tempFile('share_$_id.json.bak'),
        tempFile('IPS Summary.pdf'),
        tempFile('HealthWallet_Emergency.pkpass.tmp'),
        tempFile('nested/share_$_id.json'),
        tempFile('share_session_../keep.txt'),
      ];

      await sweeper(deleteDebugLogs: true).sweep();

      expect(temp.existsSync(), isTrue);
      for (final file in kept) {
        expect(file.existsSync(), isTrue, reason: file.path);
      }
    });

    test('does not follow links out of the temp directory', () async {
      final outside = Directory('${root.path}/outside')..createSync();
      final target = File('${outside.path}/keep.txt')..writeAsStringSync('x');
      final link = Link('${temp.path}/share_session_$_id')
        ..createSync(outside.path);

      await sweeper(deleteDebugLogs: false).sweep();

      expect(target.existsSync(), isTrue);
      expect(link.existsSync(), isTrue);
    });

    test('deletes the old debug logs when asked (release builds)', () async {
      final shareLog = docsFile('share_debug.log');
      final scanLog = docsFile('scan_debug.log');
      final other = docsFile('notes.log');

      await sweeper(deleteDebugLogs: true).sweep();

      expect(shareLog.existsSync(), isFalse);
      expect(scanLog.existsSync(), isFalse);
      expect(other.existsSync(), isTrue);
    });

    test('keeps the debug logs in debug and profile builds', () async {
      final shareLog = docsFile('share_debug.log');
      final scanLog = docsFile('scan_debug.log');

      await sweeper(deleteDebugLogs: false).sweep();

      expect(shareLog.existsSync(), isTrue);
      expect(scanLog.existsSync(), isTrue);
    });

    test('completes when a directory is missing or unavailable', () async {
      temp.deleteSync(recursive: true);
      await expectLater(sweeper(deleteDebugLogs: true).sweep(), completes);

      final failing = TempFileSweeper(
        temporaryDirectory: () async => throw const FileSystemException('x'),
        documentsDirectory: () async => throw const FileSystemException('y'),
        deleteDebugLogs: true,
      );
      await expectLater(failing.sweep(), completes);
    });

    test(
      'goes on when an entry cannot be deleted',
      () async {
        final locked = Directory('${temp.path}/share_session_$_id')
          ..createSync();
        File('${locked.path}/scan.png').writeAsStringSync('x');
        final lockedDocs = Directory('${root.path}/locked')..createSync();
        File('${lockedDocs.path}/share_debug.log').writeAsStringSync('x');
        final pass = tempFile('HealthWallet_Emergency.pkpass');
        // Read-only directories: their entries can't be removed.
        Process.runSync('chmod', ['0555', locked.path, lockedDocs.path]);
        addTearDown(
          () =>
              Process.runSync('chmod', ['0755', locked.path, lockedDocs.path]),
        );

        await expectLater(
          TempFileSweeper(
            temporaryDirectory: () async => temp,
            documentsDirectory: () async => lockedDocs,
            deleteDebugLogs: true,
          ).sweep(),
          completes,
        );

        expect(File('${locked.path}/scan.png').existsSync(), isTrue);
        expect(File('${lockedDocs.path}/share_debug.log').existsSync(), isTrue);
        expect(pass.existsSync(), isFalse);
      },
      skip: Platform.isWindows ? 'chmod is POSIX only' : false,
    );

    test('defaults to deleting the logs only in release builds', () {
      expect(TempFileSweeper.deleteDebugLogsFor(releaseMode: true), isTrue);
      expect(TempFileSweeper.deleteDebugLogsFor(releaseMode: false), isFalse);
      // `flutter test` runs in debug mode.
      expect(TempFileSweeper().deleteDebugLogs, isFalse);
      expect(TempFileSweeper().includeProcessingCache, isFalse);
    });
  });

  group('processing cache', () {
    const cacheKey =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    File cacheFile(String name) =>
        File('${docs.path}/${TempFileSweeper.ocrCacheDirName}/$name')
          ..createSync(recursive: true)
          ..writeAsStringSync('{}');

    test('is kept by default (startup)', () async {
      final page = tempFile('pdf_page_1700000000000_0.png');
      final resized = tempFile('resized_photo.jpg');
      final metadata = cacheFile('$cacheKey.json');

      await sweeper(deleteDebugLogs: true).sweep();

      expect(page.existsSync(), isTrue);
      expect(resized.existsSync(), isTrue);
      expect(metadata.existsSync(), isTrue);
    });

    test('is deleted when included (reset)', () async {
      final page = tempFile('pdf_page_1700000000000_0.png');
      final resized = tempFile('resized_photo.jpg');
      final metadata = cacheFile('$cacheKey.json');
      final keptInTemp = [
        tempFile('other_app.png'),
        tempFile('nested/pdf_page_1.png'),
      ];
      final keptInCache = [
        cacheFile('notes.json'),
        cacheFile('$cacheKey.txt'),
      ];
      final pageDir = Directory('${temp.path}/pdf_page_dir')..createSync();

      await TempFileSweeper(
        temporaryDirectory: () async => temp,
        documentsDirectory: () async => docs,
        deleteDebugLogs: false,
        includeProcessingCache: true,
      ).sweep();

      expect(page.existsSync(), isFalse);
      expect(resized.existsSync(), isFalse);
      expect(metadata.existsSync(), isFalse);
      expect(metadata.parent.existsSync(), isTrue);
      expect(pageDir.existsSync(), isTrue);
      for (final file in [...keptInTemp, ...keptInCache]) {
        expect(file.existsSync(), isTrue, reason: file.path);
      }
    });

    test('completes without a cache directory', () async {
      await expectLater(
        TempFileSweeper(
          temporaryDirectory: () async => temp,
          documentsDirectory: () async => docs,
          includeProcessingCache: true,
        ).sweep(),
        completes,
      );
    });
  });

  test('producers name their files from the sweep constants', () {
    expect(TempFileSweeper.sharePayloadName(_id), 'share_$_id.json');
    expect(TempFileSweeper.shareSessionName(_id), 'share_session_$_id');
    expect(
      TempFileSweeper.ipsSummaryName('Jane', '01-02-2026'),
      'Jane - IPS Summary - 01-02-2026',
    );
  });

  test('names built from the constants are swept', () async {
    final files = [
      tempFile(TempFileSweeper.sharePayloadName(_id)),
      tempFile('${TempFileSweeper.ipsSummaryName('Jane', '01-02-2026')}.pdf'),
      tempFile(TempFileSweeper.walletPassFileName),
      tempFile('${TempFileSweeper.shareSessionName(_id)}/a.png'),
    ];

    await sweeper(deleteDebugLogs: false).sweep();

    for (final file in files) {
      expect(file.existsSync(), isFalse, reason: file.path);
    }
  });
}
