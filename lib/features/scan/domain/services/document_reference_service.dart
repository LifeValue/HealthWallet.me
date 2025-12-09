import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:health_wallet/features/records/domain/entity/encounter/encounter.dart';
import 'package:health_wallet/features/scan/presentation/services/pdf_generation_service.dart';
import 'package:injectable/injectable.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/utils/fhir_reference_utils.dart';
import 'package:health_wallet/core/utils/logger.dart';

@injectable
class DocumentReferenceService {
  final AppDatabase _database;
  final PdfGenerationService _pdfGenerationService;

  DocumentReferenceService(this._database, this._pdfGenerationService);

  Future<List<String>> saveGroupedDocumentsAsFhirRecords({
    required List<String> filePaths,
    required String patientId,
    Encounter? encounter,
    required String sourceId,
    String? title,
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
          encounter: encounter,
          title: group.title,
        );

        final resourceId = await _saveFhirDocumentReferenceToDatabase(
          fhirDocumentReference: fhirDocumentReference,
          sourceId: sourceId,
          title: group.title,
        );

        savedResourceIds.add(resourceId);
      }

      return savedResourceIds;
    } catch (e) {
      logger.e('❌ Failed to create grouped FHIR DocumentReference records: $e');
      throw Exception(
          'Failed to create grouped FHIR DocumentReference records: $e');
    }
  }

  Future<fhir_r4.DocumentReference> _createFhirR4DocumentReferenceFromPdf({
    required String pdfPath,
    required String patientId,
    Encounter? encounter,
    required String title,
  }) async {
    final file = File(pdfPath);
    final bytes = await file.readAsBytes();
    final timestamp = DateTime.now();

    final documentReferenceId = _generateId();

    // Create encounter reference if provided
    final List<fhir_r4.Reference>? encounterReferences = encounter != null
        ? [
            fhir_r4.Reference(
              reference: fhir_r4.FhirString('Encounter/${encounter.id}'),
              display: fhir_r4.FhirString('Encounter ${encounter.id}'),
            )
          ]
        : null;

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
            url: fhir_r4.FhirUrl('file://$pdfPath'),
            title: fhir_r4.FhirString(title),
            size: fhir_r4.FhirUnsignedInt(bytes.length.toString()),
          ),
        ),
      ],
      context: encounterReferences != null
          ? fhir_r4.DocumentReferenceContext(
              encounter: encounterReferences,
            )
          : null,
      identifier: [
        fhir_r4.Identifier(
          system: fhir_r4.FhirUri('http://healthwallet.me/document-id'),
          value: fhir_r4.FhirString(_generateId()),
          use: fhir_r4.IdentifierUse.usual,
        ),
      ],
    );
  }

  Future<String> _saveFhirDocumentReferenceToDatabase({
    required fhir_r4.DocumentReference fhirDocumentReference,
    required String sourceId,
    required String title,
  }) async {
    final resourceJson = fhirDocumentReference.toJson();
    final resourceId = fhirDocumentReference.id!.valueString!;

    String? encounterId;
    String? subjectId;

    if (fhirDocumentReference.context?.encounter != null &&
        fhirDocumentReference.context!.encounter!.isNotEmpty) {
      final encounterRef = fhirDocumentReference
          .context!.encounter!.first.reference?.valueString;
      if (encounterRef != null) {
        encounterId = FhirReferenceUtils.extractReferenceId(encounterRef);
      }
    }

    if (fhirDocumentReference.subject?.reference?.valueString != null) {
      subjectId = FhirReferenceUtils.extractReferenceId(
          fhirDocumentReference.subject!.reference!.valueString!);
    }

    final dto = FhirResourceCompanion.insert(
      id: '${sourceId}_$resourceId',
      sourceId: Value(sourceId),
      resourceId: Value(resourceId),
      resourceType: Value('DocumentReference'),
      title: Value(title),
      date: Value(_extractDateFromDocumentReference(fhirDocumentReference)),
      resourceRaw: jsonEncode(resourceJson),
      encounterId:
          encounterId != null ? Value(encounterId) : const Value.absent(),
      subjectId: subjectId != null ? Value(subjectId) : const Value.absent(),
    );

    await _database.into(_database.fhirResource).insertOnConflictUpdate(dto);
    return resourceId;
  }

  DateTime? _extractDateFromDocumentReference(
      fhir_r4.DocumentReference documentReference) {
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
      ..where((tbl) => tbl.resourceType.equals('DocumentReference')));

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
        ..where((tbl) => tbl.id.equals(
            '${sourceId ?? 'scanner-app'}_$documentReferenceResourceId'));

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
          }
        ],
      };

      final updateCompanion = FhirResourceCompanion(
        id: Value(document.id),
        resourceRaw: Value(jsonEncode(resourceJson)),
        encounterId: Value(encounterId),
      );

      await (_database.update(_database.fhirResource)
            ..where((tbl) => tbl.id.equals(document.id)))
          .write(updateCompanion);
    } catch (e) {
      throw Exception('Failed to link DocumentReference to Encounter: $e');
    }
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
