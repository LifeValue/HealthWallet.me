import 'package:flutter/services.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';

/// One page of records: [nextOffset] is where the next page starts, counted
/// in stored rows (which a filter may skip), not in [resources].
typedef ResourcePage = ({
  List<IFhirResource> resources,
  int nextOffset,
  bool hasMore,
});

abstract class RecordsRepository {
  Future<List<IFhirResource>> getResources({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 20,
    int offset = 0,
  });

  /// Up to [limit] records, newest first, starting [offset] stored rows in,
  /// that match [dateFilter] (records without a date always do) and [where].
  /// Rows are read until the page is full, so a filter that skips most of
  /// them still gives full pages. A null [limit] returns every match.
  Future<ResourcePage> getResourcePage({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    DateFilter? dateFilter,
    bool Function(IFhirResource resource)? where,
    int? limit = 20,
    int offset = 0,
  });

  /// The records with these ids that aren't deleted, newest first.
  Future<List<IFhirResource>> getResourcesByIds(Iterable<String> ids);

  Future<List<IFhirResource>> getRelatedResourcesForEncounter({
    required String encounterId,
    String? sourceId,
  });

  Future<List<IFhirResource>> getRelatedResources({
    required IFhirResource resource,
  });

  Future<IFhirResource?> resolveReference(String reference);

  /// The DocumentReferences attached to [resource]: for an encounter, those
  /// of the encounter; otherwise those whose `context.related` points at it.
  Future<List<IFhirResource>> getAttachedDocuments(IFhirResource resource);

  // Record Notes - Can be attached to any FHIR resource
  Future<int> addRecordNote({
    required String resourceId,
    String? sourceId,
    required String content,
  });

  Future<List<RecordNote>> getRecordNotes(String resourceId);

  /// Serves [notes] (by resource id) from memory instead of the database,
  /// for records shared from another phone; see [clearSharedNotes].
  void showSharedNotes(Map<String, List<RecordNote>> notes);

  void clearSharedNotes();

  Future<int> editRecordNote(RecordNote note);

  Future<int> deleteRecordNote(RecordNote note);

  Future<void> deleteResource(String resourceId);

  Future<void> deleteResourcesByIds(List<String> ids);

  Future<int> getRelatedResourceCount(String resourceId);

  Future<List<IFhirResource>> getRelatedResourcesForDeletion(String resourceId);

  Future<void> loadDemoData();

  Future<void> clearDemoData();

  Future<bool> hasDemoData();

  Future<List<IFhirResource>> getBloodTypeObservations({
    required String patientId,
    String? sourceId,
  });

  Future<String> saveObservation(IFhirResource observation);

  Future<void> updatePatient(IFhirResource patient);

  /// Records matching every word of [query], best matches first, within the
  /// same filters as [getResourcePage].
  Future<List<IFhirResource>> searchResources({
    required String query,
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    DateFilter? dateFilter,
    bool Function(IFhirResource resource)? where,
    int limit = 50,
  });

  /// The IPS PDF of [patientId], from [sourceId], else [sourceIds] (the
  /// person's sources), else the sources of that Patient row.
  Future<({Uint8List bytes, String patientName})> buildIpsExport({
    String? sourceId,
    List<String>? sourceIds,
    String? patientId,
  });

  Future<void> updateResourceRaw(String resourceId, String rawJson);

  Future<void> setSpecialtyOverride(String resourceId, String? specialtyName);
}
