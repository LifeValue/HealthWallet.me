import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';
import 'package:health_wallet/features/user/data/service/app_data_reset_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _id = '3f2b8c1e-9a4d-4e6f-8b7a-1c2d3e4f5a6b';

class _CountingSweeper extends TempFileSweeper {
  _CountingSweeper(Directory temp, Directory docs)
    : super(
        temporaryDirectory: () async => temp,
        documentsDirectory: () async => docs,
        deleteDebugLogs: true,
        includeProcessingCache: true,
      );

  int sweeps = 0;

  @override
  Future<void> sweep() {
    sweeps++;
    return super.sweep();
  }
}

Future<int> _count(AppDatabase db, String table) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS n FROM $table')
      .getSingle();
  return row.data['n'] as int;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory root;
  late Directory temp;
  late Directory docs;
  late Directory support;
  late AppDatabase db;
  late _CountingSweeper sweeper;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('hw_reset_test_');
    temp = Directory('${root.path}/tmp')..createSync();
    docs = Directory('${root.path}/Documents')..createSync();
    support = Directory('${root.path}/Support')..createSync();
    db = AppDatabase(NativeDatabase.memory());
    sweeper = _CountingSweeper(temp, docs);
    SharedPreferences.setMockInitialValues({'theme': 'dark'});

    await db.customStatement(
      "INSERT INTO sources (id) VALUES ('s1')",
    );
    await db.customStatement(
      "INSERT INTO fhir_resource (id, resource_raw) VALUES ('r1', '{}')",
    );
    await db.customStatement(
      'INSERT INTO record_notes (resource_id, content, timestamp) '
      "VALUES ('r1', 'note', 0)",
    );
    await db.customStatement(
      "INSERT INTO processing_sessions (id) VALUES ('p1')",
    );
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  AppDataResetService service({Future<Directory> Function()? supportDir}) =>
      AppDataResetService(
        db,
        sweeper: sweeper,
        supportDirectory: supportDir ?? () async => support,
      );

  test('empties every table and the preferences', () async {
    await service().reset();

    for (final table in [
      'fhir_resource',
      'sources',
      'record_notes',
      'processing_sessions',
    ]) {
      expect(await _count(db, table), 0, reason: table);
    }
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test(
    'sweeps the app temp files and the OCR cache, keeping temp itself',
    () async {
      final payload = File('${temp.path}/share_$_id.json')
        ..writeAsStringSync('{}');
      final ocrPage = File('${temp.path}/healthwallet_pdf_page_1_0.png')
        ..writeAsStringSync('x');
      final resized = File('${temp.path}/healthwallet_resized_scan.jpg')
        ..writeAsStringSync('x');
      final otherApp = File('${temp.path}/other_app.tmp')
        ..writeAsStringSync('x');
      final log = File('${docs.path}/share_debug.log')..writeAsStringSync('x');

      await service().reset();

      expect(sweeper.sweeps, 1);
      expect(payload.existsSync(), isFalse);
      expect(log.existsSync(), isFalse);
      expect(temp.existsSync(), isTrue);
      expect(ocrPage.existsSync(), isFalse);
      expect(resized.existsSync(), isFalse);
      expect(otherApp.existsSync(), isTrue);
    },
  );

  test('deletes the stored share sessions', () async {
    final sessions = Directory('${support.path}/share_sessions')..createSync();
    File('${sessions.path}/s.json').writeAsStringSync('{}');

    await service().reset();

    expect(sessions.existsSync(), isFalse);
    expect(support.existsSync(), isTrue);
  });

  test('goes on when a step fails', () async {
    await db.close();
    final payload = File('${temp.path}/share_$_id.json')
      ..writeAsStringSync('{}');

    await expectLater(
      service(
        supportDir: () async => throw const FileSystemException('no dir'),
      ).reset(),
      completes,
    );

    expect(sweeper.sweeps, 1);
    expect(payload.existsSync(), isFalse);
    db = AppDatabase(NativeDatabase.memory());
  });

  test('the default sweep also deletes the processing cache', () async {
    // The default sweeper uses the real path_provider directories, so only
    // its configuration is checked here; the sweep itself is covered by the
    // TempFileSweeper tests.
    final service = AppDataResetService(db);
    expect(service.sweeper.includeProcessingCache, isTrue);
    expect(service.sweeper.deleteDebugLogs, isTrue);
  });
}
