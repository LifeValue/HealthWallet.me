import 'dart:convert';

import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/records/domain/entity/date_filter/date_filter.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Records filters a person chose: record types, specialties and a time
/// range. Empty means every record.
class RecordsFilters {
  const RecordsFilters({
    this.types = const [],
    this.specialties = const [],
    this.dateFilter,
  });

  static const none = RecordsFilters();

  final List<FhirType> types;
  final List<MedicalSpecialty> specialties;
  final DateFilter? dateFilter;

  bool get isEmpty =>
      types.isEmpty &&
      specialties.isEmpty &&
      (dateFilter == null || !dateFilter!.hasValue);
}

/// Keeps the Records filters each person chose, on this device, so Records
/// opens on them again until they are cleared, also after a restart. A
/// person who never chose a filter gets none: the app adds no filters of
/// its own.
@lazySingleton
class RecordsFilterStore {
  RecordsFilterStore(this._prefs);

  final SharedPreferences _prefs;

  static const prefsKey = 'records_filters_by_person';

  /// The filters [personId] chose, or [RecordsFilters.none].
  RecordsFilters load(String personId) {
    final saved = _all()[personId];
    if (saved is! Map<String, dynamic>) return RecordsFilters.none;
    try {
      return RecordsFilters(
        types: [
          for (final name in (saved['types'] as List? ?? const []))
            ?_byName(FhirType.values, name),
        ],
        specialties: [
          for (final name in (saved['specialties'] as List? ?? const []))
            ?_byName(MedicalSpecialty.values, name),
        ],
        dateFilter: _dateFilter(saved['date']),
      );
    } catch (e, s) {
      logger.w('The saved Records filters could not be read', e, s);
      return RecordsFilters.none;
    }
  }

  /// Saves the filters [personId] chose; no filters removes the entry.
  Future<void> save(String personId, RecordsFilters filters) async {
    final all = _all();
    if (filters.isEmpty) {
      all.remove(personId);
    } else {
      final date = filters.dateFilter;
      all[personId] = {
        'types': [for (final t in filters.types) t.name],
        'specialties': [for (final s in filters.specialties) s.name],
        if (date != null && date.hasValue)
          'date': {
            'fromYear': date.fromYear,
            'fromMonth': date.fromMonth,
            'fromDay': date.fromDay,
            'toYear': date.toYear,
            'toMonth': date.toMonth,
            'toDay': date.toDay,
          },
      };
    }
    await _write(all);
  }

  /// Forgets the filters of everyone not in [personIds], the people in the
  /// wallet: a deleted person's choices are health data and must not stay,
  /// nor come back if their id is used again.
  Future<void> forgetAllBut(Set<String> personIds) async {
    final all = _all();
    final before = all.length;
    all.removeWhere((personId, _) => !personIds.contains(personId));
    if (all.length == before) return;
    await _write(all);
  }

  Future<void> _write(Map<String, dynamic> all) async {
    try {
      await _prefs.setString(prefsKey, jsonEncode(all));
    } catch (e, s) {
      // The filters shown still apply; the saved ones are only out of date
      // until the next write.
      logger.w('The Records filters could not be saved', e, s);
    }
  }

  Map<String, dynamic> _all() {
    final raw = _prefs.getString(prefsKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } on FormatException catch (e, s) {
      logger.w('The saved Records filters are unreadable', e, s);
      return {};
    }
  }

  static T? _byName<T extends Enum>(List<T> values, Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  static DateFilter? _dateFilter(Object? saved) {
    if (saved is! Map<String, dynamic>) return null;
    final filter = DateFilter(
      fromYear: saved['fromYear'] as int?,
      fromMonth: saved['fromMonth'] as int?,
      fromDay: saved['fromDay'] as int?,
      toYear: saved['toYear'] as int?,
      toMonth: saved['toMonth'] as int?,
      toDay: saved['toDay'] as int?,
    );
    return filter.hasValue ? filter : null;
  }
}
