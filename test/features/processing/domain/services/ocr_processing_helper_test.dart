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
              img.encodeJpg(img.Image(width: 4, height: 2)),
            ))
            .path,
    ];
  }
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
      await helper.keepOcrPages(sessionId: 's', previewPaths: [photo]);

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

    test('discarding without a cache directory completes', () async {
      await expectLater(helper.discardOcrPages(sessionId: 's'), completes);
      await expectLater(helper.discardSessionPages(sessionId: 's'), completes);
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
