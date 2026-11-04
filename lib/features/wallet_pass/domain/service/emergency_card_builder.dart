import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/wallet_pass/domain/entity/emergency_card_data.dart';
import 'package:injectable/injectable.dart';

@injectable
class EmergencyCardBuilder {
  final RecordsRepository _recordsRepository;

  EmergencyCardBuilder(this._recordsRepository);

  /// Clinical statuses of a condition or allergy that no longer applies.
  static const _inactiveClinicalStatuses = {
    'inactive',
    'resolved',
    'remission',
  };

  /// Verification statuses of a condition or allergy that was ruled out.
  static const _excludedVerificationStatuses = {'refuted', 'entered-in-error'};

  /// MedicationStatement statuses of a medication the patient may be taking.
  static const _currentStatementStatuses = {
    'active',
    'intended',
    'on-hold',
    'unknown',
  };

  /// MedicationRequest statuses of a prescription that may be in use.
  static const _currentRequestStatuses = {'active', 'on-hold', 'unknown'};

  /// The card of [patientId] from [sourceIds], the person's sources; from
  /// the sources of that Patient row when null.
  Future<EmergencyCardData> build({
    required String patientId,
    List<String>? sourceIds,
  }) async {
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

    final patientSourceIds =
        sourceIds ??
        allPatients
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
    final phone = FhirFieldExtractor.extractTelecomBySystem(
      patient.telecom,
      'phone',
    );

    String? emergencyContactName;
    String? emergencyContactPhone;
    final contact = patient.contact?.firstOrNull;
    if (contact != null) {
      emergencyContactName = FhirFieldExtractor.extractHumanName(contact.name);
      emergencyContactPhone = FhirFieldExtractor.extractTelecomBySystem(
        contact.telecom,
        'phone',
      );
    }

    final bloodTypeObs = await _recordsRepository.getBloodTypeObservations(
      patientId: patientId,
    );
    final bloodType = FhirFieldExtractor.extractBloodTypeFromObservations(
      bloodTypeObs,
    );

    final allergyResources = await _recordsRepository.getResources(
      resourceTypes: [FhirType.AllergyIntolerance],
      sourceIds: patientSourceIds,
      limit: 100,
    );
    final allergies = _distinct(
      allergyResources
          .whereType<AllergyIntolerance>()
          .where((a) => _applies(a.clinicalStatus, a.verificationStatus))
          .map((a) => FhirFieldExtractor.extractCodeableConceptText(a.code)),
    );

    final conditionResources = await _recordsRepository.getResources(
      resourceTypes: [FhirType.Condition],
      sourceIds: patientSourceIds,
      limit: 100,
    );
    final conditions = _distinct(
      conditionResources
          .whereType<Condition>()
          .where((c) => _applies(c.clinicalStatus, c.verificationStatus))
          .map((c) => FhirFieldExtractor.extractCodeableConceptText(c.code)),
    );

    final statementResources = await _recordsRepository.getResources(
      resourceTypes: [FhirType.MedicationStatement],
      sourceIds: patientSourceIds,
      limit: 100,
    );
    final requestResources = await _recordsRepository.getResources(
      resourceTypes: [FhirType.MedicationRequest],
      sourceIds: patientSourceIds,
      limit: 100,
    );
    final medications = _distinct([
      ...statementResources
          .whereType<MedicationStatement>()
          .where(
            (m) => _isKept(m.status?.valueString, _currentStatementStatuses),
          )
          .map(
            (m) => m.title.trim().isNotEmpty
                ? m.title
                : _medicationName(m.medicationX),
          ),
      ...requestResources
          .whereType<MedicationRequest>()
          .where((m) => _isKept(m.status?.valueString, _currentRequestStatuses))
          .map((m) => _medicationName(m.medicationX) ?? m.title),
    ]);

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

  /// Whether a condition or allergy still applies: not inactive, resolved or
  /// in remission, and not refuted or entered in error. A missing status
  /// keeps the item.
  static bool _applies(
    fhir_r4.CodeableConcept? clinicalStatus,
    fhir_r4.CodeableConcept? verificationStatus,
  ) =>
      !_statusCodes(clinicalStatus).any(_inactiveClinicalStatuses.contains) &&
      !_statusCodes(
        verificationStatus,
      ).any(_excludedVerificationStatuses.contains);

  /// The lower-case codes of [status], or its text when it has no code.
  static Set<String> _statusCodes(fhir_r4.CodeableConcept? status) {
    final codes = {
      for (final coding in status?.coding ?? const <fhir_r4.Coding>[])
        if (coding.code?.valueString?.trim().toLowerCase() case final code?
            when code.isNotEmpty)
          code,
    };
    if (codes.isNotEmpty) return codes;
    final text = status?.text?.valueString?.trim().toLowerCase();
    return text == null || text.isEmpty ? const {} : {text};
  }

  /// Whether a medication [status] is one of [kept]; a missing status keeps
  /// the item.
  static bool _isKept(String? status, Set<String> kept) =>
      status == null || kept.contains(status.toLowerCase());

  /// The name of a coded or referenced medication.
  static String? _medicationName(Object? medicationX) => switch (medicationX) {
    final fhir_r4.CodeableConcept concept =>
      FhirFieldExtractor.extractCodeableConceptText(concept),
    final fhir_r4.Reference reference => reference.display?.valueString,
    _ => null,
  };

  /// The non-empty [names], trimmed, without case-insensitive repeats; the
  /// first spelling wins.
  static List<String> _distinct(Iterable<String?> names) {
    final seen = <String>{};
    final result = <String>[];
    for (final name in names) {
      final trimmed = name?.trim();
      if (trimmed == null || trimmed.isEmpty) continue;
      if (seen.add(trimmed.toLowerCase())) result.add(trimmed);
    }
    return result;
  }
}
