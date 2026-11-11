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

  @override
  Future<List<IFhirResource>> getResources({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 20,
    int offset = 0,
    DateFilter? dateFilter,
  }) async => _scoped(sourceId, sourceIds)
      .where(
        (r) => resourceTypes.isEmpty || resourceTypes.contains(r.fhirType),
      )
      .skip(offset)
      .take(limit)
      .toList();

  @override
  Future<List<IFhirResource>> searchResources({
    required String query,
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 50,
  }) async {
    searchedSources.add(sourceId);
    await Future<void>.delayed(searchTime);
    return _scoped(sourceId, sourceIds)
        .where((r) => r.title.toLowerCase().contains(query.toLowerCase()))
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
  void buildEncounterIndex(List<IFhirResource> resources) {}

  @override
  Set<MedicalSpecialty> classify(
    IFhirResource resource, {
    MedicalSpecialty? override,
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

    test('BUG: loading more replaces the list with the full-screen loading '
        'state', () async {
      build([for (var i = 0; i < 45; i++) _visit(i)]);
      bloc.add(const RecordsSourceChanged('s1'));
      await until((s) => s.resources.length == 20);
      final statuses = <RecordsStatus>[];
      final sub = bloc.stream.listen((s) => statuses.add(s.status));

      bloc.add(const RecordsLoadMore());
      await until((s) => s.resources.length == 40);
      await sub.cancel();

      // The page shows a spinner instead of the list while loading, which
      // throws the user back to the top (A26).
      expect(statuses, isNot(contains(const RecordsStatus.loading())));
    }, skip: 'BUG: A26 in records-audit.md');
  });

  group('source', () {
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

    test('BUG: the selection survives a change of source or patient', () async {
      build([_visit(1), _visit(2, source: 's2')]);
      bloc.add(const RecordsSourceChanged('s1'));
      await until((s) => s.resources.isNotEmpty);
      bloc.add(const RecordsSelectionToggled('s1-1'));
      await until((s) => s.selectedResourceIds.isNotEmpty);

      bloc.add(const RecordsSourceChanged('s2'));
      await until((s) => s.sourceId == 's2' && s.resources.isNotEmpty);

      // Sharing then sends records of the previous patient, or drops them
      // (A28).
      expect(bloc.state.selectedResourceIds, isEmpty);
    }, skip: 'BUG: A28 in records-audit.md');
  });

  group('search', () {
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

    test('BUG: reopening Records with a search active shows the previous '
        'source\'s results', () async {
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
    }, skip: 'BUG: A25 in records-audit.md');
  });

  group('specialty', () {
    test('BUG: a page with few matches still says more pages follow', () async {
      build([
        _visit(0, title: 'heart check'),
        for (var i = 1; i < 25; i++) _visit(i),
      ]);
      bloc
        ..add(const RecordsSourceChanged('s1'))
        ..add(const RecordsSpecialtyApplied([MedicalSpecialty.cardiology]));
      await until((s) => s.activeSpecialties.isNotEmpty);
      await until((s) => s.resources.isNotEmpty);

      // One match in the first 20 rows: the list can't scroll, so the
      // bottom spinner never goes away; the next page would also start at
      // the wrong offset (A27).
      expect(bloc.state.hasMorePages, isFalse);
    }, skip: 'BUG: A27 in records-audit.md');
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
