import 'package:drift/drift.dart';

@DataClassName('TrustedIssuerLocalDto')
class TrustedIssuers extends Table {
  TextColumn get issuerId => text()(); // Unique identifier (hash, URL, or provided ID)
  TextColumn get name => text()(); // Human-readable name (e.g., "Kaiser Permanente")
  TextColumn get publicKeyJwk =>
      text()(); // JWK (JSON Web Key) format as JSON string
  TextColumn get source =>
      text()(); // How it was added: "qr", "jwks", "manual"
  DateTimeColumn get addedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {issuerId};
}


