import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';
import 'package:health_wallet/features/processing/domain/entity/session_page_map.dart';
import 'package:health_wallet/features/processing/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';
import 'package:image/image.dart' as img;

import '../../../../helpers/log_capture.dart';
import '../../../share_records/share_test_helpers.dart';

/// Writes `<key>_page_<n>.jpg` pages into the page cache, a key per file and
/// dpi, like the app's PDF conversion.
class _FakeRecognition extends Fake implements TextRecognitionService {
  _FakeRecognition(this.cacheDir);

  final Directory cacheDir;
  final texts = <String, String>{};
  final read = <String>[];
  final failing = <String>{};
  int pages = 2;

  /// Whether the 200 dpi pages are written as bytes no decoder reads.
  bool corruptOcrPages = false;

  @override
  bool isPDF(String filePath) => filePath.endsWith('.pdf');

  @override
  bool isImage(String filePath) => filePath.endsWith('.jpg');

  @override
  Future<String> recognizeTextFromImage(String imagePath) async {
    read.add(imagePath);
    return texts[imagePath] ?? '';
  }

  @override
  Future<List<String>> convertPdfToImagesForPreview(
    String pdfPath, {
    double dpi = 72,
  }) async {
    if (failing.contains(pdfPath)) throw Exception('broken PDF');
    final key = (pdfPath.hashCode.toRadixString(16) + dpi.toString())
        .replaceAll(RegExp('[^0-9a-f]'), '')
        .padRight(64, 'a')
        .substring(0, 64);
    cacheDir.createSync(recursive: true);
    return [
      for (var n = 1; n <= pages; n++)
        (File('${cacheDir.path}/${key}_page_$n.jpg')..writeAsBytesSync(
              corruptOcrPages && dpi > 72
                  ? [1, 2, 3]
                  : img.encodeJpg(img.Image(width: 4, height: 2)),
            ))
            .path,
    ];
  }
}

/// A file that can be read but not deleted. CI runs as root, so a
/// permission can't make the delete fail.
class _UndeletableFile extends Fake implements File {
  _UndeletableFile(this._real);

  final File _real;

  @override
  String get path => _real.path;

  @override
  Future<bool> exists() => _real.exists();

  @override
  Future<String> readAsString({Encoding encoding = utf8}) =>
      _real.readAsString(encoding: encoding);

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async =>
      throw FileSystemException('Cannot delete', path);
}

/// The page cache: listed as it is on disk, with each file through
/// [wrap], or not at all when [unlistable].
class _CacheDirectory extends Fake implements Directory {
  _CacheDirectory(this._real, {required this.wrap, required this.unlistable});

  final Directory _real;
  final File Function(File file) wrap;
  final bool unlistable;

  @override
  String get path => _real.path;

  @override
  Future<bool> exists() => _real.exists();

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) {
    if (unlistable) throw FileSystemException('Cannot list', path);
    return _real
        .list(recursive: recursive, followLinks: followLinks)
        .map((entry) => entry is File ? wrap(entry) : entry);
  }
}

/// Makes the files at [undeletable] undeletable and, when [unlistable], the
/// page cache at [cacheDir] unlistable; everything else is real.
final class _FailingIo extends IOOverrides {
  _FailingIo({
    required this.cacheDir,
    this.undeletable = const {},
    this.unlistable = false,
  });

  final String cacheDir;
  final Set<String> undeletable;
  final bool unlistable;

  File _wrap(File real) =>
      undeletable.contains(real.path) ? _UndeletableFile(real) : real;

  @override
  File createFile(String path) => _wrap(super.createFile(path));

  @override
  Directory createDirectory(String path) => path == cacheDir
      ? _CacheDirectory(
          super.createDirectory(path),
          wrap: _wrap,
          unlistable: unlistable,
        )
      : super.createDirectory(path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final logs = captureLogs();
  late Directory root;
  late Directory cacheDir;
  late _FakeRecognition recognition;
  late OcrProcessingHelper helper;

  setUp(() {
    root = mockPathProvider();
    cacheDir = Directory(
      '${root.path}/Documents/${TempFileSweeper.ocrCacheDirName}',
    );
    recognition = _FakeRecognition(cacheDir);
    helper = OcrProcessingHelper(recognition, PathResolver());
  });

  File file(String name) => File('${root.path}/Documents/imports/$name')
    ..createSync(recursive: true)
    ..writeAsStringSync('x');
  File pageMap(String sessionId) => File(
    '${cacheDir.path}/${TempFileSweeper.sessionPageMapName(sessionId)}',
  );

  group('processOcrForImages', () {
    test('joins the text of the pages that exist and have text', () async {
      final a = file('a.jpg').path;
      final b = file('b.jpg').path;
      final c = file('c.jpg').path;
      recognition.texts.addAll({a: 'first', c: 'third'});

      final text = await helper.processOcrForImages([a, '/gone.jpg', b, c]);

      expect(text, 'first\nthird');
      expect(recognition.read, [a, b, c]);
    });
  });

  group('prepareAllImages', () {
    test('keeps images and turns each PDF into its pages', () async {
      final photo = file('photo.jpg').path;
      final pdf = file('report.pdf').path;

      final images = await helper.prepareAllImages(filePaths: [photo, pdf]);

      expect(images, hasLength(3));
      expect(images.first, photo);
      expect(images[1], endsWith('_page_1.jpg'));
    });

    test('a PDF that fails is logged and left out', () async {
      final pdf = file('report.pdf').path;
      recognition.failing.add(pdf);

      final images = await helper.prepareAllImages(filePaths: [pdf]);

      expect(images, isEmpty);
      expect(logs, loggedWarning('Error converting PDF'));
    });
  });

  group('page set', () {
    test('a session of photos writes no page map', () async {
      final photo = file('photo.jpg').path;

      final pages = await helper.prepareOcrPages(
        sessionId: 's',
        filePaths: [photo],
        previewPaths: [photo],
      );
      await helper.keepOcrPages(
        sessionId: 's',
        filePaths: [photo],
        previewPaths: [photo],
      );

      expect(pages, isEmpty);
      expect(pageMap('s').existsSync(), isFalse);
      expect(logs, isEmpty);
    });

    test('an unreadable page map is logged and rebuilt', () async {
      final pdf = file('report.pdf').path;
      pageMap('s')
        ..createSync(recursive: true)
        ..writeAsStringSync('{not json');
      final previews = await helper.prepareAllImages(filePaths: [pdf]);

      final pages = await helper.prepareOcrPages(
        sessionId: 's',
        filePaths: [pdf],
        previewPaths: previews,
      );

      expect(pages.keys, previews);
      expect(logs, loggedWarning('page map of s is unreadable'));
      expect(pageMap('s').readAsStringSync(), contains('imports/report.pdf'));
    });

    test('a PDF whose 200 dpi render fails leaves its pages out', () async {
      final pdf = file('report.pdf').path;
      final previews = await helper.prepareAllImages(filePaths: [pdf]);
      await helper.prepareOcrPages(
        sessionId: 's',
        filePaths: [pdf],
        previewPaths: const [],
      );
      recognition.pages = 0;

      final pages = await helper.prepareOcrPages(
        sessionId: 's',
        filePaths: const [],
        previewPaths: previews,
      );

      expect(pages, isEmpty);
      expect(logs, loggedWarning('rendered no 200 dpi pages'));
    });

    test('work on one session runs in order, and a failure does not stop '
        'the next', () async {
      final pdf = file('report.pdf').path;
      final previews = await helper.prepareAllImages(filePaths: [pdf]);
      recognition.failing.add(pdf);

      final failed = helper.prepareOcrPages(
        sessionId: 's',
        filePaths: [pdf],
        previewPaths: previews,
      );
      final turned = helper.rotateOcrPage(
        sessionId: 's',
        filePaths: const [],
        previewPath: previews.first,
        quarterTurns: 1,
      );

      await expectLater(failed, throwsException);
      expect(await turned, isNull);
    });

    test('discarding a session without a page map deletes the pages it is '
        'given, by cache key', () async {
      final pdf = file('report.pdf').path;
      final previews = await helper.prepareAllImages(filePaths: [pdf]);
      final key = previews.first.split('/').last.split('_page_').first;
      final metadata = File('${cacheDir.path}/$key.json')
        ..writeAsStringSync('{}');
      final unrelated = File('${cacheDir.path}/notes.json')
        ..writeAsStringSync('{}');

      await helper.discardSessionPages(sessionId: 's', pages: [previews.first]);

      expect(previews.any((p) => File(p).existsSync()), isFalse);
      expect(metadata.existsSync(), isFalse);
      expect(unrelated.existsSync(), isTrue);
    });

    test('a turn made before the OCR pages are prepared is kept', () async {
      final pdf = file('report.pdf').path;
      final previews = await helper.prepareAllImages(filePaths: [pdf]);

      final before = await helper.rotateOcrPage(
        sessionId: 's',
        filePaths: [pdf],
        previewPath: previews[1],
        quarterTurns: 1,
      );
      final pages = await helper.prepareOcrPages(
        sessionId: 's',
        filePaths: const [],
        previewPaths: previews,
      );

      expect(before, isNull);
      expect(pages[previews[0]], endsWith('_page_1.jpg'));
      expect(pages[previews[1]], endsWith('_page_2_r1.jpg'));
    });

    test('pages reordered before the OCR pages are prepared keep their '
        'source', () async {
      final pdf = file('report.pdf').path;
      final previews = await helper.prepareAllImages(filePaths: [pdf]);

      // After the edit the session stores only its preview pages.
      await helper.keepOcrPages(
        sessionId: 's',
        filePaths: [pdf],
        previewPaths: [previews[1]],
      );
      final pages = await helper.prepareOcrPages(
        sessionId: 's',
        filePaths: [previews[1]],
        previewPaths: [previews[1]],
      );

      expect(pages.keys, [previews[1]]);
      expect(pages[previews[1]], endsWith('_page_2.jpg'));
      expect(logs, isEmpty);
    });

    test('a turned page a crash left half written is not reused, and goes '
        'with the session', () async {
      final pdf = file('report.pdf').path;
      final previews = await helper.prepareAllImages(filePaths: [pdf]);
      final pages = await helper.prepareOcrPages(
        sessionId: 's',
        filePaths: [pdf],
        previewPaths: previews,
      );
      final partial = File(
        '${pages[previews[0]]!.replaceAll('.jpg', '')}'
        '_r1.jpg.tmp',
      )..writeAsBytesSync([0xFF, 0xD8]);

      final turned = await helper.rotateOcrPage(
        sessionId: 's',
        filePaths: const [],
        previewPath: previews[0],
        quarterTurns: 1,
      );

      expect(turned, endsWith('_page_1_r1.jpg'));
      final image = img.decodeJpg(File(turned!).readAsBytesSync())!;
      expect((image.width, image.height), (2, 4));
      expect(partial.existsSync(), isFalse);

      // A partial left by a later crash goes when the session is deleted.
      partial.writeAsBytesSync([0xFF, 0xD8]);
      await helper.discardSessionPages(sessionId: 's');
      expect(partial.existsSync(), isFalse);
    });

    test('deleting the session deletes the imported originals in its page '
        'map, also after saving released its OCR pages', () async {
      final pdf = file('report.pdf');
      final outside = File('${root.path}/Documents/elsewhere/other.pdf')
        ..createSync(recursive: true)
        ..writeAsStringSync('x');
      final previews = await helper.prepareAllImages(
        filePaths: [pdf.path, outside.path],
      );
      await helper.prepareOcrPages(
        sessionId: 's',
        filePaths: [pdf.path, outside.path],
        previewPaths: previews,
      );

      await helper.discardOcrPages(sessionId: 's');
      expect(pdf.existsSync(), isTrue);

      await helper.discardSessionPages(sessionId: 's');
      expect(pdf.existsSync(), isFalse);
      expect(outside.existsSync(), isTrue);
    });

    test('discarding without a cache directory completes', () async {
      await expectLater(helper.discardOcrPages(sessionId: 's'), completes);
      await expectLater(helper.discardSessionPages(sessionId: 's'), completes);
    });
  });

  group('page set failures', () {
    /// Prepares the OCR pages of a two-page PDF for session `s`.
    Future<(String, List<String>, Map<String, String>)> prepared() async {
      final pdf = file('report.pdf').path;
      final previews = await helper.prepareAllImages(filePaths: [pdf]);
      final pages = await helper.prepareOcrPages(
        sessionId: 's',
        filePaths: [pdf],
        previewPaths: previews,
      );
      return (pdf, previews, pages);
    }

    test('an OCR page that cannot be turned is logged and left out, so OCR '
        'reads its preview', () async {
      final pdf = file('report.pdf').path;
      final previews = await helper.prepareAllImages(filePaths: [pdf]);
      await helper.rotateOcrPage(
        sessionId: 's',
        filePaths: [pdf],
        previewPath: previews[0],
        quarterTurns: 1,
      );
      recognition.corruptOcrPages = true;

      final pages = await helper.prepareOcrPages(
        sessionId: 's',
        filePaths: const [],
        previewPaths: previews,
      );

      expect(pages.keys, [previews[1]]);
      expect(logs, loggedWarning('rotating'));
    });

    test('a page map that cannot be saved is logged; the OCR pages are still '
        'returned', () async {
      // A directory where the map is written aside makes the write fail.
      Directory('${pageMap('s').path}.tmp').createSync(recursive: true);

      final (_, previews, pages) = await prepared();

      expect(pages.keys, previews);
      expect(pageMap('s').existsSync(), isFalse);
      expect(logs, loggedWarning('saving the page map of s failed'));
    });

    test('without the documents directory the originals are kept, and the '
        'pages still deleted', () async {
      final (pdf, previews, pages) = await prepared();
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (call) async {
            if (call.method != 'getApplicationDocumentsDirectory') return null;
            // The page cache is found, the imports directory is not.
            return calls++ == 0 ? '${root.path}/Documents' : null;
          });

      await helper.discardSessionPages(sessionId: 's');

      expect(File(pdf).existsSync(), isTrue);
      expect([...previews, ...pages.values].any(_exists), isFalse);
      expect(pageMap('s').existsSync(), isFalse);
      expect(logs, loggedWarning('finding the imports directory failed'));
    });

    test('an original that cannot be deleted is logged, and the pages still '
        'deleted', () async {
      final (pdf, previews, pages) = await prepared();

      await IOOverrides.runWithIOOverrides(
        () => helper.discardSessionPages(sessionId: 's'),
        _FailingIo(cacheDir: cacheDir.path, undeletable: {pdf}),
      );

      expect(File(pdf).existsSync(), isTrue);
      expect([...previews, ...pages.values].any(_exists), isFalse);
      expect(logs, loggedWarning('deleting the original imports/report.pdf'));
    });

    test('a page map that cannot be deleted is logged, and the OCR pages '
        'still deleted', () async {
      final (_, previews, pages) = await prepared();
      final mapPath = pageMap('s').path;

      await IOOverrides.runWithIOOverrides(
        () => helper.discardOcrPages(sessionId: 's'),
        _FailingIo(cacheDir: cacheDir.path, undeletable: {mapPath}),
      );

      expect(pages.values.any(_exists), isFalse);
      expect(previews.every(_exists), isTrue);
      expect(pageMap('s').existsSync(), isTrue);
      expect(logs, loggedWarning('deleting the page map of s failed'));
    });

    test('a page that cannot be deleted is logged, and the others still '
        'deleted', () async {
      final (_, _, pages) = await prepared();
      final [stuck, other] = pages.values.toList();

      await IOOverrides.runWithIOOverrides(
        () => helper.discardOcrPages(sessionId: 's'),
        _FailingIo(cacheDir: cacheDir.path, undeletable: {stuck}),
      );

      expect(File(stuck).existsSync(), isTrue);
      expect(File(other).existsSync(), isFalse);
      expect(pageMap('s').existsSync(), isFalse);
      expect(logs, loggedWarning('deleting ${stuck.split('/').last} failed'));
    });

    test('a page cache that cannot be listed is logged; the page map is '
        'still deleted', () async {
      final (_, _, pages) = await prepared();

      await IOOverrides.runWithIOOverrides(
        () => helper.discardOcrPages(sessionId: 's'),
        _FailingIo(cacheDir: cacheDir.path, unlistable: true),
      );

      expect(pages.values.every(_exists), isTrue);
      expect(pageMap('s').existsSync(), isFalse);
      expect(logs, loggedWarning('listing the page cache failed'));
    });
  });

  group('SessionPageMap', () {
    test('survives a JSON round trip', () {
      const map = SessionPageMap(
        pages: {
          'a_page_1.jpg': PageSource(file: 'imports/a.pdf', page: 1),
          'a_page_2.jpg': PageSource(
            file: 'imports/a.pdf',
            page: 2,
            quarterTurns: 3,
          ),
        },
        previewKeys: {'a'},
        ocrKeys: {'b'},
      );

      expect(SessionPageMap.fromJson(map.toJson()), map);
      expect(const SessionPageMap().isEmpty, isTrue);
      expect(map.isEmpty, isFalse);
    });

    test('reads a page without turns as unturned', () {
      expect(
        PageSource.fromJson({'file': 'a.pdf', 'page': 4}),
        const PageSource(file: 'a.pdf', page: 4),
      );
      expect(SessionPageMap.fromJson(const {}), const SessionPageMap());
    });
  });

  test('a JPEG turns clockwise', () {
    final image = img.Image(width: 2, height: 1)
      ..setPixelRgb(0, 0, 255, 255, 255)
      ..setPixelRgb(1, 0, 0, 0, 0);

    final turned = img.decodeJpg(
      rotateJpegQuarterTurns(img.encodeJpg(image, quality: 100), 1),
    )!;

    expect((turned.width, turned.height), (1, 2));
    // Clockwise: the left (white) pixel ends up on top.
    expect(turned.getPixel(0, 0).r, greaterThan(turned.getPixel(0, 1).r));
    expect(
      () => rotateJpegQuarterTurns(img.encodePng(image), 1),
      throwsA(isA<img.ImageException>()),
    );
  });
}

bool _exists(String path) => File(path).existsSync();
