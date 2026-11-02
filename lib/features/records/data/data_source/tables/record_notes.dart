import 'package:drift/drift.dart';
import 'package:health_wallet/features/sync/data/data_source/local/tables/source_table.dart';

@DataClassName('RecordNoteDto')
@TableIndex(name: 'record_notes_uuid', columns: {#uuid}, unique: true)
class RecordNotes extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The note's identity across devices, which the desktop sync matches on;
  /// [id] counts per device. Notes from before v12, or from an app version
  /// without this column, get `legacy-<id>`.
  TextColumn get uuid => text().nullable()();
  TextColumn get resourceId => text()();
  TextColumn get sourceId => text().nullable().references(Sources, #id)();
  TextColumn get content => text()();
  DateTimeColumn get timestamp => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
