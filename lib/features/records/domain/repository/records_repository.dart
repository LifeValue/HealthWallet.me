import 'package:flutter/services.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';

abstract class RecordsRepository {
  Future<List<IFhirResource>> getResources({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 20,
    int offset = 0,
    DateFilter? dateFilter,
  });

  Future<List<IFhirResource>> getRelatedResourcesForEncounter({
    required String encounterId,
    String? sourceId,
  });

  Future<List<IFhirResource>> getRelatedResources({
    required IFhirResource resource,
  });

  Future<IFhirResource?> resolveReference(String reference);

  // Record Notes - Can be attached to any FHIR resource
  Future<int> addRecordNote({
    required String resourceId,
    String? sourceId,
    required String content,
  });

  Future<List<RecordNote>> getRecordNotes(String resourceId);

  Future<int> editRecordNote(RecordNote note);

  Future<int> deleteRecordNote(RecordNote note);

  Future<void> deleteResource(String resourceId);

  Future<void> deleteResourceWithRelated(String resourceId);

  Future<int> getRelatedResourceCount(String resourceId);

  Future<void> loadDemoData();

  Future<void> clearDemoData();

  Future<bool> hasDemoData();

  Future<List<IFhirResource>> getBloodTypeObservations({
    required String patientId,
    String? sourceId,
  });

  Future<String> saveObservation(IFhirResource observation);

  Future<void> updatePatient(IFhirResource patient);

  Future<List<IFhirResource>> searchResources({
    required String query,
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    int limit = 50,
  });

  Future<({Uint8List bytes, String patientName})> buildIpsExport({
    String? sourceId,
    String? patientId,
  });
}
