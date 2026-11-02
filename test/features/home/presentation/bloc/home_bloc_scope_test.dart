import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/home/data/services/specialty_classifier_impl.dart';
import 'package:health_wallet/features/home/domain/repository/home_preferences_repository.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/use_case/get_sources_use_case.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHolderService extends Fake implements HolderService {
  @override
  Future<HolderDirectory> load() async =>
      const HolderDirectory(holders: [jane]);
}

/// Records whose records each read asked for.
class _RecordingRecords extends Fake implements RecordsRepository {
  final scopes = <String>{};

  @override
  Future<List<IFhirResource>> getResources({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 20,
    int offset = 0,
    DateFilter? dateFilter,
  }) async {
    scopes.add(sourceId ?? sourceIds.toString());
    return [];
  }
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

class _NoSources extends Fake implements SyncRepository {
  @override
  Future<List<Source>> getSources() async => [];
}

const jane = Holder(
  id: 'jane',
  representativePatient: Patient(id: 'jane', sourceId: 'wallet-jane'),
  sourceIds: ['epic', 'wallet-jane'],
  allPatientInstances: [
    Patient(id: 'jane', sourceId: 'wallet-jane'),
    Patient(id: 'p1', sourceId: 'epic'),
  ],
);

void main() {
  late _RecordingRecords records;
  late HolderSelection selection;
  late HomeBloc bloc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    records = _RecordingRecords();
    selection = HolderSelection(
      _FakeHolderService(),
      await SharedPreferences.getInstance(),
    );
    bloc = HomeBloc(
      GetSourcesUseCase(_NoSources()),
      _NoPreferences(),
      records,
      _NoSources(),
      selection,
      SpecialtyClassifierImpl(),
    );
  });

  tearDown(() => bloc.close());

  Future<HomeState> settled() =>
      bloc.stream.firstWhere((s) => s.status == const HomeStatus.success());

  test("every reload reads all of the selected person's sources", () async {
    await selection.refresh();
    await settled();
    expect(records.scopes, {'[epic, wallet-jane]'});
    expect(bloc.state.patient!.id, 'jane');

    records.scopes.clear();
    bloc.add(const HomeRefreshPreservingOrder());
    await settled();
    bloc.add(const HomeScanCompleted());
    bloc.add(const HomeRefreshPreservingOrder());
    await settled();
    expect(records.scopes, {'[epic, wallet-jane]'});
  });

  test('a source filter reads that source and shows its row', () async {
    await selection.refresh();
    await settled();

    records.scopes.clear();
    bloc.add(const HomeSourceChanged('epic'));
    await settled();

    expect(records.scopes, {'epic'});
    expect(bloc.state.selectedSource, 'epic');
    expect(bloc.state.patient!.id, 'p1');
    expect(selection.scope.sourceFilter, 'epic');
  });
}
