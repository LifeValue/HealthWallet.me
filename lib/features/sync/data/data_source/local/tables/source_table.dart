import 'package:drift/drift.dart';

class Sources extends Table {
  TextColumn get id => text()();
  TextColumn get platformName => text().nullable()();
  TextColumn get logo => text().nullable()();
  TextColumn get labelSource => text().nullable()();
  TextColumn get platformType => text().withDefault(const Constant('wallet'))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// The person whose records this source holds. Sources with the same
  /// holder are one person in the wallet. Synced, so both devices agree on
  /// who is who.
  TextColumn get holderId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
