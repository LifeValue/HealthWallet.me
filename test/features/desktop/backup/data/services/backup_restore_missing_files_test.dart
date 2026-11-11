import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'backup_test_support.dart';

void main() {
  final fx = BackupFixture();

  setUp(fx.setUp);
  tearDown(fx.tearDown);

  group('a record whose file was missing at backup', () {
    test('is not pointed at a Windows attachment of the same name that went '
        'under a free name', () async {
      // R1's file is in the Documents root older versions saved to; R2 came
      // from the phone and its file wasn't fetched yet.
      final winRoot = Directory(p.join(fx.root.path, 'Documents'))
        ..createSync();
      final service = fx.service(legacyFolders: [winRoot.path]);
      final r1File = File(p.join(winRoot.path, 'scan.pdf'))
        ..writeAsStringSync('R1 document');
      await fx.insertDocument('r1', [
        'file://${Uri.encodeComponent(r1File.path)}',
      ]);
      await fx.insertDocument('r2', ['file://scan.pdf']);
      final entry = await service.createSnapshot();
      expect(entry.files.single.name, 'scan.pdf');
      expect(entry.missing, ['file://scan.pdf']);
      // R2's file arrives afterwards, and R1's original is deleted.
      fx.docFile('scan.pdf', 'R2 document');
      r1File.deleteSync();

      final result = await service.restoreFromFile(entry.filePath);

      expect(result.filesAdded, 1);
      final restored = fx.docNames().singleWhere((n) => n != 'scan.pdf');
      expect(await fx.urlsOf('r1'), ['file://$restored']);
      expect(await fx.urlsOf('r2'), ['file://scan.pdf']);
      expect(
        File(p.join(fx.docs.path, 'scan.pdf')).readAsStringSync(),
        'R2 document',
      );
    });

    test(
      'is not pointed at a file of the same name from a subfolder',
      () async {
        final service = fx.service();
        fx.docFile('a/scan.pdf', 'R1 document');
        await fx.insertDocument('r1', ['file://a/scan.pdf']);
        await fx.insertDocument('r2', ['file://scan.pdf']);
        final entry = await service.createSnapshot();
        expect(entry.missing, ['file://scan.pdf']);
        fx.docFile('scan.pdf', 'R2 document');
        Directory(p.join(fx.docs.path, 'a')).deleteSync(recursive: true);

        await service.restoreFromFile(entry.filePath);

        final restored = fx.docNames().singleWhere((n) => n != 'scan.pdf');
        expect(await fx.urlsOf('r1'), ['file://$restored']);
        expect(await fx.urlsOf('r2'), ['file://scan.pdf']);
      },
    );
  });

  test('a record is pointed at a restored file only through the backup\'s own '
      'paths, never by name alone', () async {
    final service = fx.service();
    fx.docFile('a/scan.pdf', 'R1 document');
    await fx.insertDocument('r1', ['file://a/scan.pdf']);
    final entry = await service.createSnapshot();
    fx.docFile('scan.pdf', 'current');
    Directory(p.join(fx.docs.path, 'a')).deleteSync(recursive: true);
    await service.saveBackupMetadata(
      entry.copyWith(
        files: [
          entry.files.single.copyWith(sourcePaths: ['b/scan.pdf']),
        ],
      ),
    );

    await service.restoreFromFile(entry.filePath);

    expect(await fx.urlsOf('r1'), ['file://a/scan.pdf']);
  });
}
