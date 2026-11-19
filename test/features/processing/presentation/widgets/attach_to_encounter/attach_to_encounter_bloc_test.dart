import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/presentation/widgets/attach_to_encounter/bloc/attach_to_encounter_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';

import '../../../../../helpers/log_capture.dart';

/// Answers encounter queries with [encounters] and records their scope.
class _FakeRecordsRepository extends Fake implements RecordsRepository {
  List<IFhirResource> encounters = [];
  Exception? error;
  final scopes = <({String? sourceId, List<String>? sourceIds})>[];

  @override
  Future<List<IFhirResource>> getResources({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 20,
    int offset = 0,
  }) async {
    if (error != null) throw error!;
    scopes.add((sourceId: sourceId, sourceIds: sourceIds));
    return encounters;
  }
}

class _FakeHolderService extends Fake implements HolderService {
  HolderDirectory directory = const HolderDirectory();
  Exception? error;

  @override
  Future<HolderDirectory> load() async {
    if (error != null) throw error!;
    return directory;
  }
}

const _ana = Patient(id: 'ana-wallet', sourceId: 'wallet-ana', title: 'Ana');
const _anaAtClinic = Patient(id: 'ana-clinic', sourceId: 'clinic');
const _bob = Patient(id: 'bob', sourceId: 'wallet-bob', title: 'Bob');

const _holders = HolderDirectory(
  holders: [
    Holder(
      id: 'ana',
      representativePatient: _ana,
      sourceIds: ['wallet-ana', 'clinic'],
      allPatientInstances: [_ana, _anaAtClinic],
    ),
    Holder(
      id: 'bob',
      representativePatient: _bob,
      sourceIds: ['wallet-bob'],
      allPatientInstances: [_bob],
    ),
  ],
);

void main() {
  final logs = captureLogs();
  late _FakeRecordsRepository records;
  late _FakeHolderService holders;
  late AttachToEncounterBloc bloc;

  setUp(() {
    records = _FakeRecordsRepository()
      ..encounters = const [
        Encounter(id: 'e1', title: 'Cardiology visit'),
        Encounter(id: 'e2', title: 'Dentist'),
      ];
    holders = _FakeHolderService()..directory = _holders;
    bloc = AttachToEncounterBloc(records, holders);
  });

  tearDown(() => bloc.close());

  Future<AttachToEncounterState> run(AttachToEncounterEvent event) async {
    bloc.add(event);
    await pumpEventQueue();
    return bloc.state;
  }

  final scanned = MappingPatient.empty();

  group('start', () {
    test('with nobody yet, there is no one to choose', () async {
      holders.directory = const HolderDirectory();

      final state = await run(const AttachToEncounterStarted());

      expect(state.status, AttachToEncounterStatus.success);
      expect(state.existingPatients, isEmpty);
    });

    test('a scanned person is offered first and makes a new one', () async {
      final state = await run(
        AttachToEncounterStarted(patient: StagedPatient(draft: scanned)),
      );

      expect(state.existingPatients, [_ana, _bob]);
      expect(state.selectedPatient, scanned);
      expect(state.patient.mode, ImportMode.createNew);
      expect(records.scopes, isEmpty, reason: 'no visits of a new person');
      expect(state.status, AttachToEncounterStatus.success);
    });

    test('a matched person is shown as their holder, with the visits of '
        'all their sources', () async {
      final state = await run(
        AttachToEncounterStarted(
          patient: StagedPatient(
            draft: scanned,
            existing: _anaAtClinic,
            mode: ImportMode.linkExisting,
          ),
        ),
      );

      expect(state.selectedPatient, _ana);
      expect(state.patient.mode, ImportMode.linkExisting);
      expect(state.patient.existing, _ana);
      expect(records.scopes.single.sourceIds, ['wallet-ana', 'clinic']);
      expect(state.existingEncounters.map((e) => e.id), ['e1', 'e2']);
    });

    test('without a scanned person the first person is chosen', () async {
      final state = await run(const AttachToEncounterStarted());

      expect(state.selectedPatient, _ana);
      expect(state.patient.mode, ImportMode.linkExisting);
    });

    test('a failure to read the people fails and is logged', () async {
      holders.error = Exception('db');

      final state = await run(const AttachToEncounterStarted());

      expect(state.status, AttachToEncounterStatus.failure);
      expect(logs, loggedWarning('Error loading patients'));
    });
  });

  group('choosing the person', () {
    setUp(
      () => run(
        AttachToEncounterStarted(patient: StagedPatient(draft: scanned)),
      ),
    );

    test('someone known loads their visits and drops the scanned '
        'fields', () async {
      final state = await run(const AttachToEncounterPatientChanged(_bob));

      expect(state.selectedPatient, _bob);
      expect(state.patient.existing, _bob);
      expect(state.patient.draft, isNull);
      expect(state.patient.mode, ImportMode.linkExisting);
      expect(records.scopes.last.sourceIds, ['wallet-bob']);
      expect(state.status, AttachToEncounterStatus.success);
    });

    test('the scanned person again clears the visits', () async {
      await run(const AttachToEncounterPatientChanged(_bob));

      final state = await run(AttachToEncounterPatientChanged(scanned));

      expect(state.patient.mode, ImportMode.createNew);
      expect(state.existingEncounters, isEmpty);
    });

    test('a person outside every holder is looked up by their source', () {
      const stranger = Patient(id: 'x', sourceId: 'elsewhere');

      return run(const AttachToEncounterPatientChanged(stranger)).then((_) {
        expect(records.scopes.last, (sourceId: 'elsewhere', sourceIds: null));
      });
    });

    test('visits that cannot be read fail and are logged', () async {
      records.error = Exception('db');

      final state = await run(const AttachToEncounterPatientChanged(_bob));

      expect(state.status, AttachToEncounterStatus.failure);
      expect(logs, loggedWarning('Error loading encounters'));
    });
  });

  group('choosing the visit', () {
    setUp(() => run(const AttachToEncounterStarted()));

    test('search narrows the visits by title, and clearing it shows them '
        'all', () async {
      var state = await run(const AttachToEncounterSearchQueryChanged('CARD'));
      expect(state.filteredEncounters.map((e) => e.id), ['e1']);

      state = await run(const AttachToEncounterSearchQueryChanged(''));
      expect(state.filteredEncounters, hasLength(2));
    });

    test('an existing visit is linked', () async {
      const visit = Encounter(id: 'e2', title: 'Dentist');

      final state = await run(const AttachToEncounterSelected(visit));

      expect(state.encounter.existing, visit);
      expect(state.encounter.mode, ImportMode.linkExisting);
    });

    test('the scanned visit makes a new one', () async {
      await run(const AttachToEncounterSelected(Encounter(id: 'e2')));

      final state = await run(
        AttachToEncounterSelected(MappingEncounter.empty()),
      );

      expect(state.encounter.existing, isNull);
      expect(state.encounter.mode, ImportMode.createNew);
    });

    test('a visit made here becomes the new one', () async {
      final made = MappingEncounter.empty();

      final state = await run(AttachToEncounterNewEncounterCreated(made));

      expect(state.encounter.draft, made);
      expect(state.encounter.mode, ImportMode.createNew);
    });
  });
}
