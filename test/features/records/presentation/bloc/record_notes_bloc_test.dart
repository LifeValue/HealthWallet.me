import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/data/repository/records_repository_impl.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_notes/bloc/record_notes_bloc.dart';

import '../../records_test_helpers.dart';

void main() {
  late AppDatabase db;
  late RecordsRepositoryImpl repository;
  late RecordNotesBloc bloc;

  const record = Condition(id: 'cond', sourceId: 's1', resourceId: 'cond');

  setUp(() async {
    db = openTestDatabase();
    repository = await openRepository(db);
    await insertSource(db, 's1');
    bloc = RecordNotesBloc(repository);
  });

  tearDown(() async {
    await bloc.close();
    await db.close();
  });

  List<String> contents() => [for (final n in bloc.state.notes) n.content];

  /// Waits until the bloc is idle showing exactly [expected].
  Future<void> shows(List<String> expected) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (bloc.state.status != const RecordNotesStatus.success() ||
        contents().join('|') != expected.join('|')) {
      if (DateTime.now().isAfter(deadline)) {
        fail('expected $expected, the bloc is at ${bloc.state}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<void> open(List<String> expected) async {
    bloc.add(const RecordNotesInitialised(resource: record));
    await shows(expected);
  }

  Future<void> write(String content, {RecordNote? editing}) async {
    bloc
      ..add(RecordNotesInputInitialised(editNote: editing))
      ..add(RecordNotesInputDone(content: content));
    await shows([content]);
  }

  test('opens with the record\'s notes only', () async {
    await repository.addRecordNote(resourceId: 'cond', content: 'mine');
    await repository.addRecordNote(resourceId: 'other', content: 'not mine');

    await open(const ['mine']);
  });

  test('a new note shows after saving, with the record\'s source', () async {
    await open(const []);

    await write('allergic to amoxicillin');

    expect((await db.select(db.recordNotes).getSingle()).sourceId, 's1');
  });

  test('editing a note changes it in place', () async {
    await open(const []);
    await write('first');

    await write('edited', editing: bloc.state.notes.single);

    expect(await db.select(db.recordNotes).get(), hasLength(1));
  });

  test('deleting a note removes it', () async {
    await open(const []);
    await write('to delete');

    bloc.add(RecordNotesNoteDeleted(note: bloc.state.notes.single));
    await shows(const []);

    // Kept as a tombstone for the paired device.
    expect((await db.select(db.recordNotes).getSingle()).deletedAt, isNotNull);
  });

  test('cancelling the editor saves nothing', () async {
    await open(const []);

    bloc
      ..add(const RecordNotesInputInitialised())
      ..add(const RecordNotesInputCanceled());
    await pumpEventQueue();

    expect(bloc.state.status, const RecordNotesStatus.success());
    expect(await db.select(db.recordNotes).get(), isEmpty);
  });

  test('a shared record shows the notes that came with it', () async {
    repository.showSharedNotes({
      'cond': [
        RecordNote(content: 'from the sender', timestamp: DateTime(2026)),
      ],
    });
    addTearDown(repository.clearSharedNotes);

    await open(const ['from the sender']);
  });
}
