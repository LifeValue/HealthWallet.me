import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/utils/validator.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/text_field_descriptor.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

part 'mapping_patient.freezed.dart';

@freezed
class MappingPatient with _$MappingPatient implements MappingResource {
  const MappingPatient._();

  const factory MappingPatient({
    @Default('') String id,
    @Default(MappedProperty()) MappedProperty familyName,
    @Default(MappedProperty()) MappedProperty givenName,
    @Default(MappedProperty()) MappedProperty dateOfBirth,
    @Default(MappedProperty()) MappedProperty gender,
    @Default(MappedProperty()) MappedProperty patientMRN,
    @Default('MRN') String identifierLabel,
  }) = _MappingPatient;

  factory MappingPatient.fromJson(Map<String, dynamic> json) {
    final rawLabel = (json['identifierLabel'] as String?)?.trim() ?? '';
    final rawDob = MappedProperty.fromJson(json['dateOfBirth']);
    return MappingPatient(
      id: json["id"] ?? const Uuid().v4(),
      familyName: MappedProperty.fromJson(json['familyName']),
      givenName: MappedProperty.fromJson(json['givenName']),
      dateOfBirth: rawDob.copyWith(
        value: MappingResource.normalizeDateValue(rawDob.value),
      ),
      gender: MappedProperty.fromJson(json['gender']),
      patientMRN:
          MappedProperty.fromJson(json['patientMRN'] ?? json['patientId']),
      identifierLabel: rawLabel.isEmpty ? 'MRN' : rawLabel,
    );
  }

  factory MappingPatient.empty() {
    return MappingPatient(
      id: const Uuid().v4(),
      familyName: MappedProperty.empty(),
      givenName: MappedProperty.empty(),
      dateOfBirth: MappedProperty.empty(),
      gender: MappedProperty.empty(),
      patientMRN: MappedProperty.empty(),
    );
  }

  factory MappingPatient.fromFhirResource(Patient patient) {
    return MappingPatient(
      id: patient.id,
      familyName: MappedProperty(
        value: FhirFieldExtractor.extractPatientFamily(patient),
        confidenceLevel: 1,
      ),
      givenName: MappedProperty(
        value: FhirFieldExtractor.extractPatientGiven(patient),
        confidenceLevel: 1,
      ),
      dateOfBirth: MappedProperty(
        value: DateFormat('yyyy-MM-dd').format(
          FhirFieldExtractor.extractPatientBirthDate(patient) ?? DateTime.now(),
        ),
        confidenceLevel: 1,
      ),
      gender: MappedProperty(
        value: FhirFieldExtractor.extractPatientGender(patient),
        confidenceLevel: 1,
      ),
      patientMRN: MappedProperty(
        value: FhirFieldExtractor.extractPatientMRN(patient),
        confidenceLevel: 1,
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'resourceType': 'Patient',
        'familyName': familyName.toJson(),
        'givenName': givenName.toJson(),
        'dateOfBirth': dateOfBirth.toJson(),
        'gender': gender.toJson(),
        'patientMRN': patientMRN.toJson(),
        'identifierLabel': identifierLabel,
      };

  @override
  IFhirResource toFhirResource({
    String? sourceId,
    String? encounterId,
    String? subjectId,
  }) {
    final identifierCoding = _mapLabelToFhirCode(identifierLabel);

    fhir_r4.Patient patient = fhir_r4.Patient(
      name: [
        fhir_r4.HumanName(
          family: fhir_r4.FhirString(familyName.value),
          given: [fhir_r4.FhirString(givenName.value)],
        )
      ],
      birthDate: fhir_r4.FhirDate.fromString(dateOfBirth.value),
      gender: fhir_r4.AdministrativeGender(gender.value),
      identifier: [
        if (patientMRN.value.isNotEmpty)
          fhir_r4.Identifier(
            value: fhir_r4.FhirString(patientMRN.value),
            type: fhir_r4.CodeableConcept(
              coding: identifierCoding != null
                  ? [
                      fhir_r4.Coding(
                        system: fhir_r4.FhirUri(
                            'http://terminology.hl7.org/CodeSystem/v2-0203'),
                        code: fhir_r4.FhirCode(identifierCoding),
                        display: fhir_r4.FhirString(identifierLabel),
                      )
                    ]
                  : null,
              text: fhir_r4.FhirString(identifierLabel),
            ),
          )
      ],
    );

    final rawResource = patient.toJson();

    return Patient(
      id: id,
      resourceId: id,
      title: "${givenName.value} ${familyName.value}",
      sourceId: sourceId ?? '',
      encounterId: encounterId ?? '',
      subjectId: subjectId ?? '',
      rawResource: rawResource,
      name: patient.name,
      birthDate: patient.birthDate,
      gender: patient.gender,
      identifier: patient.identifier,
    );
  }

  @override
  Map<String, TextFieldDescriptor> getFieldDescriptors() => {
        'givenName': TextFieldDescriptor(
          label: 'First name',
          value: givenName.value,
          confidenceLevel: givenName.confidenceLevel,
        ),
        'familyName': TextFieldDescriptor(
          label: 'Family name',
          value: familyName.value,
          confidenceLevel: familyName.confidenceLevel,
        ),
        'dateOfBirth': TextFieldDescriptor(
          label: 'Date of birth',
          value: dateOfBirth.value,
          confidenceLevel: dateOfBirth.confidenceLevel,
          fieldType: FieldType.date,
        ),
        'gender': TextFieldDescriptor(
          label: 'Gender',
          value: gender.value,
          confidenceLevel: gender.confidenceLevel,
          fieldType: FieldType.dropdown,
        ),
        'patientMRN': TextFieldDescriptor(
          label: identifierLabel,
          value: patientMRN.value,
          confidenceLevel: patientMRN.confidenceLevel,
        ),
      };

  @override
  MappingResource copyWithMap(Map<String, dynamic> newValues) => MappingPatient(
        id: id,
        givenName: MappedProperty(
          value: newValues['givenName'] ?? givenName.value,
          confidenceLevel:
              newValues['givenName'] != null ? 1 : givenName.confidenceLevel,
        ),
        familyName: MappedProperty(
          value: newValues['familyName'] ?? familyName.value,
          confidenceLevel:
              newValues['familyName'] != null ? 1 : familyName.confidenceLevel,
        ),
        dateOfBirth: MappedProperty(
          value: newValues['dateOfBirth'] ?? dateOfBirth.value,
          confidenceLevel: newValues['dateOfBirth'] != null
              ? 1
              : dateOfBirth.confidenceLevel,
        ),
        gender: MappedProperty(
          value: newValues['gender'] ?? gender.value,
          confidenceLevel:
              newValues['gender'] != null ? 1 : gender.confidenceLevel,
        ),
        patientMRN: MappedProperty(
          value: newValues['patientMRN'] ?? patientMRN.value,
          confidenceLevel:
              newValues['patientMRN'] != null ? 1 : patientMRN.confidenceLevel,
        ),
        identifierLabel: identifierLabel,
      );

  @override
  String get label => 'Patient';

  @override
  MappingResource populateConfidence(String inputText) => copyWith(
        familyName: familyName.calculateConfidence(inputText),
        givenName: givenName.calculateConfidence(inputText),
        dateOfBirth: dateOfBirth.calculateDateConfidence(inputText),
        gender: gender.calculateGenderConfidence(inputText),
        patientMRN: patientMRN.calculateConfidence(inputText),
      );

  static String? _mapLabelToFhirCode(String label) {
    switch (label.toUpperCase()) {
      case 'MRN':
        return 'MR';
      case 'CNP':
      case 'SSN':
        return 'SS';
      case 'NHS':
        return 'NH';
      case 'DL':
        return 'DL';
      case 'PPN':
        return 'PPN';
      default:
        return null;
    }
  }

  @override
  bool get isValid =>
      familyName.isValid ||
      givenName.isValid ||
      dateOfBirth.isValid ||
      gender.isValid ||
      patientMRN.isValid;
}
