import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';

void main() {
  test('metadata from before files reads as a database-only backup', () {
    // As written by 1.2.x.
    final entry = BackupEntry.fromJson(
      jsonDecode('''
        {"id": "1700000000000", "timestamp": "2026-10-01T10:00:00.000",
         "sizeBytes": 4096, "recordCount": 3, "checksum": "ab",
         "filePath": "/b/healthwallet_backup_1700000000000.db", "name": ""}
      ''') as Map<String, dynamic>,
    );

    expect(entry.formatVersion, 1);
    expect(entry.hasFiles, isFalse);
    expect(entry.files, isEmpty);
    expect(entry.missing, isEmpty);
    expect(entry.isSafetyCopy, isFalse);
    expect(entry.totalBytes, 4096);
  });

  test('metadata without a name still reads', () {
    final entry = BackupEntry.fromJson({
      'id': '1',
      'timestamp': '2026-10-01T10:00:00.000',
      'sizeBytes': 1,
      'recordCount': 0,
      'checksum': 'x',
      'filePath': '/b/x.db',
    });

    expect(entry.name, '');
  });

  test('format 2 round-trips through JSON text, files included', () {
    final entry = BackupEntry(
      id: '2',
      timestamp: DateTime(2026, 11, 3, 14, 5),
      sizeBytes: 100,
      recordCount: 2,
      checksum: 'c',
      filePath: '/b/x_2.db',
      name: 'Înainte de restaurare',
      formatVersion: BackupEntry.filesFormat,
      files: const [
        BackupFile(
          name: 'scan.pdf',
          sourcePaths: ['scan.pdf', '/docs/scan.pdf'],
          sha256: 'h',
          size: 50,
        ),
      ],
      missing: const ['file://gone.pdf'],
      isSafetyCopy: true,
    );

    final text = jsonEncode(entry.toJson());
    final json = jsonDecode(text) as Map<String, dynamic>;

    expect(json['formatVersion'], 2);
    expect((json['files'] as List).single['sourcePaths'], [
      'scan.pdf',
      '/docs/scan.pdf',
    ]);
    expect(BackupEntry.fromJson(json), entry);
    expect(entry.hasFiles, isTrue);
    expect(entry.totalBytes, 150);
  });
}
