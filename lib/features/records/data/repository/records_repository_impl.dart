import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:fhir_ips_export/fhir_ips_export.dart';
import 'package:flutter/services.dart';
import 'package:health_wallet/core/config/constants/country_identifier.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/constants/blood_types.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/data/local/soft_delete.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/utils/fhir_reference_utils.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/records/data/data_source/fhir_resource_datasource.dart';
import 'package:health_wallet/features/records/data/data_source/shared_notes_datasource.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/sync/data/data_source/local/sync_local_data_source.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/features/sync/domain/services/demo_data_extractor.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

@Injectable(as: RecordsRepository)
class RecordsRepositoryImpl implements RecordsRepository {
  final FhirResourceDatasource _datasource;
  final SyncLocalDataSource _syncLocalDataSource;
  final AppDatabase _database;
  final SharedNotesDatasource _sharedNotes;
  // Not read since deletes stopped removing files; kept so the constructor,
  // which injectable and the tests build, stays as it is.
  // ignore: unused_field
  final PathResolver _pathResolver;

  RecordsRepositoryImpl(
    this._database,
    this._syncLocalDataSource,
    this._sharedNotes,
    this._pathResolver,
  ) : _datasource = FhirResourceDatasource(_database);

  /// Rows read at a time while a filter skips some of them.
  static const _filteredBatchSize = 100;

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
    return localDtos.map(_parse).nonNulls.toList();
  }

  @override
  Future<ResourcePage> getResourcePage({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    DateFilter? dateFilter,
    bool Function(IFhirResource resource)? where,
    int? limit = 20,
    int offset = 0,
  }) async {
    final matches = _matcher(dateFilter, where);
    final batchSize = limit == null
        ? null
        : matches == null
        ? limit
        : max(limit, _filteredBatchSize);
    final types = resourceTypes.map((fhirType) => fhirType.name).toList();
    final page = <IFhirResource>[];
    var next = offset;

    while (true) {
      final rows = await _datasource.getResources(
        resourceTypes: types,
        sourceId: sourceId,
        sourceIds: sourceIds,
        limit: batchSize,
        offset: next,
      );
      for (final row in rows) {
        next++;
        final resource = _parse(row);
        if (resource == null || !(matches?.call(resource) ?? true)) continue;
        page.add(resource);
        if (page.length == limit) {
          return (resources: page, nextOffset: next, hasMore: true);
        }
      }
      if (batchSize == null || rows.length < batchSize) {
        return (resources: page, nextOffset: next, hasMore: false);
      }
    }
  }

  @override
  Future<List<IFhirResource>> getResourcesByIds(Iterable<String> ids) async {
    final rows = await _datasource.getResourcesByIds(ids.toSet().toList());
    return rows.map(_parse).nonNulls.toList();
  }

  /// [dateFilter] and [where] as one test, or null when neither filters.
  static bool Function(IFhirResource)? _matcher(
    DateFilter? dateFilter,
    bool Function(IFhirResource resource)? where,
  ) {
    final dates = dateFilter != null && dateFilter.hasValue ? dateFilter : null;
    if (dates == null && where == null) return null;
    return (resource) {
      final date = resource.date;
      if (dates != null && date != null && !dates.matches(date)) return false;
      return where?.call(resource) ?? true;
    };
  }

  /// The stored row as a record, or null (logged) when it can't be read, so
  /// one bad row doesn't hide the others.
  static IFhirResource? _parse(FhirResourceLocalDto dto) {
    try {
      return IFhirResource.fromLocalDto(dto);
    } catch (e) {
      logger.w(
        'Failed to parse resource ${dto.id} of type ${dto.resourceType}: $e',
      );
      return null;
    }
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
    final List<IFhirResource> resources = [];

    for (String? reference in resource.resourceReferences) {
      final IFhirResource? resource = await resolveReference(reference!);
      if (resource == null) continue;

      resources.add(resource);
    }

    return resources;
  }

  @override
  Future<IFhirResource?> resolveReference(String reference) async {
    final FhirResourceLocalDto? localDto = await _datasource.resolveReference(
      reference,
    );
    if (localDto == null) return null;
    return IFhirResource.fromLocalDto(localDto);
  }

  @override
  Future<List<IFhirResource>> getAttachedDocuments(
    IFhirResource resource,
  ) async {
    final id = resource.resourceId;
    if (id.isEmpty) return [];
    final isEncounter = resource.fhirType == FhirType.Encounter;

    // Narrowed in SQL to documents that mention the id, then matched exactly.
    final rows =
        await (_database.select(_database.fhirResource)
              ..where(
                (f) =>
                    f.resourceType.equals('DocumentReference') &
                    f.deletedAt.isNull() &
                    (f.encounterId.equals(id) | f.resourceRaw.contains(id)),
              )
              ..orderBy([(f) => OrderingTerm.desc(f.date)]))
            .get();

    bool refersTo(Object? references) =>
        references is List &&
        references.any(
          (r) =>
              r is Map &&
              FhirReferenceUtils.extractReferenceId(
                    r['reference']?.toString(),
                  ) ==
                  id,
        );

    final documents = <IFhirResource>[];
    for (final row in rows) {
      final IFhirResource doc;
      try {
        doc = IFhirResource.fromLocalDto(row);
      } catch (e) {
        logger.w('Unreadable DocumentReference ${row.id}', e);
        continue;
      }
      final context = doc.rawResource['context'];
      final attached = isEncounter
          ? doc.encounterId == id ||
                (context is Map && refersTo(context['encounter']))
          : context is Map && refersTo(context['related']);
      if (attached) documents.add(doc);
    }
    return documents;
  }

  // Record Notes - Can be attached to any FHIR resource
  @override
  Future<int> addRecordNote({
    required String resourceId,
    String? sourceId,
    required String content,
  }) async {
    final companion = RecordNotesCompanion.insert(
      uuid: Value(const Uuid().v4()),
      resourceId: resourceId,
      sourceId: Value(await _existingSourceId(sourceId)),
      content: content,
      timestamp: DateTime.now(),
    );

    return await _database
        .into(_database.recordNotes)
        .insertOnConflictUpdate(companion);
  }

  /// [sourceId] when that source exists. A note refers to its source, so a
  /// record without one (or whose source is gone) gets a note without one,
  /// rather than a note that can't be saved.
  Future<String?> _existingSourceId(String? sourceId) async {
    if (sourceId == null || sourceId.isEmpty) return null;
    final source = await (_database.select(
      _database.sources,
    )..where((s) => s.id.equals(sourceId))).getSingleOrNull();
    return source?.id;
  }

  @override
  Future<List<RecordNote>> getRecordNotes(String resourceId) async {
    final shared = _sharedNotes.notesFor(resourceId);
    if (shared != null) return shared;

    final notes =
        await (_database.select(_database.recordNotes)
              ..where(
                (t) => t.resourceId.equals(resourceId) & t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
            .get();

    return notes.map(RecordNote.fromDto).toList();
  }

  @override
  void showSharedNotes(Map<String, List<RecordNote>> notes) =>
      _sharedNotes.show(notes);

  @override
  void clearSharedNotes() => _sharedNotes.clear();

  @override
  Future<int> editRecordNote(RecordNote note) async {
    return await (_database.update(
      _database.recordNotes,
    )..where((t) => t.id.equals(note.id))).write(
      RecordNotesCompanion(
        resourceId: Value(note.resourceId),
        sourceId: Value(await _existingSourceId(note.sourceId)),
        content: Value(note.content),
        timestamp: Value(note.timestamp),
      ),
    );
  }

  /// Soft-deletes the note so the delete reaches the paired device.
  @override
  Future<int> deleteRecordNote(RecordNote note) =>
      _database.softDeleteNote(note.id);

  /// Soft-deletes the record and its notes so the delete reaches the paired
  /// device; the other delete methods below do the same.
  @override
  Future<void> deleteResource(String resourceId) =>
      _deleteRecords({resourceId});

  @override
  Future<void> deleteResourcesByIds(List<String> ids) =>
      _deleteRecords(ids.toSet());

  /// Deletes the records [ids] with what belongs to them: their notes and the
  /// documents attached only to them. Their attachment files stay on the
  /// device, so undoing the delete or a restore opens them again; the 30-day
  /// tombstone purge deletes the files no other row refers to.
  Future<void> _deleteRecords(Set<String> ids) async {
    if (ids.isEmpty) return;

    await _database.transaction(() async {
      final rows = await (_database.select(
        _database.fhirResource,
      )..where((f) => f.id.isIn(ids))).get();
      final attached = await _documentsAttachedOnlyTo(rows, ids);
      final allIds = {...ids, ...attached.map((r) => r.id)};

      // Tombstones the records and their notes, so the delete reaches the
      // paired device.
      await _datasource.deleteResourcesByIds(allIds.toList());
    });
  }

  /// DocumentReferences attached (`context.related`) to [rows] and to no
  /// record outside [ids].
  Future<List<FhirResourceLocalDto>> _documentsAttachedOnlyTo(
    List<FhirResourceLocalDto> rows,
    Set<String> ids,
  ) async {
    final references = {
      for (final row in rows)
        if (row.resourceType != null && row.resourceId != null)
          '${row.resourceType}/${row.resourceId}',
    };
    if (references.isEmpty) return [];

    final candidates =
        await (_database.select(_database.fhirResource)..where(
              (f) =>
                  f.resourceType.equals('DocumentReference') &
                  f.deletedAt.isNull() &
                  f.id.isNotIn(ids) &
                  references
                      .map((r) => f.resourceRaw.contains('"$r"'))
                      .reduce((a, b) => a | b),
            ))
            .get();

    return [
      for (final doc in candidates)
        if (_relatedReferences(doc.resourceRaw) case final related
            when related.isNotEmpty && related.every(references.contains))
          doc,
    ];
  }

  static List<String> _relatedReferences(String rawJson) {
    try {
      final related =
          (jsonDecode(rawJson) as Map<String, dynamic>)['context']?['related']
              as List?;
      return [
        for (final r in related ?? const [])
          if (r is Map && r['reference'] is String) r['reference'] as String,
      ];
    } catch (e) {
      logger.w('Unreadable DocumentReference context', e);
      return const [];
    }
  }

  Future<FhirResourceLocalDto?> _liveResource(String id) => (_database.select(
    _database.fhirResource,
  )..where((f) => f.id.equals(id) & f.deletedAt.isNull())).getSingleOrNull();

  Future<List<FhirResourceLocalDto>> _liveResourcesWithResourceId(
    String resourceId,
  ) =>
      (_database.select(_database.fhirResource)..where(
            (f) => f.resourceId.equals(resourceId) & f.deletedAt.isNull(),
          ))
          .get();

  @override
  Future<int> getRelatedResourceCount(String resourceId) async {
    final targetResource = await _liveResource(resourceId);

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
    String resourceId,
  ) async {
    final targetResource = await _liveResource(resourceId);

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
      final encounterRows = await _liveResourcesWithResourceId(encId);
      for (final r in encounterRows) {
        if (r.id != resourceId) relatedIds.add(r.id);
      }

      final siblings = await _datasource.getResourcesByEncounterId(
        encounterId: encId,
      );
      for (final r in siblings) {
        if (r.id != resourceId) relatedIds.add(r.id);
      }
    }

    if (relatedIds.isEmpty) return [];

    final relatedRows =
        await (_database.select(_database.fhirResource)..where(
              (f) => f.id.isIn(relatedIds.toList()) & f.deletedAt.isNull(),
            ))
            .get();

    return relatedRows.map(IFhirResource.fromLocalDto).toList();
  }

  @override
  Future<void> loadDemoData() async {
    try {
      // Create demo_data source first
      await _syncLocalDataSource.createDemoDataSource();

      // Load demo data from assets
      final String demoDataJson = await rootBundle.loadString(
        'assets/demo_data/demo_data.json',
      );
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
          'Demo data file has invalid format: neither "entry" nor "resources" key found',
        );
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
          .map(
            (resource) => FhirResourceDto.fromJson({
              'id': resource['id'],
              'source_id': 'demo_data',
              'source_resource_type': resource['resourceType'],
              'source_resource_id': resource['id'],
              'sort_title': DemoDataExtractor.extractTitle(resource),
              'sort_date': DemoDataExtractor.extractDate(resource),
              'resource_raw': resource,
              'change_type': 'created',
            }).populateEncounterIdFromRaw().populateSubjectIdFromRaw(),
          )
          .toList();

      await _syncLocalDataSource.cacheFhirResources(processedResources);

      await _attachDemoPdf();
    } catch (e, stackTrace) {
      logger.e('Failed to load demo data: $e');
      logger.e('Stack trace: $stackTrace');
      throw Exception('Failed to load demo data: $e');
    }
  }

  Future<void> _attachDemoPdf() async {
    try {
      final byteData = await rootBundle.load(
        'assets/demo_data/pdf_preview_demo_data.pdf',
      );
      final docsDir = await getApplicationDocumentsDirectory();
      final pdfFile = File('${docsDir.path}/demo_medical_report.pdf');
      await pdfFile.writeAsBytes(byteData.buffer.asUint8List());

      const docRefId = 'demo-doc-ref-pdf-001';
      final docRef = <String, dynamic>{
        'resourceType': 'DocumentReference',
        'id': docRefId,
        'status': 'current',
        'type': {
          'coding': [
            {
              'system': 'http://loinc.org',
              'code': '34117-2',
              'display': 'History and physical note',
            },
          ],
          'text': 'Medical Report',
        },
        'subject': {
          'reference': 'Patient/john-doe-patient-001',
          'display': 'John Doe',
        },
        'date': DateTime.now().toIso8601String(),
        'description': 'Demo Medical Report',
        'content': [
          {
            'attachment': {
              'contentType': 'application/pdf',
              'url': 'file://${pdfFile.path}',
              'title': 'Medical Report',
            },
          },
        ],
        'context': {
          'encounter': [
            {'reference': 'Encounter/demo-encounter-001'},
          ],
        },
      };

      final dto = FhirResourceDto.fromJson({
        'id': docRefId,
        'source_id': 'demo_data',
        'source_resource_type': 'DocumentReference',
        'source_resource_id': docRefId,
        'sort_title': 'Medical Report',
        'sort_date': DateTime.now().toIso8601String(),
        'resource_raw': docRef,
        'change_type': 'created',
      }).populateEncounterIdFromRaw().populateSubjectIdFromRaw();

      await _syncLocalDataSource.cacheFhirResources([dto]);
    } catch (e) {
      logger.w('Failed to attach the demo PDF', e);
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
        final coding = Map<String, dynamic>.from(
          codings.first as Map<String, dynamic>,
        );
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
    // The demo person's sources: the demo data and what was scanned or
    // attached for them, which would otherwise outlive their patient.
    final sourceIds = [
      'demo_data',
      for (final row
          in await _database
              .customSelect(
                'SELECT id FROM sources WHERE deleted_at IS NULL '
                "AND id != 'demo_data' AND holder_id = "
                "(SELECT holder_id FROM sources WHERE id = 'demo_data')",
              )
              .get())
        row.read<String>('id'),
    ];

    // Each tombstones the source, its records and their notes in one
    // transaction.
    for (final sourceId in sourceIds) {
      await _syncLocalDataSource.deleteSource(sourceId);
    }
  }

  @override
  Future<bool> hasDemoData() async {
    final resources = await _datasource.getResources(
      sourceId: 'demo_data',
      resourceTypes: [],
      limit: 1,
    );
    return resources.isNotEmpty;
  }

  /// The patient's blood-type observations (ABO, Rh, or both), newest
  /// first, found by LOINC code so they don't drop out behind newer results.
  /// With [sourceId], the ones from that source when it has any.
  @override
  Future<List<IFhirResource>> getBloodTypeObservations({
    required String patientId,
    String? sourceId,
  }) async {
    final patientRow =
        await (_database.select(_database.fhirResource)..where(
              (f) =>
                  f.id.equals(patientId) &
                  f.resourceType.equals('Patient') &
                  f.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (patientRow == null) return [];
    final patientIds = {patientRow.id, ?patientRow.resourceId};

    const codes = [
      BloodTypes.aboLoincCode,
      BloodTypes.rhLoincCode,
      BloodTypes.combinedLoincCode,
    ];
    final rows =
        await (_database.select(_database.fhirResource)
              ..where(
                (f) =>
                    f.resourceType.equals('Observation') &
                    f.deletedAt.isNull() &
                    codes
                        .map((code) => f.resourceRaw.contains('"$code"'))
                        .reduce((a, b) => a | b),
              )
              ..orderBy([(f) => OrderingTerm.desc(f.date)]))
            .get();

    final matches = <Observation>[];
    for (final row in rows) {
      final IFhirResource resource;
      try {
        resource = IFhirResource.fromLocalDto(row);
      } catch (e) {
        logger.w('Unreadable blood type observation ${row.id}', e);
        continue;
      }
      if (resource is! Observation) continue;
      final hasCode =
          resource.code?.coding?.any(
            (c) => codes.contains(c.code?.toString()),
          ) ??
          false;
      final subject = resource.subject?.reference?.valueString;
      if (!hasCode || subject == null) continue;
      final subjectId = FhirReferenceUtils.extractReferenceId(subject);
      if (patientIds.contains(subjectId)) matches.add(resource);
    }

    if (sourceId != null && sourceId.isNotEmpty) {
      final fromSource = matches.where((o) => o.sourceId == sourceId).toList();
      if (fromSource.isNotEmpty) return fromSource;
    }
    return matches;
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
        rawResource['encounter']['reference'],
      );
    }
    if (rawResource['subject']?['reference'] != null) {
      subjectId = FhirReferenceUtils.extractReferenceId(
        rawResource['subject']['reference'],
      );
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
    List<String>? sourceIds,
    DateFilter? dateFilter,
    bool Function(IFhirResource resource)? where,
    int limit = 50,
  }) async {
    final matches = _matcher(dateFilter, where);
    final localDtos = await _datasource.searchResources(
      query: query,
      resourceTypes: resourceTypes.map((fhirType) => fhirType.name).toList(),
      sourceId: sourceId,
      sourceIds: sourceIds,
      // A filter applied here would otherwise leave fewer than [limit].
      limit: matches == null ? limit : null,
    );

    final resources = localDtos.map(_parse).nonNulls;
    return (matches == null ? resources : resources.where(matches))
        .take(limit)
        .toList();
  }

  @override
  Future<({Uint8List bytes, String patientName})> buildIpsExport({
    String? sourceId,
    List<String>? sourceIds,
    String? patientId,
  }) async {
    List<String>? patientSourceIds = sourceIds;
    if (patientSourceIds == null && patientId != null) {
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

    final List<FhirResourceLocalDto> resourceDtos = await _datasource
        .getResources(
          resourceTypes: [],
          sourceId: sourceId,
          sourceIds: patientSourceIds,
        );

    final List<IFhirResource> resources = resourceDtos
        .map(IFhirResource.fromLocalDto)
        .toList();

    final Patient? patient = patientId != null
        ? resources
              .whereType<Patient>()
              .where((p) => p.id == patientId)
              .firstOrNull
        : resources.whereType<Patient>().firstOrNull;

    if (patient == null) {
      throw Exception('Patient not found');
    }

    final patientName =
        FhirFieldExtractor.extractHumanNameFamilyFirst(
          patient.name?.first,
        )?.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_') ??
        'Unknown';

    final FhirIpsBuilder builder = FhirIpsBuilder();
    final FhirIpsPdfRenderer renderer = FhirIpsPdfRenderer();

    final ipsData = await builder.buildFromRawResources(
      rawResources: resources.map((r) => r.rawResource).toList(),
      rawPatient: patient.rawResource,
    );

    final bytes = await renderer.render(ipsData: ipsData);
    return (bytes: bytes, patientName: patientName);
  }

  @override
  Future<void> updateResourceRaw(String resourceId, String rawJson) async {
    await (_database.update(
      _database.fhirResource,
    )..where((tbl) => tbl.id.equals(resourceId))).write(
      FhirResourceCompanion(
        resourceRaw: Value(rawJson),
      ),
    );
  }

  @override
  Future<void> setSpecialtyOverride(
    String resourceId,
    String? specialtyName,
  ) async {
    await (_database.update(
      _database.fhirResource,
    )..where((tbl) => tbl.id.equals(resourceId))).write(
      FhirResourceCompanion(
        specialtyOverride: Value(specialtyName),
      ),
    );
  }
}
