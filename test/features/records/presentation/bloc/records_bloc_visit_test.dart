import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/domain/services/records_filter_store.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers every query with no records and keeps the types each asked for.
class _FakeRecordsRepository extends Fake implements RecordsRepository {
  final queries = <List<FhirType>>[];

  @override
  Future<List<IFhirResource>> getResources({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 20,
    int offset = 0,
    DateFilter? dateFilter,
  }) async {
    queries.add(resourceTypes);
    return const [];
  }
}

class _FakeSpecialtyClassifier extends Fake implements SpecialtyClassifier {}

/// The scope Records reloads on, as `RecordsView` sends it: on every visit,
/// and again after a sync or a scope change during one.
RecordsSourceChanged _reload(String personId) => RecordsSourceChanged(
  null,
  sourceIds: ['$personId-src'],
  personId: personId,
);

/// What a Home records card sends for [personId].
List<RecordsEvent> _recordsCard(List<FhirType> types, String personId) => [
  RecordsSpecialtyApplied(const [], remember: false, personId: personId),
  RecordsFiltersApplied(types, remember: false, personId: personId),
];

void main() {
  late _FakeRecordsRepository repository;
  late RecordsFilterStore store;
  late RecordsBloc bloc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = RecordsFilterStore(await SharedPreferences.getInstance());
    await store.save('jane', const RecordsFilters(types: [FhirType.Condition]));
    await store.save('tom', const RecordsFilters(types: [FhirType.Media]));
    repository = _FakeRecordsRepository();
    bloc = RecordsBloc(repository, _FakeSpecialtyClassifier(), store);
  });

  tearDown(() => bloc.close());

  Future<RecordsState> run(List<RecordsEvent> events) async {
    events.forEach(bloc.add);
    await pumpEventQueue();
    return bloc.state;
  }

  group('a Home card filters the whole visit and that visit only', () {
    test('on the first visit after a launch', () async {
      await run(_recordsCard([FhirType.Observation], 'jane'));

      final visit = await run([_reload('jane')]);

      expect(visit.activeFilters, [FhirType.Observation]);
      expect(repository.queries.last, [FhirType.Observation]);
      expect(store.load('jane').types, [FhirType.Condition]);

      final after = await run([RecordsVisitEnded()]);

      expect(after.activeFilters, [FhirType.Condition]);
      expect(repository.queries.last, [FhirType.Condition]);
    });

    test(
      'on a later visit, also when a sync reloads Records during it',
      () async {
        await run([_reload('jane'), RecordsVisitEnded()]);

        await run(_recordsCard([FhirType.Observation], 'jane'));
        await run([_reload('jane')]);
        final synced = await run([_reload('jane')]);

        expect(synced.activeFilters, [FhirType.Observation]);
        expect(repository.queries.last, [FhirType.Observation]);

        final after = await run([RecordsVisitEnded()]);

        expect(after.activeFilters, [FhirType.Condition]);
        expect(repository.queries.last, [FhirType.Condition]);
      },
    );

    test('a specialty card too', () async {
      await run([
        const RecordsSpecialtyApplied(
          [
            MedicalSpecialty.cardiology,
          ],
          remember: false,
          personId: 'jane',
        ),
      ]);

      final visit = await run([_reload('jane'), _reload('jane')]);

      expect(visit.activeSpecialties, [MedicalSpecialty.cardiology]);
      expect(visit.activeFilters, [FhirType.Condition]);

      final after = await run([RecordsVisitEnded()]);

      expect(after.activeSpecialties, isEmpty);
      expect(store.load('jane').specialties, isEmpty);
    });

    test(
      "on the card's person when Records last showed someone else",
      () async {
        await run([_reload('jane'), RecordsVisitEnded()]);

        await run(_recordsCard([FhirType.Observation], 'tom'));
        final visit = await run([_reload('tom')]);

        expect(visit.activeFilters, [FhirType.Observation]);

        final after = await run([RecordsVisitEnded()]);

        expect(after.activeFilters, [FhirType.Media]);
        expect(store.load('jane').types, [FhirType.Condition]);
      },
    );

    test('another person chosen during the visit gets their own filters, and '
        'leaving changes nothing more', () async {
      await run(_recordsCard([FhirType.Observation], 'jane'));
      await run([_reload('jane')]);

      final tom = await run([_reload('tom')]);
      expect(tom.activeFilters, [FhirType.Media]);
      final queries = repository.queries.length;

      final after = await run([RecordsVisitEnded()]);

      expect(after.activeFilters, [FhirType.Media]);
      expect(repository.queries, hasLength(queries));
    });
  });
}
