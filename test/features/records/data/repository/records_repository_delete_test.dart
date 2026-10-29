import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/data/repository/records_repository_impl.dart';

import '../../records_test_helpers.dart';

void main() {
  late AppDatabase db;
  late Directory docs;
  late RecordsRepositoryImpl repository;

  setUp(() async {
    db = openTestDatabase();
    docs = Directory.systemTemp.createTempSync('records_delete_docs');
    repository = await openRepository(db, documentsPath: docs.path);
  });

  tearDown(() async {
    await db.close();
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  Future<List<String>> rowIds() async => [
    for (final r in await db.select(db.fhirResource).get()) r.id,
  ];

  Future<List<String>> noteResourceIds() async => [
    for (final n in await db.select(db.recordNotes).get()) n.resourceId,
  ];

  Future<void> addNote(String resourceId) => repository.addRecordNote(
    resourceId: resourceId,
    content: 'note on $resourceId',
  );

  File file(String name) =>
      File('${docs.path}/$name')..writeAsBytesSync([1, 2, 3]);

  /// A DocumentReference attached to [related] (`Type/id`), as the
  /// attachments dialog creates it.
  Future<void> attachDocument(
    String id,
    String url, {
    List<String> related = const [],
  }) => insertResource(
    db,
    id: id,
    type: 'DocumentReference',
    raw: {
      'content': [
        {
          'attachment': {'contentType': 'application/pdf', 'url': url},
        },
      ],
      if (related.isNotEmpty)
        'context': {
          'related': [
            for (final r in related) {'reference': r},
          ],
        },
    },
  );

  test('deleting a record deletes its notes', () async {
    await insertResource(db, id: 'cond', type: 'Condition');
    await insertResource(db, id: 'other', type: 'Condition');
    await addNote('cond');
    await addNote('other');

    await repository.deleteResource('cond');

    expect(await rowIds(), ['other']);
    expect(await noteResourceIds(), ['other']);
  });

  test('deleting a record deletes the documents attached to it and their '
      'files', () async {
    await insertResource(db, id: 'cond', type: 'Condition');
    final scan = file('scan.pdf');
    await attachDocument(
      'doc',
      'file://scan.pdf',
      related: ['Condition/cond'],
    );

    await repository.deleteResource('cond');

    expect(await rowIds(), isEmpty);
    expect(scan.existsSync(), isFalse);
  });

  test('a document attached to another record too stays', () async {
    await insertResource(db, id: 'cond', type: 'Condition');
    await insertResource(db, id: 'enc', type: 'Encounter');
    final scan = file('scan.pdf');
    await attachDocument(
      'doc',
      'file://scan.pdf',
      related: ['Condition/cond', 'Encounter/enc'],
    );

    await repository.deleteResource('cond');

    expect(await rowIds(), unorderedEquals(['enc', 'doc']));
    expect(scan.existsSync(), isTrue);
  });

  test('deleting a document deletes its file', () async {
    final scan = file('lab results.pdf');
    await attachDocument('doc', 'file://lab%20results.pdf');

    await repository.deleteResourcesByIds(['doc']);

    expect(scan.existsSync(), isFalse);
  });

  test('a file another record still uses stays', () async {
    final scan = file('scan.pdf');
    await attachDocument('doc-1', 'file://scan.pdf');
    await attachDocument('doc-2', 'file://scan.pdf');

    await repository.deleteResource('doc-1');

    expect(await rowIds(), ['doc-2']);
    expect(scan.existsSync(), isTrue);
  });

  test('a file outside the app documents is never deleted', () async {
    final outside = File(
      '${Directory.systemTemp.path}/records_delete_outside.pdf',
    )..writeAsBytesSync([1]);
    addTearDown(() {
      if (outside.existsSync()) outside.deleteSync();
    });
    await attachDocument('doc', 'file://${outside.path}');
    await attachDocument('escape', 'file://../records_delete_outside.pdf');

    await repository.deleteResourcesByIds(['doc', 'escape']);

    expect(await rowIds(), isEmpty);
    expect(outside.existsSync(), isTrue);
  });

  test('deleting an encounter with its related records deletes all their '
      'notes', () async {
    await insertResource(db, id: 'enc', type: 'Encounter');
    await insertResource(
      db,
      id: 'obs',
      type: 'Observation',
      encounterId: 'enc',
    );
    await addNote('enc');
    await addNote('obs');

    await repository.deleteResourceWithRelated('enc');

    expect(await rowIds(), isEmpty);
    expect(await noteResourceIds(), isEmpty);
  });

  test('clearing the demo data deletes its notes and its PDF', () async {
    await insertSource(db, 'demo_data');
    await insertResource(
      db,
      id: 'demo-obs',
      type: 'Observation',
      sourceId: 'demo_data',
    );
    await addNote('demo-obs');
    final pdf = file('demo_medical_report.pdf');
    await insertResource(
      db,
      id: 'demo-doc',
      type: 'DocumentReference',
      sourceId: 'demo_data',
      raw: {
        'content': [
          {
            'attachment': {'url': 'file://demo_medical_report.pdf'},
          },
        ],
      },
    );

    await repository.clearDemoData();

    expect(await rowIds(), isEmpty);
    expect(await noteResourceIds(), isEmpty);
    expect(pdf.existsSync(), isFalse);
  });
}
