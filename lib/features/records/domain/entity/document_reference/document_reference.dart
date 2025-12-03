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

    // Status
    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(statusText, prefix: 'Status'),
    );

    // Document Status
    final docStatusText = docStatus?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(docStatusText,
          prefix: 'Document Status'),
    );

    // Type
    final typeDisplay = FhirFieldExtractor.extractCodeableConceptText(type);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDocumentLine(typeDisplay, prefix: 'Type'),
    );

    // Category
    final categoryDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(category);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(categoryDisplay,
          prefix: 'Category'),
    );

    // Author
    final authorDisplay =
        FhirFieldExtractor.extractMultipleReferenceDisplays(author);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(authorDisplay, prefix: 'Author'),
    );

    // Authenticator
    final authenticatorDisplay =
        FhirFieldExtractor.extractReferenceDisplay(authenticator);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(authenticatorDisplay,
          prefix: 'Authenticator'),
    );

    // Custodian
    final custodianDisplay =
        FhirFieldExtractor.extractReferenceDisplay(custodian);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(custodianDisplay,
          prefix: 'Custodian'),
    );

    // Description
    final descriptionText = description?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(descriptionText,
          prefix: 'Description'),
    );

    // Content Format
    if (content != null && content!.isNotEmpty) {
      final contentType = content!.first.attachment.contentType?.toString();
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createAttachmentLine(contentType,
            prefix: 'Format'),
      );
    }

    // Date
    if (date != null) {
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
