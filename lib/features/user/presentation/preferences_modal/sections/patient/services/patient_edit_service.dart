import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/core/utils/blood_observation_utils.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/services/patient_name_builder.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/utils/gender_mapper.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

@injectable
class PatientEditService {
  final RecordsRepository _recordsRepository;
  final SourceTypeService _sourceTypeService;

  PatientEditService(
    this._recordsRepository,
    this._sourceTypeService,
  );

  Future<Patient> savePatientEdits({
    required Patient currentPatient,
    List<String>? given,
    String? family,
    DateTime? birthDate,
    String? gender,
    String? mrn,
    required List<Source> availableSources,
  }) async {
    final source = availableSources.firstWhere(
      (s) => s.id == currentPatient.sourceId,
      orElse: () =>
          throw Exception('Source not found for ${currentPatient.sourceId}'),
    );

    final isWritable = _sourceTypeService.isSourceWritable(source.platformType);

    if (isWritable) {
      return await _updatePatientInPlace(
        patient: currentPatient,
        given: given,
        family: family,
        birthDate: birthDate,
        gender: gender,
        mrn: mrn,
      );
    } else {
      return await _copyPatientToWallet(
        readOnlyPatient: currentPatient,
        given: given,
        family: family,
        birthDate: birthDate,
        gender: gender,
        mrn: mrn,
        availableSources: availableSources,
      );
    }
  }

  Future<Patient> _updatePatientInPlace({
    required Patient patient,
    List<String>? given,
    String? family,
    DateTime? birthDate,
    String? gender,
    String? mrn,
  }) async {
    final fhirPatient = fhir_r4.Patient.fromJson(patient.rawResource);

    final updatedNames = PatientNameBuilder.buildHumanNameFromPatient(
      given: given,
      family: family,
      existingNames: fhirPatient.name,
    );

    List<fhir_r4.Identifier>? updatedIdentifiers;
    if (mrn != null) {
      updatedIdentifiers = _updateMRNIdentifier(fhirPatient.identifier, mrn);
    } else {
      updatedIdentifiers = fhirPatient.identifier;
    }

    final finalGender = gender != null
        ? GenderMapper.mapDisplayGenderToFhir(gender)
        : fhirPatient.gender;

    final finalBirthDate = birthDate != null
        ? fhir_r4.FhirDate.fromDateTime(birthDate)
        : fhirPatient.birthDate;

    final updatedFhirPatient = fhirPatient.copyWith(
      name: updatedNames,
      gender: finalGender,
      birthDate: finalBirthDate,
      identifier: updatedIdentifiers,
    );

    final updatedRawResource = updatedFhirPatient.toJson();

    final displayTitle = (given != null || family != null)
        ? updatedNames?.isNotEmpty == true
            ? FhirFieldExtractor.extractHumanNameFamilyFirst(
                    updatedNames!.first) ??
                patient.displayTitle
            : patient.displayTitle
        : patient.displayTitle;

    final finalPatient = patient.copyWith(
      rawResource: updatedRawResource,
      title: displayTitle,
      name: updatedNames,
      gender: updatedFhirPatient.gender,
      birthDate: updatedFhirPatient.birthDate,
      identifier: updatedIdentifiers,
    );

    await _recordsRepository.updatePatient(finalPatient);
    return finalPatient;
  }

  Future<Patient> _copyPatientToWallet({
    required Patient readOnlyPatient,
    List<String>? given,
    String? family,
    DateTime? birthDate,
    String? gender,
    String? mrn,
    required List<Source> availableSources,
  }) async {
    final walletSource = await _sourceTypeService.getWritableSourceForPatient(
      patientId: readOnlyPatient.resourceId,
      patientName: readOnlyPatient.displayTitle,
      availableSources: availableSources,
    );

    final existingWalletPatients = await _recordsRepository.getResources(
      resourceTypes: [FhirType.Patient],
      sourceId: walletSource.id,
    );

    final existingWalletPatient = existingWalletPatients
        .whereType<Patient>()
        .where((p) => _hasSameIdentifiers(p, readOnlyPatient))
        .firstOrNull;

    if (existingWalletPatient != null) {
      return await _updatePatientInPlace(
        patient: existingWalletPatient,
        given: given,
        family: family,
        birthDate: birthDate,
        gender: gender,
        mrn: mrn,
      );
    } else {
      return await _createWalletPatientFromReadOnly(
        readOnlyPatient: readOnlyPatient,
        walletSource: walletSource,
        given: given,
        family: family,
        birthDate: birthDate,
        gender: gender,
        mrn: mrn,
      );
    }
  }

  Future<Patient> _createWalletPatientFromReadOnly({
    required Patient readOnlyPatient,
    required Source walletSource,
    List<String>? given,
    String? family,
    DateTime? birthDate,
    String? gender,
    String? mrn,
  }) async {
    final walletResourceId = const Uuid().v4();
    final walletDbId = '${walletSource.id}_$walletResourceId';
    final fhirPatient = fhir_r4.Patient.fromJson(readOnlyPatient.rawResource);

    final updatedNames = PatientNameBuilder.buildHumanNameFromPatient(
      given: given,
      family: family,
      existingNames: fhirPatient.name,
    );

    List<fhir_r4.Identifier>? updatedIdentifiers;
    if (mrn != null) {
      updatedIdentifiers = _updateMRNIdentifier(fhirPatient.identifier, mrn);
    } else {
      updatedIdentifiers = fhirPatient.identifier;
    }

    final finalName =
        (given != null || family != null) ? updatedNames : fhirPatient.name;

    final finalGender = gender != null
        ? GenderMapper.mapDisplayGenderToFhir(gender)
        : fhirPatient.gender;

    final finalBirthDate = birthDate != null
        ? fhir_r4.FhirDate.fromDateTime(birthDate)
        : fhirPatient.birthDate;

    final updatedFhirPatient = fhirPatient.copyWith(
      id: fhir_r4.FhirString(walletResourceId),
      name: finalName,
      gender: finalGender,
      birthDate: finalBirthDate,
      identifier: updatedIdentifiers,
    );

    final updatedRawResource = updatedFhirPatient.toJson();

    final displayTitle = finalName?.isNotEmpty == true
        ? FhirFieldExtractor.extractHumanNameFamilyFirst(finalName!.first) ??
            readOnlyPatient.displayTitle
        : readOnlyPatient.displayTitle;

    final finalPatient = readOnlyPatient.copyWith(
      id: walletDbId,
      sourceId: walletSource.id,
      resourceId: walletResourceId,
      rawResource: updatedRawResource,
      title: displayTitle,
      identifier: updatedIdentifiers,
      name: updatedFhirPatient.name,
      gender: updatedFhirPatient.gender,
      birthDate: updatedFhirPatient.birthDate,
      active: readOnlyPatient.active,
      telecom: readOnlyPatient.telecom,
      deceasedX: readOnlyPatient.deceasedX,
      address: readOnlyPatient.address,
      maritalStatus: readOnlyPatient.maritalStatus,
      multipleBirthX: readOnlyPatient.multipleBirthX,
      photo: readOnlyPatient.photo,
      contact: readOnlyPatient.contact,
      communication: readOnlyPatient.communication,
      generalPractitioner: readOnlyPatient.generalPractitioner,
      managingOrganization: readOnlyPatient.managingOrganization,
      link: readOnlyPatient.link,
      text: readOnlyPatient.text,
    );

    await _recordsRepository.updatePatient(finalPatient);

    return finalPatient;
  }

  List<fhir_r4.Identifier>? _updateMRNIdentifier(
    List<fhir_r4.Identifier>? currentIdentifiers,
    String? mrn,
  ) {
    if ((mrn == null || mrn.isEmpty) && currentIdentifiers == null) {
      return null;
    }

    final identifiers = List<fhir_r4.Identifier>.from(currentIdentifiers ?? []);

    final mrnIndex = identifiers.indexWhere(
      (id) =>
          id.type?.coding?.any(
            (coding) => coding.code?.toString() == 'MR',
          ) ??
          false,
    );

    if (mrn != null && mrn.isNotEmpty) {
      final mrnIdentifier = fhir_r4.Identifier(
        type: fhir_r4.CodeableConcept(
          coding: [
            fhir_r4.Coding(
              system: fhir_r4.FhirUri(
                'http://terminology.hl7.org/CodeSystem/v2-0203',
              ),
              code: fhir_r4.FhirCode('MR'),
              display: fhir_r4.FhirString('Medical Record Number'),
            ),
          ],
          text: fhir_r4.FhirString('Medical Record Number'),
        ),
        system: _getMRNSystem(currentIdentifiers),
        value: fhir_r4.FhirString(mrn),
      );

      if (mrnIndex >= 0) {
        identifiers[mrnIndex] = mrnIdentifier;
      } else {
        identifiers.add(mrnIdentifier);
      }
    } else {
      if (mrnIndex >= 0) {
        identifiers.removeAt(mrnIndex);
      }
    }

    return identifiers.isEmpty ? null : identifiers;
  }

  fhir_r4.FhirUri _getMRNSystem(List<fhir_r4.Identifier>? identifiers) {
    if (identifiers != null && identifiers.isNotEmpty) {
      final existingMRN = identifiers.firstWhere(
        (id) =>
            id.type?.coding?.any(
              (coding) => coding.code?.toString() == 'MR',
            ) ??
            false,
        orElse: () => identifiers.first,
      );

      if (existingMRN.system != null) {
        return existingMRN.system!;
      }

      if (identifiers.first.system != null) {
        return identifiers.first.system!;
      }
    }

    return fhir_r4.FhirUri('http://healthwallet.me/mrn');
  }

  bool _hasSameIdentifiers(Patient p1, Patient p2) {
    if (p1.identifier == null || p2.identifier == null) return false;
    if (p1.identifier!.isEmpty || p2.identifier!.isEmpty) return false;

    final ids1 = p1.identifier!
        .where((id) =>
            id.system?.valueString != null && id.value?.valueString != null)
        .map((id) => '${id.system!.valueString}:${id.value!.valueString}')
        .toSet();

    final ids2 = p2.identifier!
        .where((id) =>
            id.system?.valueString != null && id.value?.valueString != null)
        .map((id) => '${id.system!.valueString}:${id.value!.valueString}')
        .toSet();

    return ids1.intersection(ids2).isNotEmpty;
  }

  Future<String?> getCurrentBloodType(Patient patient) async {
    try {
      final observations = await _recordsRepository.getBloodTypeObservations(
        patientId: patient.id,
        sourceId: patient.sourceId.isNotEmpty ? patient.sourceId : null,
      );
      return FhirFieldExtractor.extractBloodTypeFromObservations(observations);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateBloodTypeObservation(
    Patient patient,
    String bloodType,
  ) async {
    try {
      final existingObservations =
          await _recordsRepository.getBloodTypeObservations(
        patientId: patient.id,
        sourceId: patient.sourceId.isNotEmpty ? patient.sourceId : null,
      );

      if (bloodType == 'N/A') {
        if (existingObservations.isNotEmpty) {
          final existingObservation = existingObservations.first as Observation;

          final updatedRawResource =
              Map<String, dynamic>.from(existingObservation.rawResource);
          updatedRawResource.remove('valueCodeableConcept');

          final clearedObservation = existingObservation.copyWith(
            valueX: null,
            date: DateTime.now(),
            rawResource: updatedRawResource,
          );
          await _recordsRepository.saveObservation(clearedObservation);
        }
        return;
      }

      if (!BloodObservationUtils.isValidBloodType(bloodType)) {
        logger.w('Invalid blood type: $bloodType');
        return;
      }

      if (existingObservations.isNotEmpty) {
        final existingObservation = existingObservations.first as Observation;

        final newValueX = BloodObservationUtils.createBloodTypeValue(bloodType);

        final updatedRawResource =
            Map<String, dynamic>.from(existingObservation.rawResource);
        updatedRawResource['valueCodeableConcept'] = newValueX.toJson();

        final updatedObservation = existingObservation.copyWith(
          valueX: newValueX,
          date: DateTime.now(),
          rawResource: updatedRawResource,
        );

        await _recordsRepository.saveObservation(updatedObservation);
      } else {
        final newObservation = BloodObservationUtils.createBloodTypeObservation(
          bloodType: bloodType,
          patientSourceId: patient.sourceId,
          patientResourceId: patient.resourceId,
        );
        await _recordsRepository.saveObservation(newObservation);
      }
    } catch (e) {
      logger.e('Error updating blood type observation: $e');
      rethrow;
    }
  }

  Future<bool> hasPatientChanges({
    required Patient currentPatient,
    required DateTime? newBirthDate,
    required String newGender,
    required String newBloodType,
    String? newMRN,
    required AppLocalizations l10n,
  }) async {
    final currentBirthDate =
        FhirFieldExtractor.extractPatientBirthDate(currentPatient);
    final currentGender =
        FhirFieldExtractor.extractPatientGender(currentPatient);
    final currentBloodType = await getCurrentBloodType(currentPatient);
    final currentMRN = FhirFieldExtractor.extractPatientMRN(currentPatient);

    final birthDateChanged = currentBirthDate != newBirthDate;
    final genderChanged =
        GenderMapper.mapFhirGenderToDisplay(currentGender, l10n) != newGender;
    final bloodTypeChanged = currentBloodType != newBloodType;
    final mrnChanged = currentMRN != (newMRN ?? '');

    return birthDateChanged || genderChanged || bloodTypeChanged || mrnChanged;
  }

  bool validatePatientData({
    required DateTime? birthDate,
    required String gender,
    required String bloodType,
  }) {
    if (birthDate == null) {
      return false;
    }

    if (birthDate.isAfter(DateTime.now())) {
      return false;
    }

    return true;
  }
}
