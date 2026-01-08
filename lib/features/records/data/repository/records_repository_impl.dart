import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:fhir_ips_export/fhir_ips_export.dart';
import 'package:health_wallet/core/constants/blood_types.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/core/utils/fhir_reference_utils.dart';
import 'package:health_wallet/features/records/data/datasource/fhir_resource_datasource.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/data/data_source/local/sync_local_data_source.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/features/sync/domain/services/demo_data_extractor.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter/services.dart';

@Injectable(as: RecordsRepository)
class RecordsRepositoryImpl implements RecordsRepository {
  final FhirResourceDatasource _datasource;
  final SyncLocalDataSource _syncLocalDataSource;
  final AppDatabase _database;

  RecordsRepositoryImpl(this._database, this._syncLocalDataSource)
      : _datasource = FhirResourceDatasource(_database);

  @override
  Future<List<IFhirResource>> getResources({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 20,
    int offset = 0,
  }) async {
    final localDtos = await _datasource.getResources(
      resourceTypes: resourceTypes.map((fhirType) => fhirType.name).toList(),
      sourceId: sourceId,
      sourceIds: sourceIds,
      limit: limit,
      offset: offset,
    );

    // Filter out resources that fail to parse to prevent app crashes
    final validResources = <IFhirResource>[];
    for (final dto in localDtos) {
      try {
        final resource = IFhirResource.fromLocalDto(dto);
        validResources.add(resource);
      } catch (e) {
        logger.w(
            'Failed to parse resource ${dto.id} of type ${dto.resourceType}: $e');
        // Skip this resource and continue with others
      }
    }
    return validResources;
  }

  /// Get related resources for an encounter
  @override
  Future<List<IFhirResource>> getRelatedResourcesForEncounter({
    required String encounterId,
    String? sourceId,
  }) async {
    final localDtos = await _datasource.getResourcesByEncounterId(
      encounterId: encounterId,
      sourceId: sourceId,
    );

    return localDtos
        .where((dto) => dto.id != encounterId)
        .map(IFhirResource.fromLocalDto)
        .toList();
  }

  @override
  Future<List<IFhirResource>> getRelatedResources({
    required IFhirResource resource,
  }) async {
    List<IFhirResource> resources = [];

    for (String? reference in resource.resourceReferences) {
      IFhirResource? resource = await resolveReference(reference!);
      if (resource == null) continue;

      resources.add(resource);
    }

    return resources;
  }

  @override
  Future<IFhirResource?> resolveReference(String reference) async {
    FhirResourceLocalDto? localDto =
        await _datasource.resolveReference(reference);
    if (localDto == null) return null;
    return IFhirResource.fromLocalDto(localDto);
  }

  // Record Notes - Can be attached to any FHIR resource
  @override
  Future<int> addRecordNote({
    required String resourceId,
    String? sourceId,
    required String content,
  }) async {
    final companion = RecordNotesCompanion.insert(
      resourceId: resourceId,
      sourceId: Value(sourceId),
      content: content,
      timestamp: DateTime.now(),
    );

    return await _database
        .into(_database.recordNotes)
        .insertOnConflictUpdate(companion);
  }

  @override
  Future<List<RecordNote>> getRecordNotes(String resourceId) async {
    final notes = await (_database.select(_database.recordNotes)
          ..where((t) => t.resourceId.equals(resourceId))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();

    return notes.map(RecordNote.fromDto).toList();
  }

  @override
  Future<int> editRecordNote(RecordNote note) async {
    return await (_database.update(_database.recordNotes)
          ..where((t) => t.id.equals(note.id)))
        .write(RecordNotesCompanion(
      resourceId: Value(note.resourceId),
      sourceId: Value(note.sourceId),
      content: Value(note.content),
      timestamp: Value(note.timestamp),
    ));
  }

  @override
  Future<int> deleteRecordNote(RecordNote note) async {
    return await (_database.delete(_database.recordNotes)
          ..where((t) => t.id.equals(note.id)))
        .go();
  }

  @override
  Future<void> loadDemoData() async {
    try {
      // Create demo_data source first
      await _syncLocalDataSource.createDemoDataSource();

      // Load demo data from assets
      final String demoDataJson =
          await rootBundle.loadString('assets/demo_data.json');
      final Map<String, dynamic> demoData = json.decode(demoDataJson);

      // Handle both FHIR Bundle format and simple resources format
      List<dynamic> resources;
      if (demoData['entry'] != null) {
        // FHIR Bundle format - extract resources from entry array
        final List<dynamic> entries = demoData['entry'] as List<dynamic>;
        resources = entries
            .map((entry) => entry['resource'])
            .where((resource) => resource != null)
            .toList();
      } else if (demoData['resources'] != null) {
        // Simple resources format
        resources = demoData['resources'] as List<dynamic>;
      } else {
        throw Exception(
            'Demo data file has invalid format: neither "entry" nor "resources" key found');
      }

      final processedResources = resources
          .map((resource) => FhirResourceDto.fromJson({
                'id': resource['id'],
                'source_id': 'demo_data',
                'source_resource_type': resource['resourceType'],
                'source_resource_id': resource['id'],
                'sort_title': DemoDataExtractor.extractTitle(resource),
                'sort_date': DemoDataExtractor.extractDate(resource),
                'resource_raw': resource,
                'change_type': 'created',
              }).populateEncounterIdFromRaw().populateSubjectIdFromRaw())
          .toList();

      _syncLocalDataSource.cacheFhirResources(processedResources);
    } catch (e, stackTrace) {
      logger.e('Failed to load demo data: $e');
      logger.e('Stack trace: $stackTrace');
      throw Exception('Failed to load demo data: $e');
    }
  }

  @override
  Future<void> clearDemoData() async {
    // Delete all FHIR resources for demo_data source
    await _datasource.deleteResourcesBySourceId('demo_data');

    // Delete the demo_data source itself
    await _syncLocalDataSource.deleteSource('demo_data');
  }

  @override
  Future<bool> hasDemoData() async {
    final resources = await _datasource.getResources(
        sourceId: 'demo_data', resourceTypes: [], limit: 1);
    return resources.isNotEmpty;
  }

  @override
  Future<List<IFhirResource>> getBloodTypeObservations({
    required String patientId,
    String? sourceId,
  }) async {
    List<IFhirResource> observations;

    if (sourceId != null && sourceId.isNotEmpty) {
      observations = await getResources(
        resourceTypes: [FhirType.Observation],
        sourceId: sourceId,
        limit: 100,
        offset: 0,
      );

      if (observations.isEmpty) {
        observations = await getResources(
          resourceTypes: [FhirType.Observation],
          limit: 100,
          offset: 0,
        );
      }
    } else {
      observations = await getResources(
        resourceTypes: [FhirType.Observation],
        limit: 100,
        offset: 0,
      );
    }

    final patients = await getResources(
      resourceTypes: [FhirType.Patient],
      limit: 100,
      offset: 0,
    );

    final patientList = patients.whereType<Patient>().toList();
    final targetPatient = patientList.firstWhere(
      (p) => p.id == patientId,
      orElse: () =>
          patientList.isNotEmpty ? patientList.first : patientList.first,
    );

    final bloodTypeObservations = observations.where((resource) {
      if (resource is! Observation) {
        return false;
      }

      final coding = resource.code?.coding;
      if (coding == null || coding.isEmpty) {
        return false;
      }

      bool hasBloodTypeCode = false;
      for (final code in coding) {
        if (code.code == null) continue;

        final loincCode = code.code.toString();

        if (loincCode == BloodTypes.aboLoincCode ||
            loincCode == BloodTypes.rhLoincCode ||
            loincCode == BloodTypes.combinedLoincCode) {
          hasBloodTypeCode = true;
          break;
        }
      }

      if (!hasBloodTypeCode) {
        return false;
      }

      final subject = resource.subject?.reference?.valueString;

      if (subject == null) {
        return false;
      }

      String subjectPatientId;
      if (subject.contains('/')) {
        subjectPatientId = subject.split('/').last;
      } else if (subject.startsWith('urn:uuid:')) {
        subjectPatientId = subject.replaceFirst('urn:uuid:', '');
      } else {
        subjectPatientId = subject;
      }

      final matches = subjectPatientId == targetPatient.resourceId ||
          subjectPatientId == targetPatient.id ||
          subject == targetPatient.resourceId ||
          subject == targetPatient.id;

      return matches;
    }).toList();

    return bloodTypeObservations;
  }

  @override
  Future<String> saveObservation(IFhirResource observation) async {
    if (observation is! Observation) {
      throw Exception('Expected Observation resource type');
    }

    // Extract encounterId and subjectId from FHIR Observation
    String? encounterId;
    String? subjectId;

    // For observations, we need to extract from the raw FHIR resource
    final rawResource = observation.rawResource;
    if (rawResource['encounter']?['reference'] != null) {
      encounterId = FhirReferenceUtils.extractReferenceId(
          rawResource['encounter']['reference']);
    }
    if (rawResource['subject']?['reference'] != null) {
      subjectId = FhirReferenceUtils.extractReferenceId(
          rawResource['subject']['reference']);
    }

    final dto = FhirResourceLocalDto(
      id: observation.id,
      sourceId: observation.sourceId,
      resourceType: observation.fhirType.name,
      resourceId: observation.resourceId,
      title: observation.title,
      date: observation.date,
      resourceRaw: jsonEncode(observation.rawResource),
      encounterId: encounterId,
      subjectId: subjectId,
    );

    final id = await _datasource.insertResource(dto);
    return id.toString();
  }

  @override
  Future<void> updatePatient(IFhirResource patient) async {
    if (patient is! Patient) {
      throw Exception('Expected Patient resource type');
    }

    // For Patient resources, subjectId should be their own resourceId
    final dto = FhirResourceLocalDto(
      id: patient.id,
      sourceId: patient.sourceId,
      resourceType: patient.fhirType.name,
      resourceId: patient.resourceId,
      title: patient.title,
      date: patient.date,
      resourceRaw: jsonEncode(patient.rawResource),
      encounterId: null, // Patients don't have encounterId
      subjectId:
          patient.resourceId, // Patient's subjectId is their own resourceId
    );

    await _datasource.insertResource(dto);
  }

  @override
  Future<List<IFhirResource>> searchResources({
    required String query,
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    int limit = 50,
  }) async {
    final localDtos = await _datasource.searchResources(
      query: query,
      resourceTypes: resourceTypes.map((fhirType) => fhirType.name).toList(),
      sourceId: sourceId,
      limit: limit,
    );

    return localDtos.map(IFhirResource.fromLocalDto).toList();
  }

  @override
  Future<Uint8List> buildIpsExport({required String? sourceId}) async {
    List<FhirResourceLocalDto> resourceDtos = await _datasource.getResources(
      resourceTypes: [],
      sourceId: sourceId,
    );

    List<IFhirResource> resources =
        resourceDtos.map(IFhirResource.fromLocalDto).toList();

    Patient? patient = resources.whereType<Patient>().firstOrNull;

    if (patient == null) {
      throw Exception("Patient not found");
    }

    FhirIpsBuilder builder = FhirIpsBuilder();
    FhirIpsPdfRenderer renderer = FhirIpsPdfRenderer();

    final ipsData = await builder.buildFromRawResources(
      rawResources: resources.map((r) => r.rawResource).toList(),
      rawPatient: patient.rawResource,
    );

    return renderer.render(ipsData: ipsData);
  }
}
