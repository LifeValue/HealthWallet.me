import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/data/data_source/shared_notes_datasource.dart';
import 'package:health_wallet/features/records/data/repository/records_repository_impl.dart';
import 'package:health_wallet/features/sync/data/data_source/local/sync_local_data_source.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _aboRh = '34530-6';
const _abo = '883-9';
const _rh = '10331-7';
const _heartRate = '8867-4';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late SyncLocalDataSourceImpl syncLocal;
  late RecordsRepositoryImpl repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    syncLocal = SyncLocalDataSourceImpl(
      database,
      await SharedPreferences.getInstance(),
    );
    repository = RecordsRepositoryImpl(
      database,
      syncLocal,
      SharedNotesDatasource(),
    );
  });

  tearDown(() => database.close());

  FhirResourceDto patient(String id, {String sourceId = 'src-1'}) =>
      FhirResourceDto(
        resourceId: id,
        sourceId: sourceId,
        resourceType: 'Patient',
        resourceRaw: {'resourceType': 'Patient', 'id': id},
      );

  FhirResourceDto observation(
    String id, {
    String? subject,
    String loinc = _aboRh,
    String sourceId = 'src-1',
  }) => FhirResourceDto(
    resourceId: id,
    sourceId: sourceId,
    resourceType: 'Observation',
    resourceRaw: {
      'resourceType': 'Observation',
      'id': id,
      'status': 'final',
      'code': {
        'coding': [
          {'system': 'http://loinc.org', 'code': loinc},
        ],
      },
      if (subject != null) 'subject': {'reference': subject},
      'valueCodeableConcept': {'text': 'A+'},
    },
  );

  Future<List<String>> bloodTypeIds({
    String patientId = 'pat-7',
    String? sourceId,
  }) async {
    final found = await repository.getBloodTypeObservations(
      patientId: patientId,
      sourceId: sourceId,
    );
    return found.map((r) => r.id).toList()..sort();
  }

  group('getBloodTypeObservations', () {
    test('matches the patient of a versioned subject reference', () async {
      await syncLocal.cacheFhirResources([
        patient('pat-7'),
        patient('pat-8'),
        observation('obs-versioned', subject: 'Patient/pat-7/_history/3'),
        observation('obs-other', subject: 'Patient/pat-8/_history/7'),
        observation('obs-version-as-id', subject: 'Patient/x/_history/pat-7'),
      ]);

      expect(await bloodTypeIds(), ['obs-versioned']);
    });

    test('matches relative, urn:uuid and bare subject references', () async {
      await syncLocal.cacheFhirResources([
        patient('pat-7'),
        patient('pat-8'),
        observation('obs-relative', subject: 'Patient/pat-7'),
        observation(
          'obs-absolute',
          subject: 'https://fhir.example/Patient/pat-7',
        ),
        observation('obs-urn', subject: 'urn:uuid:pat-7'),
        observation('obs-bare', subject: 'pat-7'),
        observation('obs-other', subject: 'Patient/pat-8'),
      ]);

      expect(await bloodTypeIds(), [
        'obs-absolute',
        'obs-bare',
        'obs-relative',
        'obs-urn',
      ]);
    });

    test('accepts the ABO, Rh and combined LOINC codes only', () async {
      await syncLocal.cacheFhirResources([
        patient('pat-7'),
        observation('obs-abo', subject: 'Patient/pat-7', loinc: _abo),
        observation('obs-rh', subject: 'Patient/pat-7', loinc: _rh),
        observation('obs-hr', subject: 'Patient/pat-7', loinc: _heartRate),
        observation('obs-no-subject'),
      ]);

      expect(await bloodTypeIds(), ['obs-abo', 'obs-rh']);
    });

    test('is empty without patients', () async {
      await syncLocal.cacheFhirResources([
        observation('obs-1', subject: 'Patient/pat-7'),
      ]);

      expect(await bloodTypeIds(), isEmpty);
    });

    test('falls back to the first patient for an unknown id', () async {
      await syncLocal.cacheFhirResources([
        patient('pat-7'),
        observation('obs-1', subject: 'Patient/pat-7'),
      ]);

      expect(await bloodTypeIds(patientId: 'missing'), ['obs-1']);
    });

    test(
      'reads the given source, then every source when it is empty',
      () async {
        await syncLocal.cacheFhirResources([
          patient('pat-7'),
          observation('obs-a', subject: 'Patient/pat-7'),
          observation('obs-b', subject: 'Patient/pat-7', sourceId: 'src-2'),
        ]);

        expect(await bloodTypeIds(sourceId: 'src-2'), ['obs-b']);
        expect(await bloodTypeIds(sourceId: 'src-none'), ['obs-a', 'obs-b']);
        expect(await bloodTypeIds(sourceId: ''), ['obs-a', 'obs-b']);
      },
    );
  });
}
