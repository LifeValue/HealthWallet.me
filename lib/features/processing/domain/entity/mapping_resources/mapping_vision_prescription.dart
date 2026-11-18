import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/utils/validator.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/extractor_provenance.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/entity/text_field_descriptor.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/records/domain/entity/vision_prescription/vision_prescription.dart';
import 'package:uuid/uuid.dart';

part 'mapping_vision_prescription.freezed.dart';

/// A glasses prescription read from a document, one lens specification per
/// eye. [existingId] is the stored row it is the same prescription as, when
/// the wallet already holds it; [completesExisting] says whether saving
/// fills fields that row leaves empty.
@freezed
abstract class MappingVisionPrescription
    with _$MappingVisionPrescription
    implements MappingResource {
  const MappingVisionPrescription._();

  const factory MappingVisionPrescription({
    @Default('') String id,

    /// The prescription's title as the document prints it; the record's
    /// title.
    @Default('') String title,
    @Default(VisionLensType.other) VisionLensType lensType,
    @Default(MappedProperty()) MappedProperty serial,
    @Default('') String serialSystem,
    @Default(MappedProperty()) MappedProperty dateWritten,
    @Default(MappedProperty()) MappedProperty followUpDate,

    /// `Practitioner/<id>`, or empty for the clinic placeholder.
    @Default('') String prescriberRef,
    @Default(MappedProperty()) MappedProperty prescriberName,

    /// The clinic named by the placeholder prescriber.
    @Default('') String clinicName,
    @Default(MappedProperty()) MappedProperty rightSphere,
    @Default(MappedProperty()) MappedProperty rightCylinder,
    @Default(MappedProperty()) MappedProperty rightAxis,
    @Default(MappedProperty()) MappedProperty rightAdd,
    @Default(MappedProperty()) MappedProperty rightPrism,
    @Default(MappedProperty()) MappedProperty rightBase,
    @Default(MappedProperty()) MappedProperty leftSphere,
    @Default(MappedProperty()) MappedProperty leftCylinder,
    @Default(MappedProperty()) MappedProperty leftAxis,
    @Default(MappedProperty()) MappedProperty leftAdd,
    @Default(MappedProperty()) MappedProperty leftPrism,
    @Default(MappedProperty()) MappedProperty leftBase,
    @Default('') String existingId,
    @Default(false) bool completesExisting,

    /// The extractor tag code (`<id>@<version>`), empty when typed by hand.
    @Default('') String provenance,
  }) = _MappingVisionPrescription;

  static const _fieldKeys = [
    'serial',
    'dateWritten',
    'followUpDate',
    'prescriberName',
    'rightSphere',
    'rightCylinder',
    'rightAxis',
    'rightAdd',
    'rightPrism',
    'rightBase',
    'leftSphere',
    'leftCylinder',
    'leftAxis',
    'leftAdd',
    'leftPrism',
    'leftBase',
  ];

  factory MappingVisionPrescription.fromJson(Map<String, dynamic> json) {
    MappedProperty read(String key) => MappedProperty.fromJson(json[key]);
    final dateWritten = read('dateWritten');
    final followUp = read('followUpDate');
    return MappingVisionPrescription(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: json['title'] as String? ?? '',
      lensType: VisionLensType.fromCode(json['lensType'] as String?),
      serial: read('serial'),
      serialSystem: json['serialSystem'] as String? ?? '',
      dateWritten: dateWritten.copyWith(
        value: MappingResource.normalizeDateValue(dateWritten.value),
      ),
      followUpDate: followUp.copyWith(
        value: MappingResource.normalizeDateValue(followUp.value),
      ),
      prescriberRef: json['prescriberRef'] as String? ?? '',
      prescriberName: read('prescriberName'),
      clinicName: json['clinicName'] as String? ?? '',
      rightSphere: read('rightSphere'),
      rightCylinder: read('rightCylinder'),
      rightAxis: read('rightAxis'),
      rightAdd: read('rightAdd'),
      rightPrism: read('rightPrism'),
      rightBase: read('rightBase'),
      leftSphere: read('leftSphere'),
      leftCylinder: read('leftCylinder'),
      leftAxis: read('leftAxis'),
      leftAdd: read('leftAdd'),
      leftPrism: read('leftPrism'),
      leftBase: read('leftBase'),
      existingId: json['existingId'] as String? ?? '',
      completesExisting: json['completesExisting'] as bool? ?? false,
      provenance: json['provenance'] as String? ?? '',
    );
  }

  factory MappingVisionPrescription.empty() => MappingVisionPrescription(
    id: const Uuid().v4(),
    serial: MappedProperty.empty(),
    dateWritten: MappedProperty.empty(),
    followUpDate: MappedProperty.empty(),
    prescriberName: MappedProperty.empty(),
  );

  Map<String, MappedProperty> get _fields => {
    'serial': serial,
    'dateWritten': dateWritten,
    'followUpDate': followUpDate,
    'prescriberName': prescriberName,
    'rightSphere': rightSphere,
    'rightCylinder': rightCylinder,
    'rightAxis': rightAxis,
    'rightAdd': rightAdd,
    'rightPrism': rightPrism,
    'rightBase': rightBase,
    'leftSphere': leftSphere,
    'leftCylinder': leftCylinder,
    'leftAxis': leftAxis,
    'leftAdd': leftAdd,
    'leftPrism': leftPrism,
    'leftBase': leftBase,
  };

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'resourceType': 'VisionPrescription',
    'title': title,
    'lensType': lensType.name,
    'serialSystem': serialSystem,
    'prescriberRef': prescriberRef,
    'clinicName': clinicName,
    'existingId': existingId,
    'completesExisting': completesExisting,
    'provenance': provenance,
    for (final MapEntry(:key, :value) in _fields.entries) key: value.toJson(),
  };

  /// The values of one eye, as FHIR numbers (null when not printed).
  ({double? sphere, double? cylinder, int? axis, double? add}) eyeValues({
    required bool right,
  }) => (
    sphere: _decimal(right ? rightSphere : leftSphere),
    cylinder: _decimal(right ? rightCylinder : leftCylinder),
    axis: int.tryParse((right ? rightAxis : leftAxis).value.trim()),
    add: _decimal(right ? rightAdd : leftAdd),
  );

  static double? _decimal(MappedProperty p) =>
      double.tryParse(p.value.trim().replaceAll(',', '.'));

  @override
  IFhirResource toFhirResource({
    String? sourceId,
    String? encounterId,
    String? subjectId,
    fhir_r4.FhirMeta? meta,
  }) {
    final written = dateWritten.value.isNotEmpty
        ? dateWritten.value
        : DateTime.now().toIso8601String().substring(0, 10);
    final prescription = fhir_r4.VisionPrescription(
      meta: ExtractorProvenance.merge(meta, provenance),
      identifier: serial.value.isEmpty
          ? null
          : [
              fhir_r4.Identifier(
                system: serialSystem.isEmpty
                    ? null
                    : fhir_r4.FhirUri(serialSystem),
                value: fhir_r4.FhirString(serial.value),
              ),
            ],
      extension_: followUpDate.value.isEmpty
          ? null
          : [
              fhir_r4.FhirExtension(
                url: fhir_r4.FhirString(VisionPrescriptionFhir.followUpUrl),
                valueDate: fhir_r4.FhirDate.fromString(followUpDate.value),
              ),
            ],
      status: fhir_r4.FinancialResourceStatusCodes.active,
      created: fhir_r4.FhirDateTime.fromString(written),
      dateWritten: fhir_r4.FhirDateTime.fromString(written),
      patient: fhir_r4.Reference(
        reference: fhir_r4.FhirString('Patient/$subjectId'),
      ),
      encounter: encounterId == null || encounterId.isEmpty
          ? null
          : fhir_r4.Reference(
              reference: fhir_r4.FhirString('Encounter/$encounterId'),
            ),
      prescriber: prescriberRef.isNotEmpty
          ? fhir_r4.Reference(
              reference: fhir_r4.FhirString(prescriberRef),
              display: prescriberName.value.isEmpty
                  ? null
                  : fhir_r4.FhirString(prescriberName.value),
            )
          : placeholderPrescriber(clinicName),
      lensSpecification: [_lens(right: true), _lens(right: false)],
    );

    return VisionPrescription.fromFhir(
      prescription,
      id: id,
      title: title,
      sourceId: sourceId ?? '',
      encounterId: encounterId ?? '',
      subjectId: subjectId ?? '',
    );
  }

  /// The display-only reference to the clinic a prescription without an
  /// examiner gets, since FHIR requires a prescriber.
  static fhir_r4.Reference placeholderPrescriber(String clinicName) =>
      fhir_r4.Reference(
        type: fhir_r4.FhirUri('Organization'),
        display: fhir_r4.FhirString(clinicName.isEmpty ? '-' : clinicName),
        extension_: [
          fhir_r4.FhirExtension(
            url: fhir_r4.FhirString(VisionPrescriptionFhir.placeholderUrl),
            valueBoolean: fhir_r4.FhirBoolean(true),
          ),
        ],
      );

  fhir_r4.VisionPrescriptionLensSpecification _lens({required bool right}) {
    final values = eyeValues(right: right);
    final prism = _decimal(right ? rightPrism : leftPrism);
    final base = (right ? rightBase : leftBase).value.trim().toLowerCase();
    return fhir_r4.VisionPrescriptionLensSpecification(
      product: fhir_r4.CodeableConcept(
        text: title.isEmpty ? null : fhir_r4.FhirString(title),
        coding: [
          fhir_r4.Coding(
            system: fhir_r4.FhirUri(VisionPrescriptionFhir.productSystem),
            code: fhir_r4.FhirCode('lens'),
          ),
          fhir_r4.Coding(
            system: fhir_r4.FhirUri(VisionLensType.system),
            code: fhir_r4.FhirCode(lensType.name),
            display: fhir_r4.FhirString(lensType.display),
          ),
        ],
      ),
      eye: right ? fhir_r4.VisionEyes.right : fhir_r4.VisionEyes.left,
      sphere: values.sphere == null ? null : fhir_r4.FhirDecimal(values.sphere),
      cylinder: values.cylinder == null
          ? null
          : fhir_r4.FhirDecimal(values.cylinder),
      axis: values.axis == null ? null : fhir_r4.FhirInteger(values.axis),
      add: values.add == null ? null : fhir_r4.FhirDecimal(values.add),
      prism: prism == null || !_bases.contains(base)
          ? null
          : [
              fhir_r4.VisionPrescriptionPrism(
                amount: fhir_r4.FhirDecimal(prism),
                base: fhir_r4.VisionBase(base),
              ),
            ],
    );
  }

  static const _bases = {'up', 'down', 'in', 'out'};

  /// The prescription's own fields; the lens values are edited in the
  /// per-eye grid of [lensRows].
  @override
  Map<String, TextFieldDescriptor> getFieldDescriptors(AppLocalizations l10n) =>
      {
        'dateWritten': TextFieldDescriptor(
          label: l10n.fieldDateWritten,
          value: dateWritten.value,
          confidenceLevel: dateWritten.confidenceLevel,
          fieldType: FieldType.date,
          validators: [dateValidator],
        ),
        'followUpDate': TextFieldDescriptor(
          label: l10n.fieldRecommendedFollowUp,
          value: followUpDate.value,
          confidenceLevel: followUpDate.confidenceLevel,
          fieldType: FieldType.date,
          validators: [dateValidator],
        ),
        'prescriberName': TextFieldDescriptor(
          label: l10n.fieldPrescribedBy,
          value: prescriberName.value,
          confidenceLevel: prescriberName.confidenceLevel,
        ),
      };

  /// The review's lens grid: one row per value, the right eye's field then
  /// the left's. The reading add is offered on multifocal lenses or when
  /// printed, the prism only when printed.
  List<VisionLensRow> lensRows(AppLocalizations l10n) {
    VisionLensRow row(
      String value,
      String label, {
      required FieldValidationError? Function(String?)? validator,
      TextInputType? keyboardType,
    }) {
      TextFieldDescriptor field(String key) => TextFieldDescriptor(
        label: label,
        value: _fields[key]!.value,
        confidenceLevel: _fields[key]!.confidenceLevel,
        validators: validator == null ? null : [validator],
        keyboardType: keyboardType,
      );
      return (
        rightKey: 'right$value',
        right: field('right$value'),
        leftKey: 'left$value',
        left: field('left$value'),
      );
    }

    bool printed(String value) =>
        _fields['right$value']!.value.isNotEmpty ||
        _fields['left$value']!.value.isNotEmpty;
    const dioptres = TextInputType.numberWithOptions(
      signed: true,
      decimal: true,
    );
    return [
      row(
        'Sphere',
        l10n.visionSphere,
        validator: dioptreValidator,
        keyboardType: dioptres,
      ),
      row(
        'Cylinder',
        l10n.visionCylinder,
        validator: dioptreValidator,
        keyboardType: dioptres,
      ),
      row(
        'Axis',
        l10n.visionAxis,
        validator: axisValidator,
        keyboardType: TextInputType.number,
      ),
      if (lensType == VisionLensType.multifocal || printed('Add'))
        row(
          'Add',
          l10n.visionAdd,
          validator: dioptreValidator,
          keyboardType: dioptres,
        ),
      if (printed('Prism') || printed('Base')) ...[
        row(
          'Prism',
          l10n.visionPrism,
          validator: dioptreValidator,
          keyboardType: dioptres,
        ),
        row('Base', l10n.visionBase, validator: null),
      ],
    ];
  }

  @override
  MappingResource copyWithMap(Map<String, dynamic> newValues) {
    MappedProperty edit(String key, MappedProperty current) =>
        newValues[key] == null
        ? current
        : MappedProperty(value: newValues[key] as String, confidenceLevel: 1);
    return copyWith(
      dateWritten: edit('dateWritten', dateWritten),
      followUpDate: edit('followUpDate', followUpDate),
      prescriberName: edit('prescriberName', prescriberName),
      rightSphere: edit('rightSphere', rightSphere),
      rightCylinder: edit('rightCylinder', rightCylinder),
      rightAxis: edit('rightAxis', rightAxis),
      rightAdd: edit('rightAdd', rightAdd),
      rightPrism: edit('rightPrism', rightPrism),
      rightBase: edit('rightBase', rightBase),
      leftSphere: edit('leftSphere', leftSphere),
      leftCylinder: edit('leftCylinder', leftCylinder),
      leftAxis: edit('leftAxis', leftAxis),
      leftAdd: edit('leftAdd', leftAdd),
      leftPrism: edit('leftPrism', leftPrism),
      leftBase: edit('leftBase', leftBase),
    );
  }

  @override
  String localizedLabel(AppLocalizations l10n) =>
      '${l10n.fhirTypeVisionPrescription} · ${lensType.localizedName(l10n)}';

  @override
  MappingResource populateConfidence(String inputText) => copyWith(
    serial: serial.calculateConfidence(inputText),
    dateWritten: dateWritten.calculateDateConfidence(inputText),
    followUpDate: followUpDate.calculateDateConfidence(inputText),
    prescriberName: prescriberName.calculateConfidence(inputText),
  );

  @override
  bool get isValid => _fieldKeys.any((key) => _fields[key]!.value.isNotEmpty);
}

/// One value of a prescription's lens grid: the field of each eye, under
/// the property key the review edits it by.
typedef VisionLensRow = ({
  String rightKey,
  TextFieldDescriptor right,
  String leftKey,
  TextFieldDescriptor left,
});
