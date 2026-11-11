import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'backup_test_support.dart';

void main() {
  final fx = BackupFixture();

  setUp(fx.setUp);
  tearDown(fx.tearDown);

  final old = DateTime.now().subtract(const Duration(hours: 1));

  /// An hour from now: what was written in the test is then old enough.
  final later = DateTime.now().add(const Duration(hours: 1));

  /// What an app killed during a backup leaves: the `.db`, maybe part of
  /// `.files/` and maybe the metadata's `.tmp`. The files are an hour old.
  void interruptedBackup(
    String base, {
    bool withFiles = true,
    bool withTmp = true,
  }) {
    File(p.join(fx.backups.path, '$base.db'))
      ..writeAsStringSync('a full copy of the health data')
      ..setLastModifiedSync(old);
    if (withFiles) {
      final files = Directory(p.join(fx.backups.path, '$base.files'))
        ..createSync();
      File(p.join(files.path, 'scan.pdf'))
        ..writeAsStringSync('scan')
        ..setLastModifiedSync(old);
    }
    if (withTmp) {
      File(p.join(fx.backups.path, '$base.db.meta.json.tmp'))
        ..writeAsStringSync('{')
        ..setLastModifiedSync(old);
    }
  }

  List<String> backupNames() => [
    for (final e in fx.backups.listSync()) p.basename(e.path),
  ]..sort();

  test('start-up removes what a backup killed while writing its database '
      'left', () async {
    interruptedBackup('healthwallet_backup_1700000000000', withFiles: false);
    interruptedBackup(
      'October_1700000000001',
      withFiles: false,
      withTmp: false,
    );

    await fx.service().cleanUpOnStartup();

    expect(backupNames(), isEmpty);
  });

  test('removes the database, files and metadata .tmp of an interrupted '
      'backup', () async {
    interruptedBackup('healthwallet_backup_1700000000000');
    interruptedBackup('October_1700000000001', withTmp: false);

    expect(await fx.service().removeBackupLeftovers(now: later), 2);

    expect(backupNames(), isEmpty);
  });

  test('a complete backup is never touched, however old', () async {
    final service = fx.service();
    fx.docFile('scan.pdf');
    await fx.insertDocument('d1', ['file://scan.pdf']);
    final entry = await service.createSnapshot();
    final before = backupNames();

    expect(
      await service.removeBackupLeftovers(
        now: DateTime.now().add(const Duration(days: 365)),
      ),
      0,
    );

    expect(backupNames(), before);
    expect(await service.listBackups(), [entry]);
  });

  test('a recent leftover is kept: the backup may still be running', () async {
    final base = 'healthwallet_backup_1700000000000';
    interruptedBackup(base);
    // A file still being copied into `.files/` keeps the whole backup.
    File(
      p.join(fx.backups.path, '$base.files', 'large.pdf'),
    ).writeAsStringSync('being copied');

    expect(await fx.service().removeBackupLeftovers(), 0);

    expect(backupNames(), contains('$base.db'));
  });

  test('files that are not a backup\'s parts are kept', () async {
    for (final name in [
      'notes.db',
      'export_1700000000000.txt',
      'healthwallet_backup_17000.db',
    ]) {
      File(p.join(fx.backups.path, name))
        ..writeAsStringSync('x')
        ..setLastModifiedSync(old);
    }
    Directory(p.join(fx.backups.path, 'photos.files')).createSync();

    expect(await fx.service().removeBackupLeftovers(now: later), 0);

    expect(backupNames(), [
      'export_1700000000000.txt',
      'healthwallet_backup_17000.db',
      'notes.db',
      'photos.files',
    ]);
  });

  test('a backup this run is writing is never removed', () async {
    final service = fx.service();
    fx.docFile('scan.pdf');
    await fx.insertDocument('d1', ['file://scan.pdf']);
    int? removed;
    // Once the snapshot's `.db` is written, before its files and metadata.
    fx.db.beforeStatement = (statement) async {
      if (!statement.contains('AS backup_snapshot')) return;
      fx.db.beforeStatement = null;
      removed = await service.removeBackupLeftovers(now: later);
    };

    final entry = await service.createSnapshot();

    expect(removed, 0);
    expect(File(entry.filePath).existsSync(), isTrue);
    expect(await service.listBackups(), [entry]);
  });
}
