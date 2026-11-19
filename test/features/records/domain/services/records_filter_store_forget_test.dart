import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/services/records_filter_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late RecordsFilterStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = RecordsFilterStore(prefs);
    await store.save(
      'jane',
      const RecordsFilters(types: [FhirType.Condition]),
    );
    await store.save(
      'tom',
      const RecordsFilters(specialties: [MedicalSpecialty.psychiatry]),
    );
  });

  group('forgetting people no longer in the wallet', () {
    test('removes their filters and keeps everyone else\'s', () async {
      await store.forgetAllBut({'jane'});

      expect(store.load('tom').isEmpty, isTrue);
      expect(store.load('jane').types, [FhirType.Condition]);
      expect(
        prefs.getString(RecordsFilterStore.prefsKey),
        isNot(contains('tom')),
      );
    });

    test('with no one left, removes every entry', () async {
      await store.forgetAllBut(const {});

      expect(prefs.getString(RecordsFilterStore.prefsKey), '{}');
    });

    test(
      'leaves the saved filters untouched when everyone is still there',
      () async {
        final before = prefs.getString(RecordsFilterStore.prefsKey);

        await store.forgetAllBut({'jane', 'tom', 'anna'});

        expect(prefs.getString(RecordsFilterStore.prefsKey), before);
      },
    );
  });
}
