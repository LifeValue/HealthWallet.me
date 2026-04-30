import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:fhir_r4/fhir_r4.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:intl/intl.dart';

part 'binary.freezed.dart';

@freezed
class Binary with _$Binary implements IFhirResource {
  const Binary._();

  const factory Binary({
    @Default('') String id,
    @Default('') String sourceId,
    @Default('') String resourceId,
    @Default('') String title,
    DateTime? date,
    @Default({}) Map<String, dynamic> rawResource,
    @Default('') String encounterId,
    @Default('') String subjectId,
    String? specialtyOverride,
    FhirCode? contentType,
    Reference? securityContext,
    FhirBase64Binary? data,
  }) = _Binary;

  @override
  FhirType get fhirType => FhirType.Binary;

  factory Binary.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirBinary = fhir_r4.Binary.fromJson(resourceJson);

    return Binary(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      specialtyOverride: data.specialtyOverride,
      contentType: fhirBinary.contentType,
      securityContext: fhirBinary.securityContext,
      data: fhirBinary.data,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
        id: id,
        sourceId: sourceId,
        resourceType: 'Binary',
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

    final type = contentType?.toString();
    if (type != null && type.isNotEmpty) return type;

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> get additionalInfo {
    List<RecordInfoLine> infoLines = [];

    final typeDisplay = contentType?.valueString;
    if (typeDisplay != null) {
      infoLines.add(RecordInfoLine(
        icon: Assets.icons.information,
        info: typeDisplay,
      ));
    }

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
      securityContext?.reference?.valueString,
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => '';
}
