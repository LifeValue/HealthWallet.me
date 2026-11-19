import 'package:drift/drift.dart';

/// Every local write to a synced table, in order, logged by triggers. The
/// desktop sync sends the rows behind the entries the peer hasn't
/// acknowledged yet, so delivery doesn't depend on either device's clock.
/// Writes made by the sync itself are removed again inside the same
/// transaction, so received rows aren't sent back.
@DataClassName('SyncOutboxEntry')
class SyncOutbox extends Table {
  IntColumn get seq => integer().autoIncrement()();

  /// `fhir_resource`, `sources` or `record_notes`.
  TextColumn get syncedTable => text()();

  /// The row's key on every device: `id`, or `uuid` for notes.
  TextColumn get rowKey => text()();
}
