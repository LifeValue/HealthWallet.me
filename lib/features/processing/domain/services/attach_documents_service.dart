import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:injectable/injectable.dart';

/// Files documents under an encounter without reading them (no AI model):
/// for the person the user picked, in their wallet source, against their
/// own wallet Patient.
@injectable
class AttachDocumentsService {
  AttachDocumentsService(
    this._holders,
    this._selection,
    this._syncRepository,
    this._documents,
  );

  final HolderService _holders;
  final HolderSelection _selection;
  final SyncRepository _syncRepository;
  final DocumentReferenceService _documents;

  /// [patient] is the person picked, by any of their rows; [encounter] is
  /// an existing encounter or one to create for them.
  Future<void> attach({
    required Patient patient,
    required StagedEncounter encounter,
    required List<String> filePaths,
    required String title,
  }) async {
    final written = await _holders.walletPatientOf(patient.id);
    final sourceId = written.patient.sourceId;

    final Encounter target;
    if (encounter.draft case final draft?) {
      target = draft.toFhirResource(
        sourceId: sourceId,
        subjectId: written.patient.id,
      ) as Encounter;
      await _syncRepository.saveResources([target]);
    } else {
      target = encounter.existing!;
    }

    await _documents.saveGroupedDocumentsAsFhirRecords(
      filePaths: filePaths,
      patientId: written.patient.id,
      encounter: target,
      sourceId: sourceId,
      title: title,
    );
    await _selection.select(written.holderId);
  }
}
