import 'package:drift/drift.dart';

@DataClassName('ProcessingSessionDto')
class ProcessingSessions extends Table {
  TextColumn get id => text()();
  TextColumn get filePaths => text().nullable()();
  TextColumn get resources => text().nullable()();
  TextColumn get status => text().nullable()();
  TextColumn get origin => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get patient => text().nullable()();
  TextColumn get encounter => text().nullable()();
  BoolColumn get isDocumentAttached => boolean().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
