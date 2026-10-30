import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/features/processing/data/services/pdf_generation_service.dart';
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/records/domain/entity/encounter/encounter.dart';

import '../../../desktop/lww_sync/lww_sync_test_helpers.dart';

class _DocsPathResolver extends PathResolver {
  _DocsPathResolver(this.docs);

  final String docs;

  @override
  Future<String> getDocumentsPath() async => docs;
}

/// Hands back the given groups instead of rendering PDFs.
class _FakePdfGenerationService extends Fake implements PdfGenerationService {
  List<DocumentGroup> groups = [];
  Exception? error;
  List<String>? requested;

  @override
  Future<List<DocumentGroup>> groupAndConvertDocuments({
    required List<String> filePaths,
    String? scannedDocumentsTitle,
    String Function(int)? scannedDocumentsPagesTitle,
    String Function(String)? pdfFileTitle,
  }) async {
    requested = filePaths;
    final e = error;
    if (e != null) throw e;
    return groups;
  }
}

void main() {
  late TestDirs dirs;
  late AppDatabase db;
  late _FakePdfGenerationService pdfs;
  late DocumentReferenceService service;

  setUp(() async {
    dirs = await TestDirs.create();
    db = openTestDatabase();
    pdfs = _FakePdfGenerationService();
    service = DocumentReferenceService(
      db,
      pdfs,
      _DocsPathResolver(dirs.docs.path),
    );
  });

  tearDown(() async {
    await db.close();
    await dirs.dispose();
  });

  Future<DocumentGroup> pdfGroup(String name, String title) async {
    final file = await dirs.writeDoc(name, utf8.encode('%PDF $name'));
    return DocumentGroup(
      type: DocumentGroupType.importedPdf,
      pdfPath: file.path,
      title: title,
      originalCount: 1,
    );
  }

  Future<void> doc(
    String id, {
    String sourceId = 's',
    String? encounterId = 'e',
    String type = 'DocumentReference',
    Object? raw,
    int? deletedAt,
  }) => db.customStatement(
    'INSERT INTO fhir_resource (id, source_id, resource_type, resource_raw, '
    'encounter_id, updated_at, deleted_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
    [
      id,
      sourceId,
      type,
      jsonEncode(raw ?? {'resourceType': type}),
      encounterId,
      ms(at(0)),
      deletedAt,
    ],
  );

  Map<String, dynamic> linkedTo(String encounterId) => {
    'resourceType': 'DocumentReference',
    'context': {
      'encounter': [
        {'reference': 'Encounter/$encounterId'},
      ],
    },
  };

  group('saveGroupedDocumentsAsFhirRecords', () {
    test('stores one DocumentReference per group with a relative file '
        'url', () async {
      pdfs.groups = [await pdfGroup('a.pdf', 'PDF: a')];

      final ids = await service.saveGroupedDocumentsAsFhirRecords(
        filePaths: ['/in/a.pdf'],
        patientId: 'pat-1',
        encounter: const Encounter(resourceId: 'enc-1'),
        sourceId: 'wallet-1',
      );

      expect(pdfs.requested, ['/in/a.pdf']);
      final row = (await fetchRow(
        db,
        'fhir_resource',
        'wallet-1_${ids.single}',
      ))!;
      expect(row['source_id'], 'wallet-1');
      expect(row['resource_id'], ids.single);
      expect(row['resource_type'], 'DocumentReference');
      expect(row['title'], 'PDF: a');
      expect(row['encounter_id'], 'enc-1');
      expect(row['subject_id'], 'pat-1');
      expect(row['date'], isNotNull);
      expect(row['deleted_at'], isNull);

      final raw = jsonDecode(row['resource_raw'] as String);
      final attachment = raw['content'][0]['attachment'];
      expect(attachment['url'], 'file://a.pdf');
      expect(attachment['title'], 'PDF: a');
      expect(attachment['contentType'], 'application/pdf');
      expect(attachment['size'], utf8.encode('%PDF a.pdf').length);
      expect(raw['subject']['reference'], 'Patient/pat-1');
      expect(raw['context']['encounter'][0]['reference'], 'Encounter/enc-1');
    });

    test('without an encounter the record has no visit', () async {
      pdfs.groups = [await pdfGroup('b.pdf', 'PDF: b')];

      final ids = await service.saveGroupedDocumentsAsFhirRecords(
        filePaths: ['/in/b.pdf'],
        patientId: 'pat-1',
        sourceId: 'wallet-1',
      );

      final row = (await fetchRow(
        db,
        'fhir_resource',
        'wallet-1_${ids.single}',
      ))!;
      expect(row['encounter_id'], isNull);
      expect(jsonDecode(row['resource_raw'] as String)['context'], isNull);
    });

    test('BUG: two groups saved in the same millisecond get the same id, so '
        'the second replaces the first', () async {
      pdfs.groups = [
        await pdfGroup('a.pdf', 'PDF: a'),
        await pdfGroup('b.pdf', 'PDF: b'),
      ];

      final ids = await service.saveGroupedDocumentsAsFhirRecords(
        filePaths: ['/in/a.pdf', '/in/b.pdf'],
        patientId: 'pat-1',
        sourceId: 'wallet-1',
      );

      expect(ids.toSet(), hasLength(2));
      expect(await countRows(db, 'fhir_resource'), 2);
    }, skip: 'ids come from DateTime.now().millisecondsSinceEpoch');

    test('wraps a failure in an exception', () async {
      pdfs.error = Exception('render failed');

      await expectLater(
        service.saveGroupedDocumentsAsFhirRecords(
          filePaths: ['/in/a.pdf'],
          patientId: 'pat-1',
          sourceId: 'wallet-1',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            contains('render failed'),
          ),
        ),
      );
    });
  });

  group('deleteDocumentReferences', () {
    test('tombstones the DocumentReferences of the source and visit, in '
        'ms', () async {
      await doc('doc');
      await doc('other-visit', encounterId: 'x');
      await doc('other-source', sourceId: 't');
      await doc('obs', type: 'Observation');
      final before = DateTime.now().millisecondsSinceEpoch;

      await service.deleteDocumentReferences(sourceId: 's', encounterId: 'e');

      final row = (await fetchRow(db, 'fhir_resource', 'doc'))!;
      expect(row['deleted_at'] as int, greaterThanOrEqualTo(before));
      expect(row['updated_at'], row['deleted_at']);
      for (final id in ['other-visit', 'other-source', 'obs']) {
        expect(
          (await fetchRow(db, 'fhir_resource', id))!['deleted_at'],
          isNull,
        );
      }
      expect(await countRows(db, 'fhir_resource'), 4);
    });

    test('a replacement saved afterwards is live', () async {
      await doc('doc');
      await service.deleteDocumentReferences(sourceId: 's', encounterId: 'e');
      pdfs.groups = [await pdfGroup('c.pdf', 'PDF: c')];

      await service.saveGroupedDocumentsAsFhirRecords(
        filePaths: ['/in/c.pdf'],
        patientId: 'pat-1',
        encounter: const Encounter(resourceId: 'e'),
        sourceId: 's',
      );

      final docs = await service.getAllDocumentReferences(sourceId: 's');
      expect(docs.single.title, 'PDF: c');
    });
  });

  group('reads', () {
    test('getAllDocumentReferences lists live DocumentReferences', () async {
      await doc('a');
      await doc('b', sourceId: 't');
      await doc('gone', deletedAt: ms(at(0)));
      await doc('obs', type: 'Observation');

      expect(
        (await service.getAllDocumentReferences()).map((d) => d.id),
        unorderedEquals(['a', 'b']),
      );
      expect(
        (await service.getAllDocumentReferences(sourceId: 't')).map(
          (d) => d.id,
        ),
        ['b'],
      );
    });

    test('getDocumentReferencesForEncounter matches the context '
        'reference', () async {
      await doc('linked', raw: linkedTo('enc-1'));
      await doc('elsewhere', raw: linkedTo('enc-2'));
      await doc('unlinked');
      await doc('broken-context', raw: {'context': 'oops'});
      await doc('gone', raw: linkedTo('enc-1'), deletedAt: ms(at(0)));
      await db.customStatement(
        'INSERT INTO fhir_resource (id, resource_type, resource_raw) '
        "VALUES ('bad', 'DocumentReference', 'not json')",
      );

      expect(
        (await service.getDocumentReferencesForEncounter(
          encounterId: 'enc-1',
        )).map((d) => d.id),
        ['linked'],
      );
    });

    test('linkDocumentReferenceToEncounter rewrites the context of a live '
        'document', () async {
      await doc(
        'scanner-app_doc-1',
        sourceId: 'scanner-app',
        encounterId: null,
      );

      await service.linkDocumentReferenceToEncounter(
        documentReferenceResourceId: 'doc-1',
        encounterId: 'enc-9',
      );

      final row = (await fetchRow(db, 'fhir_resource', 'scanner-app_doc-1'))!;
      expect(row['encounter_id'], 'enc-9');
      expect(
        jsonDecode(
          row['resource_raw'] as String,
        )['context']['encounter'][0]['reference'],
        'Encounter/enc-9',
      );
    });

    test('linkDocumentReferenceToEncounter fails for a missing or deleted '
        'document', () async {
      await doc('s_gone', deletedAt: ms(at(0)));

      for (final id in ['gone', 'missing']) {
        await expectLater(
          service.linkDocumentReferenceToEncounter(
            documentReferenceResourceId: id,
            encounterId: 'enc-9',
            sourceId: 's',
          ),
          throwsA(isA<Exception>()),
        );
      }
      expect(
        (await fetchRow(db, 'fhir_resource', 's_gone'))!['encounter_id'],
        'e',
      );
    });
  });
}
