import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:health_wallet/core/config/constants/country_identifier.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/features/sync/data/data_source/local/sync_local_data_source.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

@injectable
class DefaultPatientService {
  final RecordsRepository _recordsRepository;
  final SyncLocalDataSource _syncLocalDataSource;

  DefaultPatientService(this._recordsRepository, this._syncLocalDataSource);

  Future<Patient> createDefaultWalletHolder() async {
    final resourceId = const Uuid().v4();
    final prefs = await SharedPreferences.getInstance();
    final savedCountry = prefs.getString(SharedPrefsConstants.countryCode);
    final profile = savedCountry != null
        ? CountryIdentifier.forCountry(savedCountry)
        : CountryIdentifier.forCurrentLocale();

    final dbId = 'wallet_default_wallet_holder';

    final identifier = fhir_r4.Identifier(
      type: fhir_r4.CodeableConcept(
        coding: [
          fhir_r4.Coding(
            system: fhir_r4.FhirUri(
              'http://terminology.hl7.org/CodeSystem/v2-0203',
            ),
            code: fhir_r4.FhirCode(profile.identifierFhirCode),
            display: fhir_r4.FhirString(profile.identifierDisplayName),
          ),
        ],
        text: fhir_r4.FhirString(profile.identifierDisplayName),
      ),
      system: fhir_r4.FhirUri(profile.fhirIdentifierSystem),
      value: fhir_r4.FhirString('default_wallet_holder'),
    );

    return Patient(
      id: dbId,
      sourceId: 'wallet',
      resourceId: resourceId,
      title: 'Health Wallet Holder',
      name: [
        fhir_r4.HumanName(
          use: fhir_r4.NameUse.official,
          given: [fhir_r4.FhirString('Health Wallet')],
          family: fhir_r4.FhirString('Holder'),
        ),
      ],
      birthDate: null,
      gender: null,
      identifier: [identifier],
      rawResource: {
        'resourceType': 'Patient',
        'id': resourceId,
        'name': [
          {
            'use': 'official',
            'given': ['Health Wallet'],
            'family': 'Holder',
          }
        ],
        'identifier': [
          {
            'type': {
              'coding': [
                {
                  'system': 'http://terminology.hl7.org/CodeSystem/v2-0203',
                  'code': profile.identifierFhirCode,
                  'display': profile.identifierDisplayName,
                }
              ],
              'text': profile.identifierDisplayName,
            },
            'system': profile.fhirIdentifierSystem,
            'value': 'default_wallet_holder',
          }
        ],
      },
    );
  }

  Future<void> createAndSetAsMain() async {
    try {
      final existingPatients = await _recordsRepository.getResources(
        resourceTypes: [FhirType.Patient],
        limit: 1,
      );

      if (existingPatients.isNotEmpty) {
        return;
      }

      final defaultPatient = await createDefaultWalletHolder();

      final fhirResourceDto = FhirResourceDto(
        id: defaultPatient.id,
        sourceId: defaultPatient.sourceId,
        resourceType: 'Patient',
        resourceId: defaultPatient.resourceId,
        title: defaultPatient.title,
        date: DateTime.now(),
        resourceRaw: defaultPatient.rawResource,
        changeType: 'created',
      );

      await _syncLocalDataSource.cacheFhirResources([fhirResourceDto]);
    } catch (e) {
    }
  }

  Future<bool> shouldCreateDefaultWalletHolder() async {
    try {
      final patients = await _recordsRepository.getResources(
        resourceTypes: [FhirType.Patient],
        limit: 1,
      );

      return patients.isEmpty;
    } catch (e) {
      return true;
    }
  }
}
