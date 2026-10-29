import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';

/// [sourceIds] joined with commas, since records compare lists by identity.
typedef Scope = ({String? sourceId, String? sourceIds});

/// Records the scope of every query.
class _ScopeRecordingRepository extends Fake implements RecordsRepository {
  final lists = <Scope>[];
  final searches = <Scope>[];
  final exports = <(String?, String?)>[];

  @override
  Future<List<IFhirResource>> getResources({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 20,
    int offset = 0,
    DateFilter? dateFilter,
  }) async {
    lists.add((sourceId: sourceId, sourceIds: sourceIds?.join(',')));
    return [];
  }

  @override
  Future<List<IFhirResource>> searchResources({
    required String query,
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 50,
  }) async {
    searches.add((sourceId: sourceId, sourceIds: sourceIds?.join(',')));
    return [];
  }

  @override
  Future<({Uint8List bytes, String patientName})> buildIpsExport({
    String? sourceId,
    String? patientId,
  }) async {
    exports.add((sourceId, patientId));
    throw StateError('stop after recording');
  }
}

class _FakeSpecialtyClassifier extends Fake implements SpecialtyClassifier {}

/// Waits until [done] holds, for as long as a slow machine needs.
Future<void> _until(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('not reached within 10 s');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late _ScopeRecordingRepository repository;

  setUp(() => repository = _ScopeRecordingRepository());

  RecordsBloc build() => RecordsBloc(repository, _FakeSpecialtyClassifier());

  const janeSources = ['s1', 's2'];

  blocTest<RecordsBloc, RecordsState>(
    'search keeps to the selected patient\'s sources',
    build: build,
    act: (bloc) async {
      bloc.add(const RecordsSourceChanged(null, sourceIds: janeSources));
      bloc.add(const RecordsSearch('insulin'));
      // The search runs after a 500 ms debounce.
      await _until(() => repository.searches.isNotEmpty);
    },
    verify: (_) {
      expect(repository.searches, [(sourceId: null, sourceIds: 's1,s2')]);
    },
  );

  blocTest<RecordsBloc, RecordsState>(
    'the Media filter keeps the selected source',
    build: build,
    act: (bloc) {
      bloc.add(const RecordsSourceChanged('s1'));
      bloc.add(const RecordsFiltersApplied([FhirType.Media]));
    },
    verify: (_) {
      expect(repository.lists.last, (sourceId: 's1', sourceIds: null));
    },
  );

  blocTest<RecordsBloc, RecordsState>(
    'the Media filter keeps the selected patient\'s sources',
    build: build,
    act: (bloc) {
      bloc.add(const RecordsSourceChanged(null, sourceIds: janeSources));
      bloc.add(const RecordsFiltersApplied([FhirType.Media]));
    },
    verify: (_) {
      expect(repository.lists.last, (sourceId: null, sourceIds: 's1,s2'));
    },
  );

  blocTest<RecordsBloc, RecordsState>(
    'IPS export uses the source chosen on Home, not the one Records last saw',
    build: build,
    act: (bloc) async {
      bloc.add(const RecordsSourceChanged('s1'));
      bloc.add(const RecordsSharePressed(patientId: 'tom', sourceId: 's3'));
      await _until(() => repository.exports.isNotEmpty);
    },
    verify: (_) {
      expect(repository.exports, [('s3', 'tom')]);
    },
  );

  blocTest<RecordsBloc, RecordsState>(
    'IPS export with all sources selected leaves the scope to the patient',
    build: build,
    act: (bloc) async {
      bloc.add(const RecordsSourceChanged('s1'));
      bloc.add(const RecordsSharePressed(patientId: 'tom'));
      await _until(() => repository.exports.isNotEmpty);
    },
    verify: (_) {
      expect(repository.exports, [(null, 'tom')]);
    },
  );
}
