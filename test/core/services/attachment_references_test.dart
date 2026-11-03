import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/attachment_references.dart';

String documentReference(List<String> urls) => jsonEncode({
  'resourceType': 'DocumentReference',
  'content': [
    for (final url in urls)
      {
        'attachment': {'url': url, 'title': 'x'},
      },
  ],
});

String media(String url) => jsonEncode({
  'resourceType': 'Media',
  'content': {'url': url, 'contentType': 'image/jpeg'},
});

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late AttachmentReferences refs;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    refs = AttachmentReferences(db);
  });

  tearDown(() => db.close());

  Future<void> insertResource(String id, String raw, {bool deleted = false}) =>
      db.customStatement(
        'INSERT INTO fhir_resource (id, resource_raw, deleted_at, updated_at) '
        'VALUES (?, ?, ?, ?)',
        [id, raw, if (deleted) 5 else null, 1],
      );

  Future<void> insertSession(
    String id, {
    String? filePaths,
    String? resources,
  }) => db.customStatement(
    'INSERT INTO processing_sessions (id, file_paths, resources) '
    'VALUES (?, ?, ?)',
    [id, filePaths, resources],
  );

  group('fromResourceRaw', () {
    test('lists the file urls of a DocumentReference', () async {
      final list = await refs.fromResourceRaw(
        documentReference([
          'file://scan.pdf',
          'https://example.org/remote.pdf',
          'file://sub/photo.jpg',
        ]),
        mode: OnUnparseable.skip,
      );

      expect(list.map((r) => r.url), [
        'file://scan.pdf',
        'file://sub/photo.jpg',
      ]);
      expect(list.map((r) => r.path), ['scan.pdf', 'sub/photo.jpg']);
      expect(list.map((r) => r.basename), ['scan.pdf', 'photo.jpg']);
    });

    test("reads Media's single content", () async {
      final list = await refs.fromResourceRaw(
        media('file://picture.jpg'),
        mode: OnUnparseable.skip,
      );

      expect(list.single.basename, 'picture.jpg');
    });

    test('decodes percent-encoded urls, Windows paths included', () async {
      final list = await refs.fromResourceRaw(
        documentReference([
          'file://My%20Scan.pdf',
          'file://C%3A%5CUsers%5Cana%5CDocuments%5Creport.pdf',
        ]),
        mode: OnUnparseable.skip,
      );

      expect(list.map((r) => r.path), [
        'My Scan.pdf',
        r'C:\Users\ana\Documents\report.pdf',
      ]);
      expect(list.map((r) => r.basename), ['My Scan.pdf', 'report.pdf']);
    });

    test('keeps a url that is not percent-encoded as written', () async {
      final list = await refs.fromResourceRaw(
        documentReference(['file://100%.pdf']),
        mode: OnUnparseable.skip,
      );

      expect(list.single.path, '100%.pdf');
    });

    test('an unreadable row is skipped for backups', () async {
      final list = await refs.fromResourceRaw(
        '{not json file://kept.pdf',
        mode: OnUnparseable.skip,
      );

      expect(list, isEmpty);
    });

    test('an unreadable row is kept as raw text for the cleaner', () async {
      final list = await refs.fromResourceRaw(
        '{not json file://Kept.pdf',
        mode: OnUnparseable.rawText,
      );

      expect(list.single.isRawText, isTrue);
      expect(list.single.refersTo('kept.pdf'), isTrue);
      expect(list.single.refersTo('other.pdf'), isFalse);
    });
  });

  group('matches', () {
    test('compares the basename raw and decoded, ignoring case', () {
      expect(refs.matches('scan.pdf', 'file://folder/Scan.PDF'), isTrue);
      expect(refs.matches('My Scan.pdf', 'file://My%20Scan.pdf'), isTrue);
      expect(refs.matches('My%20Scan.pdf', 'file://My Scan.pdf'), isTrue);
      expect(
        refs.matches('report.pdf', r'file://C:\Users\ana\Documents\report.pdf'),
        isTrue,
      );
      expect(
        refs.matches(
          'report.pdf',
          'file://C%3A%5CUsers%5Cana%5CDocuments%5Creport.pdf',
        ),
        isTrue,
      );
      expect(
        refs.matches(
          'report.pdf',
          'file:///var/mobile/Containers/Data/Application/X/Documents/report.pdf',
        ),
        isTrue,
      );
    });

    test('a different name or a partial match does not count', () {
      expect(refs.matches('scan.pdf', 'file://scan.pdf.bak'), isFalse);
      expect(refs.matches('can.pdf', 'file://scan.pdf'), isFalse);
      expect(refs.matches('scan.pdf', 'https://x.org/scan.pdf'), isFalse);
    });
  });

  group('referencedBasenames', () {
    test('covers live and deleted records and Media', () async {
      await insertResource('live', documentReference(['file://live.pdf']));
      await insertResource(
        'gone',
        documentReference(['file://Deleted%20One.pdf']),
        deleted: true,
      );
      await insertResource('media', media('file://Photo.JPG'));

      final names = await refs.referencedBasenames(includeSessions: false);

      expect(names, containsAll(['live.pdf', 'deleted one.pdf', 'photo.jpg']));
    });

    test("includes scan sessions' files and resources", () async {
      await insertSession(
        's1',
        filePaths: jsonEncode(['imports/page1.jpg', '/abs/docs/page2.jpg']),
        resources: jsonEncode([
          {
            'resourceType': 'DocumentReference',
            'content': [
              {
                'attachment': {'url': 'file://staged.pdf'},
              },
            ],
          },
        ]),
      );

      expect(
        await refs.referencedBasenames(),
        containsAll(['page1.jpg', 'page2.jpg', 'staged.pdf']),
      );
      expect(await refs.referencedBasenames(includeSessions: false), isEmpty);
    });

    test('an unreadable row still names the files it mentions', () async {
      await insertResource(
        'bad',
        '{"content": [{"attachment": {"url": "file://half.pdf"',
      );

      expect(await refs.referencedBasenames(), contains('half.pdf'));
    });
  });

  group('isReferenced', () {
    test('finds a file in a record, a deleted record or a session', () async {
      await insertResource('a', documentReference(['file://A.pdf']));
      await insertResource(
        'b',
        documentReference(['file://b.pdf']),
        deleted: true,
      );
      await insertSession('s', filePaths: jsonEncode(['c.jpg']));

      expect(await refs.isReferenced('a.pdf'), isTrue);
      expect(await refs.isReferenced('b.pdf'), isTrue);
      expect(await refs.isReferenced('c.jpg'), isTrue);
      expect(await refs.isReferenced('c.jpg', includeSessions: false), isFalse);
      expect(await refs.isReferenced('d.pdf'), isFalse);
    });

    test('an unreadable row keeps any file its text names', () async {
      await insertResource('bad', 'garbage mentioning Odd%20Name.pdf');

      expect(await refs.isReferenced('Odd Name.pdf'), isTrue);
      expect(await refs.isReferenced('other.pdf'), isFalse);
    });
  });

  group('rewriteUrls', () {
    test('rewrites the chosen urls and leaves the rest', () async {
      final raw = documentReference(['file://a.pdf', 'file://b.pdf']);

      final rewritten = refs.rewriteUrls(
        raw,
        (ref) => ref.basename == 'a.pdf' ? 'file://a_1.pdf' : null,
      );

      final urls = await refs.fromResourceRaw(
        rewritten!,
        mode: OnUnparseable.skip,
      );
      expect(urls.map((r) => r.url), ['file://a_1.pdf', 'file://b.pdf']);
    });

    test('returns null when nothing changed or the row is unreadable', () {
      expect(
        refs.rewriteUrls(documentReference(['file://a.pdf']), (_) => null),
        isNull,
      );
      expect(refs.rewriteUrls('{', (_) => 'file://x'), isNull);
    });

    test('rewrites Media content', () async {
      final rewritten = refs.rewriteUrls(
        media('file://p.jpg'),
        (_) => 'file://q.jpg',
      );

      expect(jsonDecode(rewritten!)['content']['url'], 'file://q.jpg');
    });
  });

  test('isDatabase recognises the database and its side files', () {
    expect(AttachmentReferences.isDatabase('/docs/db.sqlite'), isTrue);
    expect(AttachmentReferences.isDatabase('/docs/DB.sqlite-wal'), isTrue);
    expect(AttachmentReferences.isDatabase('/docs/report.pdf'), isFalse);
  });
}
