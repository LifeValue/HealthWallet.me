import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/utils/stored_file_name.dart';
import 'package:path/path.dart' as p;

import '../../helpers/log_capture.dart';

void main() {
  final logs = captureLogs();
  late Directory docs;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('stored_file_name_test_');
  });

  tearDown(() async {
    if (docs.existsSync()) await docs.delete(recursive: true);
  });

  group('uniqueStoredFileName', () {
    Future<String> name(String original) =>
        uniqueStoredFileName(docs.path, original);

    test('keeps a safe name and adds a suffix before the extension', () async {
      expect(
        await name('report.v2.pdf'),
        matches(r'^report\.v2_[0-9a-f]{8}\.pdf$'),
      );
      expect(await name('notes'), matches(r'^notes_[0-9a-f]{8}$'));
      expect(
        await name('my-file_1.txt'),
        matches(r'^my-file_1_[0-9a-f]{8}\.txt$'),
      );
    });

    test('two calls give different names', () async {
      expect(await name('a.pdf'), isNot(await name('a.pdf')));
    });

    test('never gives a hidden or empty name', () async {
      expect(await name('.pdf'), matches(r'^file_[0-9a-f]{8}\.pdf$'));
      expect(await name('..report.pdf'), matches(r'^report_[0-9a-f]{8}\.pdf$'));
      expect(await name('отчет.pdf'), matches(r'^file_[0-9a-f]{8}\.pdf$'));
      expect(await name(''), matches(r'^file_[0-9a-f]{8}$'));
      expect(await name('report.'), matches(r'^report\._[0-9a-f]{8}$'));
    });

    test('shortens long names and ignores a long extension', () async {
      final long = await name('${'a' * 300}.pdf');
      expect(long, matches(RegExp('^a{100}_[0-9a-f]{8}\\.pdf\$')));

      final odd = await name('archive.${'x' * 20}');
      expect(odd, startsWith('archive.xxxx'));
      expect(odd, matches(r'_[0-9a-f]{8}$'));
      expect(odd.length, lessThan(120));
    });

    test('keeps a path out of the name', () async {
      final escaped = await name('../../etc/passwd');
      expect(escaped, isNot(contains('/')));
      expect(escaped, isNot(startsWith('.')));
      expect(
        await name(r'C:\Users\me\scan.pdf'),
        matches(r'^C__Users_me_scan_[0-9a-f]{8}\.pdf$'),
      );
    });

    test('a name taken by a file, a folder or a link is not given', () async {
      // Many names that are all taken except one would need the suffix to be
      // predictable; instead check the result is free whatever exists.
      for (var i = 0; i < 20; i++) {
        final taken = await name('a.pdf');
        expect(File(p.join(docs.path, taken)).existsSync(), isFalse);
        switch (i % 3) {
          case 0:
            await File(p.join(docs.path, taken)).create();
          case 1:
            await Directory(p.join(docs.path, taken)).create();
          case 2:
            await Link(p.join(docs.path, taken)).create('/nowhere');
        }
      }
      expect(docs.listSync(), hasLength(20));
    });
  });

  group('copyAsNewFile', () {
    test('copies the content and marks the copy as modified now', () async {
      final source = File(p.join(docs.path, 'source.pdf'));
      await source.writeAsString('%PDF old');
      await source.setLastModified(DateTime(2020));
      final before = DateTime.now().subtract(const Duration(seconds: 5));

      final copy = await copyAsNewFile(source, p.join(docs.path, 'copy.pdf'));

      expect(copy.path, p.join(docs.path, 'copy.pdf'));
      expect(await copy.readAsString(), '%PDF old');
      expect(copy.lastModifiedSync().isAfter(before), isTrue);
      expect(source.lastModifiedSync().year, 2020);
      expect(logs, isEmpty);
    });

    test('a missing source fails', () async {
      await expectLater(
        copyAsNewFile(
          File(p.join(docs.path, 'gone.pdf')),
          p.join(docs.path, 'copy.pdf'),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(File(p.join(docs.path, 'copy.pdf')).existsSync(), isFalse);
    });
  });
}
