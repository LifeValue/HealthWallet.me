import 'dart:convert';

import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:fhir_r4/fhir_r4.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/utils/file_size_formatter.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/records/domain/utils/resource_field_mapper.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/gen/assets.gen.dart';

part 'document_reference.freezed.dart';

@freezed
abstract class DocumentReference
    with _$DocumentReference
    implements IFhirResource {
  const DocumentReference._();

  factory DocumentReference({
    @Default('') String id,
    @Default('') String sourceId,
    @Default('') String resourceId,
    @Default('') String title,
    DateTime? date,
    @Default({}) Map<String, dynamic> rawResource,
    @Default('') String encounterId,
    @Default('') String subjectId,
    String? specialtyOverride,
    Narrative? text,
    Identifier? masterIdentifier,
    List<Identifier>? identifier,
    DocumentReferenceStatus? status,
    CompositionStatus? docStatus,
    CodeableConcept? type,
    List<CodeableConcept>? category,
    Reference? subject,
    FhirInstant? fhirDate,
    List<Reference>? author,
    Reference? authenticator,
    Reference? custodian,
    List<DocumentReferenceRelatesTo>? relatesTo,
    FhirString? description,
    List<CodeableConcept>? securityLabel,
    List<DocumentReferenceContent>? content,
    DocumentReferenceContext? context,
  }) = _DocumentReference;

  @override
  FhirType get fhirType => FhirType.DocumentReference;

  factory DocumentReference.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirDocumentReference = fhir_r4.DocumentReference.fromJson(
      resourceJson,
    );

    return DocumentReference(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      specialtyOverride: data.specialtyOverride,
      text: fhirDocumentReference.text,
      masterIdentifier: fhirDocumentReference.masterIdentifier,
      identifier: fhirDocumentReference.identifier,
      status: fhirDocumentReference.status,
      docStatus: fhirDocumentReference.docStatus,
      type: fhirDocumentReference.type,
      category: fhirDocumentReference.category,
      subject: fhirDocumentReference.subject,
      fhirDate: fhirDocumentReference.date,
      author: fhirDocumentReference.author,
      authenticator: fhirDocumentReference.authenticator,
      custodian: fhirDocumentReference.custodian,
      relatesTo: fhirDocumentReference.relatesTo,
      description: fhirDocumentReference.description,
      securityLabel: fhirDocumentReference.securityLabel,
      content: fhirDocumentReference.content,
      context: fhirDocumentReference.context,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
    id: id,
    sourceId: sourceId,
    resourceType: 'DocumentReference',
    resourceId: resourceId,
    title: title,
    date: date,
    resourceRaw: rawResource,
    encounterId: encounterId,
    subjectId: subjectId,
  );

  @override
  String get displayTitle {
    if (title.isNotEmpty) {
      return title;
    }

    final displayText = FhirFieldExtractor.extractCodeableConceptText(type);
    if (displayText != null) return displayText;

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> additionalInfo(AppLocalizations l10n) {
    final List<RecordInfoLine> infoLines = [];
    final documentDetailsStartIndex = infoLines.length;

    // Type (What kind of document - CRITICAL)
    final typeDisplay = FhirFieldExtractor.extractCodeableConceptText(type);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDocumentLine(
        typeDisplay,
        prefix: l10n.fieldType,
      ),
    );

    // Category
    if (category != null && category!.isNotEmpty) {
      final categoryDisplay = category!
          .map(FhirFieldExtractor.extractCodeableConceptText)
          .where((c) => c != null && c.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createCategoryLine(
          categoryDisplay.isNotEmpty ? categoryDisplay : null,
          prefix: l10n.fieldCategory,
        ),
      );
    }

    // Date (When document was created)
    final fhirDateDisplay = FhirFieldExtractor.formatFhirInstant(fhirDate);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(
        fhirDateDisplay,
        prefix: l10n.fieldCreated,
      ),
    );

    // Author
    if (author != null && author!.isNotEmpty) {
      final authorDisplay = author!
          .map(FhirFieldExtractor.extractReferenceDisplay)
          .where((a) => a != null && a.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createUserLine(
          authorDisplay.isNotEmpty ? authorDisplay : null,
          prefix: l10n.fieldAuthor,
        ),
      );
    }

    // Status (Current/Superseded/Entered in Error)
    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        statusText,
        prefix: l10n.fieldStatus,
      ),
    );

    // Add section header only if we added content
    if (infoLines.length > documentDetailsStartIndex) {
      infoLines.insert(
        documentDetailsStartIndex,
        ResourceFieldMapper.createSectionHeader(l10n.fieldDocumentDetails),
      );
    }

    final basicInfoStartIndex = infoLines.length;

    // Description (Summary of document content)
    final descriptionText = description?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(
        descriptionText,
        prefix: l10n.fieldDescription,
      ),
    );

    // Document Status (Preliminary/Final/Amended)
    final docStatusText = docStatus?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        docStatusText,
        prefix: l10n.fieldDocumentStatus,
      ),
    );

    // Authenticated By (Who verified/signed)
    final authenticatorDisplay = FhirFieldExtractor.extractReferenceDisplay(
      authenticator,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(
        authenticatorDisplay,
        prefix: l10n.fieldAuthenticatedBy,
      ),
    );

    // Facility (from context)
    if (context != null) {
      if (context!.facilityType != null) {
        final facilityType = FhirFieldExtractor.extractCodeableConceptText(
          context!.facilityType,
        );
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createLocationLine(
            facilityType,
            prefix: l10n.fieldFacilityType,
          ),
        );
      }

      // Practice Setting
      if (context!.practiceSetting != null) {
        final practiceSetting = FhirFieldExtractor.extractCodeableConceptText(
          context!.practiceSetting,
        );
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createLocationLine(
            practiceSetting,
            prefix: l10n.fieldPracticeSetting,
          ),
        );
      }

      // Period (Time period documented)
      if (context!.period != null) {
        final periodDisplay = FhirFieldExtractor.extractPeriodFormatted(
          context!.period,
          l10n: l10n,
        );
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createTimelineLine(
            periodDisplay,
            prefix: l10n.fieldServicePeriod,
          ),
        );
      }
    }

    // Add section header only if we added content
    if (infoLines.length > basicInfoStartIndex) {
      infoLines.insert(
        basicInfoStartIndex,
        ResourceFieldMapper.createSectionHeader(l10n.fieldBasicInformation),
      );
    }

    final additionalInfoStartIndex = infoLines.length;

    // Context Event (Encounter/Episode codes)
    if (context != null &&
        context!.event != null &&
        context!.event!.isNotEmpty) {
      final eventDisplay = context!.event!
          .map(FhirFieldExtractor.extractCodeableConceptText)
          .where((e) => e != null && e.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createNotesLine(
          eventDisplay.isNotEmpty ? eventDisplay : null,
          prefix: l10n.fieldContext,
        ),
      );
    }

    // Related Documents
    if (relatesTo != null && relatesTo!.isNotEmpty) {
      for (final relation in relatesTo!) {
        final relationCode = relation.code.valueString;
        final targetDisplay = FhirFieldExtractor.extractReferenceDisplay(
          relation.target,
        );

        final relationDisplay = relationCode != null && targetDisplay != null
            ? '$relationCode: $targetDisplay'
            : targetDisplay ?? relationCode;

        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createDocumentLine(
            relationDisplay,
            prefix: l10n.fieldRelatedDocument,
          ),
        );
      }
    }

    // Security Label
    if (securityLabel != null && securityLabel!.isNotEmpty) {
      final securityDisplay = securityLabel!
          .map(FhirFieldExtractor.extractCodeableConceptText)
          .where((s) => s != null && s.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createWarningLine(
          securityDisplay.isNotEmpty ? securityDisplay : null,
          prefix: l10n.fieldSecurityClassification,
        ),
      );
    }

    // Content/Format Details
    if (content != null && content!.isNotEmpty) {
      final firstContent = content!.first;

      // Format
      final formatDisplay = FhirFieldExtractor.extractCodeableConceptText(
        firstContent.format,
      );
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createDocumentLine(
          formatDisplay,
          prefix: l10n.fieldFormat,
        ),
      );

      // Content Type (MIME type)
      final contentType = firstContent.attachment.contentType?.toString();
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createAttachmentLine(
          contentType,
          prefix: l10n.fieldContentType,
        ),
      );

      // Size, in bytes in FHIR
      final sizeBytes = int.tryParse(
        firstContent.attachment.size?.valueString ?? '',
      );
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createAttachmentLine(
          sizeBytes == null ? null : FileSizeFormatter.format(sizeBytes),
          prefix: l10n.fieldSize,
        ),
      );

      // Language
      final language = firstContent.attachment.language?.toString();
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(
          language,
          prefix: l10n.fieldLanguage,
        ),
      );

      // Title
      final attachmentTitle = firstContent.attachment.title?.valueString;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createDocumentLine(
          attachmentTitle,
          prefix: l10n.fieldAttachmentTitle,
        ),
      );
    }

    // Custodian (Who maintains the document)
    final custodianDisplay = FhirFieldExtractor.extractReferenceDisplay(
      custodian,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(
        custodianDisplay,
        prefix: l10n.fieldCustodian,
      ),
    );

    // Master Identifier (Unique document ID)
    final masterIdDisplay = masterIdentifier?.value?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createIdentificationLine(
        masterIdDisplay,
        prefix: l10n.fieldDocumentId,
      ),
    );

    // Add section header only if we added content
    if (infoLines.length > additionalInfoStartIndex) {
      infoLines.insert(
        additionalInfoStartIndex,
        ResourceFieldMapper.createSectionHeader(
          l10n.fieldAdditionalInformation,
        ),
      );
    }

    // Date (fallback if not shown above)
    if (date != null && fhirDate == null) {
      infoLines.add(
        RecordInfoLine(
          icon: Assets.icons.calendar,
          info: FhirFieldExtractor.formatRecordDate(date!, l10n.localeName),
        ),
      );
    }

    return infoLines;
  }

  @override
  List<String?> get resourceReferences {
    return {
      subject?.reference?.valueString,
      authenticator?.reference?.valueString,
      custodian?.reference?.valueString,
      ...?author?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
