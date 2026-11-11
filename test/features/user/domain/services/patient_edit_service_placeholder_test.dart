import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/features/holders/domain/entity/holder_patient.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/sync/data/data_source/local/sync_local_data_source.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';
import 'package:health_wallet/features/user/domain/services/default_patient_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_edit_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRecords extends Fake implements RecordsRepository {
  final updated = <Patient>[];

  @override
  Future<void> updatePatient(IFhirResource patient) async {
    updated.add(patient as Patient);
  }
}

class _FakeSyncLocalDataSource extends Fake implements SyncLocalDataSource {}

class _FakeHolders extends Fake implements HolderService {}

const _walletSource = Source(id: 'wallet-default_patient');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRecords records;
  late PatientEditService service;

  /// The unnamed "Health Wallet Holder", made while [country] was chosen.
  Future<Patient> placeholderMadeIn(String country) async {
    SharedPreferences.setMockInitialValues({
      SharedPrefsConstants.countryCode: country,
    });
    return DefaultPatientService(
      records,
      _FakeSyncLocalDataSource(),
      _FakeHolders(),
    ).createDefaultWalletHolder();
  }

  /// Chooses [country], as the edit dialog does before it saves.
  Future<void> choose(String country) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPrefsConstants.countryCode, country);
  }

  List<Map<String, dynamic>> identifiersOf(Patient patient) => [
    for (final id in patient.rawResource['identifier'] as List? ?? const [])
      Map<String, dynamic>.from(id as Map),
  ];

  String? codeOf(Map<String, dynamic> identifier) =>
      ((identifier['type'] as Map)['coding'] as List).first['code'] as String?;

  setUp(() {
    records = _FakeRecords();
    service = PatientEditService(
      records,
      const SourceTypeService(),
      _FakeHolders(),
    );
  });

  group('the default holder\'s placeholder identifier', () {
    test('is kept, under the new country\'s code, when only the country '
        'changes, so the unnamed holder still takes a scanned name', () async {
      final holder = await placeholderMadeIn('RO');
      await choose('GB');

      // The dialog shows no ID for the placeholder, so it sends ''.
      final saved = await service.savePatientEdits(
        currentPatient: holder,
        identifierValue: '',
        availableSources: [_walletSource],
      );

      final identifier = identifiersOf(saved).single;
      expect(identifier['value'], HolderPatient.placeholderRowId);
      expect(codeOf(identifier), 'NH');
      expect(identifier['system'], 'https://fhir.nhs.uk/Id/nhs-number');
      expect(saved.identifier!.single.value?.valueString, 'default_patient');
      expect(records.updated.single, saved);
      // Each install stores the holder under its own row id: the
      // placeholder is known by its identifier there.
      expect(
        HolderPatient.fromRow(
          rowId: 'another-install-row',
          resourceId: saved.resourceId,
          sourceId: saved.sourceId,
          raw: saved.rawResource,
        ).isPlaceholder,
        isTrue,
      );
      // Still shown as no ID.
      expect(FhirFieldExtractor.extractPatientIdentifierValue(saved), '');
    });

    test('is replaced by an ID the user types', () async {
      final holder = await placeholderMadeIn('RO');
      await choose('GB');

      final saved = await service.savePatientEdits(
        currentPatient: holder,
        identifierValue: '9434765919',
        availableSources: [_walletSource],
      );

      final identifier = identifiersOf(saved).single;
      expect(identifier['value'], '9434765919');
      expect(codeOf(identifier), 'NH');
      expect(
        FhirFieldExtractor.extractPatientIdentifierValue(saved),
        '9434765919',
      );
    });
  });

  test('a real ID the user empties is removed', () async {
    final holder = await placeholderMadeIn('RO');
    final withId = await service.savePatientEdits(
      currentPatient: holder,
      identifierValue: '1800101123456',
      availableSources: [_walletSource],
    );

    final saved = await service.savePatientEdits(
      currentPatient: withId,
      identifierValue: '',
      availableSources: [_walletSource],
    );

    expect(saved.rawResource['identifier'], isNull);
    expect(saved.identifier, isNull);
  });
}
