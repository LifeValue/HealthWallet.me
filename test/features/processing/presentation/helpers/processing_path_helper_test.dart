import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/presentation/helpers/processing_path_helper.dart';

import '../../../../helpers/log_capture.dart';

class _FakeProcessingRepository extends Fake implements ProcessingRepository {
  final saved = <String>[];
  final failing = <String>{};

  @override
  Future<String> saveScannedDocument(String sourcePath) async {
    if (failing.contains(sourcePath)) {
      throw const FileSystemException('disk full');
    }
    saved.add(sourcePath);
    return '/documents/${sourcePath.split('/').last}';
  }
}

void main() {
  final logs = captureLogs();

  group('normalizePaths', () {
    test('returns nothing for null', () {
      expect(ProcessingPathHelper.normalizePaths(null), isEmpty);
    });

    test('decodes file URIs in a list and drops empty entries', () {
      expect(
        ProcessingPathHelper.normalizePaths([
          'file:///tmp/scan%201.jpg',
          '',
          null,
          '/tmp/page2.jpg',
        ]),
        ['/tmp/scan 1.jpg', '/tmp/page2.jpg'],
      );
    });

    test('reads the uri and path keys of a scanner result map', () {
      expect(
        ProcessingPathHelper.normalizePaths({
          'imageUris': ['file:///tmp/a.jpg', 'file:///tmp/b.jpg'],
          'pdfPath': '/tmp/doc.pdf',
          'pageCount': 2,
        }),
        ['/tmp/a.jpg', '/tmp/b.jpg', '/tmp/doc.pdf'],
      );
    });

    test('falls back to the pages entry of a map', () {
      expect(
        ProcessingPathHelper.normalizePaths({'pages': '/tmp/only.jpg'}),
        ['/tmp/only.jpg'],
      );
    });

    test('splits URIs out of a single string and removes duplicates', () {
      expect(
        ProcessingPathHelper.normalizePaths(
          '[file:///tmp/a.jpg, file:///tmp/a.jpg, content://media/1]',
        ),
        ['/tmp/a.jpg', 'content://media/1'],
      );
    });
  });

  group('extractPdfPath', () {
    test('returns null for null', () {
      expect(ProcessingPathHelper.extractPdfPath(null), isNull);
    });

    test('reads pdfUri from a map', () {
      expect(
        ProcessingPathHelper.extractPdfPath({'pdfUri': 'file:///tmp/a.pdf'}),
        '/tmp/a.pdf',
      );
    });

    test('sanitizes a plain value', () {
      expect(ProcessingPathHelper.extractPdfPath('/tmp/b.pdf'), '/tmp/b.pdf');
    });
  });

  group('persistScanFiles', () {
    late Directory dir;
    late _FakeProcessingRepository repository;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('path_helper_test');
      repository = _FakeProcessingRepository();
    });

    tearDown(() => dir.deleteSync(recursive: true));

    String createFile(String name) {
      final file = File('${dir.path}/$name')..writeAsStringSync('x');
      return file.path;
    }

    test('returns nothing for no paths', () async {
      expect(
        await ProcessingPathHelper.persistScanFiles(
          sourcePaths: [],
          repository: repository,
        ),
        isEmpty,
      );
    });

    test('saves existing files and skips missing and content URIs', () async {
      final page = createFile('page1.jpg');

      final result = await ProcessingPathHelper.persistScanFiles(
        sourcePaths: [
          'file://$page',
          '${dir.path}/missing.jpg',
          'content://media/1',
          '',
        ],
        repository: repository,
      );

      expect(result, ['/documents/page1.jpg']);
      expect(repository.saved, [page]);
      expect(logs, isEmpty);
    });

    test('a page that fails to save is logged and the rest are kept', () async {
      final bad = createFile('bad.jpg');
      final good = createFile('good.jpg');
      repository.failing.add(bad);

      final result = await ProcessingPathHelper.persistScanFiles(
        sourcePaths: [bad, good],
        repository: repository,
      );

      expect(result, ['/documents/good.jpg']);
      expect(logs, loggedWarning('Could not keep the scanned page'));
    });
  });
}
