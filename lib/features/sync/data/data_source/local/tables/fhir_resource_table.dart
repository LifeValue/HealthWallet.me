import 'package:drift/drift.dart';

@DataClassName('FhirResourceLocalDto')
@TableIndex(name: 'resourceType', columns: {#resourceType})
@TableIndex(name: 'resourceId', columns: {#resourceId})
class FhirResource extends Table {
  TextColumn get id => text()();
  TextColumn get sourceId => text().nullable()();
  TextColumn get resourceType => text().nullable()();
  TextColumn get resourceId => text().nullable()();
  TextColumn get title => text().nullable()();
  DateTimeColumn get date => dateTime().nullable()();
  TextColumn get resourceRaw => text()();
  TextColumn get encounterId => text().nullable()();
  TextColumn get subjectId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deviceId => text().nullable()();
  TextColumn get specialtyOverride => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
