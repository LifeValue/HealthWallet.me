import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/records/domain/entity/date_filter/date_filter.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/records/domain/services/records_filter_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/log_capture.dart';

/// Reads like the device's preferences but can't write.
class _ReadOnlyPrefs extends Fake implements SharedPreferences {
  @override
  String? getString(String key) => null;

  @override
  Future<bool> setString(String key, String value) async =>
      throw Exception('disk full');
}

void main() {
  final logs = captureLogs();
  late SharedPreferences prefs;
  late RecordsFilterStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = RecordsFilterStore(prefs);
  });

  test('a person who chose nothing has no filters', () {
    final filters = store.load('jane');

    expect(filters.isEmpty, isTrue);
    expect(filters.types, isEmpty);
    expect(filters.specialties, isEmpty);
    expect(filters.dateFilter, isNull);
  });

  test('types, specialties and a time range are kept per person', () async {
    const range = DateFilter(fromYear: 2023, toYear: 2024, toMonth: 6);
    await store.save(
      'jane',
      const RecordsFilters(
        types: [FhirType.Observation, FhirType.Condition],
        specialties: [MedicalSpecialty.cardiology],
        dateFilter: range,
      ),
    );
    await store.save(
      'tom',
      const RecordsFilters(types: [FhirType.Immunization]),
    );

    final jane = RecordsFilterStore(prefs).load('jane');

    expect(jane.types, [FhirType.Observation, FhirType.Condition]);
    expect(jane.specialties, [MedicalSpecialty.cardiology]);
    expect(jane.dateFilter, range);
    expect(store.load('tom').types, [FhirType.Immunization]);
    expect(store.load('tom').dateFilter, isNull);
  });

  test('saving no filters forgets the person', () async {
    await store.save('jane', const RecordsFilters(types: [FhirType.Media]));

    await store.save(
      'jane',
      const RecordsFilters(dateFilter: DateFilter()),
    );

    expect(store.load('jane').isEmpty, isTrue);
    expect(prefs.getString(RecordsFilterStore.prefsKey), '{}');
  });

  test('names this version does not know are skipped', () async {
    await prefs.setString(
      RecordsFilterStore.prefsKey,
      '{"jane":{"types":["Observation","Spaceship"],'
      '"specialties":["cardiology","astrology"],'
      '"date":{"fromYear":null}}}',
    );

    final filters = store.load('jane');

    expect(filters.types, [FhirType.Observation]);
    expect(filters.specialties, [MedicalSpecialty.cardiology]);
    expect(filters.dateFilter, isNull);
  });

  test('unreadable saved filters count as none and are logged', () async {
    await prefs.setString(RecordsFilterStore.prefsKey, 'not json');
    expect(store.load('jane').isEmpty, isTrue);
    expect(logs, loggedWarning('The saved Records filters are unreadable'));

    await prefs.setString(RecordsFilterStore.prefsKey, '["a list"]');
    expect(store.load('jane').isEmpty, isTrue);

    await prefs.setString(
      RecordsFilterStore.prefsKey,
      '{"jane":{"types":"Observation"}}',
    );
    expect(store.load('jane').isEmpty, isTrue);
    expect(logs, loggedWarning('The saved Records filters could not be read'));
  });

  test('a person saved as something else than filters has none', () async {
    await prefs.setString(RecordsFilterStore.prefsKey, '{"jane":"all"}');

    expect(store.load('jane').isEmpty, isTrue);
  });

  test('filters that cannot be saved are logged, not thrown', () async {
    final readOnly = RecordsFilterStore(_ReadOnlyPrefs());

    await readOnly.save(
      'jane',
      const RecordsFilters(types: [FhirType.Condition]),
    );

    expect(logs, loggedWarning('The Records filters could not be saved'));
  });
}
