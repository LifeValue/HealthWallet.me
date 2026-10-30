import 'dart:async';

import 'package:drift/drift.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:injectable/injectable.dart';

/// Tells the sync when a synced table was written, debounced. What changed is
/// in the outbox, so a write that drift doesn't report (a custom statement)
/// is still sent with the next one.
@lazySingleton
class ChangeWatcherService {
  static const debounce = Duration(milliseconds: 500);

  final AppDatabase _db;

  StreamSubscription? _subscription;
  Timer? _debounceTimer;
  void Function()? _onChanged;

  ChangeWatcherService(this._db);

  bool get isWatching => _subscription != null;

  void startWatching(void Function() onChanged) {
    if (isWatching) return;
    _onChanged = onChanged;

    // Table update notifications, not queries: a write costs nothing until
    // the debounce runs.
    _subscription = _db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            _db.fhirResource,
            _db.sources,
            _db.recordNotes,
          ]),
        )
        .listen((_) => _schedule());

    // Whatever changed while nothing was watching.
    _schedule();
  }

  void stopWatching() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _onChanged = null;
  }

  void _schedule() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => _onChanged?.call());
  }

  void dispose() => stopWatching();
}
