import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:drift/drift.dart' as drift;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/utils/fhir_reference_utils.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;

part 'record_attachments_event.dart';
part 'record_attachments_state.dart';
part 'record_attachments_bloc.freezed.dart';

@injectable
class RecordAttachmentsBloc
    extends Bloc<RecordAttachmentsEvent, RecordAttachmentsState> {
  RecordAttachmentsBloc(
    this._recordsRepository,
    this._sourceTypeService,
    this._syncRepository,
    this._database,
    this._pathResolver,
  ) : super(const RecordAttachmentsState()) {
    on<RecordAttachmentsInitialised>(_onRecordAttachmentsInitialised);
    on<RecordAttachmentsFileAttached>(_onRecordAttachmentsFileAttached);
    on<RecordAttachmentsFileDeleted>(_onRecordAttachmentsFileDeleted);
  }

  final RecordsRepository _recordsRepository;
  final SourceTypeService _sourceTypeService;
  final SyncRepository _syncRepository;
  final AppDatabase _database;
  final PathResolver _pathResolver;

  _onRecordAttachmentsInitialised(
    RecordAttachmentsInitialised event,
    Emitter<RecordAttachmentsState> emit,
  ) async {
    emit(state.copyWith(status: const RecordAttachmentsStatus.loading()));

    try {
      if (event.resource.fhirType == FhirType.DocumentReference) {
        final attachmentInfo = await _extractAttachmentInfo(event.resource);
        emit(state.copyWith(
            attachments: [attachmentInfo],
            resource: event.resource,
            status: const RecordAttachmentsStatus.success()));
        return;
      }

      final encounterId = _extractEncounterId(event.resource);

      final List<IFhirResource> documentReferences;
      if (event.ephemeralRecords.isNotEmpty) {
        documentReferences = event.ephemeralRecords
            .where((r) => r.fhirType == FhirType.DocumentReference)
            .toList();
      } else {
        documentReferences = await _recordsRepository.getResources(
          resourceTypes: [FhirType.DocumentReference],
          sourceId: null,
          limit: 100,
        );
      }

      final relatedDocuments = documentReferences.where((doc) {
        if (doc.rawResource.isEmpty) return false;

        try {
          final context = doc.rawResource['context'];
          if (context == null) return false;

          if (context['related'] != null) {
            final relatedList = context['related'] as List;
            final isRelatedToThisResource = relatedList.any((related) {
              final refId = FhirReferenceUtils.extractReferenceId(
                  related['reference']?.toString());
              return refId == event.resource.resourceId;
            });
            if (isRelatedToThisResource) return true;
          }

          if (encounterId != null && context['encounter'] != null) {
            final encounters = context['encounter'] as List;
            final isInSameEncounter = encounters.any((encounter) {
              final refId = FhirReferenceUtils.extractReferenceId(
                  encounter['reference']?.toString());
              return refId == encounterId;
            });
            if (isInSameEncounter) return true;
          }

          if (event.resource.fhirType == FhirType.Encounter &&
              context['encounter'] != null) {
            final encounters = context['encounter'] as List;
            return encounters.any((encounter) {
              final refId = FhirReferenceUtils.extractReferenceId(
                  encounter['reference']?.toString());
              return refId == event.resource.resourceId;
            });
          }

          return false;
        } catch (e) {
          return false;
        }
      }).toList();

      final attachmentInfos = await Future.wait(
          relatedDocuments.map((doc) => _extractAttachmentInfo(doc)));

      emit(state.copyWith(
          attachments: attachmentInfos,
          resource: event.resource,
          status: const RecordAttachmentsStatus.success()));
    } catch (e) {
      emit(state.copyWith(status: RecordAttachmentsStatus.error(e)));
    }
  }

  Future<AttachmentInfo> _extractAttachmentInfo(
      IFhirResource documentReference) async {
    try {
      final content = documentReference.rawResource['content'] as List?;
      final attachmentData = content?.isNotEmpty == true
          ? content!.first['attachment'] as Map<String, dynamic>?
          : null;

      final contentType = attachmentData?['contentType'] as String?;
      final title =
          attachmentData?['title'] as String? ?? documentReference.title;
      final url = attachmentData?['url'] as String?;

      String? filePath;
      if (url?.startsWith('file://') == true) {
        final rawPath = url!.substring(7);
        filePath = await _pathResolver.toAbsolute(rawPath);
      }

      return AttachmentInfo(
        documentReference: documentReference,
        title: title,
        contentType: contentType,
        filePath: filePath,
      );
    } catch (e) {
      return AttachmentInfo(
        documentReference: documentReference,
        title: documentReference.title,
      );
    }
  }

  _onRecordAttachmentsFileAttached(
    RecordAttachmentsFileAttached event,
    Emitter<RecordAttachmentsState> emit,
  ) async {
    emit(state.copyWith(status: const RecordAttachmentsStatus.loading()));

    try {
      if (state.resource.fhirType == FhirType.DocumentReference) {
        emit(state.copyWith(
            status: const RecordAttachmentsStatus.error(
                'Cannot attach files to DocumentReference resources')));
        return;
      }

      Directory appDirectory = await getApplicationDocumentsDirectory();

      String originalFileName = basename(event.file.path);
      String newFilePath = join(appDirectory.path, originalFileName);

      await event.file.copy(newFilePath);

      final subjectId = _extractSubjectId(state.resource);
      final encounterId = _extractEncounterId(state.resource);

      final effectiveSourceId = await _getEffectiveSourceId(
        resourceSourceId: state.resource.sourceId,
        patientId: subjectId ?? '',
      );

      final documentReference = await _createDocumentReference(
        filePath: newFilePath,
        fileName: originalFileName,
        subjectId: subjectId ?? '',
        encounterId: encounterId,
        relatedResourceId: state.resource.id,
        relatedResourceType: state.resource.fhirType.name,
      );

      await _saveDocumentReferenceToDatabase(
        documentReference: documentReference,
        sourceId: effectiveSourceId,
        title: originalFileName,
      );

      try {
        final homeBloc = getIt<HomeBloc>();
        homeBloc.add(const HomeRefreshPreservingOrder());
      } catch (e) {
      }

      emit(state.copyWith(attachments: []));
      add(RecordAttachmentsInitialised(resource: state.resource));
    } catch (e) {
      emit(state.copyWith(status: RecordAttachmentsStatus.error(e)));
    }
  }

  Future<fhir_r4.DocumentReference> _createDocumentReference({
    required String filePath,
    required String fileName,
    required String subjectId,
    String? encounterId,
    String? relatedResourceId,
    String? relatedResourceType,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final timestamp = DateTime.now();
    final documentReferenceId = _generateId();
    final relativeFilePath = await _pathResolver.toRelative(filePath);

    final List<fhir_r4.Reference>? encounterReferences = encounterId != null
        ? [
            fhir_r4.Reference(
              reference: fhir_r4.FhirString('Encounter/$encounterId'),
              display: fhir_r4.FhirString('Encounter $encounterId'),
            )
          ]
        : null;

    final subjectReference = fhir_r4.Reference(
      reference: fhir_r4.FhirString('Patient/$subjectId'),
      display: fhir_r4.FhirString('Patient $subjectId'),
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
            contentType: fhir_r4.FhirCode(_getContentTypeFromPath(filePath)),
            url: fhir_r4.FhirUrl('file://$relativeFilePath'),
            title: fhir_r4.FhirString(fileName),
            size: fhir_r4.FhirUnsignedInt(bytes.length.toString()),
          ),
        ),
      ],
      context: (encounterReferences != null || relatedResourceId != null)
          ? fhir_r4.DocumentReferenceContext(
              encounter: encounterReferences,
              related: relatedResourceId != null && relatedResourceType != null
                  ? [
                      fhir_r4.Reference(
                        reference: fhir_r4.FhirString(
                            '$relatedResourceType/$relatedResourceId'),
                        display:
                            fhir_r4.FhirString('Related $relatedResourceType'),
                      )
                    ]
                  : null,
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

  Future<String> _saveDocumentReferenceToDatabase({
    required fhir_r4.DocumentReference documentReference,
    required String sourceId,
    required String title,
  }) async {
    final resourceJson = documentReference.toJson();
    final resourceId = documentReference.id!.valueString!;

    String? encounterId;
    String? subjectId;

    if (documentReference.context?.encounter != null &&
        documentReference.context!.encounter!.isNotEmpty) {
      final encounterRef =
          documentReference.context!.encounter!.first.reference?.valueString;
      if (encounterRef != null) {
        encounterId = FhirReferenceUtils.extractReferenceId(encounterRef);
      }
    }

    if (documentReference.subject?.reference?.valueString != null) {
      subjectId = FhirReferenceUtils.extractReferenceId(
          documentReference.subject!.reference!.valueString!);
    }

    final dto = FhirResourceCompanion.insert(
      id: '${sourceId}_$resourceId',
      sourceId: drift.Value(sourceId),
      resourceId: drift.Value(resourceId),
      resourceType: drift.Value('DocumentReference'),
      title: drift.Value(title),
      date:
          drift.Value(documentReference.date?.valueDateTime ?? DateTime.now()),
      resourceRaw: jsonEncode(resourceJson),
      encounterId: encounterId != null
          ? drift.Value(encounterId)
          : const drift.Value.absent(),
      subjectId: subjectId != null
          ? drift.Value(subjectId)
          : const drift.Value.absent(),
    );

    await _database.into(_database.fhirResource).insertOnConflictUpdate(dto);
    return resourceId;
  }

  String _getContentTypeFromPath(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  _onRecordAttachmentsFileDeleted(
    RecordAttachmentsFileDeleted event,
    Emitter<RecordAttachmentsState> emit,
  ) async {
    emit(state.copyWith(status: const RecordAttachmentsStatus.loading()));

    try {
      await (_database.delete(_database.fhirResource)
            ..where((t) => t.id.equals(event.attachment.id)))
          .go();

      try {
        final content = event.attachment.rawResource['content'] as List?;
        if (content != null && content.isNotEmpty) {
          final attachment = content.first['attachment'];
          final url = attachment?['url'] as String?;
          if (url != null && url.startsWith('file://')) {
            final rawPath = url.substring(7);
            final absolutePath = await _pathResolver.toAbsolute(rawPath);
            final file = File(absolutePath);
            if (await file.exists()) {
              await file.delete();
            }
          }
        }
      } catch (e) {}

      try {
        final homeBloc = getIt<HomeBloc>();
        homeBloc.add(const HomeRefreshPreservingOrder());
      } catch (e) {
      }

      add(RecordAttachmentsInitialised(resource: state.resource));
    } catch (e) {
      emit(state.copyWith(status: RecordAttachmentsStatus.error(e)));
    }
  }

  String? _extractSubjectId(IFhirResource resource) {
    final rawResource = resource.rawResource;

    if (resource.fhirType == FhirType.Patient) {
      return resource.resourceId;
    }

    if (rawResource['subject']?['reference'] != null) {
      final reference = rawResource['subject']['reference'] as String;
      if (reference.startsWith('Patient/')) {
        return reference.substring(8);
      } else if (reference.startsWith('urn:uuid:')) {
        return reference.substring(9);
      }
    }

    return null;
  }

  String? _extractEncounterId(IFhirResource resource) {
    final rawResource = resource.rawResource;

    if (resource.fhirType == FhirType.Encounter) {
      return resource.resourceId;
    }

    if (rawResource['encounter']?['reference'] != null) {
      final reference = rawResource['encounter']['reference'] as String;
      if (reference.startsWith('Encounter/')) {
        return reference.substring(10);
      } else if (reference.startsWith('urn:uuid:')) {
        return reference.substring(9);
      }
    }

    if (rawResource['context']?['encounter'] != null) {
      final encounters = rawResource['context']['encounter'] as List;
      if (encounters.isNotEmpty) {
        final reference = encounters.first['reference'] as String?;
        if (reference != null) {
          if (reference.startsWith('Encounter/')) {
            return reference.substring(10);
          } else if (reference.startsWith('urn:uuid:')) {
            return reference.substring(9);
          }
        }
      }
    }

    return null;
  }

  Future<String> _getEffectiveSourceId({
    required String resourceSourceId,
    required String patientId,
  }) async {
    final allSources = await _syncRepository.getSources();

    final resourceSource = allSources
        .where(
          (s) => s.id == resourceSourceId,
        )
        .firstOrNull;

    if (resourceSource == null ||
        !_sourceTypeService.isSourceWritable(resourceSource.platformType)) {
      final walletSource = await _sourceTypeService.getWritableSourceForPatient(
        patientId: patientId,
        patientName: null,
        availableSources: allSources,
      );
      return walletSource.id;
    }

    return resourceSourceId;
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
