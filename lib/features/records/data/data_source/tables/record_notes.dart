import 'package:drift/drift.dart';
import 'package:health_wallet/features/sync/data/data_source/local/tables/source_table.dart';

@DataClassName('RecordNoteDto')
class RecordNotes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get resourceId => text()();
  TextColumn get sourceId => text().nullable().references(Sources, #id)();
  TextColumn get content => text()();
  DateTimeColumn get timestamp => dateTime()();
}
