import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/data/services/pdf_generation_service.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../../desktop/lww_sync/lww_sync_test_helpers.dart';

void main() {
  late Directory root;
  late Directory docs;
  late Directory inbox;
  late PdfGenerationService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pdf_generation_test_');
    docs = await Directory(p.join(root.path, 'Documents')).create();
    inbox = await Directory(p.join(root.path, 'inbox')).create();
    service = PdfGenerationService(FakePathResolver(docs.path));
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<String> inboxFile(String relative, List<int> bytes) async {
    final file = File(p.join(inbox.path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<String> image(String name) =>
      inboxFile(name, img.encodePng(img.Image(width: 2, height: 2)));

  List<String> storedNames() =>
      docs.listSync().whereType<File>().map((f) => p.basename(f.path)).toList()
        ..sort();

  group('imported PDFs', () {
    test('two PDFs with the same name get two files, each with its own '
        'content', () async {
      final first = await inboxFile('one/report.pdf', utf8.encode('%PDF one'));
      final second = await inboxFile('two/report.pdf', utf8.encode('%PDF two'));

      final groups = await service.groupAndConvertDocuments(
        filePaths: [first, second],
      );

      expect(groups, hasLength(2));
      final paths = groups.map((g) => g.pdfPath).toList();
      expect(paths.toSet(), hasLength(2));
      for (final path in paths) {
        expect(p.dirname(path), docs.path);
        expect(p.basename(path), matches(r'^report_[0-9a-f]{8}\.pdf$'));
      }
      expect(
        await Future.wait(paths.map((path) => File(path).readAsString())),
        ['%PDF one', '%PDF two'],
      );
      expect(groups.map((g) => g.title), ['PDF: report', 'PDF: report']);
      expect(groups.map((g) => g.type), [
        DocumentGroupType.importedPdf,
        DocumentGroupType.importedPdf,
      ]);
      expect(storedNames(), hasLength(2));
    });

    test('importing the same PDF again never replaces the earlier '
        'copy', () async {
      final source = await inboxFile('report.pdf', utf8.encode('%PDF'));

      final first = await service.groupAndConvertDocuments(
        filePaths: [source],
      );
      final second = await service.groupAndConvertDocuments(
        filePaths: [source],
      );

      expect(first.single.pdfPath, isNot(second.single.pdfPath));
      expect(storedNames(), hasLength(2));
    });

    test('a name with unsafe characters is stored under a safe one and keeps '
        'its title', () async {
      final source = await inboxFile('My scan (1).pdf', utf8.encode('%PDF'));

      final group = (await service.groupAndConvertDocuments(
        filePaths: [source],
        pdfFileTitle: (name) => 'Imported $name',
      )).single;

      expect(
        p.basename(group.pdfPath),
        matches(r'^My_scan__1__[0-9a-f]{8}\.pdf$'),
      );
      expect(group.title, 'Imported My scan (1)');
    });

    test('the copy counts as new even when the source is old', () async {
      final source = await inboxFile('old.pdf', utf8.encode('%PDF'));
      await File(source).setLastModified(DateTime(2020));
      final before = DateTime.now().subtract(const Duration(seconds: 5));

      final group = (await service.groupAndConvertDocuments(
        filePaths: [source],
      )).single;

      expect(File(group.pdfPath).lastModifiedSync().isAfter(before), isTrue);
    });

    test('a missing source fails', () async {
      await expectLater(
        service.groupAndConvertDocuments(
          filePaths: [p.join(inbox.path, 'gone.pdf')],
        ),
        throwsA(isA<Exception>()),
      );
      expect(storedNames(), isEmpty);
    });
  });

  group('scanned images', () {
    test('become one PDF with a unique name and a page count', () async {
      final pages = [await image('a.png'), await image('b.jpg')];

      final group = (await service.groupAndConvertDocuments(
        filePaths: pages,
      )).single;

      expect(group.type, DocumentGroupType.scannedImages);
      expect(group.originalCount, 2);
      expect(group.title, 'Scanned Documents (2 pages)');
      expect(p.dirname(group.pdfPath), docs.path);
      expect(
        p.basename(group.pdfPath),
        matches(r'^scanned_document_[0-9a-f]{8}\.pdf$'),
      );
      expect(
        await File(group.pdfPath).openRead(0, 4).expand((b) => b).toList(),
        utf8.encode('%PDF'),
      );
    });

    test('two scans get two names', () async {
      final page = await image('a.png');

      final first = await service.groupAndConvertDocuments(filePaths: [page]);
      final second = await service.groupAndConvertDocuments(filePaths: [page]);

      expect(first.single.pdfPath, isNot(second.single.pdfPath));
      expect(storedNames(), hasLength(2));
    });

    test('a name is not reused after its file is deleted', () async {
      final page = await image('a.png');
      final names = <String>{};

      for (var i = 0; i < 3; i++) {
        final pdf = (await service.groupAndConvertDocuments(
          filePaths: [page],
        )).single.pdfPath;
        expect(names.add(p.basename(pdf)), isTrue, reason: pdf);
        await File(pdf).delete();
      }
    });

    test('images and PDFs of one save are stored apart', () async {
      final page = await image('scan.png');
      final pdf = await inboxFile('scan.pdf', utf8.encode('%PDF'));

      final groups = await service.groupAndConvertDocuments(
        filePaths: [page, pdf],
        scannedDocumentsTitle: 'Scans',
        scannedDocumentsPagesTitle: (n) => '$n page',
      );

      expect(groups.map((g) => g.type), [
        DocumentGroupType.scannedImages,
        DocumentGroupType.importedPdf,
      ]);
      expect(groups.first.title, '1 page');
      expect(storedNames(), hasLength(2));
    });

    test('createPdfFromImages skips missing pages and needs at least one '
        'image', () async {
      await expectLater(
        service.createPdfFromImages(imagePaths: const [], fileName: 'x'),
        throwsA(isA<Exception>()),
      );

      final path = await service.createPdfFromImages(
        imagePaths: [p.join(inbox.path, 'gone.png'), await image('a.png')],
        fileName: 'out',
      );
      expect(path, p.join(docs.path, 'out.pdf'));
      expect(File(path).existsSync(), isTrue);
    });
  });
}
