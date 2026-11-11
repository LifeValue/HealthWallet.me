import 'dart:async';

import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/records/domain/services/records_filter_store.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whose records the app shows: the selected person and, optionally, one of
/// their sources. Every screen reads it from here.
class HolderScope {
  const HolderScope({
    this.directory = const HolderDirectory(),
    this.holder,
    this.sourceFilter,
    this.loaded = false,
  });

  /// Everyone in the wallet, as last read.
  final HolderDirectory directory;
  final Holder? holder;

  /// One of [holder]'s sources, or null for all of them.
  final String? sourceFilter;

  /// False until the people have been read once.
  final bool loaded;

  /// The sources whose records are shown: the filter, or all the person's
  /// sources. Nothing until the people are read, so no one else's records
  /// show meanwhile; every source when the wallet has no one to keep apart.
  List<String>? get sourceIds {
    if (!loaded) return const [];
    final holder = this.holder;
    if (holder == null) return directory.holders.isEmpty ? null : const [];
    final filter = sourceFilter;
    return filter != null ? [filter] : holder.sourceIds;
  }

  /// The person's row for the filter, or the row shown for them.
  Patient? get patient {
    final holder = this.holder;
    if (holder == null) return null;
    final filter = sourceFilter;
    return (filter == null ? null : holder.getPatientForSource(filter)) ??
        holder.representativePatient;
  }
}

/// Owns the selection and keeps it: the person by holder id, the source
/// filter by source id. Reading the people again ([refresh]) keeps both
/// while they still exist, and forgets the Records filters of anyone who no
/// longer does.
@lazySingleton
class HolderSelection {
  HolderSelection(this._holders, this._prefs, [this._recordsFilters]);

  final HolderService _holders;
  final SharedPreferences _prefs;

  /// Without it (tests), no saved Records filters are forgotten.
  final RecordsFilterStore? _recordsFilters;

  static const _holderKey = 'selected_holder_id';

  /// Where older versions kept a Patient row id; read once, as the holder of
  /// that row.
  static const _legacyPatientKey = 'selected_patient_id';
  static const _sourceKey = 'home_selected_source_id';
  static const _allSources = 'All';

  HolderScope _scope = const HolderScope();
  final _changes = StreamController<HolderScope>.broadcast();

  HolderScope get scope => _scope;
  Stream<HolderScope> get changes => _changes.stream;

  /// Reads the people again, after anything that may have changed them: a
  /// sync, a scan, an edit, an answer, a delete.
  Future<HolderScope> refresh() async {
    final directory = await _holders.load();
    await _recordsFilters?.forgetAllBut({
      for (final holder in directory.holders) holder.id,
    });
    final saved =
        _prefs.getString(_holderKey) ?? _prefs.getString(_legacyPatientKey);
    final holder =
        (saved == null
            ? null
            : directory.byId(saved) ?? directory.ofPatientId(saved)) ??
        directory.holders.firstOrNull;
    return _set(
      HolderScope(
        directory: directory,
        holder: holder,
        sourceFilter: _filterFor(holder, _prefs.getString(_sourceKey)),
        loaded: true,
      ),
    );
  }

  /// Selects a person. One not read yet (just made by a scan) is selected
  /// when the people are read again.
  Future<void> select(String holderId) async {
    await _prefs.setString(_holderKey, holderId);
    final holder = _scope.directory.byId(holderId);
    if (holder == null || holder.id == _scope.holder?.id) return;
    _set(
      HolderScope(
        directory: _scope.directory,
        holder: holder,
        sourceFilter: _filterFor(holder, _scope.sourceFilter),
        loaded: _scope.loaded,
      ),
    );
  }

  /// Shows one of the person's sources, or all of them for null.
  Future<void> filter(String? sourceId) async {
    final filter = _filterFor(_scope.holder, sourceId);
    if (filter == _scope.sourceFilter) return;
    _set(
      HolderScope(
        directory: _scope.directory,
        holder: _scope.holder,
        sourceFilter: filter,
        loaded: _scope.loaded,
      ),
    );
  }

  /// The filter if it is one of [holder]'s sources.
  String? _filterFor(Holder? holder, String? sourceId) =>
      sourceId != null &&
          sourceId != _allSources &&
          (holder?.existsInSource(sourceId) ?? false)
      ? sourceId
      : null;

  HolderScope _set(HolderScope scope) {
    _scope = scope;
    if (scope.holder case final holder?) {
      unawaited(_prefs.setString(_holderKey, holder.id));
    }
    unawaited(_prefs.setString(_sourceKey, scope.sourceFilter ?? _allSources));
    _changes.add(scope);
    return scope;
  }
}
