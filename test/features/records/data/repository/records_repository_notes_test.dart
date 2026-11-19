import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/data/repository/records_repository_impl.dart';

import '../../records_test_helpers.dart';

void main() {
  late AppDatabase db;
  late RecordsRepositoryImpl repository;

  setUp(() async {
    db = openTestDatabase();
    repository = await openRepository(db);
  });

  tearDown(() => db.close());

  Future<String?> storedSourceId() async =>
      (await db.select(db.recordNotes).getSingle()).sourceId;

  test('a note keeps the source of its record', () async {
    await insertSource(db, 's1');

    await repository.addRecordNote(
      resourceId: 'r1',
      sourceId: 's1',
      content: 'allergic to amoxicillin',
    );

    expect(await storedSourceId(), 's1');
  });

  test('a note on a record without a source is saved', () async {
    await repository.addRecordNote(
      resourceId: 'r1',
      sourceId: '',
      content: 'note',
    );

    expect(await storedSourceId(), isNull);
  });

  test('a note on a record whose source is gone is saved', () async {
    await repository.addRecordNote(
      resourceId: 'r1',
      sourceId: 'missing',
      content: 'note',
    );

    expect(await storedSourceId(), isNull);
  });

  test('each note gets its own key for the desktop sync', () async {
    await repository.addRecordNote(resourceId: 'r1', content: 'one');
    await repository.addRecordNote(resourceId: 'r1', content: 'two');

    final keys = (await db.select(db.recordNotes).get()).map((n) => n.uuid);
    expect(keys.toSet(), hasLength(2));
    expect(keys, everyElement(isNot(startsWith('legacy-'))));
  });
}
