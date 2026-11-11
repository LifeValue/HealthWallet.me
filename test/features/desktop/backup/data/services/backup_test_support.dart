import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/attachment_references.dart';
import 'package:health_wallet/core/services/folder_access_service.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/attachment_sync_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the macOS bookmark channel: no bookmarks.
class FakeFolderAccess extends Fake implements FolderAccessService {
  @override
  Future<String?> bookmarkFor(String path) async => null;

  @override
  Future<String?> restore(String bookmark) async => bookmark;
}

/// The real [PathResolver] with a fixed documents directory.
class DocsPathResolver extends PathResolver {
  DocsPathResolver(this.documentsPath);

  final String documentsPath;

  @override
  Future<String> getDocumentsPath() async => documentsPath;
}

/// Fixed legacy attachment folders instead of the platform's.
class FixedLegacyFolders extends LegacyAttachmentFolders {
  FixedLegacyFolders([this.folders = const []]) : super(DocsPathResolver(''));

  final List<String> folders;

  @override
  Future<List<String>> roots() async => folders;
}

/// The app's database in memory, running [beforeStatement] before each
/// custom statement, so a test can act at a given step of a backup or a
/// restore.
class HookedDatabase extends AppDatabase {
  HookedDatabase()
    : super(
        NativeDatabase.memory(
          setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
        ),
      );

  Future<void> Function(String statement)? beforeStatement;

  @override
  Future<void> customStatement(String statement, [List<dynamic>? args]) async {
    await beforeStatement?.call(statement);
    return super.customStatement(statement, args);
  }
}

/// A backup folder, a documents folder and an in-memory database, in a real
/// temporary directory, with helpers for records and their files.
class BackupFixture {
  late Directory root;

  /// The backup folder.
  late Directory backups;

  /// The app's documents folder, where attachments live.
  late Directory docs;
  late HookedDatabase db;

  Future<void> setUp() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    root = await Directory.systemTemp.createTemp('backup_fixture');
    backups = Directory(p.join(root.path, 'backups'))..createSync();
    docs = Directory(p.join(root.path, 'docs'))..createSync();
    SharedPreferences.setMockInitialValues({'backupDirectory': backups.path});
    db = HookedDatabase();
  }

  Future<void> tearDown() async {
    await db.close();
    await root.delete(recursive: true);
  }

  BackupService service({List<String> legacyFolders = const []}) {
    final resolver = DocsPathResolver(docs.path);
    return BackupService(
      db,
      FakeFolderAccess(),
      resolver,
      AttachmentReferences(db),
      AttachmentSyncService(resolver),
      FixedLegacyFolders(legacyFolders),
    );
  }

  static String docRaw(List<String> urls) => jsonEncode({
    'resourceType': 'DocumentReference',
    'content': [
      for (final url in urls)
        {
          'attachment': {'url': url, 'title': 't'},
        },
    ],
  });

  Future<void> insertDocument(String id, List<String> urls) =>
      db.customStatement(
        'INSERT INTO fhir_resource (id, resource_type, resource_raw) '
        'VALUES (?, ?, ?)',
        [id, 'DocumentReference', docRaw(urls)],
      );

  File docFile(String name, [String? content]) => File(p.join(docs.path, name))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content ?? 'content of $name');

  Future<Map<String, dynamic>> rowOf(String table, String id) => db
      .customSelect(
        'SELECT * FROM $table WHERE id = ?',
        variables: [Variable.withString(id)],
      )
      .getSingle()
      .then((r) => r.data);

  Future<List<String>> urlsOf(String id) async {
    final raw = (await rowOf('fhir_resource', id))['resource_raw'] as String;
    return [
      for (final item in (jsonDecode(raw)['content'] as List))
        item['attachment']['url'] as String,
    ];
  }

  String filesDirOf(BackupEntry entry) =>
      '${entry.filePath.substring(0, entry.filePath.length - 3)}.files';

  List<String> docNames() => [
    for (final e in docs.listSync())
      if (e is File) p.basename(e.path),
  ]..sort();
}
