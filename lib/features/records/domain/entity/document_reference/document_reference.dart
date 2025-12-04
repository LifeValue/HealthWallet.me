import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:fhir_r4/fhir_r4.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/records/domain/utils/resource_field_mapper.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:intl/intl.dart';

part 'document_reference.freezed.dart';

@freezed
class DocumentReference with _$DocumentReference implements IFhirResource {
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
    final fhirDocumentReference =
        fhir_r4.DocumentReference.fromJson(resourceJson);

    return DocumentReference(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
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
  List<RecordInfoLine> get additionalInfo {
    List<RecordInfoLine> infoLines = [];
    final documentDetailsStartIndex = infoLines.length;

    // Type (What kind of document - CRITICAL)
    final typeDisplay = FhirFieldExtractor.extractCodeableConceptText(type);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDocumentLine(typeDisplay, prefix: 'Type'),
    );

    // Category
    if (category != null && category!.isNotEmpty) {
      final categoryDisplay = category!
          .map((c) => FhirFieldExtractor.extractCodeableConceptText(c))
          .where((c) => c != null && c.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createCategoryLine(
            categoryDisplay.isNotEmpty ? categoryDisplay : null,
            prefix: 'Category'),
      );
    }

    // Date (When document was created)
    final fhirDateDisplay = fhirDate?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(fhirDateDisplay, prefix: 'Created'),
    );

    // Author
    if (author != null && author!.isNotEmpty) {
      final authorDisplay = author!
          .map((a) => FhirFieldExtractor.extractReferenceDisplay(a))
          .where((a) => a != null && a.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createUserLine(
            authorDisplay.isNotEmpty ? authorDisplay : null,
            prefix: 'Author'),
      );
    }

    // Status (Current/Superseded/Entered in Error)
    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(statusText, prefix: 'Status'),
    );

    // Add section header only if we added content
    if (infoLines.length > documentDetailsStartIndex) {
      infoLines.insert(documentDetailsStartIndex,
        ResourceFieldMapper.createSectionHeader('Document Details'));
    }

    final basicInfoStartIndex = infoLines.length;

    // Description (Summary of document content)
    final descriptionText = description?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(descriptionText,
          prefix: 'Description'),
    );

    // Document Status (Preliminary/Final/Amended)
    final docStatusText = docStatus?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(docStatusText,
          prefix: 'Document Status'),
    );

    // Authenticated By (Who verified/signed)
    final authenticatorDisplay =
        FhirFieldExtractor.extractReferenceDisplay(authenticator);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(authenticatorDisplay,
          prefix: 'Authenticated By'),
    );

    // Facility (from context)
    if (context != null) {
      if (context!.facilityType != null) {
        final facilityType = FhirFieldExtractor.extractCodeableConceptText(
            context!.facilityType);
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createLocationLine(facilityType,
              prefix: 'Facility Type'),
        );
      }

      // Practice Setting
      if (context!.practiceSetting != null) {
        final practiceSetting = FhirFieldExtractor.extractCodeableConceptText(
            context!.practiceSetting);
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createLocationLine(practiceSetting,
              prefix: 'Practice Setting'),
        );
      }

      // Period (Time period documented)
      if (context!.period != null) {
        final periodDisplay = FhirFieldExtractor.extractPeriodFormatted(context!.period);
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createTimelineLine(periodDisplay,
              prefix: 'Service Period'),
        );
      }
    }

    // Add section header only if we added content
    if (infoLines.length > basicInfoStartIndex) {
      infoLines.insert(basicInfoStartIndex,
        ResourceFieldMapper.createSectionHeader('Basic Information'));
    }

    final additionalInfoStartIndex = infoLines.length;

    // Context Event (Encounter/Episode codes)
    if (context != null && context!.event != null && context!.event!.isNotEmpty) {
      final eventDisplay = context!.event!
          .map((e) => FhirFieldExtractor.extractCodeableConceptText(e))
          .where((e) => e != null && e.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createNotesLine(
            eventDisplay.isNotEmpty ? eventDisplay : null,
            prefix: 'Context'),
      );
    }

    // Related Documents
    if (relatesTo != null && relatesTo!.isNotEmpty) {
      for (final relation in relatesTo!) {
        final relationCode = relation.code?.valueString;
        final targetDisplay = FhirFieldExtractor.extractReferenceDisplay(
            relation.target);
        
        final relationDisplay = relationCode != null && targetDisplay != null
            ? '$relationCode: $targetDisplay'
            : targetDisplay ?? relationCode;
        
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createDocumentLine(relationDisplay,
              prefix: 'Related Document'),
        );
      }
    }

    // Security Label
    if (securityLabel != null && securityLabel!.isNotEmpty) {
      final securityDisplay = securityLabel!
          .map((s) => FhirFieldExtractor.extractCodeableConceptText(s))
          .where((s) => s != null && s.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createWarningLine(
            securityDisplay.isNotEmpty ? securityDisplay : null,
            prefix: 'Security Classification'),
      );
    }

    // Content/Format Details
    if (content != null && content!.isNotEmpty) {
      final firstContent = content!.first;
      
      // Format
      final formatDisplay = FhirFieldExtractor.extractCodeableConceptText(firstContent.format);
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createDocumentLine(formatDisplay, prefix: 'Format'),
      );

      // Content Type (MIME type)
      final contentType = firstContent.attachment.contentType?.toString();
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createAttachmentLine(contentType,
            prefix: 'Content Type'),
      );

      // Size
      if (firstContent.attachment.size != null) {
        final sizeValue = firstContent.attachment.size!.valueString;
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createAttachmentLine(
              sizeValue != null ? '$sizeValue bytes' : null,
              prefix: 'Size'),
        );
      }

      // Language
      final language = firstContent.attachment.language?.toString();
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(language, prefix: 'Language'),
      );

      // Title
      final attachmentTitle = firstContent.attachment.title?.valueString;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createDocumentLine(attachmentTitle,
            prefix: 'Attachment Title'),
      );
    }

    // Custodian (Who maintains the document)
    final custodianDisplay =
        FhirFieldExtractor.extractReferenceDisplay(custodian);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(custodianDisplay,
          prefix: 'Custodian'),
    );

    // Master Identifier (Unique document ID)
    final masterIdDisplay = masterIdentifier?.value?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createIdentificationLine(masterIdDisplay,
          prefix: 'Document ID'),
    );

    // Add section header only if we added content
    if (infoLines.length > additionalInfoStartIndex) {
      infoLines.insert(additionalInfoStartIndex,
        ResourceFieldMapper.createSectionHeader('Additional Information'));
    }

    // Date (fallback if not shown above)
    if (date != null && fhirDate == null) {
      infoLines.add(RecordInfoLine(
        icon: Assets.icons.calendar,
        info: DateFormat.yMMMMd().format(date!),
      ));
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
