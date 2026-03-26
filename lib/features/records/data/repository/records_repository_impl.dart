import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:fhir_ips_export/fhir_ips_export.dart';
import 'package:health_wallet/core/constants/blood_types.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/core/utils/fhir_reference_utils.dart';
import 'package:health_wallet/features/records/data/data_source/fhir_resource_datasource.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/sync/data/data_source/local/sync_local_data_source.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/core/config/constants/country_identifier.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/features/sync/domain/services/demo_data_extractor.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    DateFilter? dateFilter,
  }) async {
    final localDtos = await _datasource.getResources(
      resourceTypes: resourceTypes.map((fhirType) => fhirType.name).toList(),
      sourceId: sourceId,
      sourceIds: sourceIds,
      limit: limit,
      offset: offset,
    );

    final validResources = <IFhirResource>[];
    for (final dto in localDtos) {
      try {
        final resource = IFhirResource.fromLocalDto(dto);

        if (dateFilter != null && dateFilter.hasValue) {
          final resourceDate = resource.date;
          if (resourceDate != null && !dateFilter.matches(resourceDate)) {
            continue;
          }
        }

        validResources.add(resource);
      } catch (e) {
        logger.w(
            'Failed to parse resource ${dto.id} of type ${dto.resourceType}: $e');
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

    final resources = localDtos
        .where((dto) => dto.id != encounterId)
        .map(IFhirResource.fromLocalDto)
        .toList();

    resources.sort((a, b) {
      final aIsDoc = a.fhirType == FhirType.DocumentReference ? 0 : 1;
      final bIsDoc = b.fhirType == FhirType.DocumentReference ? 0 : 1;
      return aIsDoc.compareTo(bIsDoc);
    });

    return resources;
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
  Future<void> deleteResource(String resourceId) async {
    await _datasource.deleteResourceById(resourceId);
  }

  @override
  Future<void> deleteResourcesByIds(List<String> ids) async {
    await _datasource.deleteResourcesByIds(ids);
  }

  @override
  Future<void> deleteResourceWithRelated(String resourceId) async {
    final targetResource = (await (_database.select(_database.fhirResource)
          ..where((f) => f.id.equals(resourceId)))
        .get())
        .firstOrNull;

    if (targetResource == null) return;

    final idsToDelete = <String>{resourceId};

    if (targetResource.resourceType == 'Encounter' ||
        targetResource.resourceType == 'DiagnosticReport') {
      final related = await _datasource.getResourcesByEncounterId(
        encounterId: targetResource.resourceId ?? '',
      );
      idsToDelete.addAll(related.map((r) => r.id));
    }

    final encId = targetResource.encounterId;
    if (encId != null && encId.isNotEmpty) {
      final encounterRows = await (_database.select(_database.fhirResource)
            ..where((f) => f.resourceId.equals(encId)))
          .get();
      idsToDelete.addAll(encounterRows.map((r) => r.id));

      final siblings = await _datasource.getResourcesByEncounterId(encounterId: encId);
      idsToDelete.addAll(siblings.map((r) => r.id));
    }

    await _datasource.deleteResourcesByIds(idsToDelete.toList());
  }

  @override
  Future<int> getRelatedResourceCount(String resourceId) async {
    final targetResource = (await (_database.select(_database.fhirResource)
          ..where((f) => f.id.equals(resourceId)))
        .get())
        .firstOrNull;

    if (targetResource == null) return 0;

    if (targetResource.resourceType == 'Encounter' ||
        targetResource.resourceType == 'DiagnosticReport') {
      return _datasource.getRelatedResourceCount(
        targetResource.resourceId ?? '',
      );
    }

    final encId = targetResource.encounterId;
    if (encId != null && encId.isNotEmpty) {
      final count = await _datasource.getRelatedResourceCount(encId);
      return count + 1;
    }

    return 0;
  }

  @override
  Future<List<IFhirResource>> getRelatedResourcesForDeletion(
      String resourceId) async {
    final targetResource = (await (_database.select(_database.fhirResource)
          ..where((f) => f.id.equals(resourceId)))
        .get())
        .firstOrNull;

    if (targetResource == null) return [];

    final relatedIds = <String>{};

    if (targetResource.resourceType == 'Encounter' ||
        targetResource.resourceType == 'DiagnosticReport') {
      final related = await _datasource.getResourcesByEncounterId(
        encounterId: targetResource.resourceId ?? '',
      );
      for (final r in related) {
        if (r.id != resourceId) relatedIds.add(r.id);
      }
    }

    final encId = targetResource.encounterId;
    if (encId != null && encId.isNotEmpty) {
      final encounterRows = await (_database.select(_database.fhirResource)
            ..where((f) => f.resourceId.equals(encId)))
          .get();
      for (final r in encounterRows) {
        if (r.id != resourceId) relatedIds.add(r.id);
      }

      final siblings =
          await _datasource.getResourcesByEncounterId(encounterId: encId);
      for (final r in siblings) {
        if (r.id != resourceId) relatedIds.add(r.id);
      }
    }

    if (relatedIds.isEmpty) return [];

    final relatedRows = await (_database.select(_database.fhirResource)
          ..where((f) => f.id.isIn(relatedIds.toList())))
        .get();

    return relatedRows.map(IFhirResource.fromLocalDto).toList();
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

      final prefs = await SharedPreferences.getInstance();
      final savedCountry = prefs.getString(SharedPrefsConstants.countryCode);
      final profile = savedCountry != null
          ? CountryIdentifier.forCountry(savedCountry)
          : CountryIdentifier.forCurrentLocale();
      for (int i = 0; i < resources.length; i++) {
        final resource = resources[i] as Map<String, dynamic>;
        if (resource['resourceType'] == 'Patient') {
          resources[i] = _adaptDemoPatientIdentifier(resource, profile);
        }
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

  Map<String, dynamic> _adaptDemoPatientIdentifier(
    Map<String, dynamic> patient,
    CountryIdentifier profile,
  ) {
    var result = Map<String, dynamic>.from(patient);

    final identifiers = result['identifier'] as List<dynamic>?;
    if (identifiers != null) {
      result['identifier'] = identifiers.map((id) {
        final idMap = Map<String, dynamic>.from(id as Map<String, dynamic>);
        final type = idMap['type'] as Map<String, dynamic>?;
        if (type == null) return idMap;
        final codings = type['coding'] as List<dynamic>?;
        if (codings == null || codings.isEmpty) return idMap;
        final coding = Map<String, dynamic>.from(codings.first as Map<String, dynamic>);
        if (coding['code'] == 'MR') {
          coding['code'] = profile.identifierFhirCode;
          coding['display'] = profile.identifierDisplayName;
          idMap['type'] = {
            'coding': [coding],
            'text': profile.identifierDisplayName,
          };
          idMap['system'] = profile.fhirIdentifierSystem;
        }
        return idMap;
      }).toList();
    }

    result = _adaptPhoneNumbers(result, profile.dialCode);

    return result;
  }

  Map<String, dynamic> _adaptPhoneNumbers(
    Map<String, dynamic> resource,
    String dialCode,
  ) {
    final result = Map<String, dynamic>.from(resource);

    final telecom = result['telecom'] as List<dynamic>?;
    if (telecom != null) {
      result['telecom'] = telecom.map((t) {
        final tMap = Map<String, dynamic>.from(t as Map<String, dynamic>);
        if (tMap['system'] == 'phone') tMap['value'] = '+$dialCode';
        return tMap;
      }).toList();
    }

    final contact = result['contact'] as List<dynamic>?;
    if (contact != null) {
      result['contact'] = contact.map((c) {
        final cMap = Map<String, dynamic>.from(c as Map<String, dynamic>);
        final cTelecom = cMap['telecom'] as List<dynamic>?;
        if (cTelecom != null) {
          cMap['telecom'] = cTelecom.map((t) {
            final tMap = Map<String, dynamic>.from(t as Map<String, dynamic>);
            if (tMap['system'] == 'phone') tMap['value'] = '+$dialCode';
            return tMap;
          }).toList();
        }
        return cMap;
      }).toList();
    }

    return result;
  }

  @override
  Future<void> clearDemoData() async {
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
    if (patientList.isEmpty) return [];

    final targetPatient = patientList.firstWhere(
      (p) => p.id == patientId,
      orElse: () => patientList.first,
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
  Future<({Uint8List bytes, String patientName})> buildIpsExport({
    String? sourceId,
    String? patientId,
  }) async {
    List<String>? patientSourceIds;
    if (patientId != null) {
      final allPatients = await _datasource.getResources(
        resourceTypes: [FhirType.Patient.name],
      );
      patientSourceIds = allPatients
          .map(IFhirResource.fromLocalDto)
          .where((p) => p.id == patientId && p.sourceId.isNotEmpty)
          .map((p) => p.sourceId)
          .toSet()
          .toList();
    }

    List<FhirResourceLocalDto> resourceDtos = await _datasource.getResources(
      resourceTypes: [],
      sourceId: sourceId,
      sourceIds: patientSourceIds,
    );

    List<IFhirResource> resources =
        resourceDtos.map(IFhirResource.fromLocalDto).toList();

    Patient? patient = patientId != null
        ? resources.whereType<Patient>().where((p) => p.id == patientId).firstOrNull
        : resources.whereType<Patient>().firstOrNull;

    if (patient == null) {
      throw Exception("Patient not found");
    }

    final patientName = FhirFieldExtractor.extractHumanNameFamilyFirst(
          patient.name?.first,
        )?.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_') ??
        'Unknown';

    FhirIpsBuilder builder = FhirIpsBuilder();
    FhirIpsPdfRenderer renderer = FhirIpsPdfRenderer();

    final ipsData = await builder.buildFromRawResources(
      rawResources: resources.map((r) => r.rawResource).toList(),
      rawPatient: patient.rawResource,
    );

    final bytes = await renderer.render(ipsData: ipsData);
    return (bytes: bytes, patientName: patientName);
  }
}
