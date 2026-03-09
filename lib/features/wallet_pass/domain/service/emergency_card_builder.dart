import 'package:injectable/injectable.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/wallet_pass/domain/entity/emergency_card_data.dart';

@injectable
class EmergencyCardBuilder {
  final RecordsRepository _recordsRepository;

  EmergencyCardBuilder(this._recordsRepository);

  Future<EmergencyCardData> build({required String patientId}) async {
    final allPatients = await _recordsRepository.getResources(
      resourceTypes: [FhirType.Patient],
      limit: 100,
    );

    final patient = allPatients
        .whereType<Patient>()
        .where((p) => p.id == patientId)
        .firstOrNull;

    if (patient == null) {
      throw Exception('Patient not found');
    }

    final patientSourceIds = allPatients
        .whereType<Patient>()
        .where((p) => p.id == patientId && p.sourceId.isNotEmpty)
        .map((p) => p.sourceId)
        .toSet()
        .toList();

    final patientName =
        FhirFieldExtractor.extractHumanNameFamilyFirst(patient.name?.first) ??
            '';

    final dob = FhirFieldExtractor.extractPatientBirthDate(patient);
    final gender = FhirFieldExtractor.extractPatientGender(patient);
    final phone =
        FhirFieldExtractor.extractTelecomBySystem(patient.telecom, 'phone');

    String? emergencyContactName;
    String? emergencyContactPhone;
    final contact = patient.contact?.firstOrNull;
    if (contact != null) {
      emergencyContactName =
          FhirFieldExtractor.extractHumanName(contact.name);
      emergencyContactPhone =
          FhirFieldExtractor.extractTelecomBySystem(contact.telecom, 'phone');
    }

    final bloodTypeObs = await _recordsRepository.getBloodTypeObservations(
      patientId: patientId,
    );
    final bloodType =
        FhirFieldExtractor.extractBloodTypeFromObservations(bloodTypeObs);

    final allergyResources = await _recordsRepository.getResources(
      resourceTypes: [FhirType.AllergyIntolerance],
      sourceIds: patientSourceIds.isNotEmpty ? patientSourceIds : null,
      limit: 100,
    );
    final allergies = allergyResources
        .whereType<AllergyIntolerance>()
        .map((a) => FhirFieldExtractor.extractCodeableConceptText(a.code))
        .whereType<String>()
        .toList();

    final conditionResources = await _recordsRepository.getResources(
      resourceTypes: [FhirType.Condition],
      sourceIds: patientSourceIds.isNotEmpty ? patientSourceIds : null,
      limit: 100,
    );
    final conditions = conditionResources
        .whereType<Condition>()
        .map((c) => FhirFieldExtractor.extractCodeableConceptText(c.code))
        .whereType<String>()
        .toList();

    final medicationResources = await _recordsRepository.getResources(
      resourceTypes: [FhirType.MedicationStatement],
      sourceIds: patientSourceIds.isNotEmpty ? patientSourceIds : null,
      limit: 100,
    );
    final medications = medicationResources
        .whereType<MedicationStatement>()
        .map((m) => m.title)
        .where((t) => t.isNotEmpty)
        .toList();

    return EmergencyCardData(
      patientName: patientName,
      bloodType: bloodType,
      dateOfBirth: dob,
      gender: gender,
      allergies: allergies,
      conditions: conditions,
      medications: medications,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
      patientPhone: phone,
    );
  }
}
