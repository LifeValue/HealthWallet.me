import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/change_watcher_service.dart';

import '../../lww_sync_test_helpers.dart';

void main() {
  late AppDatabase db;
  late ChangeWatcherService watcher;
  late int calls;

  setUp(() {
    db = openTestDatabase();
    watcher = ChangeWatcherService(db);
    calls = 0;
  });

  tearDown(() async {
    watcher.dispose();
    await db.close();
  });

  Future<void> settle() =>
      Future<void>.delayed(ChangeWatcherService.debounce * 2);

  test(
    'reports once at start for what changed while nothing watched',
    () async {
      watcher.startWatching(() => calls++);
      await settle();
      expect(calls, 1);
    },
  );

  test('starting twice still reports once', () async {
    watcher.startWatching(() => calls++);
    watcher.startWatching(() => calls++);
    await settle();
    expect(calls, 1);
  });

  test('a burst of writes to the synced tables is one report', () async {
    watcher.startWatching(() => calls++);
    await settle();
    calls = 0;

    await db.into(db.sources).insert(SourcesCompanion.insert(id: 's'));
    await db
        .into(db.fhirResource)
        .insert(
          FhirResourceCompanion.insert(
            id: 'a',
            resourceType: const Value('Observation'),
            resourceRaw: '{}',
          ),
        );
    await db
        .into(db.recordNotes)
        .insert(
          RecordNotesCompanion.insert(
            resourceId: 'a',
            content: 'note',
            timestamp: DateTime(2026),
          ),
        );
    await settle();
    expect(calls, 1);
  });

  test('a processing_sessions write is not reported', () async {
    watcher.startWatching(() => calls++);
    await settle();
    calls = 0;
    await db
        .into(db.processingSessions)
        .insert(
          ProcessingSessionsCompanion.insert(id: 'p', status: const Value('x')),
        );
    await settle();
    expect(calls, 0);
  });

  test('nothing is reported after stopping', () async {
    watcher.startWatching(() => calls++);
    watcher.stopWatching();
    await settle();
    expect(calls, 0);
    expect(watcher.isWatching, isFalse);
  });
}
