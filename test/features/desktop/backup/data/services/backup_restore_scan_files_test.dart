import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/attachment_references.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/backup/data/services/scan_file_sweeper.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/attachment_sync_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../lww_sync/lww_sync_test_helpers.dart';
import 'backup_test_support.dart';

void main() {
  late TestDirs dirs;
  late Directory imports;
  late Directory cache;
  late AppDatabase db;
  late BackupService service;

  final old = DateTime.now().subtract(const Duration(days: 2));

  /// A day and a half from now: what the test wrote is then old enough.
  final later = DateTime.now().add(const Duration(hours: 36));

  setUp(() async {
    dirs = await TestDirs.create();
    final backups = Directory(p.join(dirs.root.path, 'backups'))..createSync();
    SharedPreferences.setMockInitialValues({'backupDirectory': backups.path});
    imports = Directory(p.join(dirs.docs.path, ScanFileSweeper.importsDirName))
      ..createSync();
    cache = Directory(p.join(dirs.docs.path, TempFileSweeper.ocrCacheDirName))
      ..createSync();
    db = openTestDatabase();
    final paths = DocsPathResolver(dirs.docs.path);
    service = BackupService(
      db,
      FakeFolderAccess(),
      paths,
      AttachmentReferences(db),
      AttachmentSyncService(paths),
      FixedLegacyFolders(),
    );
  });

  tearDown(() async {
    await db.close();
    await dirs.dispose();
  });

  File write(Directory dir, String name, {DateTime? modified}) =>
      File(p.join(dir.path, name))
        ..writeAsStringSync('content of $name')
        ..setLastModifiedSync(modified ?? old);

  /// The page-image cache key of the imported PDF [name], as the preview
  /// renders it.
  String keyOf(String name, {double dpi = 72}) {
    final file = File(p.join(imports.path, name));
    final stat = file.statSync();
    return TempFileSweeper.pdfPageCacheKey(
      '${imports.path}/$name',
      stat.size,
      stat.modified,
      dpi,
    );
  }

  /// A scan session of the PDF `imports/<name>` with its preview pages, and
  /// with a page map naming [mapKey]'s pages when given.
  Future<void> scan(String id, String name, {String? mapKey}) async {
    write(imports, '$name.pdf');
    for (final dpi in [72.0, 200.0]) {
      final key = keyOf('$name.pdf', dpi: dpi);
      write(cache, '${key}_page_1.jpg');
      write(cache, '$key.json');
    }
    if (mapKey != null) {
      write(cache, '${mapKey}_page_1.jpg');
      File(p.join(cache.path, TempFileSweeper.sessionPageMapName(id)))
        ..writeAsStringSync(
          jsonEncode({
            'pages': {
              '${mapKey}_page_1.jpg': {'file': 'imports/$name.pdf', 'page': 1},
            },
            'previewKeys': [mapKey],
            'ocrKeys': <String>[],
          }),
        )
        ..setLastModifiedSync(old);
    }
    await db.customStatement(
      'INSERT INTO processing_sessions (id, file_paths, status) '
      "VALUES (?, ?, 'Draft')",
      [
        id,
        jsonEncode(['imports/$name.pdf']),
      ],
    );
  }

  List<String> names(Directory dir) => [
    for (final e in dir.listSync()) p.basename(e.path),
  ]..sort();

  const kept = '11111111-1111-4111-8111-111111111111';
  const dropped = '22222222-2222-4222-8222-222222222222';
  final keptMapKey = 'a' * 64;
  final droppedMapKey = 'b' * 64;

  test('start-up deletes the files of the scans a restore removed and keeps '
      'those of the scans it restored', () async {
    await scan(kept, 'kept', mapKey: keptMapKey);
    final backup = await service.createSnapshot();
    await scan(dropped, 'dropped', mapKey: droppedMapKey);
    final keptCache = names(cache)
        .where((n) => !n.startsWith(droppedMapKey))
        .where((n) => !n.startsWith(dropped))
        .where((n) => !n.startsWith(keyOf('dropped.pdf')))
        .where((n) => !n.startsWith(keyOf('dropped.pdf', dpi: 200)))
        .toList();

    await service.restoreFromFile(backup.filePath);
    await service.cleanUpOnStartup();

    expect(names(imports), ['kept.pdf']);
    expect(names(cache), keptCache);
    expect(
      names(cache),
      containsAll([
        TempFileSweeper.sessionPageMapName(kept),
        '${keptMapKey}_page_1.jpg',
        '${keyOf('kept.pdf')}_page_1.jpg',
        '${keyOf('kept.pdf')}.json',
      ]),
    );
  });

  test('keeps the files of the scans a kept safety copy holds, until it '
      'expires', () async {
    final backup = await service.createSnapshot();
    await scan(dropped, 'dropped', mapKey: droppedMapKey);
    final before = names(cache);
    await service.createSnapshot(name: 'Before restore', isSafetyCopy: true);
    await service.restoreFromFile(backup.filePath);

    expect(await service.removeDroppedScanFiles(now: later), 0);
    expect(names(imports), ['dropped.pdf']);
    expect(names(cache), before);

    final expired = DateTime.now().add(const Duration(days: 31));
    expect(await service.deleteExpiredSafetyCopies(now: expired), 1);
    expect(await service.removeDroppedScanFiles(now: expired), 2);
    expect(names(imports), isEmpty);
    expect(names(cache), isEmpty);
  });

  test(
    'keeps a file younger than a day: its scan may not be written yet',
    () async {
      write(imports, 'arriving.pdf', modified: DateTime.now());

      expect(await service.removeDroppedScanFiles(), 0);

      expect(names(imports), ['arriving.pdf']);
    },
  );

  test('keeps an original the page map of a kept scan names', () async {
    // An edited scan stores only its preview pages; its page map names the
    // original.
    await scan(kept, 'kept', mapKey: keptMapKey);
    await db.customStatement(
      'UPDATE processing_sessions SET file_paths = ?',
      [
        jsonEncode(['pdf_preview_cache/${keptMapKey}_page_1.jpg']),
      ],
    );

    expect(await service.removeDroppedScanFiles(now: later), 0);

    expect(names(imports), ['kept.pdf']);
  });

  test('deletes nothing when a kept scan\'s page map is unreadable', () async {
    await scan(kept, 'kept', mapKey: keptMapKey);
    File(
      p.join(cache.path, TempFileSweeper.sessionPageMapName(kept)),
    ).writeAsStringSync('{');
    write(imports, 'orphan.pdf');

    expect(await service.removeDroppedScanFiles(now: later), 0);

    expect(names(imports), ['kept.pdf', 'orphan.pdf']);
  });

  test('leaves files that are not a scan\'s in the page cache', () async {
    write(cache, 'notes.txt');
    write(cache, 'not-a-session.pages.json');
    write(imports, 'orphan.pdf');

    await service.removeDroppedScanFiles(now: later);

    expect(names(imports), isEmpty);
    expect(names(cache), ['not-a-session.pages.json', 'notes.txt']);
  });
}
