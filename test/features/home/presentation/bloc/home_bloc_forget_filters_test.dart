import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/home/data/services/specialty_classifier_impl.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/repository/home_preferences_repository.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/domain/services/records_filter_store.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/use_case/get_sources_use_case.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _jane = Holder(
  id: 'jane',
  representativePatient: Patient(id: 'jane', sourceId: 'wallet-jane'),
  sourceIds: ['wallet-jane'],
  allPatientInstances: [Patient(id: 'jane', sourceId: 'wallet-jane')],
);
const _tom = Holder(
  id: 'tom',
  representativePatient: Patient(id: 'tom', sourceId: 'epic'),
  sourceIds: ['epic'],
  allPatientInstances: [Patient(id: 'tom', sourceId: 'epic')],
);

/// The wallet's sources, and the people they make: a person is there while
/// one of their sources is.
class _FakeWallet extends Fake implements SyncRepository, HolderService {
  final sourceIds = {'wallet-jane', 'epic'};

  @override
  Future<List<Source>> getSources() async => [
    for (final id in sourceIds) Source(id: id),
  ];

  @override
  Future<void> deleteSource(String sourceId) async =>
      sourceIds.remove(sourceId);

  @override
  Future<HolderDirectory> load() async => HolderDirectory(
    holders: [
      for (final holder in const [_jane, _tom])
        if (holder.sourceIds.any(sourceIds.contains)) holder,
    ],
  );
}

class _NoRecords extends Fake implements RecordsRepository {
  @override
  Future<List<IFhirResource>> getResources({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 20,
    int offset = 0,
    DateFilter? dateFilter,
  }) async => [];
}

class _NoPreferences extends Fake implements HomePreferencesRepository {
  @override
  Future<List<String>?> getVitalsOrder() async => null;
  @override
  Future<List<String>?> getRecordsOrder() async => null;
  @override
  Future<Map<String, bool>?> getVitalsVisibility() async => null;
  @override
  Future<Map<String, bool>?> getRecordsVisibility() async => null;
  @override
  Future<List<String>?> getSpecialtiesOrder() async => null;
  @override
  Future<Map<String, bool>?> getSpecialtiesVisibility() async => null;
}

void main() {
  late _FakeWallet wallet;
  late RecordsFilterStore filters;
  late HolderSelection selection;
  late HomeBloc bloc;

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
    wallet = _FakeWallet();
    selection = HolderSelection(wallet, prefs, filters);
    bloc = HomeBloc(
      GetSourcesUseCase(wallet),
      _NoPreferences(),
      _NoRecords(),
      wallet,
      selection,
      SpecialtyClassifierImpl(),
    );
  });

  tearDown(() => bloc.close());

  test(
    "deleting a person's last source forgets their Records filters",
    () async {
      await selection.refresh();

      bloc.add(const HomeSourceDeleted('epic'));
      await pumpEventQueue();

      expect(selection.scope.directory.holders, [_jane]);
      expect(filters.load('tom').isEmpty, isTrue);
      expect(filters.load('jane').types, [FhirType.Condition]);
    },
  );
}
