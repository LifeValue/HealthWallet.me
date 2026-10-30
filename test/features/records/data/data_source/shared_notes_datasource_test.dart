import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/records/data/data_source/shared_notes_datasource.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';

void main() {
  final note = RecordNote(content: 'seen', timestamp: DateTime.utc(2026));

  test('serves shared notes until cleared', () {
    final datasource = SharedNotesDatasource();
    expect(datasource.notesFor('c1'), isNull);

    datasource.show({
      'c1': [note],
    });
    expect(datasource.notesFor('c1'), [note]);
    expect(datasource.notesFor('other'), isNull);

    datasource.clear();
    expect(datasource.notesFor('c1'), isNull);
  });

  test('keeps its own copy of the map', () {
    final datasource = SharedNotesDatasource();
    final notes = {
      'c1': [note],
    };

    datasource.show(notes);
    notes.clear();

    expect(datasource.notesFor('c1'), [note]);
  });
}
