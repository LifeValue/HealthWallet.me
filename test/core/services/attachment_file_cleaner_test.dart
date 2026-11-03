import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/attachment_file_cleaner.dart';
import 'package:health_wallet/core/services/attachment_references.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:path/path.dart' as p;

class _FakePaths extends Fake implements PathResolver {
  _FakePaths(this.documentsPath);

  final String documentsPath;

  @override
  Future<String> getDocumentsPath() async => documentsPath;
}

/// Runs [onCheck] the first time a file's references are checked, to act
/// while the cleaner holds its transaction.
class _HookedReferences extends AttachmentReferences {
  _HookedReferences(super.db);

  Future<void> Function()? onCheck;
  Future<void> Function()? afterSnapshot;

  @override
  Future<bool> isReferenced(
    String basename, {
    bool includeSessions = true,
  }) async {
    final hook = onCheck;
    onCheck = null;
    if (hook != null) await hook();
    return super.isReferenced(basename, includeSessions: includeSessions);
  }

  @override
  Future<Set<String>> referencedBasenames({bool includeSessions = true}) async {
    final names = await super.referencedBasenames(
      includeSessions: includeSessions,
    );
    await afterSnapshot?.call();
    return names;
  }
}

String documentReference(List<String> urls) => jsonEncode({
  'resourceType': 'DocumentReference',
  'content': [
    for (final url in urls)
      {
        'attachment': {'url': url, 'title': 'x'},
      },
  ],
});

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory root;
  late Directory docs;
  late AppDatabase db;
  late _HookedReferences refs;

  /// The sweep's clock: by default 8 days ahead, so every file is old.
  late DateTime Function() now;

  AttachmentFileCleaner cleaner({String os = 'android', String? docsPath}) =>
      AttachmentFileCleaner.forTesting(
        db,
        _FakePaths(docsPath ?? docs.path),
        refs,
        operatingSystem: os,
        now: () => now(),
      );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('attachment_cleaner_test_');
    docs = await Directory(p.join(root.path, 'Documents')).create();
    db = AppDatabase(NativeDatabase.memory());
    refs = _HookedReferences(db);
    now = () => DateTime.now().add(const Duration(days: 8));
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) await root.delete(recursive: true);
  });

  File doc(String name) => File(p.join(docs.path, name));

  Future<File> writeDoc(String name) async {
    final file = doc(name);
    await file.parent.create(recursive: true);
    return file.writeAsString('content of $name');
  }

  Future<void> insertResource(String id, String raw, {bool deleted = false}) =>
      db.customStatement(
        'INSERT INTO fhir_resource (id, resource_raw, deleted_at, updated_at) '
        'VALUES (?, ?, ?, ?)',
        [id, raw, if (deleted) 5 else null, 1],
      );

  Future<void> insertSession(String id, {String? filePaths}) =>
      db.customStatement(
        'INSERT INTO processing_sessions (id, status, file_paths) '
        'VALUES (?, ?, ?)',
        [id, 'pending', filePaths],
      );

  group('deleteUnreferenced', () {
    test('deletes a top-level file no row refers to', () async {
      await writeDoc('scan.pdf');

      expect(await cleaner().deleteUnreferenced(['file://scan.pdf']), 1);

      expect(doc('scan.pdf').existsSync(), isFalse);
    });

    test('keeps a file a live row, a deleted row or a scan session still '
        'refers to', () async {
      await writeDoc('live.pdf');
      await writeDoc('tombstoned.pdf');
      await writeDoc('session.jpg');
      await insertResource('a', documentReference(['file://live.pdf']));
      await insertResource(
        'b',
        documentReference(['file://tombstoned.pdf']),
        deleted: true,
      );
      await insertSession('s', filePaths: jsonEncode(['session.jpg']));

      expect(
        await cleaner().deleteUnreferenced([
          'file://live.pdf',
          'file://tombstoned.pdf',
          'file://session.jpg',
        ]),
        0,
      );

      expect(doc('live.pdf').existsSync(), isTrue);
      expect(doc('tombstoned.pdf').existsSync(), isTrue);
      expect(doc('session.jpg').existsSync(), isTrue);
    });

    test('a row brought back before the check keeps its file', () async {
      await writeDoc('scan.pdf');
      // Purged, then received again from the peer before the file check.
      await insertResource('doc', documentReference(['file://scan.pdf']));

      expect(await cleaner().deleteUnreferenced(['file://scan.pdf']), 0);

      expect(doc('scan.pdf').existsSync(), isTrue);
    });

    for (final (label, url) in [
      (
        'a legacy iOS container path',
        'file:///var/mobile/Containers/Data/'
            'Application/OLD-ID/Documents/My Scan.pdf',
      ),
      (
        'an encoded Windows path',
        'file://C%3A%5CUsers%5Cana%5CDocuments%5CHealthWallet%5CDocuments'
            '%5CMy%20Scan.pdf',
      ),
      ('an encoded name', 'file://My%20Scan.pdf'),
      ('another case', 'file://MY SCAN.PDF'),
    ]) {
      test('keeps a file another row names by $label', () async {
        await writeDoc('My Scan.pdf');
        await insertResource('other', documentReference([url]));

        expect(await cleaner().deleteUnreferenced(['file://My Scan.pdf']), 0);

        expect(doc('My Scan.pdf').existsSync(), isTrue);
      });
    }

    for (final (label, url) in [
      ('an encoded name', 'file://My%20Scan.pdf'),
      ('another case', 'file://my scan.PDF'),
      (
        'a legacy iOS container path',
        'file:///var/mobile/Containers/Data/'
            'Application/OLD-ID/Documents/My Scan.pdf',
      ),
      (
        'an encoded Windows path',
        'file://C%3A%5CUsers%5Cana%5CDocuments%5CHealthWallet%5CDocuments'
            '%5CMy%20Scan.pdf',
      ),
    ]) {
      test('a purged row naming its file by $label deletes it', () async {
        await writeDoc('My Scan.pdf');

        expect(await cleaner().deleteUnreferenced([url]), 1);

        expect(doc('My Scan.pdf').existsSync(), isFalse);
      });
    }

    test('a purged row naming its file by an absolute path in Documents '
        'deletes it', () async {
      await writeDoc('scan.pdf');

      expect(
        await cleaner().deleteUnreferenced([
          'file://${p.join(docs.path, 'scan.pdf')}',
        ]),
        1,
      );

      expect(doc('scan.pdf').existsSync(), isFalse);
    });

    test('keeps a file an unreadable row mentions', () async {
      await writeDoc('scan.pdf');
      await insertResource('broken', '{"content": [file://scan.pdf');

      expect(await cleaner().deleteUnreferenced(['file://scan.pdf']), 0);

      expect(doc('scan.pdf').existsSync(), isTrue);
    });

    test('keeps a file a row names with a url that is not valid '
        'percent-encoding', () async {
      await writeDoc('50%.pdf');
      await insertResource('odd', documentReference(['file://50%.pdf']));

      expect(await cleaner().deleteUnreferenced(['file://50%.pdf']), 0);

      expect(doc('50%.pdf').existsSync(), isTrue);
    });

    test('never deletes a file in a subfolder, nor a top-level file of the '
        'same name', () async {
      await writeDoc('ai_models/x.gguf');
      await writeDoc('imports/scan.jpg');
      await writeDoc('x.gguf');

      expect(
        await cleaner().deleteUnreferenced([
          'file://ai_models/x.gguf',
          'file://ai_models%2Fx.gguf',
          'file://${p.join(docs.path, 'imports', 'scan.jpg')}',
          'file://../Documents/x.gguf',
        ]),
        0,
      );

      expect(doc('ai_models/x.gguf').existsSync(), isTrue);
      expect(doc('imports/scan.jpg').existsSync(), isTrue);
      expect(doc('x.gguf').existsSync(), isTrue);
    });

    test('never deletes a directory, a dot-file, the database, a log or a '
        '.db file', () async {
      await Directory(p.join(docs.path, 'ai_models')).create();
      final names = [
        '.hidden',
        'db.sqlite',
        'db.sqlite-wal',
        'DB.SQLITE-shm',
        'scan_debug.log',
        'cache.db',
        'OTHER.DB',
      ];
      for (final name in names) {
        await writeDoc(name);
      }

      expect(
        await cleaner().deleteUnreferenced([
          'file://ai_models',
          for (final name in names) 'file://$name',
        ]),
        0,
      );

      expect(Directory(p.join(docs.path, 'ai_models')).existsSync(), isTrue);
      for (final name in names) {
        expect(doc(name).existsSync(), isTrue, reason: name);
      }
    });

    test('never deletes a symbolic link or what it points at', () async {
      final outside = File(p.join(root.path, 'outside.pdf'))
        ..writeAsStringSync('not an attachment');
      await Link(p.join(docs.path, 'link.pdf')).create(outside.path);

      expect(await cleaner().deleteUnreferenced(['file://link.pdf']), 0);

      expect(Link(p.join(docs.path, 'link.pdf')).existsSync(), isTrue);
      expect(outside.existsSync(), isTrue);
    });

    test('deletes nothing when the documents directory is a link', () async {
      await writeDoc('scan.pdf');
      final linkedRoot = p.join(root.path, 'LinkedDocuments');
      await Link(linkedRoot).create(docs.path);

      expect(
        await cleaner(
          docsPath: linkedRoot,
        ).deleteUnreferenced(['file://scan.pdf']),
        0,
      );
      expect(await cleaner(docsPath: linkedRoot).sweep(), 0);

      expect(doc('scan.pdf').existsSync(), isTrue);
    });

    test('deletes nothing on Linux', () async {
      await writeDoc('scan.pdf');

      expect(
        await cleaner(os: 'linux').deleteUnreferenced(['file://scan.pdf']),
        0,
      );

      expect(doc('scan.pdf').existsSync(), isTrue);
    });

    test('ignores urls of another scheme', () async {
      await writeDoc('scan.pdf');

      expect(
        await cleaner().deleteUnreferenced(['https://example.com/scan.pdf']),
        0,
      );

      expect(doc('scan.pdf').existsSync(), isTrue);
    });

    test('checks and deletes each file in one transaction: a sync write '
        'issued during the check lands after the delete', () async {
      await writeDoc('scan.pdf');
      final checking = Completer<void>();
      refs.onCheck = () async {
        checking.complete();
        // Room for the write below to commit, if it didn't wait.
        await Future<void>.delayed(const Duration(milliseconds: 50));
      };

      final cleaning = cleaner().deleteUnreferenced(['file://scan.pdf']);
      await checking.future;
      bool? fileExistedAtCommit;
      final write = insertResource(
        'late',
        documentReference(['file://scan.pdf']),
      ).then((_) => fileExistedAtCommit = doc('scan.pdf').existsSync());

      expect(await cleaning, 1);
      await write;
      expect(fileExistedAtCommit, isFalse);
    });
  });

  group('fileUrlsOf', () {
    test('lists every file url of a record, and none of an unreadable '
        'one', () async {
      expect(
        await cleaner().fileUrlsOf(
          documentReference(['file://a.pdf', 'https://x/b.pdf']),
        ),
        ['file://a.pdf'],
      );
      expect(await cleaner().fileUrlsOf('{not json file://a.pdf'), isEmpty);
    });
  });

  group('sweep', () {
    test('deletes old top-level files nothing refers to and keeps the '
        'rest', () async {
      await writeDoc('orphan.pdf');
      await writeDoc('live.pdf');
      await writeDoc('tombstoned.pdf');
      await writeDoc('session.jpg');
      await writeDoc('ai_models/x.gguf');
      await writeDoc('db.sqlite');
      await writeDoc('processing_debug.log');
      await writeDoc('.DS_Store');
      await insertResource('a', documentReference(['file://live.pdf']));
      await insertResource(
        'b',
        documentReference(['file://Tombstoned.PDF']),
        deleted: true,
      );
      await insertSession(
        's',
        filePaths: jsonEncode([p.join(docs.path, 'session.jpg')]),
      );

      expect(await cleaner().sweep(), 1);

      expect(doc('orphan.pdf').existsSync(), isFalse);
      for (final name in [
        'live.pdf',
        'tombstoned.pdf',
        'session.jpg',
        'ai_models/x.gguf',
        'db.sqlite',
        'processing_debug.log',
        '.DS_Store',
      ]) {
        expect(doc(name).existsSync(), isTrue, reason: name);
      }
    });

    test('keeps a file not yet 7 days old', () async {
      await writeDoc('fresh.pdf');
      now = () => DateTime.now().add(const Duration(days: 6));

      expect(await cleaner().sweep(), 0);

      expect(doc('fresh.pdf').existsSync(), isTrue);
    });

    test('ages a file by the later of its modified and changed times: a '
        'fresh copy with an old modified time is kept', () async {
      final file = await writeDoc('copied.pdf');
      await file.setLastModified(
        DateTime.now().subtract(const Duration(days: 60)),
      );
      now = DateTime.now;

      expect(await cleaner().sweep(), 0);
      expect(file.existsSync(), isTrue);

      now = () => DateTime.now().add(const Duration(days: 8));
      expect(await cleaner().sweep(), 1);
      expect(file.existsSync(), isFalse);
    });

    test('keeps a file whose row is written after the sweep listed the '
        'references', () async {
      await writeDoc('received.pdf');
      refs.afterSnapshot = () =>
          insertResource('synced', documentReference(['file://received.pdf']));

      expect(await cleaner().sweep(), 0);

      expect(doc('received.pdf').existsSync(), isTrue);
    });

    test('keeps a file an unreadable row mentions', () async {
      await writeDoc('scan.pdf');
      await insertResource('broken', 'not json, file://scan.pdf');

      expect(await cleaner().sweep(), 0);

      expect(doc('scan.pdf').existsSync(), isTrue);
    });

    test('never deletes a symbolic link or what it points at', () async {
      final outside = File(p.join(root.path, 'outside.pdf'))
        ..writeAsStringSync('not an attachment');
      await Link(p.join(docs.path, 'link.pdf')).create(outside.path);

      expect(await cleaner().sweep(), 0);

      expect(Link(p.join(docs.path, 'link.pdf')).existsSync(), isTrue);
      expect(outside.existsSync(), isTrue);
    });

    for (final os in ['android', 'ios', 'macos', 'windows']) {
      test('runs on $os', () async {
        await writeDoc('orphan.pdf');

        expect(await cleaner(os: os).sweep(), 1);
      });
    }

    test('does not run on Linux', () async {
      await writeDoc('orphan.pdf');

      expect(await cleaner(os: 'linux').sweep(), 0);

      expect(doc('orphan.pdf').existsSync(), isTrue);
    });

    test('a second call while a sweep runs joins it', () async {
      await writeDoc('orphan.pdf');
      final c = cleaner();

      final results = await Future.wait([c.sweep(), c.sweep()]);

      expect(results, [1, 1]);
      expect(doc('orphan.pdf').existsSync(), isFalse);
    });
  });
}
