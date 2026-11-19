import 'dart:convert';

import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:fhir_r4/fhir_r4.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_code_labels.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/records/domain/utils/resource_field_mapper.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:intl/intl.dart';

part 'vision_prescription.freezed.dart';

/// The kind of glasses a prescription is for, coded in [system].
enum VisionLensType {
  multifocal('Multifocal glasses'),
  distance('Distance glasses'),
  reading('Reading glasses'),
  other('Glasses');

  const VisionLensType(this.display);

  /// The English display of the code in [system].
  final String display;

  static const system = 'http://healthwallet.me/lens-type';

  static VisionLensType fromCode(String? code) =>
      values.where((t) => t.name == code).firstOrNull ?? other;

  String localizedName(AppLocalizations l10n) => switch (this) {
    multifocal => l10n.lensTypeMultifocal,
    distance => l10n.lensTypeDistance,
    reading => l10n.lensTypeReading,
    other => l10n.lensTypeOther,
  };
}

/// FHIR names the app uses on a VisionPrescription.
abstract final class VisionPrescriptionFhir {
  static const productSystem =
      'http://terminology.hl7.org/CodeSystem/ex-visionprescriptionproduct';
  static const followUpUrl =
      'http://healthwallet.me/fhir/StructureDefinition/recommended-follow-up';

  /// Marks a prescriber reference written because the document names no
  /// examiner; completing the record may replace it.
  static const placeholderUrl =
      'http://healthwallet.me/fhir/StructureDefinition/placeholder';
}

/// One eye of a prescription as printed: a row of the per-eye table.
class VisionEyeRow {
  const VisionEyeRow({
    required this.right,
    this.sphere,
    this.cylinder,
    this.axis,
    this.add,
    this.prism,
  });

  final bool right;
  final String? sphere;
  final String? cylinder;
  final String? axis;
  final String? add;

  /// Amount and base, e.g. "0.5 up".
  final String? prism;
}

@freezed
abstract class VisionPrescription
    with _$VisionPrescription
    implements IFhirResource {
  const VisionPrescription._();

  const factory VisionPrescription({
    @Default('') String id,
    @Default('') String sourceId,
    @Default('') String resourceId,
    @Default('') String title,
    DateTime? date,
    @Default({}) Map<String, dynamic> rawResource,
    @Default('') String encounterId,
    @Default('') String subjectId,
    String? specialtyOverride,
    List<Identifier>? identifier,
    FinancialResourceStatusCodes? status,
    FhirDateTime? created,
    FhirDateTime? dateWritten,
    Reference? patient,
    Reference? encounter,
    Reference? prescriber,
    List<VisionPrescriptionLensSpecification>? lensSpecification,
    List<FhirExtension>? extension_,
  }) = _VisionPrescription;

  @override
  FhirType get fhirType => FhirType.VisionPrescription;

  /// Throws when the stored JSON lacks a field FHIR requires;
  /// [IFhirResource.fromLocalDto] then shows the row as a generic resource.
  factory VisionPrescription.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw) as Map<String, dynamic>;
    return VisionPrescription.fromFhir(
      fhir_r4.VisionPrescription.fromJson(resourceJson),
      id: data.id,
      resourceId: data.resourceId,
      sourceId: data.sourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      specialtyOverride: data.specialtyOverride,
      rawResource: resourceJson,
    );
  }

  factory VisionPrescription.fromFhir(
    fhir_r4.VisionPrescription fhir, {
    required String id,
    String? resourceId,
    String sourceId = '',
    String title = '',
    DateTime? date,
    String encounterId = '',
    String subjectId = '',
    String? specialtyOverride,
    Map<String, dynamic>? rawResource,
  }) => VisionPrescription(
    id: id,
    sourceId: sourceId,
    resourceId: resourceId ?? id,
    title: title,
    date:
        date ??
        DateTime.tryParse(
          fhir.dateWritten.valueString ?? fhir.created.valueString ?? '',
        ),
    rawResource: rawResource ?? fhir.toJson(),
    encounterId: encounterId,
    subjectId: subjectId,
    specialtyOverride: specialtyOverride,
    identifier: fhir.identifier,
    status: fhir.status,
    created: fhir.created,
    dateWritten: fhir.dateWritten,
    patient: fhir.patient,
    encounter: fhir.encounter,
    prescriber: fhir.prescriber,
    lensSpecification: fhir.lensSpecification,
    extension_: fhir.extension_,
  );

  @override
  FhirResourceDto toDto() => FhirResourceDto(
    id: id,
    sourceId: sourceId,
    resourceType: 'VisionPrescription',
    resourceId: resourceId,
    title: title,
    date: date,
    resourceRaw: rawResource,
    encounterId: encounterId,
    subjectId: subjectId,
  );

  /// The lens type of the first lens that names one.
  VisionLensType get lensType {
    for (final lens in lensSpecification ?? const []) {
      for (final coding in lens.product.coding ?? const <Coding>[]) {
        if (coding.system?.valueString == VisionLensType.system) {
          return VisionLensType.fromCode(coding.code?.valueString);
        }
      }
    }
    return VisionLensType.other;
  }

  String? get followUpDate => extension_
      ?.where((e) => e.url.valueString == VisionPrescriptionFhir.followUpUrl)
      .map((e) => e.valueX)
      .whereType<FhirDate>()
      .firstOrNull
      ?.valueString;

  /// The right eye, then the left, as printed.
  List<VisionEyeRow> get eyeRows {
    String? number(FhirDecimal? value, {bool signed = false}) {
      final v = value?.valueDouble;
      if (v == null) return null;
      final text = v.toStringAsFixed(2);
      return signed && v > 0 ? '+$text' : text;
    }

    VisionEyeRow? row(bool right) {
      final lens = lensSpecification
          ?.where(
            (l) => l.eye.valueString == (right ? 'right' : 'left'),
          )
          .firstOrNull;
      if (lens == null) return null;
      final prism = lens.prism
          ?.map(
            (p) =>
                '${p.amount.valueDouble?.toStringAsFixed(2) ?? ''} '
                        '${p.base.valueString ?? ''}'
                    .trim(),
          )
          .join(', ');
      return VisionEyeRow(
        right: right,
        sphere: number(lens.sphere, signed: true),
        cylinder: number(lens.cylinder, signed: true),
        axis: lens.axis?.valueString,
        add: number(lens.add, signed: true),
        prism: prism == null || prism.isEmpty ? null : prism,
      );
    }

    return [?row(true), ?row(false)];
  }

  /// The title the document printed, else the lens type in the app's
  /// language (`Intl.defaultLocale`, which the app keeps on it).
  @override
  String get displayTitle {
    if (title.isNotEmpty) return title;
    final printed = lensSpecification
        ?.map((l) => l.product.text?.valueString)
        .whereType<String>()
        .where((t) => t.isNotEmpty)
        .firstOrNull;
    if (printed != null) return printed;
    final type = lensType;
    if (type == VisionLensType.other) return fhirType.display;
    return type.localizedName(_appL10n());
  }

  static AppLocalizations _appL10n() {
    final language = (Intl.defaultLocale ?? 'en').split(RegExp('[_-]')).first;
    final locale = Locale(language);
    return AppLocalizations.delegate.isSupported(locale)
        ? lookupAppLocalizations(locale)
        : lookupAppLocalizations(const Locale('en'));
  }

  @override
  List<RecordInfoLine> additionalInfo(AppLocalizations l10n) {
    final lines = <RecordInfoLine>[
      ResourceFieldMapper.createSectionHeader(l10n.fieldBasicInformation),
    ];
    ResourceFieldMapper.addIfNotNull(
      lines,
      ResourceFieldMapper.createCategoryLine(
        lensType.localizedName(l10n),
        prefix: l10n.fieldLensType,
      ),
    );
    ResourceFieldMapper.addIfNotNull(
      lines,
      FhirCodeLabels.statusLine(
        status?.valueString,
        l10n,
        prefix: l10n.fieldStatus,
      ),
    );
    ResourceFieldMapper.addIfNotNull(
      lines,
      ResourceFieldMapper.createDateLine(
        FhirFieldExtractor.formatFhirDateTime(dateWritten),
        prefix: l10n.fieldDateWritten,
      ),
    );
    ResourceFieldMapper.addIfNotNull(
      lines,
      ResourceFieldMapper.createUserLine(
        FhirFieldExtractor.extractReferenceDisplay(prescriber),
        prefix: l10n.fieldPrescribedBy,
      ),
    );
    ResourceFieldMapper.addIfNotNull(
      lines,
      ResourceFieldMapper.createTimelineLine(
        FhirFieldExtractor.formatDateTimeString(followUpDate),
        prefix: l10n.fieldRecommendedFollowUp,
      ),
    );
    ResourceFieldMapper.addIfNotNull(
      lines,
      ResourceFieldMapper.createIdentificationLine(
        identifier
            ?.map((i) => i.value?.valueString)
            .whereType<String>()
            .join(', '),
        prefix: l10n.labelSerialNumber,
      ),
    );
    return lines;
  }

  @override
  List<String?> get resourceReferences => {
    patient?.reference?.valueString,
    encounter?.reference?.valueString,
    prescriber?.reference?.valueString,
  }.where((reference) => reference != null).toList();

  @override
  String get statusDisplay => status?.valueString ?? '';
}
