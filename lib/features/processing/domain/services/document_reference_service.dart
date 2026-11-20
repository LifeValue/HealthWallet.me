import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/data/local/soft_delete.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/utils/fhir_reference_utils.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/processing/data/services/pdf_generation_service.dart';
import 'package:health_wallet/features/records/domain/entity/encounter/encounter.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

@injectable
class DocumentReferenceService {
  final AppDatabase _database;
  final PdfGenerationService _pdfGenerationService;
  final PathResolver _pathResolver;

  DocumentReferenceService(
    this._database,
    this._pdfGenerationService,
    this._pathResolver,
  );

  static const _sessionSystem = 'http://healthwallet.me/processing-session';

  /// Saves a processing session's files as DocumentReferences attached to
  /// the session's [container] (its Encounter or DiagnosticReport), then
  /// deletes the ones an earlier save of the same session created. Only
  /// documents tagged with [sessionId] are replaced: other scans and files
  /// attached by hand to the same record stay, and if the new PDFs fail the
  /// earlier documents are kept.
  Future<List<String>> replaceSessionDocuments({
    required String sessionId,
    required List<String> filePaths,
    required String patientId,
    required IFhirResource container,
    required String sourceId,
    String? title,
  }) async {
    final saved = await saveGroupedDocumentsAsFhirRecords(
      filePaths: filePaths,
      patientId: patientId,
      container: container,
      sourceId: sourceId,
      title: title,
      sessionId: sessionId,
    );

    final earlier =
        await (_database.select(_database.fhirResource)..where(
              (t) =>
                  t.resourceType.equals('DocumentReference') &
                  t.deletedAt.isNull() &
                  t.resourceRaw.contains(_sessionSystem) &
                  t.resourceRaw.contains(sessionId),
            ))
            .get();
    final replaced = [
      for (final row in earlier)
        if (!saved.contains(row.resourceId) &&
            _sessionIdOf(row.resourceRaw) == sessionId)
          row.id,
    ];
    // Tombstoned, so the paired device drops them too (see [SoftDelete]).
    await _database.softDeleteResources(replaced);
    return saved;
  }

  static String? _sessionIdOf(String rawJson) {
    try {
      final identifiers =
          (jsonDecode(rawJson) as Map<String, dynamic>)['identifier'] as List?;
      for (final identifier in identifiers ?? const []) {
        if (identifier is Map && identifier['system'] == _sessionSystem) {
          return identifier['value'] as String?;
        }
      }
    } catch (e) {
      logger.w('Unreadable DocumentReference identifiers', e);
    }
    return null;
  }

  /// Saves [filePaths] as DocumentReferences, attached to [container] when
  /// there is one: an Encounter through `context.encounter`, any other record
  /// through `context.related`, as files attached by hand are. Either way the
  /// row's encounter id is the container's id, which is how an Encounter or a
  /// DiagnosticReport finds, counts and deletes the records filed under it.
  Future<List<String>> saveGroupedDocumentsAsFhirRecords({
    required List<String> filePaths,
    required String patientId,
    IFhirResource? container,
    required String sourceId,
    String? title,
    String? sessionId,
  }) async {
    try {
      final List<String> savedResourceIds = [];

      final documentGroups = await _pdfGenerationService
          .groupAndConvertDocuments(filePaths: filePaths);

      for (int i = 0; i < documentGroups.length; i++) {
        final group = documentGroups[i];

        final fhirDocumentReference =
            await _createFhirR4DocumentReferenceFromPdf(
              pdfPath: group.pdfPath,
              patientId: patientId,
              container: container,
              title: group.title,
              sessionId: sessionId,
              index: i,
            );

        final resourceId = await _saveFhirDocumentReferenceToDatabase(
          fhirDocumentReference: fhirDocumentReference,
          sourceId: sourceId,
          title: group.title,
          containerId: container?.resourceId,
        );

        savedResourceIds.add(resourceId);
      }

      return savedResourceIds;
    } catch (e) {
      logger.e('❌ Failed to create grouped FHIR DocumentReference records: $e');
      throw Exception(
        'Failed to create grouped FHIR DocumentReference records: $e',
      );
    }
  }

  Future<fhir_r4.DocumentReference> _createFhirR4DocumentReferenceFromPdf({
    required String pdfPath,
    required String patientId,
    IFhirResource? container,
    required String title,
    String? sessionId,
    int index = 0,
  }) async {
    final file = File(pdfPath);
    final bytes = await file.readAsBytes();
    final timestamp = DateTime.now();
    final relativePdfPath = await _pathResolver.toRelative(pdfPath);

    // A scan's documents get the same ids every time its session is saved,
    // on either device: a handed-over document saved on the phone and on the
    // desktop is one record, not two. Without a session, a uuid, so two
    // documents saved in the same millisecond get two rows.
    final documentReferenceId = sessionId == null
        ? const Uuid().v4()
        : sessionDocumentId(sessionId, index);

    final context = switch (container) {
      null => null,
      Encounter(:final resourceId) => fhir_r4.DocumentReferenceContext(
        encounter: [
          fhir_r4.Reference(
            reference: fhir_r4.FhirString('Encounter/$resourceId'),
            display: fhir_r4.FhirString('Encounter $resourceId'),
          ),
        ],
      ),
      _ => fhir_r4.DocumentReferenceContext(
        related: [
          fhir_r4.Reference(
            reference: fhir_r4.FhirString(
              '${container.fhirType.name}/${container.resourceId}',
            ),
            display: fhir_r4.FhirString('Related ${container.fhirType.name}'),
          ),
        ],
      ),
    };

    final subjectReference = fhir_r4.Reference(
      reference: fhir_r4.FhirString('Patient/$patientId'),
      display: fhir_r4.FhirString('Patient $patientId'),
    );

    return fhir_r4.DocumentReference(
      id: fhir_r4.FhirString(documentReferenceId),
      status: fhir_r4.DocumentReferenceStatus.current,
      type: fhir_r4.CodeableConcept(
        coding: [
          fhir_r4.Coding(
            system: fhir_r4.FhirUri('http://loinc.org'),
            code: fhir_r4.FhirCode('34133-9'),
            display: fhir_r4.FhirString('Summary of episode note'),
          ),
        ],
        text: fhir_r4.FhirString('Medical Document'),
      ),
      subject: subjectReference,
      date: fhir_r4.FhirInstant.fromDateTime(timestamp),
      content: [
        fhir_r4.DocumentReferenceContent(
          attachment: fhir_r4.Attachment(
            contentType: fhir_r4.FhirCode('application/pdf'),
            url: fhir_r4.FhirUrl('file://$relativePdfPath'),
            title: fhir_r4.FhirString(title),
            size: fhir_r4.FhirUnsignedInt(bytes.length.toString()),
          ),
        ),
      ],
      context: context,
      identifier: [
        fhir_r4.Identifier(
          system: fhir_r4.FhirUri('http://healthwallet.me/document-id'),
          value: fhir_r4.FhirString(documentReferenceId),
          use: fhir_r4.IdentifierUse.usual,
        ),
        if (sessionId != null)
          fhir_r4.Identifier(
            system: fhir_r4.FhirUri(_sessionSystem),
            value: fhir_r4.FhirString(sessionId),
            use: fhir_r4.IdentifierUse.secondary,
          ),
      ],
    );
  }

  Future<String> _saveFhirDocumentReferenceToDatabase({
    required fhir_r4.DocumentReference fhirDocumentReference,
    required String sourceId,
    required String title,
    String? containerId,
  }) async {
    final resourceJson = fhirDocumentReference.toJson();
    final resourceId = fhirDocumentReference.id!.valueString!;

    final encounterId = containerId == null || containerId.isEmpty
        ? null
        : containerId;
    String? subjectId;

    if (fhirDocumentReference.subject?.reference?.valueString != null) {
      subjectId = FhirReferenceUtils.extractReferenceId(
        fhirDocumentReference.subject!.reference!.valueString!,
      );
    }

    final dto = FhirResourceCompanion.insert(
      id: '${sourceId}_$resourceId',
      sourceId: Value(sourceId),
      resourceId: Value(resourceId),
      resourceType: const Value('DocumentReference'),
      title: Value(title),
      date: Value(_extractDateFromDocumentReference(fhirDocumentReference)),
      resourceRaw: jsonEncode(resourceJson),
      encounterId: encounterId != null
          ? Value(encounterId)
          : const Value.absent(),
      subjectId: subjectId != null ? Value(subjectId) : const Value.absent(),
      deletedAt: const Value(null),
    );

    await _database.into(_database.fhirResource).insertOnConflictUpdate(dto);
    return resourceId;
  }

  DateTime? _extractDateFromDocumentReference(
    fhir_r4.DocumentReference documentReference,
  ) {
    if (documentReference.date != null) {
      try {
        return documentReference.date!.valueDateTime;
      } catch (e) {
        return null;
      }
    }
    return DateTime.now();
  }

  Future<List<FhirResourceLocalDto>> getAllDocumentReferences({
    String? sourceId,
  }) async {
    var query = (_database.select(_database.fhirResource)
      ..where(
        (tbl) =>
            tbl.resourceType.equals('DocumentReference') &
            tbl.deletedAt.isNull(),
      ));

    if (sourceId != null) {
      query = query..where((tbl) => tbl.sourceId.equals(sourceId));
    }

    return query.get();
  }

  Future<List<FhirResourceLocalDto>> getDocumentReferencesForEncounter({
    required String encounterId,
    String? sourceId,
  }) async {
    final allDocuments = await getAllDocumentReferences(sourceId: sourceId);

    return allDocuments.where((document) {
      try {
        final resourceJson = jsonDecode(document.resourceRaw);
        final context = resourceJson['context'];
        if (context != null && context['encounter'] != null) {
          final encounters = context['encounter'] as List;
          return encounters.any((encounter) {
            return encounter['reference'] == 'Encounter/$encounterId';
          });
        }
        return false;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Future<void> linkDocumentReferenceToEncounter({
    required String documentReferenceResourceId,
    required String encounterId,
    String? sourceId,
  }) async {
    try {
      final documentQuery = _database.select(_database.fhirResource)
        ..where(
          (tbl) =>
              tbl.id.equals(
                '${sourceId ?? 'scanner-app'}_$documentReferenceResourceId',
              ) &
              tbl.deletedAt.isNull(),
        );

      final document = await documentQuery.getSingleOrNull();

      if (document == null) {
        throw Exception('DocumentReference resource not found');
      }

      final resourceJson =
          jsonDecode(document.resourceRaw) as Map<String, dynamic>;

      resourceJson['context'] = {
        'encounter': [
          {
            'reference': 'Encounter/$encounterId',
            'display': 'Encounter $encounterId',
          },
        ],
      };

      final updateCompanion = FhirResourceCompanion(
        id: Value(document.id),
        resourceRaw: Value(jsonEncode(resourceJson)),
        encounterId: Value(encounterId),
      );

      await (_database.update(
        _database.fhirResource,
      )..where((tbl) => tbl.id.equals(document.id))).write(updateCompanion);
    } catch (e) {
      throw Exception('Failed to link DocumentReference to Encounter: $e');
    }
  }

  /// The id of document [index] of processing session [sessionId].
  static String sessionDocumentId(String sessionId, int index) =>
      const Uuid().v5(
        Namespace.url.value,
        'http://healthwallet.me/session/$sessionId/document/$index',
      );
}
