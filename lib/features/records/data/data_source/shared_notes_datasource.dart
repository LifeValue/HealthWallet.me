import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';
import 'package:injectable/injectable.dart';

/// Notes that came with records shared from another phone, kept in memory
/// for the length of the share session. They never reach the database, so
/// they are not synced and nothing is left behind if the app is killed.
@lazySingleton
class SharedNotesDatasource {
  Map<String, List<RecordNote>> _notes = const {};

  List<RecordNote>? notesFor(String resourceId) => _notes[resourceId];

  void show(Map<String, List<RecordNote>> notes) => _notes = Map.of(notes);

  void clear() => _notes = const {};
}
