import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/services/attachment_browse_service.dart';
import 'package:health_wallet/features/records/presentation/bloc/attachment_browse_bloc.dart';

/// Answers each load with one record named after its scope, when the test
/// completes that load.
class _ControlledBrowseService extends Fake implements AttachmentBrowseService {
  final pending = <String, Completer<void>>{};

  @override
  Future<List<AttachmentBrowseEntry>> loadEntries({
    String? sourceId,
    List<String>? sourceIds,
    List<FhirType> resourceTypes = const [],
  }) async {
    final scope = sourceId ?? sourceIds?.join(',') ?? 'all';
    await (pending[scope] = Completer<void>()).future;
    return [
      AttachmentBrowseEntry(record: Encounter(id: scope)),
    ];
  }

  @override
  Future<AttachmentBrowseDetail> loadDetail(
    IFhirResource record, {
    String? sourceId,
  }) async => AttachmentBrowseDetail(record: record);
}

class _FakeSpecialtyClassifier extends Fake implements SpecialtyClassifier {}

void main() {
  test('the latest scope wins when an earlier load finishes last', () async {
    final service = _ControlledBrowseService();
    final bloc = AttachmentBrowseBloc(service, _FakeSpecialtyClassifier());
    addTearDown(bloc.close);

    // First an unscoped load, then the patient's scope.
    bloc.add(const AttachmentBrowseInitialised());
    await pumpEventQueue();
    bloc.add(const AttachmentBrowseInitialised(sourceIds: ['s1', 's2']));
    await pumpEventQueue();

    service.pending['s1,s2']!.complete();
    await pumpEventQueue();
    service.pending['all']!.complete();
    await pumpEventQueue();

    expect(bloc.state.records.map((e) => e.record.id), ['s1,s2']);
  });
}
