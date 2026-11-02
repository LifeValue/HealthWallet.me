import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/domain/services/attach_documents_service.dart';
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';

const tomWallet = Patient(
  id: 'tom-w',
  resourceId: 'tom-w',
  sourceId: 'wallet-tom',
);

class _FakeHolders extends Fake implements HolderService {
  final asked = <String>[];

  @override
  Future<({Patient patient, String holderId})> walletPatientOf(
    String patientId, {
    Object? scanned,
  }) async {
    asked.add(patientId);
    return (patient: tomWallet, holderId: 'tom');
  }
}

class _FakeSelection extends Fake implements HolderSelection {
  final selected = <String>[];

  @override
  Future<void> select(String holderId) async => selected.add(holderId);
}

class _FakeSync extends Fake implements SyncRepository {
  final saved = <IFhirResource>[];

  @override
  Future saveResources(List<IFhirResource> resources) async =>
      saved.addAll(resources);
}

class _FakeDocuments extends Fake implements DocumentReferenceService {
  final calls = <String>[];

  @override
  Future<List<String>> saveGroupedDocumentsAsFhirRecords({
    required List<String> filePaths,
    required String patientId,
    Encounter? encounter,
    required String sourceId,
    String? title,
    String? sessionId,
  }) async {
    calls.add('$patientId $sourceId ${encounter?.id}');
    return [];
  }
}

void main() {
  late _FakeHolders holders;
  late _FakeSelection selection;
  late _FakeSync sync;
  late _FakeDocuments documents;
  late AttachDocumentsService service;

  setUp(() {
    holders = _FakeHolders();
    selection = _FakeSelection();
    sync = _FakeSync();
    documents = _FakeDocuments();
    service = AttachDocumentsService(holders, selection, sync, documents);
  });

  test(
    'files under the person picked, in their wallet, and shows them',
    () async {
      await service.attach(
        patient: const Patient(id: 'tom-epic', sourceId: 'epic'),
        encounter: const StagedEncounter(
          existing: Encounter(id: 'enc-1', sourceId: 'epic'),
          mode: ImportMode.linkExisting,
        ),
        filePaths: const ['/a.pdf'],
        title: 'Attached',
      );

      expect(holders.asked, ['tom-epic']);
      expect(documents.calls, ['tom-w wallet-tom enc-1']);
      expect(selection.selected, ['tom']);
      expect(sync.saved, isEmpty);
    },
  );

  test('a new encounter is saved first, for the wallet Patient', () async {
    await service.attach(
      patient: const Patient(id: 'tom-epic', sourceId: 'epic'),
      encounter: const StagedEncounter(
        draft: MappingEncounter(id: 'enc-new'),
        mode: ImportMode.createNew,
      ),
      filePaths: const ['/a.pdf'],
      title: 'Attached',
    );

    final encounter = sync.saved.single as Encounter;
    expect(encounter.sourceId, 'wallet-tom');
    expect(
      encounter.rawResource['subject']?['reference'],
      'Patient/tom-w',
    );
    expect(documents.calls, ['tom-w wallet-tom enc-new']);
  });
}
