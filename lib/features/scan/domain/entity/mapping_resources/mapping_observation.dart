import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/text_field_descriptor.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:uuid/uuid.dart';

part 'mapping_observation.freezed.dart';

@freezed
class MappingObservation with _$MappingObservation implements MappingResource {
  const MappingObservation._();

  const factory MappingObservation({
    @Default('') String id,
    @Default(MappedProperty()) MappedProperty observationName,
    @Default(MappedProperty()) MappedProperty value,
    @Default(MappedProperty()) MappedProperty unit,
    @Default(MappedProperty()) MappedProperty referenceRange,
  }) = _MappingObservation;

  factory MappingObservation.fromJson(Map<String, dynamic> json) {
    return MappingObservation(
      id: json["id"] ?? const Uuid().v4(),
      observationName: MappedProperty.fromJson(json['observationName']),
      value: MappedProperty.fromJson(json['value']),
      unit: MappedProperty.fromJson(json['unit']),
      referenceRange: MappedProperty.fromJson(json['referenceRange']),
    );
  }

  factory MappingObservation.empty() {
    return MappingObservation(
      id: const Uuid().v4(),
      observationName: MappedProperty.empty(),
      value: MappedProperty.empty(),
      unit: MappedProperty.empty(),
      referenceRange: MappedProperty.empty(),
    );
  }

  String get computedInterpretation {
    final numVal = double.tryParse(value.value);
    if (numVal == null || referenceRange.value.isEmpty) return '';

    final rangeStr = referenceRange.value.trim();

    final dashMatch = RegExp(r'([\d.]+)\s*[-–]\s*([\d.]+)').firstMatch(rangeStr);
    if (dashMatch != null) {
      final low = double.tryParse(dashMatch.group(1)!);
      final high = double.tryParse(dashMatch.group(2)!);
      if (low != null && high != null) {
        if (numVal < low) return 'Low';
        if (numVal > high) return 'High';
        return 'Normal';
      }
    }

    final ltMatch = RegExp(r'<\s*([\d.]+)').firstMatch(rangeStr);
    if (ltMatch != null) {
      final upper = double.tryParse(ltMatch.group(1)!);
      if (upper != null) return numVal > upper ? 'High' : 'Normal';
    }

    final gtMatch = RegExp(r'>\s*([\d.]+)').firstMatch(rangeStr);
    if (gtMatch != null) {
      final lower = double.tryParse(gtMatch.group(1)!);
      if (lower != null) return numVal < lower ? 'Low' : 'Normal';
    }

    final gteMatch = RegExp(r'>=\s*([\d.]+)').firstMatch(rangeStr);
    if (gteMatch != null) {
      final lower = double.tryParse(gteMatch.group(1)!);
      if (lower != null) return numVal < lower ? 'Low' : 'Normal';
    }

    return '';
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'resourceType': 'Observation',
        'observationName': observationName.toJson(),
        'value': value.toJson(),
        'unit': unit.toJson(),
        'referenceRange': referenceRange.toJson(),
      };

  static final _bpCombinedPattern = RegExp(r'^(\d+)\s*/\s*(\d+)$');

  static final _vitalLoincMap = <RegExp, (String, String)>{
    RegExp(r'heart\s*rate|pulse|^AV$|frecventa\s*cardiaca', caseSensitive: false):
        ('8867-4', 'Heart Rate'),
    RegExp(r'systolic|sistolica', caseSensitive: false):
        ('8480-6', 'Systolic Blood Pressure'),
    RegExp(r'diastolic|diastolica', caseSensitive: false):
        ('8462-4', 'Diastolic Blood Pressure'),
    RegExp(r'temperature|temperatura', caseSensitive: false):
        ('8310-5', 'Temperature'),
    RegExp(r'spo2|oxygen\s*saturation|^SO2$|saturatie', caseSensitive: false):
        ('2708-6', 'Blood Oxygen'),
    RegExp(r'weight|greutate', caseSensitive: false):
        ('29463-7', 'Weight'),
    RegExp(r'height|inaltime|talie', caseSensitive: false):
        ('8302-2', 'Height'),
    RegExp(r'\bbmi\b|body\s*mass\s*index', caseSensitive: false):
        ('39156-5', 'BMI'),
    RegExp(r'respiratory\s*rate|^FR$|frecventa\s*respiratorie', caseSensitive: false):
        ('9279-1', 'Respiratory Rate'),
    RegExp(r'blood\s*glucose|glicemie|^glucose$', caseSensitive: false):
        ('2339-0', 'Blood Glucose'),
  };

  static final _bpNamePattern = RegExp(
    r'^TA$|tensiune\s*arteriala|blood\s*pressure|presiune\s*arteriala',
    caseSensitive: false,
  );

  static (String, String)? _matchVitalLoinc(String name) {
    for (final entry in _vitalLoincMap.entries) {
      if (entry.key.hasMatch(name)) return entry.value;
    }
    return null;
  }

  static final _kgPattern = RegExp(r'\((\d+(?:\.\d+)?)\s*kg\)', caseSensitive: false);
  static final _cmPattern = RegExp(r'\((\d+(?:\.\d+)?)\s*cm\)', caseSensitive: false);
  static final _lbOzPattern = RegExp(
    r'(\d+(?:\.\d+)?)\s*(?:lb|lbs|Ib)\s*(?:(\d+(?:\.\d+)?)\s*oz)?',
    caseSensitive: false,
  );
  static final _ftInPattern = RegExp(
    r'''(\d+)['′]\s*(\d+(?:\.\d+)?)["″]?''',
  );

  static (double, String)? _cleanVitalValue(String raw, String unitField, String? loincCode) {
    if (raw.isEmpty) return null;

    final direct = double.tryParse(raw);
    if (direct != null) return (direct, unitField);

    if (loincCode == '29463-7') {
      final kgMatch = _kgPattern.firstMatch(raw);
      if (kgMatch != null) {
        final kg = double.tryParse(kgMatch.group(1)!);
        if (kg != null) return (kg, 'kg');
      }
      final lbMatch = _lbOzPattern.firstMatch(raw);
      if (lbMatch != null) {
        final lb = double.tryParse(lbMatch.group(1)!) ?? 0;
        final oz = double.tryParse(lbMatch.group(2) ?? '0') ?? 0;
        final kg = (lb * 0.453592 + oz * 0.0283495);
        return (double.parse(kg.toStringAsFixed(1)), 'kg');
      }
    }

    if (loincCode == '8302-2') {
      final cmMatch = _cmPattern.firstMatch(raw);
      if (cmMatch != null) {
        final cm = double.tryParse(cmMatch.group(1)!);
        if (cm != null) return (cm, 'cm');
      }
      final ftMatch = _ftInPattern.firstMatch(raw);
      if (ftMatch != null) {
        final ft = double.tryParse(ftMatch.group(1)!) ?? 0;
        final inches = double.tryParse(ftMatch.group(2) ?? '0') ?? 0;
        final cm = (ft * 30.48 + inches * 2.54);
        return (double.parse(cm.toStringAsFixed(1)), 'cm');
      }
    }

    if (loincCode == '8310-5') {
      final numMatch = RegExp(r'^(-?[\d.]+)').firstMatch(raw);
      if (numMatch != null) {
        final temp = double.tryParse(numMatch.group(1)!);
        if (temp != null) {
          if (raw.contains('°F') || raw.contains('F') || temp > 50) {
            return (temp, '°F');
          }
          return (temp, '°C');
        }
      }
    }

    final numMatch = RegExp(r'^(-?[\d.]+)\s*(.*)$').firstMatch(raw);
    if (numMatch != null) {
      final parsed = double.tryParse(numMatch.group(1)!);
      if (parsed != null) {
        final embedded = numMatch.group(2)!.trim();
        return (parsed, embedded.isNotEmpty ? embedded : unitField);
      }
    }

    return null;
  }

  @override
  IFhirResource toFhirResource({
    String? sourceId,
    String? encounterId,
    String? subjectId,
  }) {
    final name = observationName.value.trim();
    final bpMatch = _bpCombinedPattern.firstMatch(value.value.trim());
    if (_bpNamePattern.hasMatch(name) && bpMatch != null) {
      return _buildBpPanel(
        systolic: double.parse(bpMatch.group(1)!),
        diastolic: double.parse(bpMatch.group(2)!),
        sourceId: sourceId,
        encounterId: encounterId,
        subjectId: subjectId,
      );
    }

    List<fhir_r4.ObservationReferenceRange>? fhirReferenceRange;
    if (referenceRange.value.isNotEmpty) {
      fhirReferenceRange = [
        fhir_r4.ObservationReferenceRange(
          text: fhir_r4.FhirString(referenceRange.value),
        ),
      ];
    }

    List<fhir_r4.CodeableConcept>? fhirInterpretation;
    final interp = computedInterpretation;
    if (interp.isNotEmpty) {
      final code = switch (interp) {
        'High' => 'H',
        'Low' => 'L',
        _ => 'N',
      };
      final display = interp;
      fhirInterpretation = [
        fhir_r4.CodeableConcept(
          coding: [
            fhir_r4.Coding(
              system: fhir_r4.FhirUri(
                  'http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation'),
              code: fhir_r4.FhirCode(code),
              display: fhir_r4.FhirString(display),
            ),
          ],
          text: fhir_r4.FhirString(display),
        ),
      ];
    }

    final loincMatch = _matchVitalLoinc(name);
    final cleaned = _cleanVitalValue(value.value.trim(), unit.value.trim(), loincMatch?.$1);
    final fhir_r4.ValueXObservation? valueX;
    if (cleaned != null) {
      valueX = fhir_r4.Quantity(
        value: fhir_r4.FhirDecimal(cleaned.$1),
        unit: fhir_r4.FhirString(cleaned.$2),
      );
    } else if (value.value.trim().isNotEmpty) {
      valueX = fhir_r4.FhirString(value.value.trim());
    } else {
      valueX = null;
    }
    final fhir_r4.CodeableConcept codeableConcept;
    if (loincMatch != null) {
      codeableConcept = fhir_r4.CodeableConcept(
        coding: [
          fhir_r4.Coding(
            system: fhir_r4.FhirUri('http://loinc.org'),
            code: fhir_r4.FhirCode(loincMatch.$1),
            display: fhir_r4.FhirString(loincMatch.$2),
          ),
        ],
        text: fhir_r4.FhirString(loincMatch.$2),
      );
    } else {
      codeableConcept = fhir_r4.CodeableConcept(
        text: fhir_r4.FhirString(name),
      );
    }

    fhir_r4.Observation observation = fhir_r4.Observation(
      code: codeableConcept,
      valueX: valueX,
      status: fhir_r4.ObservationStatus.unknown,
      subject: fhir_r4.Reference(
          reference: fhir_r4.FhirString('Patient/$subjectId')),
      encounter: fhir_r4.Reference(
          reference: fhir_r4.FhirString('Encounter/$encounterId')),
      referenceRange: fhirReferenceRange,
      interpretation: fhirInterpretation,
    );

    Map<String, dynamic> rawResource = observation.toJson();

    return Observation(
      id: id,
      resourceId: id,
      title: loincMatch?.$2 ?? name,
      sourceId: sourceId ?? '',
      encounterId: encounterId ?? '',
      subjectId: subjectId ?? '',
      rawResource: rawResource,
      code: observation.code,
      valueX: observation.valueX,
    );
  }

  Observation _buildBpPanel({
    required double systolic,
    required double diastolic,
    String? sourceId,
    String? encounterId,
    String? subjectId,
  }) {
    final observation = fhir_r4.Observation(
      code: fhir_r4.CodeableConcept(
        coding: [
          fhir_r4.Coding(
            system: fhir_r4.FhirUri('http://loinc.org'),
            code: fhir_r4.FhirCode('85354-9'),
            display: fhir_r4.FhirString('Blood Pressure Panel'),
          ),
        ],
        text: fhir_r4.FhirString(observationName.value),
      ),
      status: fhir_r4.ObservationStatus.unknown,
      subject: fhir_r4.Reference(
          reference: fhir_r4.FhirString('Patient/$subjectId')),
      encounter: fhir_r4.Reference(
          reference: fhir_r4.FhirString('Encounter/$encounterId')),
      component: [
        fhir_r4.ObservationComponent(
          code: fhir_r4.CodeableConcept(
            coding: [
              fhir_r4.Coding(
                system: fhir_r4.FhirUri('http://loinc.org'),
                code: fhir_r4.FhirCode('8480-6'),
                display: fhir_r4.FhirString('Systolic Blood Pressure'),
              ),
            ],
          ),
          valueX: fhir_r4.Quantity(
            value: fhir_r4.FhirDecimal(systolic),
            unit: fhir_r4.FhirString('mmHg'),
          ),
        ),
        fhir_r4.ObservationComponent(
          code: fhir_r4.CodeableConcept(
            coding: [
              fhir_r4.Coding(
                system: fhir_r4.FhirUri('http://loinc.org'),
                code: fhir_r4.FhirCode('8462-4'),
                display: fhir_r4.FhirString('Diastolic Blood Pressure'),
              ),
            ],
          ),
          valueX: fhir_r4.Quantity(
            value: fhir_r4.FhirDecimal(diastolic),
            unit: fhir_r4.FhirString('mmHg'),
          ),
        ),
      ],
    );

    return Observation(
      id: id,
      resourceId: id,
      title: 'Blood Pressure Panel',
      sourceId: sourceId ?? '',
      encounterId: encounterId ?? '',
      subjectId: subjectId ?? '',
      rawResource: observation.toJson(),
      code: observation.code,
      component: observation.component,
    );
  }

  @override
  Map<String, TextFieldDescriptor> getFieldDescriptors() => {
        'observationName': TextFieldDescriptor(
          label: 'Observation name',
          value: observationName.value,
          confidenceLevel: observationName.confidenceLevel,
        ),
        'value': TextFieldDescriptor(
          label: 'Value',
          value: value.value,
          confidenceLevel: value.confidenceLevel,
        ),
        'unit': TextFieldDescriptor(
          label: 'Unit',
          value: unit.value,
          confidenceLevel: unit.confidenceLevel,
        ),
        'referenceRange': TextFieldDescriptor(
          label: 'Reference Range',
          value: referenceRange.value,
          confidenceLevel: referenceRange.confidenceLevel,
        ),
      };

  @override
  MappingResource copyWithMap(Map<String, dynamic> newValues) =>
      MappingObservation(
        id: id,
        observationName: MappedProperty(
          value: newValues['observationName'] ?? observationName.value,
          confidenceLevel: newValues['observationName'] != null
              ? 1
              : observationName.confidenceLevel,
        ),
        value: MappedProperty(
          value: newValues['value'] ?? value.value,
          confidenceLevel:
              newValues['value'] != null ? 1 : value.confidenceLevel,
        ),
        unit: MappedProperty(
          value: newValues['unit'] ?? unit.value,
          confidenceLevel: newValues['unit'] != null ? 1 : unit.confidenceLevel,
        ),
        referenceRange: MappedProperty(
          value: newValues['referenceRange'] ?? referenceRange.value,
          confidenceLevel: newValues['referenceRange'] != null
              ? 1
              : referenceRange.confidenceLevel,
        ),
      );

  @override
  String get label => 'Observation';

  @override
  MappingResource populateConfidence(String inputText) => copyWith(
        observationName: observationName.calculateConfidence(inputText),
        value: value.calculateConfidence(inputText),
        unit: unit.calculateConfidence(inputText),
        referenceRange: referenceRange.calculateConfidence(inputText),
      );

  @override
  bool get isValid =>
      observationName.isValid ||
      value.isValid ||
      unit.isValid ||
      referenceRange.isValid;
}
