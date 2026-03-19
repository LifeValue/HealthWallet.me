import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/config/constants/country_identifier.dart';
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
    @Default(MappedProperty()) MappedProperty patientIdentifier,
    @Default('ID') String identifierLabel,
  }) = _MappingPatient;

  factory MappingPatient.fromJson(
    Map<String, dynamic> json, {
    String defaultLabel = 'ID',
  }) {
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
      patientIdentifier:
          MappedProperty.fromJson(json['patientIdentifier'] ?? json['patientMRN'] ?? json['patientId']),
      identifierLabel: rawLabel.isEmpty ? defaultLabel : rawLabel,
    );
  }

  factory MappingPatient.empty() {
    return MappingPatient(
      id: const Uuid().v4(),
      familyName: MappedProperty.empty(),
      givenName: MappedProperty.empty(),
      dateOfBirth: MappedProperty.empty(),
      gender: MappedProperty.empty(),
      patientIdentifier: MappedProperty.empty(),
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
      patientIdentifier: MappedProperty(
        value: FhirFieldExtractor.extractPatientIdentifierValue(patient),
        confidenceLevel: 1,
      ),
      identifierLabel: FhirFieldExtractor.extractPatientIdentifierLabel(patient),
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
        'patientIdentifier': patientIdentifier.toJson(),
        'identifierLabel': identifierLabel,
      };

  @override
  IFhirResource toFhirResource({
    String? sourceId,
    String? encounterId,
    String? subjectId,
  }) {
    final identifierCoding = _mapLabelToFhirCode(identifierLabel);
    final profile = CountryIdentifier.forCurrentLocale();
    final identifierSystem = identifierCoding == profile.identifierFhirCode
        ? profile.fhirIdentifierSystem
        : 'http://healthwallet.me/mrn';

    fhir_r4.Patient patient = fhir_r4.Patient(
      name: [
        fhir_r4.HumanName(
          family: fhir_r4.FhirString(familyName.value),
          given: [fhir_r4.FhirString(givenName.value)],
        )
      ],
      birthDate: dateOfBirth.value.isNotEmpty
          ? fhir_r4.FhirDate.fromString(dateOfBirth.value)
          : null,
      gender: fhir_r4.AdministrativeGender(gender.value),
      identifier: [
        if (patientIdentifier.value.isNotEmpty)
          fhir_r4.Identifier(
            value: fhir_r4.FhirString(patientIdentifier.value),
            system: fhir_r4.FhirUri(identifierSystem),
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
        'patientIdentifier': TextFieldDescriptor(
          label: identifierLabel,
          value: patientIdentifier.value,
          confidenceLevel: patientIdentifier.confidenceLevel,
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
        patientIdentifier: MappedProperty(
          value: newValues['patientIdentifier'] ?? patientIdentifier.value,
          confidenceLevel:
              newValues['patientIdentifier'] != null ? 1 : patientIdentifier.confidenceLevel,
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
        patientIdentifier: patientIdentifier.calculateConfidence(inputText),
      );

  static String? _mapLabelToFhirCode(String label) {
    switch (label.toUpperCase()) {
      case 'MRN':
        return 'MR';
      case 'CNP':
      case 'SSN':
      case 'KVNR':
      case 'SVNR':
      case 'CIP':
      case 'NIR':
      case 'CF':
      case 'BSN':
      case 'PESEL':
      case 'PNR':
      case 'AHV':
        return 'SS';
      case 'NHS':
        return 'NH';
      case 'DNI':
        return 'NI';
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
      patientIdentifier.isValid;
}
