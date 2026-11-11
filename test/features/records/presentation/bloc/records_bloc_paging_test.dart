import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';

/// Serves [records] per source, newest first, a page at a time.
class _FakeRecordsRepository extends Fake implements RecordsRepository {
  _FakeRecordsRepository(this.records);

  final List<IFhirResource> records;
  final deleted = <String>[];
  final searchedSources = <String?>[];

  /// How long a search takes; the database is not instant.
  Duration searchTime = Duration.zero;

  Iterable<IFhirResource> _scoped(String? sourceId, List<String>? sourceIds) =>
      records.where(
        (r) =>
            (sourceId == null || r.sourceId == sourceId) &&
            (sourceIds == null || sourceIds.contains(r.sourceId)),
      );

  /// Pages the way the real repository does: offsets count stored rows,
  /// and a page is filled past the rows a filter skips.
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
    final rows = _scoped(sourceId, sourceIds)
        .where(
          (r) => resourceTypes.isEmpty || resourceTypes.contains(r.fhirType),
        )
        .toList();
    final page = <IFhirResource>[];
    var next = offset;
    while (next < rows.length) {
      final row = rows[next++];
      final date = row.date;
      if (dateFilter != null && date != null && !dateFilter.matches(date)) {
        continue;
      }
      if (where != null && !where(row)) continue;
      page.add(row);
      if (page.length == limit) break;
    }
    return (resources: page, nextOffset: next, hasMore: next < rows.length);
  }

  @override
  Future<List<IFhirResource>> getResourcesByIds(Iterable<String> ids) async =>
      records.where((r) => ids.contains(r.id)).toList();

  /// Only the patients, which the bloc checks after a delete.
  @override
  Future<List<IFhirResource>> getResources({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 20,
    int offset = 0,
  }) async => _scoped(
    sourceId,
    sourceIds,
  ).where((r) => resourceTypes.contains(r.fhirType)).take(limit).toList();

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
    searchedSources.add(sourceId);
    await Future<void>.delayed(searchTime);
    return _scoped(sourceId, sourceIds)
        .where(
          (r) => resourceTypes.isEmpty || resourceTypes.contains(r.fhirType),
        )
        .where((r) => r.title.toLowerCase().contains(query.toLowerCase()))
        .where((r) {
          final date = r.date;
          return dateFilter == null || date == null || dateFilter.matches(date);
        })
        .where((r) => where?.call(r) ?? true)
        .take(limit)
        .toList();
  }

  @override
  Future<void> deleteResourcesByIds(List<String> ids) async {
    deleted.addAll(ids);
    records.removeWhere((r) => ids.contains(r.id));
  }

  @override
  Future<void> deleteResource(String resourceId) =>
      deleteResourcesByIds([resourceId]);
}

/// Classifies a record as cardiology when its title mentions the heart.
class _FakeSpecialtyClassifier extends Fake implements SpecialtyClassifier {
  @override
  EncounterSpecialties indexEncounters(Iterable<IFhirResource> resources) => {};

  @override
  Set<MedicalSpecialty> classify(
    IFhirResource resource, {
    MedicalSpecialty? override,
    EncounterSpecialties? encounterSpecialties,
  }) => resource.title.contains('heart')
      ? {MedicalSpecialty.cardiology}
      : {MedicalSpecialty.generalCare};
}

Encounter _visit(int i, {String source = 's1', String title = 'Visit'}) =>
    Encounter(
      id: '$source-$i',
      resourceId: '$source-$i',
      sourceId: source,
      title: '$title $i',
      date: DateTime(2024).subtract(Duration(days: i)),
    );

void main() {
  late _FakeRecordsRepository repository;
  late RecordsBloc bloc;

  void build(List<IFhirResource> records) {
    repository = _FakeRecordsRepository(records);
    bloc = RecordsBloc(repository, _FakeSpecialtyClassifier());
  }

  tearDown(() => bloc.close());

  /// Waits until the bloc is idle and [condition] holds.
  Future<void> until(bool Function(RecordsState s) condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (bloc.state.status != const RecordsStatus.success() ||
        !condition(bloc.state)) {
      if (DateTime.now().isAfter(deadline)) {
        fail('not reached; the bloc is at ${bloc.state}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  group('paging', () {
    test('the first page has 20 records and more to come', () async {
      build([for (var i = 0; i < 45; i++) _visit(i)]);

      bloc.add(const RecordsSourceChanged('s1'));
      await until((s) => s.resources.length == 20);

      expect(bloc.state.hasMorePages, isTrue);
    });

    test('loading more appends the next pages and stops at the end', () async {
      build([for (var i = 0; i < 45; i++) _visit(i)]);
      bloc.add(const RecordsSourceChanged('s1'));
      await until((s) => s.resources.length == 20);

      bloc.add(const RecordsLoadMore());
      await until((s) => s.resources.length == 40);
      bloc.add(const RecordsLoadMore());
      await until((s) => s.resources.length == 45);

      expect(bloc.state.hasMorePages, isFalse);
      expect(
        bloc.state.resources.map((r) => r.id).toSet(),
        hasLength(45),
        reason: 'no record twice',
      );
    });

    test('loading more keeps the list on screen', () async {
      build([for (var i = 0; i < 45; i++) _visit(i)]);
      bloc.add(const RecordsSourceChanged('s1'));
      await until((s) => s.resources.length == 20);
      final statuses = <RecordsStatus>[];
      final sub = bloc.stream.listen((s) => statuses.add(s.status));

      bloc.add(const RecordsLoadMore());
      await until((s) => s.resources.length == 40);
      await sub.cancel();

      // A full-screen spinner instead of the list would throw the user back
      // to the top (A26).
      expect(statuses, isNot(contains(const RecordsStatus.loading())));
    });
  });

  group('source', () {
    test('the same source again refreshes without emptying the list or the '
        'selection', () async {
      build([_visit(1), _visit(2)]);
      bloc.add(const RecordsSourceChanged('s1'));
      await until((s) => s.resources.length == 2);
      bloc.add(const RecordsSelectionToggled('s1-1'));
      final shown = <int>[];
      final sub = bloc.stream.listen((s) => shown.add(s.resources.length));

      bloc.add(const RecordsSourceChanged('s1'));
      await until((s) => shown.isNotEmpty);
      await sub.cancel();

      expect(shown, everyElement(2));
      expect(bloc.state.selectedResourceIds, {'s1-1'});
    });

    test('a new source starts the list over with its records', () async {
      build([_visit(1), _visit(2, source: 's2')]);
      bloc.add(const RecordsSourceChanged('s1'));
      await until((s) => s.resources.isNotEmpty);

      bloc.add(const RecordsSourceChanged('s2'));
      await until((s) => s.sourceId == 's2' && s.resources.isNotEmpty);

      expect(bloc.state.resources.map((r) => r.id), ['s2-2']);
    });

    test('a patient\'s sources list only their records', () async {
      build([_visit(1), _visit(2, source: 's2'), _visit(3, source: 's3')]);

      bloc.add(const RecordsSourceChanged(null, sourceIds: ['s1', 's2']));
      await until((s) => s.resources.length == 2);

      expect(bloc.state.resources.map((r) => r.id), ['s1-1', 's2-2']);
    });

    test('without chosen filters, every record is shown', () async {
      build([_visit(1), const Patient(id: 'p', sourceId: 's1')]);

      bloc.add(const RecordsSourceChanged('s1'));
      await until((s) => s.resources.length == 2);

      expect(bloc.state.activeFilters, isEmpty);
      expect(bloc.state.resources.map((r) => r.id), containsAll(['s1-1', 'p']));
    });

    test('chosen filters stay when the source changes', () async {
      build([_visit(1)]);
      bloc.add(const RecordsFiltersApplied([FhirType.Condition]));
      await until((s) => s.activeFilters.isNotEmpty);

      bloc.add(const RecordsSourceChanged('s2'));
      await until((s) => s.sourceId == 's2');

      expect(bloc.state.activeFilters, [FhirType.Condition]);
    });

    test('sharing starts without filters', () async {
      build([_visit(1)]);

      bloc.add(const RecordsSourceChanged('s1', isShareContext: true));
      await until((s) => s.resources.isNotEmpty);

      expect(bloc.state.activeFilters, isEmpty);
    });

    test('a change of source or patient clears the selection', () async {
      build([_visit(1), _visit(2, source: 's2')]);
      bloc.add(const RecordsSourceChanged('s1'));
      await until((s) => s.resources.isNotEmpty);
      bloc.add(const RecordsSelectionToggled('s1-1'));
      await until((s) => s.selectedResourceIds.isNotEmpty);

      bloc.add(const RecordsSourceChanged('s2'));
      await until((s) => s.sourceId == 's2' && s.resources.isNotEmpty);

      // Share would otherwise send the previous patient's records (A28).
      expect(bloc.state.selectedResourceIds, isEmpty);
    });
  });

  group('search', () {
    test('keeps to the type and date filters', () async {
      build([
        _visit(1, title: 'Insulin review'),
        _visit(400, title: 'Insulin start'),
        const Observation(id: 'o', sourceId: 's1', title: 'Insulin level'),
      ]);
      bloc
        ..add(const RecordsSourceChanged('s1'))
        ..add(
          const RecordsFiltersApplied([
            FhirType.Encounter,
          ], dateFilter: DateFilter(fromYear: 2023, toYear: 2023)),
        )
        ..add(const RecordsSearch('insulin'));
      await until((s) => s.searchQuery.isNotEmpty && s.resources.isNotEmpty);

      expect(bloc.state.resources.map((r) => r.id), ['s1-1']);
    });

    test('shortening it to one letter brings the list back', () async {
      build([
        _visit(1, title: 'Insulin review'),
        _visit(2, title: 'Dentist'),
      ]);
      bloc.add(const RecordsSourceChanged('s1'));
      await until((s) => s.resources.length == 2);
      bloc.add(const RecordsSearch('insulin'));
      await until((s) => s.resources.length == 1);

      bloc.add(const RecordsSearch('i'));
      await until((s) => s.resources.length == 2);
    });

    test('shows the matches, and clearing it brings the list back', () async {
      build([
        _visit(1, title: 'Insulin review'),
        _visit(2, title: 'Dentist'),
      ]);
      bloc.add(const RecordsSourceChanged('s1'));
      await until((s) => s.resources.length == 2);

      bloc.add(const RecordsSearch('insulin'));
      await until((s) => s.resources.length == 1);
      expect(bloc.state.resources.single.title, 'Insulin review 1');

      bloc.add(const RecordsSearch(''));
      await until((s) => s.resources.length == 2);
    });

    test('a single letter does not search', () async {
      build([_visit(1, title: 'Insulin review')]);
      bloc.add(const RecordsSourceChanged('s1'));
      await until((s) => s.resources.isNotEmpty);

      bloc.add(const RecordsSearch('i'));
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(repository.searchedSources, isEmpty);
    });

    test('reopening Records with a search active shows the new source\'s '
        'results', () async {
      build([
        _visit(1, title: 'Insulin'),
        _visit(2, source: 's2', title: 'Insulin'),
      ]);
      bloc.add(const RecordsSourceChanged('s1'));
      await until((s) => s.resources.isNotEmpty);
      bloc.add(const RecordsSearch('insulin'));
      await until((s) => s.searchQuery.isNotEmpty && s.resources.isNotEmpty);

      repository.searchTime = const Duration(milliseconds: 50);

      // What the app does when Records opens again, after a patient switch.
      bloc
        ..add(const RecordsInitialised())
        ..add(const RecordsSourceChanged('s2'));
      await until((s) => s.sourceId == 's2' && s.resources.isNotEmpty);

      expect(bloc.state.resources.map((r) => r.sourceId), ['s2']);
    });
  });

  group('specialty', () {
    test('a page with few matches says no more pages follow', () async {
      build([
        _visit(0, title: 'heart check'),
        for (var i = 1; i < 25; i++) _visit(i),
      ]);
      bloc
        ..add(const RecordsSourceChanged('s1'))
        ..add(const RecordsSpecialtyApplied([MedicalSpecialty.cardiology]));
      await until((s) => s.activeSpecialties.isNotEmpty);
      await until((s) => s.resources.isNotEmpty);

      // One match in all 25 rows: a bottom spinner waiting for more would
      // never go away, as the short list can't scroll (A27).
      expect(bloc.state.hasMorePages, isFalse);
    });

    test('pages are filled with matches and none comes twice', () async {
      // Every third visit is a cardiology one: 20 of the first 60 rows.
      build([
        for (var i = 0; i < 90; i++)
          _visit(i, title: i % 3 == 0 ? 'heart check' : 'Visit'),
      ]);
      bloc
        ..add(const RecordsSourceChanged('s1'))
        ..add(const RecordsSpecialtyApplied([MedicalSpecialty.cardiology]));
      await until((s) => s.resources.length == 20);
      expect(bloc.state.hasMorePages, isTrue);

      bloc.add(const RecordsLoadMore());
      await until((s) => s.resources.length == 30);

      final ids = bloc.state.resources.map((r) => r.id).toList();
      expect(ids.toSet(), hasLength(30), reason: 'no record twice');
      expect(ids, [for (var i = 0; i < 90; i += 3) 's1-$i']);
    });

    test('keeps the type filter', () async {
      build([
        _visit(1, title: 'heart check'),
        const Observation(id: 'o', sourceId: 's1', title: 'heart rate'),
      ]);
      bloc
        ..add(const RecordsSourceChanged('s1'))
        ..add(const RecordsFiltersApplied([FhirType.Observation]))
        ..add(const RecordsSpecialtyApplied([MedicalSpecialty.cardiology]));
      await until((s) => s.activeSpecialties.isNotEmpty);

      expect(bloc.state.activeFilters, [FhirType.Observation]);
      expect(bloc.state.resources.map((r) => r.id), ['o']);
    });

    test('from Home shows every type and stays when Records opens', () async {
      build([
        _visit(1, title: 'heart check'),
        const Observation(id: 'o', sourceId: 's1', title: 'heart rate'),
      ]);

      // Tapping a specialty on Home, then the page opening.
      bloc
        ..add(
          const RecordsFiltersApplied(
            [],
            specialties: [MedicalSpecialty.cardiology],
          ),
        )
        ..add(const RecordsSourceChanged('s1'));
      await until((s) => s.sourceId == 's1' && s.resources.length == 2);

      expect(bloc.state.activeFilters, isEmpty, reason: 'no default types');
      expect(bloc.state.activeSpecialties, [MedicalSpecialty.cardiology]);
    });
  });

  group('dates', () {
    test('pages are filled with records of those dates', () async {
      // _visit(i) is i days before 2024-01-01: 2023 from i = 1.
      build([for (var i = 0; i < 60; i++) _visit(i)]);
      bloc
        ..add(const RecordsSourceChanged('s1'))
        ..add(
          const RecordsFiltersApplied([
            FhirType.Encounter,
          ], dateFilter: DateFilter(fromYear: 2023, toYear: 2023)),
        );
      await until((s) => s.dateFilter != null && s.resources.length == 20);

      expect(bloc.state.resources.first.id, 's1-1');
      expect(bloc.state.resources.every((r) => r.date!.year == 2023), isTrue);
    });
  });

  test('deleting a record with chosen related records deletes them '
      'together and reloads', () async {
    // A patient remains, so the list reloads.
    build([
      _visit(1),
      _visit(2),
      _visit(3),
      const Patient(id: 'p', sourceId: 's1'),
    ]);
    bloc.add(const RecordsSourceChanged('s1'));
    await until((s) => s.resources.length == 4);

    bloc.add(
      const RecordsResourceDeleted(
        resourceId: 's1-1',
        selectedRelatedIds: ['s1-2'],
      ),
    );
    await until((s) => s.resources.length == 2);

    expect(repository.deleted, ['s1-1', 's1-2']);
  });

  test('sharing reads every selected record, loaded or not', () async {
    build([for (var i = 0; i < 45; i++) _visit(i)]);
    bloc.add(const RecordsSourceChanged('s1'));
    await until((s) => s.resources.length == 20);

    // Selected in the Attachments view, which shows more than the list.
    bloc
      ..add(const RecordsSelectionToggled('s1-1'))
      ..add(const RecordsSelectionToggled('s1-40'));
    await Future<void>.delayed(Duration.zero);

    final selected = await bloc.loadSelectedResources();

    expect(selected.map((r) => r.id), ['s1-1', 's1-40']);
  });

  test('selecting a record twice unselects it', () async {
    build([_visit(1)]);

    bloc.add(const RecordsSelectionToggled('s1-1'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.selectedResourceIds, {'s1-1'});

    bloc.add(const RecordsSelectionToggled('s1-1'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.selectedResourceIds, isEmpty);
  });
}
