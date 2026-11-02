import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';

/// One `getResources` call as the bloc made it.
typedef _Query = ({
  List<FhirType> types,
  String? sourceId,
  List<String>? sourceIds,
  int limit,
  int offset,
  DateFilter? dateFilter,
});

class _FakeRecordsRepository extends Fake implements RecordsRepository {
  List<IFhirResource> page = [];
  List<IFhirResource> patients = const [Patient(id: 'p')];
  List<IFhirResource> searchResults = [];
  List<IFhirResource> related = [];
  Exception? error;
  bool demoLoaded = false;
  final queries = <_Query>[];
  final searches = <String>[];
  final deletes = <String>[];

  @override
  Future<List<IFhirResource>> getResources({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 20,
    int offset = 0,
    DateFilter? dateFilter,
  }) async {
    if (resourceTypes.length == 1 && resourceTypes.single == FhirType.Patient) {
      return patients;
    }
    if (error != null) throw error!;
    queries.add((
      types: resourceTypes,
      sourceId: sourceId,
      sourceIds: sourceIds,
      limit: limit,
      offset: offset,
      dateFilter: dateFilter,
    ));
    return page;
  }

  @override
  Future<List<IFhirResource>> searchResources({
    required String query,
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 50,
  }) async {
    searches.add(query);
    return searchResults;
  }

  @override
  Future<List<IFhirResource>> getRelatedResourcesForEncounter({
    required String encounterId,
    String? sourceId,
  }) async {
    if (error != null) throw error!;
    return related;
  }

  @override
  Future<List<IFhirResource>> getRelatedResources({
    required IFhirResource resource,
  }) async => related;

  @override
  Future<void> loadDemoData() async {
    if (error != null) throw error!;
    demoLoaded = true;
  }

  @override
  Future<void> clearDemoData() async {
    if (error != null) throw error!;
    demoLoaded = false;
  }

  @override
  Future<bool> hasDemoData() async => demoLoaded;

  @override
  Future<void> deleteResource(String resourceId) async {
    if (error != null) throw error!;
    deletes.add('one:$resourceId');
  }

  @override
  Future<void> deleteResourceWithRelated(String resourceId) async =>
      deletes.add('related:$resourceId');

  @override
  Future<void> deleteResourcesByIds(List<String> ids) async =>
      deletes.add('ids:${ids.join(',')}');
}

/// Classifies a resource as cardiology when its title says so.
class _FakeSpecialtyClassifier extends Fake implements SpecialtyClassifier {
  @override
  void buildEncounterIndex(List<IFhirResource> allResources) {}

  @override
  Set<MedicalSpecialty> classify(
    IFhirResource resource, {
    MedicalSpecialty? override,
  }) => {
    ?override,
    if (resource.title.contains('heart')) MedicalSpecialty.cardiology,
  };
}

void main() {
  late _FakeRecordsRepository repository;
  late RecordsBloc bloc;

  setUp(() {
    repository = _FakeRecordsRepository();
    bloc = RecordsBloc(repository, _FakeSpecialtyClassifier());
  });

  tearDown(() => bloc.close());

  /// Adds [event] and waits until the bloc has handled it.
  Future<RecordsState> run(RecordsEvent event) async {
    bloc.add(event);
    await pumpEventQueue();
    return bloc.state;
  }

  List<Encounter> encounters(int count, {String title = 'visit'}) => [
    for (var i = 0; i < count; i++) Encounter(id: 'e$i', title: title),
  ];

  group('loading', () {
    test('starts on encounters and reports', () async {
      repository.page = encounters(3);

      final state = await run(const RecordsInitialised());

      expect(state.activeFilters, [
        FhirType.Encounter,
        FhirType.DiagnosticReport,
      ]);
      expect(state.status, const RecordsStatus.success());
      expect(state.resources, hasLength(3));
      expect(state.hasMorePages, isFalse);
    });

    test('a share context starts without filters', () async {
      final state = await run(const RecordsInitialised(isShareContext: true));

      expect(state.activeFilters, isEmpty);
    });

    test('a full page loads the next one', () async {
      repository.page = encounters(20);
      await run(const RecordsInitialised());
      expect(bloc.state.hasMorePages, isTrue);

      repository.page = encounters(5);
      final state = await run(const RecordsLoadMore());

      expect(repository.queries.last.offset, 20);
      expect(state.resources, hasLength(25));
      expect(state.hasMorePages, isFalse);
    });

    test('no next page is loaded after the last one', () async {
      await run(const RecordsInitialised());

      await run(const RecordsLoadMore());

      expect(repository.queries, hasLength(1));
    });

    test('a failed load fails', () async {
      repository.error = Exception('db');

      final state = await run(const RecordsInitialised());

      expect(state.status, isA<RecordsStatus>());
      expect(state.status, isNot(const RecordsStatus.success()));
    });

    test('a source change reloads that source', () async {
      final state = await run(const RecordsSourceChanged('s1'));

      expect(repository.queries.single.sourceId, 's1');
      expect(state.sourceId, 's1');
      expect(state.activeFilters, isNotEmpty);
    });

    test('several sources are passed when no single one is chosen', () async {
      await run(const RecordsSourceChanged(null, sourceIds: ['a', 'b']));

      expect(repository.queries.single.sourceIds, ['a', 'b']);
    });

    test('a share context source change keeps no filters', () async {
      final state = await run(
        const RecordsSourceChanged('s1', isShareContext: true),
      );

      expect(state.activeFilters, isEmpty);
    });

    test('media keep to the chosen source', () async {
      await run(const RecordsSourceChanged('s1'));

      await run(const RecordsFiltersApplied([FhirType.Media]));

      expect(repository.queries.last.sourceId, 's1');
    });
  });

  group('filters', () {
    const range = DateFilter(fromYear: 2024);

    test('applied filters and dates are queried', () async {
      final state = await run(
        const RecordsFiltersApplied([
          FhirType.Observation,
        ], dateFilter: range),
      );

      expect(repository.queries.last.types, [FhirType.Observation]);
      expect(repository.queries.last.dateFilter, range);
      expect(state.dateFilter, range);
    });

    test('a removed filter is dropped', () async {
      await run(
        const RecordsFiltersApplied([FhirType.Observation, FhirType.Condition]),
      );

      final state = await run(const RecordsFilterRemoved(FhirType.Condition));

      expect(state.activeFilters, [FhirType.Observation]);
    });

    test('clearing the dates reloads without them', () async {
      await run(const RecordsFiltersApplied([], dateFilter: range));

      final state = await run(const RecordsDateRangeCleared());

      expect(state.dateFilter, isNull);
      expect(repository.queries.last.dateFilter, isNull);
    });

    test('a specialty keeps only the matching records', () async {
      repository.page = [
        const Encounter(id: 'a', title: 'heart check'),
        const Encounter(id: 'b', title: 'skin check'),
        const Encounter(
          id: 'c',
          title: 'other',
          specialtyOverride: 'cardiology',
        ),
      ];
      await run(const RecordsFiltersApplied([FhirType.Encounter]));

      final state = await run(
        const RecordsSpecialtyApplied([MedicalSpecialty.cardiology]),
      );

      expect(state.activeFilters, isEmpty);
      expect(state.resources.map((r) => r.id), ['a', 'c']);
    });

    test('an empty specialty choice keeps the type filters', () async {
      await run(const RecordsFiltersApplied([FhirType.Encounter]));

      final state = await run(const RecordsSpecialtyApplied([]));

      expect(state.activeFilters, [FhirType.Encounter]);
    });

    test('clearing all filters drops types, specialties and dates', () async {
      await run(const RecordsFiltersApplied([FhirType.Encounter]));

      final state = await run(RecordsClearAllFilters());

      expect(state.activeFilters, isEmpty);
      expect(state.activeSpecialties, isEmpty);
      expect(state.dateFilter, isNull);
    });

    test('a refresh reloads', () async {
      await run(RecordsRefreshRequested());

      expect(repository.queries, hasLength(1));
    });
  });

  group('search', () {
    test('runs after the debounce and lists the matches', () async {
      repository.searchResults = encounters(2);

      await run(const RecordsSearch('  he  '));
      expect(bloc.state.searchQuery, 'he');
      expect(repository.searches, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 600));
      await pumpEventQueue();

      expect(repository.searches, ['he']);
      expect(bloc.state.resources, hasLength(2));
      expect(bloc.state.hasMorePages, isFalse);
    });

    test('a one-letter query does not search', () async {
      await run(const RecordsSearch('h'));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await pumpEventQueue();

      expect(repository.searches, isEmpty);
    });

    test('an empty query reloads the list', () async {
      await run(const RecordsSearch(''));

      expect(repository.queries, hasLength(1));
    });

    test('while searching, no next page is loaded', () async {
      await run(const RecordsSearch('he'));

      await run(const RecordsLoadMore());

      expect(repository.queries, isEmpty);
    });
  });

  group('record detail', () {
    test('an encounter loads the records it groups', () async {
      repository.related = encounters(2);

      final state = await run(
        const RecordDetailLoaded(Encounter(id: 'e', resourceId: 'r')),
      );

      expect(state.recordDetailStatus, const RecordDetailStatus.success());
      expect(state.relatedResources, hasLength(2));
    });

    test('another record loads its references', () async {
      repository.related = encounters(1);

      final state = await run(const RecordDetailLoaded(Observation(id: 'o')));

      expect(state.relatedResources, hasLength(1));
    });

    test('a failed load fails the detail', () async {
      repository.error = Exception('db');

      final state = await run(const RecordDetailLoaded(Encounter(id: 'e')));

      expect(
        state.recordDetailStatus,
        isNot(const RecordDetailStatus.success()),
      );
    });
  });

  group('demo data', () {
    test('loading marks it present and reloads', () async {
      final state = await run(const LoadDemoData());

      expect(state.hasDemoData, isTrue);
      expect(state.isLoadingDemoData, isFalse);
      expect(repository.queries, hasLength(1));
    });

    test('clearing marks it absent and reloads', () async {
      await run(const LoadDemoData());

      final state = await run(const ClearDemoData());

      expect(state.hasDemoData, isFalse);
      expect(repository.queries, hasLength(2));
    });

    test('a failed load or clear keeps the error', () async {
      repository.error = Exception('asset');

      expect((await run(const LoadDemoData())).demoDataError, isNotNull);
      expect((await run(const ClearDemoData())).demoDataError, isNotNull);
    });
  });

  group('selection', () {
    test('toggling selects and unselects', () async {
      await run(const RecordsSelectionToggled('a'));
      await run(const RecordsSelectionToggled('b'));
      expect(bloc.state.selectedResourceIds, {'a', 'b'});

      await run(const RecordsSelectionToggled('a'));
      expect(bloc.state.selectedResourceIds, {'b'});

      await run(const RecordsSelectionCleared());
      expect(bloc.state.selectedResourceIds, isEmpty);
    });

    test('leaving selection mode clears the selection', () async {
      await run(const RecordsSelectionModeToggled());
      await run(const RecordsSelectionToggled('a'));
      expect(bloc.state.isSelectionMode, isTrue);
      expect(bloc.state.selectedResourceIds, {'a'});

      await run(const RecordsSelectionModeToggled());

      expect(bloc.state.isSelectionMode, isFalse);
      expect(bloc.state.selectedResourceIds, isEmpty);
    });
  });

  group('delete', () {
    test('one record is deleted, then the list reloads', () async {
      final statuses = <RecordsStatus>[];
      final sub = bloc.stream.listen((s) => statuses.add(s.status));

      await run(const RecordsResourceDeleted(resourceId: 'r'));
      await sub.cancel();

      expect(repository.deletes, ['one:r']);
      expect(statuses, contains(const RecordsStatus.deleted()));
      expect(repository.queries, hasLength(1));
    });

    test('a record with its related records', () async {
      await run(
        const RecordsResourceDeleted(resourceId: 'r', deleteRelated: true),
      );

      expect(repository.deletes, ['related:r']);
    });

    test('a record with the chosen related records', () async {
      await run(
        const RecordsResourceDeleted(
          resourceId: 'r',
          selectedRelatedIds: ['x', 'y'],
        ),
      );

      expect(repository.deletes, ['ids:r,x,y']);
    });

    test('the last patient gone leaves an empty list', () async {
      repository.patients = const [];

      final state = await run(const RecordsResourceDeleted(resourceId: 'r'));

      expect(state.status, const RecordsStatus.success());
      expect(state.resources, isEmpty);
      expect(repository.queries, isEmpty);
    });

    test('a failed delete fails', () async {
      repository.error = Exception('db');

      final state = await run(const RecordsResourceDeleted(resourceId: 'r'));

      expect(state.status, isNot(const RecordsStatus.success()));
      expect(state.status, isNot(const RecordsStatus.deleted()));
    });
  });

  test('exposes its repository', () {
    expect(bloc.recordsRepository, same(repository));
  });
}
