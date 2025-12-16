import 'package:drift/drift.dart';

@DataClassName('UserKeysLocalDto')
class UserKeys extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get publicKey => text()(); // Base64 encoded ES256 public key (ECDSA P-256)
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}


