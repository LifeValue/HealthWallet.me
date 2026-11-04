import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:drift/drift.dart' as drift;
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/utils/fhir_reference_utils.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/domain/services/fhir_resource_relationship_service.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

part 'record_attachments_bloc.freezed.dart';
part 'record_attachments_event.dart';
part 'record_attachments_state.dart';

@injectable
class RecordAttachmentsBloc
    extends Bloc<RecordAttachmentsEvent, RecordAttachmentsState> {
  RecordAttachmentsBloc(
    this._recordsRepository,
    this._sourceTypeService,
    this._holderService,
    this._syncRepository,
    this._database,
    this._pathResolver,
    this._strings,
  ) : super(const RecordAttachmentsState()) {
    on<RecordAttachmentsInitialised>(_onRecordAttachmentsInitialised);
    on<RecordAttachmentsFileAttached>(_onRecordAttachmentsFileAttached);
    on<RecordAttachmentsFileDeleted>(_onRecordAttachmentsFileDeleted);
  }

  final RecordsRepository _recordsRepository;
  final SourceTypeService _sourceTypeService;
  final HolderService _holderService;
  final SyncRepository _syncRepository;
  final AppDatabase _database;
  final PathResolver _pathResolver;
  final AppStringsProvider _strings;

  Future<void> _onRecordAttachmentsInitialised(
    RecordAttachmentsInitialised event,
    Emitter<RecordAttachmentsState> emit,
  ) async {
    emit(state.copyWith(status: const RecordAttachmentsStatus.loading()));

    try {
      if (event.resource.fhirType == FhirType.DocumentReference) {
        final attachmentInfo = await _extractAttachmentInfo(event.resource);
        emit(
          state.copyWith(
            attachments: [attachmentInfo],
            resource: event.resource,
            status: const RecordAttachmentsStatus.success(),
          ),
        );
        return;
      }

      final isEncounter = event.resource.fhirType == FhirType.Encounter;

      final List<IFhirResource> relatedDocuments;
      if (event.ephemeralRecords.isNotEmpty) {
        final related = FhirResourceRelationshipService.findRelatedInMemory(
          resource: event.resource,
          allRecords: event.ephemeralRecords,
        );
        relatedDocuments = related
            .where((r) => r.fhirType == FhirType.DocumentReference)
            .toList();
      } else {
        relatedDocuments = await _recordsRepository.getAttachedDocuments(
          event.resource,
        );
      }

      final List<AttachmentInfo> attachmentInfos;
      if (isEncounter) {
        final allRelated = event.ephemeralRecords.isNotEmpty
            ? event.ephemeralRecords
            : await _recordsRepository.getRelatedResourcesForEncounter(
                encounterId: event.resource.resourceId,
              );
        final resourceMap = <String, IFhirResource>{};
        for (final r in allRelated) {
          resourceMap[r.resourceId] = r;
        }

        final infos = await Future.wait(
          relatedDocuments.map((doc) async {
            final info = await _extractAttachmentInfo(doc);
            final relatedRef = _extractRelatedResourceId(doc);
            final isDirect =
                relatedRef == null || relatedRef == event.resource.resourceId;
            if (!isDirect && resourceMap.containsKey(relatedRef)) {
              final source = resourceMap[relatedRef]!;
              return info.copyWith(
                sourceRecordTitle: source.title,
                sourceRecordType: source.fhirType,
              );
            }
            return info;
          }),
        );
        infos.sort((a, b) {
          final aIsDirect = a.sourceRecordTitle == null;
          final bIsDirect = b.sourceRecordTitle == null;
          if (aIsDirect && !bIsDirect) return -1;
          if (!aIsDirect && bIsDirect) return 1;
          return 0;
        });
        attachmentInfos = infos;
      } else {
        attachmentInfos = await Future.wait(
          relatedDocuments.map(_extractAttachmentInfo),
        );
      }

      emit(
        state.copyWith(
          attachments: attachmentInfos,
          resource: event.resource,
          status: const RecordAttachmentsStatus.success(),
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: RecordAttachmentsStatus.error(e)));
    }
  }

  Future<AttachmentInfo> _extractAttachmentInfo(
    IFhirResource documentReference,
  ) async {
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
        final rawPath = Uri.decodeComponent(url!.substring(7));
        final resolved = await _pathResolver.toAbsolute(rawPath);
        if (await File(resolved).exists()) {
          filePath = resolved;
        }
      }

      return AttachmentInfo(
        documentReference: documentReference,
        title: title,
        contentType: contentType,
        filePath: filePath,
      );
    } catch (e, s) {
      logger.w('Reading an attachment of a DocumentReference failed', e, s);
      return AttachmentInfo(
        documentReference: documentReference,
        title: documentReference.title,
      );
    }
  }

  Future<void> _onRecordAttachmentsFileAttached(
    RecordAttachmentsFileAttached event,
    Emitter<RecordAttachmentsState> emit,
  ) async {
    emit(state.copyWith(status: const RecordAttachmentsStatus.loading()));

    try {
      if (state.resource.fhirType == FhirType.DocumentReference) {
        emit(
          state.copyWith(
            status: RecordAttachmentsStatus.error(
              _strings.l10n.cannotAttachToDocumentReference,
            ),
          ),
        );
        return;
      }

      final subjectId = _extractSubjectId(state.resource);
      if (subjectId == null) {
        // A document without a patient would fall outside every patient's
        // records and create a wallet source with no name.
        logger.w(
          'Not attaching to a ${state.resource.fhirType.name} with no patient',
        );
        emit(
          state.copyWith(
            status: RecordAttachmentsStatus.error(
              StateError('The record has no patient'),
            ),
          ),
        );
        return;
      }
      final Directory appDirectory = await getApplicationDocumentsDirectory();
      final encounterId = _extractEncounterId(state.resource);
      final effectiveSourceId = await _getEffectiveSourceId(
        resourceSourceId: state.resource.sourceId,
        patientId: subjectId,
      );

      for (final file in event.files) {
        final String originalFileName = basename(file.path);
        final String newFilePath = join(
          appDirectory.path,
          await uniqueStoredFileName(appDirectory.path, originalFileName),
        );

        await file.copy(newFilePath);

        try {
          final documentReference = await _createDocumentReference(
            filePath: newFilePath,
            fileName: originalFileName,
            subjectId: subjectId,
            encounterId: encounterId,
            relatedResourceId: state.resource.resourceId,
            relatedResourceType: state.resource.fhirType.name,
          );

          await _saveDocumentReferenceToDatabase(
            documentReference: documentReference,
            sourceId: effectiveSourceId,
            title: originalFileName,
          );
        } catch (_) {
          await _deleteUnsavedCopy(newFilePath);
          rethrow;
        }
        debugPrint(
          '[ATTACH_BLOC] Saved DocumentReference to DB: title=$originalFileName, sourceId=$effectiveSourceId, subjectId=$subjectId, encounterId=$encounterId',
        );
      }

      debugPrint('[ATTACH_BLOC] All files saved, refreshing state');
      emit(state.copyWith(attachments: []));
      add(RecordAttachmentsInitialised(resource: state.resource));
    } catch (e, s) {
      logger.e('Attaching files to a record failed', e, s);
      emit(
        state.copyWith(
          status: RecordAttachmentsStatus.error(_strings.l10n.attachFileFailed),
        ),
      );
      // Files saved before the failure are attached; list them, so a retry
      // does not add them again.
      add(RecordAttachmentsInitialised(resource: state.resource));
    }
  }

  /// A file name for [originalName] in [directory] that no file has yet: the
  /// sanitised name with an 8-character unique suffix, so two attachments
  /// with the same name never replace each other. The original name stays
  /// the attachment's title.
  @visibleForTesting
  static Future<String> uniqueStoredFileName(
    String directory,
    String originalName,
  ) async {
    final base = originalName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final dot = base.lastIndexOf('.');
    final hasExtension =
        dot >= 0 && dot < base.length - 1 && base.length - dot <= 16;
    var stem = (hasExtension ? base.substring(0, dot) : base).replaceFirst(
      RegExp(r'^\.+'),
      '',
    );
    if (!stem.contains(RegExp('[A-Za-z0-9]'))) stem = 'file';
    if (stem.length > 100) stem = stem.substring(0, 100);
    final extension = hasExtension ? base.substring(dot) : '';
    while (true) {
      final name = '${stem}_${const Uuid().v4().substring(0, 8)}$extension';
      final type = await FileSystemEntity.type(
        join(directory, name),
        followLinks: false,
      );
      if (type == FileSystemEntityType.notFound) return name;
    }
  }

  /// Removes a copied file whose DocumentReference could not be saved, so no
  /// file is left that no record points to.
  Future<void> _deleteUnsavedCopy(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e, s) {
      logger.w('Removing an unsaved attachment copy failed', e, s);
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
            ),
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
            url: fhir_r4.FhirUrl(
              'file://${relativeFilePath.split('/').map(Uri.encodeComponent).join('/')}',
            ),
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
                          '$relatedResourceType/$relatedResourceId',
                        ),
                        display: fhir_r4.FhirString(
                          'Related $relatedResourceType',
                        ),
                      ),
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
        documentReference.subject!.reference!.valueString!,
      );
    }

    final dto = FhirResourceCompanion.insert(
      id: '${sourceId}_$resourceId',
      sourceId: drift.Value(sourceId),
      resourceId: drift.Value(resourceId),
      resourceType: const drift.Value('DocumentReference'),
      title: drift.Value(title),
      date: drift.Value(
        documentReference.date?.valueDateTime ?? DateTime.now(),
      ),
      resourceRaw: jsonEncode(resourceJson),
      encounterId: encounterId != null
          ? drift.Value(encounterId)
          : const drift.Value.absent(),
      subjectId: subjectId != null
          ? drift.Value(subjectId)
          : const drift.Value.absent(),
      deletedAt: const drift.Value(null),
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

  Future<void> _onRecordAttachmentsFileDeleted(
    RecordAttachmentsFileDeleted event,
    Emitter<RecordAttachmentsState> emit,
  ) async {
    emit(state.copyWith(status: const RecordAttachmentsStatus.loading()));

    try {
      // A soft delete, so the paired device drops the attachment too.
      await _recordsRepository.deleteResource(event.attachment.id);

      try {
        final content = event.attachment.rawResource['content'] as List?;
        if (content != null && content.isNotEmpty) {
          final attachment = content.first['attachment'];
          final url = attachment?['url'] as String?;
          if (url != null && url.startsWith('file://')) {
            final rawPath = Uri.decodeComponent(url.substring(7));
            final absolutePath = await _pathResolver.toAbsolute(rawPath);
            final file = File(absolutePath);
            if (await file.exists()) {
              await file.delete();
            }
          }
        }
      } catch (_) {
        // Best-effort cleanup; a leftover file is harmless.
      }

      add(RecordAttachmentsInitialised(resource: state.resource));
    } catch (e, s) {
      logger.e('Deleting an attachment failed', e, s);
      emit(
        state.copyWith(
          status: RecordAttachmentsStatus.error(
            _strings.l10n.attachmentDeleteFailed,
          ),
        ),
      );
    }
  }

  String? _extractSubjectId(IFhirResource resource) {
    if (resource.fhirType == FhirType.Patient) return resource.resourceId;
    final fromReference = FhirReferenceUtils.patientIdOf(resource.rawResource);
    if (fromReference != null) return fromReference;
    return resource.subjectId.isNotEmpty ? resource.subjectId : null;
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
      final walletSource = await _holderService.walletSourceForPatient(
        patientId,
      );
      return walletSource.id;
    }

    return resourceSourceId;
  }

  String? _extractRelatedResourceId(IFhirResource doc) {
    final related = doc.rawResource['context']?['related'] as List?;
    if (related == null || related.isEmpty) return null;
    final refStr = related.first['reference']?.toString();
    if (refStr == null) return null;
    return FhirReferenceUtils.extractReferenceId(refStr);
  }

  /// A random id; unlike a timestamp it stays unique for files attached in
  /// the same millisecond.
  String _generateId() => const Uuid().v4();
}
