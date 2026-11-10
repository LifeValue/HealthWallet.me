import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/processing/data/services/pdf_generation_service.dart';
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/records/domain/entity/encounter/encounter.dart';

import '../../../records/records_test_helpers.dart';

/// One PDF per file, written into the documents directory.
class _FakePdfGenerationService extends Fake implements PdfGenerationService {
  _FakePdfGenerationService(this.docs);

  final Directory docs;
  bool fail = false;

  @override
  Future<List<DocumentGroup>> groupAndConvertDocuments({
    required List<String> filePaths,
    String? scannedDocumentsTitle,
    String Function(int)? scannedDocumentsPagesTitle,
    String Function(String)? pdfFileTitle,
  }) async {
    if (fail) throw const FileSystemException('no space left');
    return [
      for (final path in filePaths)
        DocumentGroup(
          type: DocumentGroupType.importedPdf,
          pdfPath: (File(
            '${docs.path}/${path.split('/').last}.pdf',
          )..writeAsBytesSync([1])).path,
          title: path,
          originalCount: 1,
        ),
    ];
  }
}

void main() {
  late AppDatabase db;
  late Directory docs;
  late _FakePdfGenerationService pdfs;
  late DocumentReferenceService service;

  const encounter = Encounter(id: 'enc', resourceId: 'enc');

  setUp(() {
    db = openTestDatabase();
    docs = Directory.systemTemp.createTempSync('document_reference_docs');
    pdfs = _FakePdfGenerationService(docs);
    service = DocumentReferenceService(
      db,
      pdfs,
      DocumentsPathResolver(docs.path),
    );
  });

  tearDown(() async {
    await db.close();
    docs.deleteSync(recursive: true);
  });

  /// The titles of the live documents, or of the deleted ones.
  Future<List<String>> documentTitles({bool deleted = false}) async => [
    for (final row
        in await (db.select(db.fhirResource)..where(
              (r) =>
                  r.resourceType.equals('DocumentReference') &
                  (deleted ? r.deletedAt.isNotNull() : r.deletedAt.isNull()),
            ))
            .get())
      row.title ?? '',
  ];

  Future<void> saveSession(String sessionId, List<String> files) =>
      service.replaceSessionDocuments(
        sessionId: sessionId,
        filePaths: files,
        patientId: 'pat',
        encounter: encounter,
        sourceId: 'wallet-pat',
      );

  test('saving a session again rewrites its documents in place', () async {
    await saveSession('session-1', ['scan-a']);
    await saveSession('session-1', ['scan-a', 'scan-b']);

    expect(await documentTitles(), unorderedEquals(['scan-a', 'scan-b']));
    expect(await documentTitles(deleted: true), isEmpty);
  });

  test('a save with fewer documents removes the rest', () async {
    await saveSession('session-1', ['scan-a', 'scan-b']);
    await saveSession('session-1', ['scan-a']);

    expect(await documentTitles(), ['scan-a']);
    // Tombstoned, so the paired device drops it too.
    expect(await documentTitles(deleted: true), ['scan-b']);
  });

  test(
    'a session gets the same document ids on every device, so a handover '
    'saved on the phone and on the desktop is one record',
    () {
      expect(
        DocumentReferenceService.sessionDocumentId('session-1', 0),
        DocumentReferenceService.sessionDocumentId('session-1', 0),
      );
      expect(
        DocumentReferenceService.sessionDocumentId('session-1', 0),
        isNot(DocumentReferenceService.sessionDocumentId('session-1', 1)),
      );
      expect(
        DocumentReferenceService.sessionDocumentId('session-1', 0),
        isNot(DocumentReferenceService.sessionDocumentId('session-2', 0)),
      );
    },
  );

  test('another session\'s documents on the same encounter stay', () async {
    await saveSession('session-1', ['first visit scan']);
    await saveSession('session-2', ['second visit scan']);

    expect(
      await documentTitles(),
      unorderedEquals(['first visit scan', 'second visit scan']),
    );
  });

  test('a file attached by hand to the encounter stays', () async {
    await insertResource(
      db,
      id: 'wallet-pat_attached',
      type: 'DocumentReference',
      sourceId: 'wallet-pat',
      encounterId: 'enc',
      title: 'attached by hand',
    );

    await saveSession('session-1', ['scan-a']);

    expect(
      await documentTitles(),
      unorderedEquals(['attached by hand', 'scan-a']),
    );
  });

  test('when the new PDFs fail, the earlier documents stay', () async {
    await saveSession('session-1', ['scan-a']);
    pdfs.fail = true;

    await expectLater(saveSession('session-1', ['scan-b']), throwsException);

    expect(await documentTitles(), ['scan-a']);
  });
}
