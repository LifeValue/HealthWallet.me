import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/domain/services/records_filter_store.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One `getResourcePage` call for the list, as the bloc made it.
typedef _Query = ({
  List<FhirType> types,
  String? sourceId,
  List<String>? sourceIds,
  int? limit,
  int offset,
  DateFilter? dateFilter,
});

class _FakeRecordsRepository extends Fake implements RecordsRepository {
  List<IFhirResource> page = [];

  /// When set, what a query without type filters returns instead of [page].
  List<IFhirResource>? unfiltered;
  List<IFhirResource> patients = const [Patient(id: 'p')];
  List<IFhirResource> searchResults = [];
  List<IFhirResource> related = [];

  /// What one record's related query returns instead of [related].
  final relatedOf = <String, List<IFhirResource>>{};
  Exception? error;
  final queries = <_Query>[];
  final searches = <String>[];
  final searchTypes = <List<FhirType>>[];
  final deletes = <String>[];

  /// While set, each list or search query answers only once its own entry
  /// in [held] is completed, so a test can finish them in any order.
  bool hold = false;
  final held = <Completer<void>>[];

  Future<void> _answer() async {
    if (!hold) return;
    final answer = Completer<void>();
    held.add(answer);
    await answer.future;
  }

  @override
  Future<List<IFhirResource>> getResources({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 20,
    int offset = 0,
  }) async => patients;

  /// [page] (or [unfiltered]) filtered by [where], as one page that ends the
  /// list unless it is full. Reading every encounter for the specialty index
  /// (no limit) isn't recorded.
  @override
  Future<ResourcePage> getResourcePage({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    DateFilter? dateFilter,
    bool Function(IFhirResource resource)? where,
    int? limit = 20,
    int offset = 0,
  }) async {
    if (limit == null) {
      if (error != null) throw error!;
      return (resources: page, nextOffset: 0, hasMore: false);
    }
    queries.add((
      types: resourceTypes,
      sourceId: sourceId,
      sourceIds: sourceIds,
      limit: limit,
      offset: offset,
      dateFilter: dateFilter,
    ));
    await _answer();
    if (error != null) throw error!;
    final rows = resourceTypes.isEmpty && unfiltered != null
        ? unfiltered!
        : page;
    final matches = rows.where((r) => where?.call(r) ?? true).toList();
    return (
      resources: matches,
      nextOffset: offset + rows.length,
      hasMore: rows.length == limit,
    );
  }

  @override
  Future<List<IFhirResource>> searchResources({
    required String query,
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    DateFilter? dateFilter,
    bool Function(IFhirResource resource)? where,
    int limit = 50,
  }) async {
    searches.add(query);
    searchTypes.add(resourceTypes);
    await _answer();
    return [
      for (final r in searchResults)
        if (sourceId == null || r.sourceId == sourceId) r,
    ];
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
  }) async {
    await _answer();
    return relatedOf[resource.id] ?? related;
  }

  @override
  Future<void> deleteResource(String resourceId) async {
    if (error != null) throw error!;
    deletes.add('one:$resourceId');
  }

  @override
  Future<void> deleteResourcesByIds(List<String> ids) async =>
      deletes.add('ids:${ids.join(',')}');
}

/// Classifies a resource as cardiology when its title says so.
class _FakeSpecialtyClassifier extends Fake implements SpecialtyClassifier {
  @override
  EncounterSpecialties indexEncounters(Iterable<IFhirResource> resources) => {};

  @override
  Set<MedicalSpecialty> classify(
    IFhirResource resource, {
    MedicalSpecialty? override,
    EncounterSpecialties? encounterSpecialties,
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

  /// Runs [body] on a new bloc in fake time, so the search debounce passes
  /// without waiting for it.
  void inFakeTime(
    void Function(FakeAsync time, RecordsBloc records) body, {
    RecordsFilterStore? store,
  }) {
    fakeAsync((time) {
      final records = RecordsBloc(
        repository,
        _FakeSpecialtyClassifier(),
        store,
      );
      body(time, records);
      records.close();
      time.flushMicrotasks();
    });
  }

  List<Encounter> encounters(int count, {String title = 'visit'}) => [
    for (var i = 0; i < count; i++) Encounter(id: 'e$i', title: title),
  ];

  group('loading', () {
    test('starts with no filters, on every record', () async {
      repository.page = encounters(3);

      final state = await run(const RecordsInitialised());

      expect(state.activeFilters, isEmpty);
      expect(repository.queries.single.types, isEmpty);
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

    test('scrolling on while the next page loads loads it once', () async {
      repository.page = encounters(20);
      await run(const RecordsInitialised());
      repository.hold = true;

      bloc
        ..add(const RecordsLoadMore())
        ..add(const RecordsLoadMore());
      await pumpEventQueue();
      for (final answer in repository.held) {
        answer.complete();
      }
      await pumpEventQueue();

      expect(repository.queries.map((q) => q.offset), [0, 20]);
      expect(bloc.state.resources, hasLength(40));
    });

    test('no next page is loaded after the last one', () async {
      repository.page = encounters(1);
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
      repository.page = encounters(1);
      final state = await run(const RecordsSourceChanged('s1'));

      expect(repository.queries.single.sourceId, 's1');
      expect(state.sourceId, 's1');
      expect(state.activeFilters, isEmpty);
    });

    test('several sources are passed when no single one is chosen', () async {
      repository.page = encounters(1);
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

  group('each person\'s filters', () {
    late SharedPreferences prefs;
    late RecordsFilterStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = RecordsFilterStore(prefs);
      await bloc.close();
      bloc = RecordsBloc(repository, _FakeSpecialtyClassifier(), store);
    });

    /// A new bloc on the same device, as after an app restart.
    RecordsBloc restart() =>
        bloc = RecordsBloc(repository, _FakeSpecialtyClassifier(), store);

    const range = DateFilter(fromYear: 2024, fromMonth: 3);

    test('a person who never chose a filter sees every record', () async {
      repository.page = encounters(2);

      final state = await run(
        const RecordsSourceChanged('s1', personId: 'jane'),
      );

      expect(state.activeFilters, isEmpty);
      expect(state.activeSpecialties, isEmpty);
      expect(state.dateFilter, isNull);
      expect(repository.queries.single.types, isEmpty);
    });

    test(
      'the filters a person chose are there again after a restart',
      () async {
        await run(const RecordsSourceChanged('s1', personId: 'jane'));
        await run(
          const RecordsFiltersApplied([FhirType.Encounter], dateFilter: range),
        );

        await bloc.close();
        restart();
        final state = await run(
          const RecordsSourceChanged('s1', personId: 'jane'),
        );

        expect(state.activeFilters, [FhirType.Encounter]);
        expect(state.dateFilter, range);
        expect(repository.queries.last.types, [FhirType.Encounter]);
      },
    );

    test('each person keeps their own filters', () async {
      await run(const RecordsSourceChanged(null, personId: 'jane'));
      await run(const RecordsFiltersApplied([FhirType.Condition]));

      final tom = await run(const RecordsSourceChanged(null, personId: 'tom'));
      expect(tom.activeFilters, isEmpty);
      await run(
        const RecordsSpecialtyApplied([MedicalSpecialty.cardiology]),
      );

      final jane = await run(
        const RecordsSourceChanged(null, personId: 'jane'),
      );
      expect(jane.activeFilters, [FhirType.Condition]);
      expect(jane.activeSpecialties, isEmpty);

      final tomAgain = await run(
        const RecordsSourceChanged(null, personId: 'tom'),
      );
      expect(tomAgain.activeSpecialties, [MedicalSpecialty.cardiology]);
    });

    test('reloading the same person keeps the filters on screen', () async {
      await run(const RecordsSourceChanged('s1', personId: 'jane'));
      await run(const RecordsFiltersApplied([FhirType.Condition]));

      final state = await run(
        const RecordsSourceChanged('s2', personId: 'jane'),
      );

      expect(state.activeFilters, [FhirType.Condition]);
      expect(state.sourceId, 's2');
    });

    test('removing a filter, clearing the dates or clearing all is kept '
        'too', () async {
      await run(const RecordsSourceChanged(null, personId: 'jane'));
      await run(
        const RecordsFiltersApplied([
          FhirType.Condition,
          FhirType.Observation,
        ], dateFilter: range),
      );
      await run(const RecordsFilterRemoved(FhirType.Condition));
      await run(const RecordsDateRangeCleared());
      expect(store.load('jane').types, [FhirType.Observation]);
      expect(store.load('jane').dateFilter, isNull);

      await run(RecordsClearAllFilters());

      expect(store.load('jane').isEmpty, isTrue);
      expect(prefs.getString(RecordsFilterStore.prefsKey), '{}');
    });

    test('a share shows no saved filters and keeps none', () async {
      await run(const RecordsSourceChanged(null, personId: 'jane'));
      await run(const RecordsFiltersApplied([FhirType.Condition]));

      final share = await run(
        const RecordsSourceChanged(
          's1',
          personId: 'jane',
          isShareContext: true,
        ),
      );
      expect(share.activeFilters, isEmpty);
      await run(const RecordsFiltersApplied([FhirType.Media]));

      expect(store.load('jane').types, [FhirType.Condition]);
    });

    test('record types and specialties chosen together both apply and are '
        'both kept', () async {
      repository.page = [
        const Encounter(id: 'e1', title: 'heart check'),
        const Encounter(id: 'e2', title: 'flu'),
      ];
      await run(const RecordsSourceChanged(null, personId: 'jane'));

      await run(const RecordsFiltersApplied([FhirType.Encounter]));
      final state = await run(
        const RecordsSpecialtyApplied([MedicalSpecialty.cardiology]),
      );

      expect(state.activeFilters, [FhirType.Encounter]);
      expect(state.activeSpecialties, [MedicalSpecialty.cardiology]);
      expect(repository.queries.last.types, [FhirType.Encounter]);
      expect(state.resources.map((r) => r.id), ['e1']);
      expect(store.load('jane').types, [FhirType.Encounter]);
      expect(store.load('jane').specialties, [MedicalSpecialty.cardiology]);
    });

    test('a Home card filters this visit only, and the person\'s own '
        'filters come back when Records is left', () async {
      await run(const RecordsSourceChanged(null, personId: 'jane'));
      await run(const RecordsFiltersApplied([FhirType.Condition]));

      await run(const RecordsSpecialtyApplied([], remember: false));
      final card = await run(
        const RecordsFiltersApplied([FhirType.Observation], remember: false),
      );
      expect(card.activeFilters, [FhirType.Observation]);
      expect(store.load('jane').types, [FhirType.Condition]);

      final after = await run(RecordsVisitEnded());

      expect(after.activeFilters, [FhirType.Condition]);
      expect(repository.queries.last.types, [FhirType.Condition]);
    });

    test('a Home card specialty is not kept either', () async {
      await run(const RecordsSourceChanged(null, personId: 'jane'));

      await run(
        const RecordsSpecialtyApplied([
          MedicalSpecialty.cardiology,
        ], remember: false),
      );
      expect(store.load('jane').isEmpty, isTrue);

      final after = await run(RecordsVisitEnded());

      expect(after.activeSpecialties, isEmpty);
    });

    test('leaving Records after choosing filters yourself changes '
        'nothing', () async {
      await run(const RecordsSourceChanged(null, personId: 'jane'));
      await run(const RecordsFiltersApplied([FhirType.Condition]));
      final queries = repository.queries.length;

      final after = await run(RecordsVisitEnded());

      expect(after.activeFilters, [FhirType.Condition]);
      expect(repository.queries, hasLength(queries));
    });

    test('changing a Home card\'s filter yourself makes it your own', () async {
      await run(const RecordsSourceChanged(null, personId: 'jane'));
      await run(
        const RecordsFiltersApplied([
          FhirType.Observation,
          FhirType.Condition,
        ], remember: false),
      );

      await run(const RecordsFilterRemoved(FhirType.Observation));
      final after = await run(RecordsVisitEnded());

      expect(store.load('jane').types, [FhirType.Condition]);
      expect(after.activeFilters, [FhirType.Condition]);
    });

    test('a search does not change the saved filters', () {
      inFakeTime(store: store, (time, records) {
        records
          ..add(const RecordsSourceChanged(null, personId: 'jane'))
          ..add(const RecordsFiltersApplied([FhirType.Condition]));
        time.flushMicrotasks();

        records.add(const RecordsSearch('zz'));
        time.elapse(const Duration(milliseconds: 500));

        expect(repository.searches, ['zz']);
        expect(store.load('jane').types, [FhirType.Condition]);
      });
    });
  });

  test('without a store, chosen filters last as long as the bloc and stay '
      'when the person changes', () async {
    await run(const RecordsSourceChanged(null, personId: 'jane'));
    await run(const RecordsFiltersApplied([FhirType.Condition]));

    final state = await run(const RecordsSourceChanged(null, personId: 'tom'));

    expect(state.activeFilters, [FhirType.Condition]);
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

    test('a specialty keeps only the matching records, and the chosen '
        'types stay', () async {
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

      expect(state.activeFilters, [FhirType.Encounter]);
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

    test('a specialty, then record types, show only records matching both, '
        'whichever query answers last', () async {
      repository
        ..unfiltered = [const Encounter(id: 'e1', title: 'heart check')]
        ..page = [const Observation(id: 'o1', title: 'heart rate')]
        ..hold = true;

      // The specialty's query still has the old types, and is still out
      // when the types change.
      bloc.add(
        const RecordsSpecialtyApplied([
          MedicalSpecialty.cardiology,
        ], remember: false),
      );
      await pumpEventQueue();
      bloc.add(
        const RecordsFiltersApplied(
          [FhirType.Observation],
          specialties: [MedicalSpecialty.cardiology],
          remember: false,
        ),
      );
      await pumpEventQueue();
      expect(repository.held, hasLength(2));

      repository.held[1].complete();
      await pumpEventQueue();
      repository.held[0].complete();
      await pumpEventQueue();

      final state = bloc.state;
      expect(state.activeFilters, [FhirType.Observation]);
      expect(state.activeSpecialties, [MedicalSpecialty.cardiology]);
      expect(state.status, const RecordsStatus.success());
      expect(state.resources.map((r) => r.id), ['o1']);
    });

    test('a failed earlier load does not hide the latest one', () async {
      repository
        ..page = encounters(1)
        ..hold = true;
      bloc
        ..add(const RecordsFiltersApplied([FhirType.Encounter]))
        ..add(const RecordsFiltersApplied([FhirType.Observation]));
      await pumpEventQueue();

      repository.held[1].complete();
      await pumpEventQueue();
      repository.error = Exception('db');
      repository.held[0].complete();
      await pumpEventQueue();

      expect(bloc.state.status, const RecordsStatus.success());
      expect(bloc.state.resources, hasLength(1));
    });

    test('a refresh reloads', () async {
      await run(RecordsRefreshRequested());

      expect(repository.queries, hasLength(1));
    });
  });

  group('search', () {
    test('runs after the debounce and lists the matches', () {
      repository.searchResults = encounters(2);

      inFakeTime((time, records) {
        records.add(const RecordsSearch('  he  '));
        time.elapse(const Duration(milliseconds: 499));
        expect(records.state.searchQuery, 'he');
        expect(repository.searches, isEmpty);

        time.elapse(const Duration(milliseconds: 1));

        expect(repository.searches, ['he']);
        expect(records.state.resources, hasLength(2));
        expect(records.state.hasMorePages, isFalse);
      });
    });

    test('a one-letter query does not search', () {
      inFakeTime((time, records) {
        records.add(const RecordsSearch('h'));
        time.elapse(const Duration(seconds: 1));

        expect(repository.searches, isEmpty);
      });
    });

    test('a search on the previous source does not replace the new '
        'source\'s hits', () {
      repository.searchResults = [
        const Encounter(id: 'a', sourceId: 's1', title: 'insulin'),
        const Encounter(id: 'b', sourceId: 's2', title: 'insulin'),
      ];

      inFakeTime((time, records) {
        records
          ..add(const RecordsSourceChanged('s1'))
          ..add(const RecordsSearch('insulin'));
        time.elapse(const Duration(milliseconds: 500));
        expect(records.state.resources.map((r) => r.id), ['a']);

        repository.hold = true;
        // What Records sends when it opens again, after a patient switch.
        records
          ..add(const RecordsInitialised())
          ..add(const RecordsSourceChanged('s2'));
        time.flushMicrotasks();
        for (final answer in repository.held.reversed.toList()) {
          answer.complete();
          time.flushMicrotasks();
        }

        expect(records.state.sourceId, 's2');
        expect(records.state.resources.map((r) => r.id), ['b']);
      });
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

    test('only the last record opened shows its related records', () async {
      repository
        ..relatedOf['o1'] = encounters(1)
        ..relatedOf['o2'] = encounters(2)
        ..hold = true;

      bloc
        ..add(const RecordDetailLoaded(Observation(id: 'o1')))
        ..add(const RecordDetailLoaded(Observation(id: 'o2')));
      await pumpEventQueue();
      repository.held[1].complete();
      await pumpEventQueue();
      repository.held[0].complete();
      await pumpEventQueue();

      expect(bloc.state.relatedResources, hasLength(2));
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
