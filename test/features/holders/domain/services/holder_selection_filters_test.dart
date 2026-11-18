import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/services/records_filter_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHolderService extends Fake implements HolderService {
  HolderDirectory directory = const HolderDirectory();

  @override
  Future<HolderDirectory> load() async => directory;
}

const _jane = Holder(
  id: 'jane',
  representativePatient: Patient(id: 'jane', sourceId: 'wallet-jane'),
  sourceIds: ['wallet-jane'],
  allPatientInstances: [Patient(id: 'jane', sourceId: 'wallet-jane')],
);
const _tom = Holder(
  id: 'tom',
  representativePatient: Patient(id: 'tom', sourceId: 'wallet-tom'),
  sourceIds: ['wallet-tom'],
  allPatientInstances: [Patient(id: 'tom', sourceId: 'wallet-tom')],
);

void main() {
  late _FakeHolderService holders;
  late RecordsFilterStore filters;
  late HolderSelection selection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    filters = RecordsFilterStore(prefs);
    await filters.save(
      'jane',
      const RecordsFilters(types: [FhirType.Condition]),
    );
    await filters.save(
      'tom',
      const RecordsFilters(specialties: [MedicalSpecialty.psychiatry]),
    );
    holders = _FakeHolderService()
      ..directory = const HolderDirectory(holders: [_jane, _tom]);
    selection = HolderSelection(holders, prefs, filters);
  });

  group("a deleted person's Records filters", () {
    test('are forgotten once the people are read again', () async {
      await selection.refresh();
      expect(filters.load('tom').specialties, [MedicalSpecialty.psychiatry]);

      holders.directory = const HolderDirectory(holders: [_jane]);
      await selection.refresh();

      expect(filters.load('tom').isEmpty, isTrue);
      expect(filters.load('jane').types, [FhirType.Condition]);
    });

    test('do not come back when the same id returns', () async {
      holders.directory = const HolderDirectory(holders: [_jane]);
      await selection.refresh();

      holders.directory = const HolderDirectory(holders: [_jane, _tom]);
      await selection.refresh();

      expect(filters.load('tom').isEmpty, isTrue);
    });

    test('are all forgotten when no one is left', () async {
      holders.directory = const HolderDirectory();
      await selection.refresh();

      expect(filters.load('jane').isEmpty, isTrue);
      expect(filters.load('tom').isEmpty, isTrue);
    });
  });
}
