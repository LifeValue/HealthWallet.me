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
      final sharePayload = tempFile('share_$_id.bin');
      final oldSharePayload = tempFile('share_$_id.json');
      final sessionFile = tempFile('share_session_$_id/scan.png');
      final ips = tempFile('Jane Doe - IPS Summary - 28-10-2026.pdf');
      final unnamedIps = tempFile(' - IPS Summary - 10-28-2026.pdf');
      final pass = tempFile('HealthWallet_Emergency.pkpass');
      final preview = tempFile('healthwallet_record_preview_$_id.pdf');

      await sweeper(deleteDebugLogs: false).sweep();

      expect(preview.existsSync(), isFalse);

      expect(sharePayload.existsSync(), isFalse);
      expect(oldSharePayload.existsSync(), isFalse);
      expect(sessionFile.parent.existsSync(), isFalse);
      expect(ips.existsSync(), isFalse);
      expect(unnamedIps.existsSync(), isFalse);
      expect(pass.existsSync(), isFalse);
    });

    test('keeps the temp directory and every other file in it', () async {
      final kept = [
        tempFile('healthwallet_pdf_page_1.png'),
        tempFile('healthwallet_resized_photo.jpg'),
        tempFile('other_app.json'),
        tempFile('share_not-a-uuid.json'),
        tempFile('share_$_id.json.bak'),
        tempFile('share_$_id.bin.part'),
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

    // A failed delete is simulated, not made with chmod: the CI container
    // runs the tests as root, which ignores file permissions.
    test('goes on when an entry cannot be deleted', () async {
      final pass = tempFile('HealthWallet_Emergency.pkpass');
      final locked = _UndeletableDirectory('${temp.path}/share_session_$_id');
      final listed = _ListedDirectory(temp.path, [locked, File(pass.path)]);

      await expectLater(
        TempFileSweeper(
          temporaryDirectory: () async => listed,
          documentsDirectory: () async => docs,
          deleteDebugLogs: false,
        ).sweep(),
        completes,
      );

      expect(locked.deleteCalls, 1);
      expect(pass.existsSync(), isFalse);
    });

    test('goes on when an old debug log cannot be deleted', () async {
      final attempts = <String>[];

      await IOOverrides.runZoned(
        () => expectLater(
          TempFileSweeper(
            temporaryDirectory: () async => temp,
            documentsDirectory: () async => docs,
            deleteDebugLogs: true,
          ).sweep(),
          completes,
        ),
        createFile: (path) => _UndeletableFile(path, attempts),
      );

      expect(attempts, [
        '${docs.path}/${TempFileSweeper.shareDebugLogName}',
        '${docs.path}/${TempFileSweeper.scanDebugLogName}',
      ]);
    });

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
      final page = tempFile('healthwallet_pdf_page_1700000000000_0.png');
      final resized = tempFile('healthwallet_resized_photo.jpg');
      final metadata = cacheFile('$cacheKey.json');

      await sweeper(deleteDebugLogs: true).sweep();

      expect(page.existsSync(), isTrue);
      expect(resized.existsSync(), isTrue);
      expect(metadata.existsSync(), isTrue);
    });

    test('is deleted when included (reset)', () async {
      final page = tempFile('healthwallet_pdf_page_1700000000000_0.png');
      final resized = tempFile('healthwallet_resized_photo.jpg');
      final metadata = cacheFile('$cacheKey.json');
      final keptInTemp = [
        tempFile('other_app.png'),
        tempFile('nested/healthwallet_pdf_page_1.png'),
      ];
      final keptInCache = [
        cacheFile('notes.json'),
        cacheFile('$cacheKey.txt'),
      ];
      final pageDir = Directory('${temp.path}/healthwallet_pdf_page_dir')
        ..createSync();

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

    test('page images and session page maps go on reset, not at '
        'startup', () async {
      final pages = [
        cacheFile('${cacheKey}_page_1.jpg'),
        cacheFile('${cacheKey}_page_12.jpg'),
        cacheFile('${cacheKey}_page_2_r3.jpg'),
        cacheFile(TempFileSweeper.sessionPageMapName(_id)),
        cacheFile('${TempFileSweeper.sessionPageMapName(_id)}.tmp'),
      ];
      final kept = [
        cacheFile('${cacheKey}_page_1.png'),
        cacheFile('${cacheKey}_page_x.jpg'),
        cacheFile('${cacheKey}_page_1_r4.jpg'),
        cacheFile('not-a-session.pages.json'),
        cacheFile('photo.jpg'),
      ];

      await sweeper(deleteDebugLogs: true).sweep();
      for (final file in [...pages, ...kept]) {
        expect(file.existsSync(), isTrue, reason: file.path);
      }

      await TempFileSweeper(
        temporaryDirectory: () async => temp,
        documentsDirectory: () async => docs,
        deleteDebugLogs: false,
        includeProcessingCache: true,
      ).sweep();
      for (final file in pages) {
        expect(file.existsSync(), isFalse, reason: file.path);
      }
      for (final file in kept) {
        expect(file.existsSync(), isTrue, reason: file.path);
      }
    });

    test('the page pattern reads the cache key and page number', () {
      final match = TempFileSweeper.ocrCachePagePattern.firstMatch(
        '${cacheKey}_page_7_r2.jpg',
      )!;

      expect(match.group(1), cacheKey);
      expect(match.group(2), '7');
      expect(
        TempFileSweeper.sessionPageMapName(_id),
        '$_id${TempFileSweeper.sessionPageMapSuffix}',
      );
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
    expect(TempFileSweeper.sharePayloadName(_id), 'share_$_id.bin');
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
      tempFile(TempFileSweeper.recordPreviewName('pdf')),
      tempFile(TempFileSweeper.recordPreviewName('png')),
    ];

    await sweeper(deleteDebugLogs: false).sweep();

    for (final file in files) {
      expect(file.existsSync(), isFalse, reason: file.path);
    }
  });

  test('Reset leaves other apps\' files with generic names alone', () async {
    // On Windows the temporary directory is the user's shared %TEMP%.
    final temp = await Directory.systemTemp.createTemp('sweeper_shared');
    addTearDown(() => temp.delete(recursive: true));
    final ours = File('${temp.path}/${TempFileSweeper.ocrPagePrefix}1_0.png')
      ..writeAsStringSync('x');
    final theirs = [
      File('${temp.path}/pdf_page_1_0.png')..writeAsStringSync('x'),
      File('${temp.path}/resized_photo.jpg')..writeAsStringSync('x'),
    ];

    await TempFileSweeper(
      temporaryDirectory: () async => temp,
      documentsDirectory: () async => temp,
      deleteDebugLogs: false,
      includeProcessingCache: true,
    ).sweep();

    expect(ours.existsSync(), isFalse);
    expect(theirs.every((f) => f.existsSync()), isTrue);
  });
}

/// A temporary directory that lists the given entries.
class _ListedDirectory extends Fake implements Directory {
  _ListedDirectory(this.path, this.entries);

  @override
  final String path;
  final List<FileSystemEntity> entries;

  @override
  Future<bool> exists() async => true;

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) => Stream.fromIterable(entries);
}

/// A directory whose delete fails, as a locked or busy one would.
class _UndeletableDirectory extends Fake implements Directory {
  _UndeletableDirectory(this.path);

  @override
  final String path;
  var deleteCalls = 0;

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    deleteCalls++;
    throw FileSystemException('Directory not empty', path);
  }
}

/// A file that exists but can't be deleted; records each attempt.
class _UndeletableFile extends Fake implements File {
  _UndeletableFile(this.path, this.attempts);

  @override
  final String path;
  final List<String> attempts;

  @override
  Future<bool> exists() async => true;

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    attempts.add(path);
    throw FileSystemException('Permission denied', path);
  }
}
