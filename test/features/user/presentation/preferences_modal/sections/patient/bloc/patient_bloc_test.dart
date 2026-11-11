import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/holders/domain/services/holder_linker.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/user/domain/services/patient_edit_service.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHolderService extends Fake implements HolderService {
  _FakeHolderService(this.directory);

  HolderDirectory directory;
  final answers = <String>[];

  /// Thrown by [load] while set, as when the database can't be read.
  StateError? loadError;

  /// Thrown by [answer] while set.
  StateError? answerError;

  @override
  Future<HolderDirectory> load() async {
    if (loadError case final error?) throw error;
    return directory;
  }

  @override
  Future<void> answer(HolderQuestion question, {String? holderId}) async {
    if (answerError case final error?) throw error;
    answers.add('${question.sourceIds.join(',')} → $holderId');
  }
}

class _FakePatientEditService extends Fake implements PatientEditService {
  /// Each patient's stored blood type; a patient missing has none.
  final bloodTypes = <String, String>{'jane': 'A+'};

  /// Patients whose blood type can't be read.
  final unreadable = <String>{};

  final saved = <String>[];
  final bloodTypesWritten = <String>[];

  @override
  Future<String?> getCurrentBloodType(Patient patient) async {
    if (unreadable.contains(patient.id)) {
      throw StateError('observations of ${patient.id} unreadable');
    }
    return bloodTypes[patient.id];
  }

  @override
  Future<Patient> savePatientEdits({
    required Patient currentPatient,
    List<String>? given,
    String? family,
    DateTime? birthDate,
    String? gender,
    String? identifierValue,
    String? contactPhone,
    required List<Source> availableSources,
  }) async {
    saved.add('${currentPatient.id}: $family');
    return currentPatient;
  }

  @override
  Future<void> updateBloodTypeObservation(
    Patient person,
    String bloodType,
  ) async {
    bloodTypesWritten.add('${person.id}: $bloodType');
    bloodTypes[person.id] = bloodType;
  }
}

/// A selection that can't be saved.
class _FailingHolderSelection extends HolderSelection {
  _FailingHolderSelection(super.holders, super.prefs);

  @override
  Future<void> select(String holderId) async =>
      throw StateError('preferences unavailable');
}

const jane = Patient(id: 'jane', sourceId: 'wallet-jane', title: 'Jane');
const janeAtEpic = Patient(id: 'p1', sourceId: 'epic', title: 'Jane Doe');
const tom = Patient(id: 'tom', sourceId: 'wallet-tom', title: 'Tom');
const anna = Patient(id: 'p9', sourceId: 'kaiser', title: 'Anna');

const janeHolder = Holder(
  id: 'jane',
  representativePatient: jane,
  sourceIds: ['epic', 'wallet-jane'],
  allPatientInstances: [jane, janeAtEpic],
);
const tomHolder = Holder(
  id: 'tom',
  representativePatient: tom,
  sourceIds: ['wallet-tom'],
  allPatientInstances: [tom],
);
const annaHolder = Holder(
  id: 'p9',
  representativePatient: anna,
  sourceIds: ['kaiser'],
  allPatientInstances: [anna],
);

/// What the patient list shows at one moment, in words.
String _shown(PatientState s) => [
  s.animationPhase.name,
  if (s.animatingPatientId.isNotEmpty) 'tapped ${s.animatingPatientId}',
  if (s.collapsingPatientId.isNotEmpty) 'closing ${s.collapsingPatientId}',
  if (s.swappingFromPatientId.isNotEmpty)
    'swapping ${s.swappingFromPatientId}→${s.swappingToPatientId}',
  if (s.expandingPatientId.isNotEmpty) 'opening ${s.expandingPatientId}',
  'open {${s.expandedPatientIds.join(',')}}',
  'list ${s.patients.map((p) => p.id).join(',')}',
  'selected ${s.selectedPatientId}',
].join(', ');

void main() {
  late _FakeHolderService holders;
  late _FakePatientEditService editService;
  late SharedPreferences prefs;
  late HolderSelection selection;

  PatientBloc build() => PatientBloc(holders, selection, editService);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    holders = _FakeHolderService(
      const HolderDirectory(holders: [janeHolder, tomHolder]),
    );
    editService = _FakePatientEditService();
    selection = HolderSelection(holders, prefs);
  });

  blocTest<PatientBloc, PatientState>(
    'lists one patient per person, with all their sources',
    build: build,
    act: (bloc) => bloc.add(const PatientInitialised()),
    skip: 1,
    verify: (bloc) {
      expect(bloc.state.patients.map((p) => p.id), ['jane', 'tom']);
      expect(bloc.state.patientGroups['jane']!.sourceIds, [
        'epic',
        'wallet-jane',
      ]);
      expect(bloc.state.selectedPatientId, 'jane');
      expect(bloc.state.expandedPatientIds, {'jane'});
      expect(bloc.state.bloodTypes, {'jane': 'A+', 'tom': null});
    },
  );

  blocTest<PatientBloc, PatientState>(
    'a Patient row id saved by an older version selects its person',
    setUp: () => prefs.setString('selected_patient_id', 'p1'),
    build: build,
    act: (bloc) => bloc.add(const PatientInitialised()),
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(bloc.state.selectedPatientId, 'jane');
      expect(bloc.state.patients.first.id, 'jane');
    },
  );

  blocTest<PatientBloc, PatientState>(
    'the people that can\'t be read show as a failure',
    setUp: () => holders.loadError = StateError('database closed'),
    build: build,
    act: (bloc) => bloc.add(const PatientInitialised()),
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(
        bloc.state.status,
        PatientStatus.failure(holders.loadError!),
      );
      expect(bloc.state.patients, isEmpty);
    },
  );

  blocTest<PatientBloc, PatientState>(
    'a blood type that can\'t be read shows as none, the others still show',
    setUp: () => editService.unreadable.add('jane'),
    build: build,
    act: (bloc) => bloc.add(const PatientInitialised()),
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(bloc.state.bloodTypes, {'jane': null, 'tom': null});
      expect(bloc.state.status, const PatientStatus.success());
    },
  );

  blocTest<PatientBloc, PatientState>(
    'asking for the blood types again shows one saved meanwhile',
    build: build,
    act: (bloc) async {
      bloc.add(const PatientInitialised());
      await Future<void>.delayed(Duration.zero);
      editService.bloodTypes['tom'] = 'O-';
      bloc.add(const PatientBloodTypesRequested());
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) =>
        expect(bloc.state.bloodTypes, {'jane': 'A+', 'tom': 'O-'}),
  );

  blocTest<PatientBloc, PatientState>(
    'reading the patients again puts the selected person first and opens '
    'their card',
    setUp: () => prefs.setString('selected_holder_id', 'tom'),
    build: build,
    act: (bloc) => bloc.add(const PatientPatientsLoaded()),
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(bloc.state.patients.map((p) => p.id), ['tom', 'jane']);
      expect(bloc.state.selectedPatientId, 'tom');
      expect(bloc.state.expandedPatientIds, {'tom'});
    },
  );

  blocTest<PatientBloc, PatientState>(
    'passes on whom to ask about, and an answer is saved and read again',
    build: () {
      holders.directory = const HolderDirectory(
        holders: [janeHolder, tomHolder],
        questions: [
          HolderAsk(
            HolderQuestion(sourceIds: ['kaiser'], newHolderId: 'p9'),
            anna,
          ),
        ],
      );
      return build();
    },
    act: (bloc) async {
      bloc.add(const PatientInitialised());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.holderQuestions.single.patient.id, 'p9');
      holders.directory = const HolderDirectory(
        holders: [janeHolder, tomHolder],
      );
      bloc.add(
        PatientHolderAnswered(
          ask: bloc.state.holderQuestions.single,
          holderId: 'tom',
        ),
      );
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(holders.answers, ['kaiser → tom']);
      expect(bloc.state.holderQuestions, isEmpty);
    },
  );

  blocTest<PatientBloc, PatientState>(
    'an answer that can\'t be saved still reads the people again',
    build: () {
      holders.directory = const HolderDirectory(
        holders: [janeHolder, tomHolder],
        questions: [
          HolderAsk(
            HolderQuestion(sourceIds: ['kaiser'], newHolderId: 'p9'),
            anna,
          ),
        ],
      );
      return build();
    },
    act: (bloc) async {
      bloc.add(const PatientInitialised());
      await Future<void>.delayed(Duration.zero);
      holders
        ..answerError = StateError('database closed')
        ..directory = const HolderDirectory(
          holders: [janeHolder, tomHolder, annaHolder],
        );
      bloc.add(
        PatientHolderAnswered(
          ask: bloc.state.holderQuestions.single,
          holderId: 'tom',
        ),
      );
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(holders.answers, isEmpty);
      expect(bloc.state.patients.map((p) => p.id), ['jane', 'tom', 'p9']);
      expect(bloc.state.status, const PatientStatus.success());
    },
  );

  group('a selection made elsewhere', () {
    blocTest<PatientBloc, PatientState>(
      'moves that person first and opens their card',
      build: build,
      act: (bloc) async {
        bloc.add(const PatientInitialised());
        await Future<void>.delayed(Duration.zero);
        await selection.select('tom');
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.patients.map((p) => p.id), ['tom', 'jane']);
        expect(bloc.state.selectedPatientId, 'tom');
        expect(bloc.state.expandedPatientIds, {'tom'});
      },
    );

    blocTest<PatientBloc, PatientState>(
      'the people read again keep their order and open card, a new person '
      'comes last',
      build: build,
      act: (bloc) async {
        bloc.add(const PatientInitialised());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PatientSelectionChanged(patientId: 'tom'));
        await Future<void>.delayed(Duration.zero);
        holders.directory = const HolderDirectory(
          holders: [janeHolder, annaHolder, tomHolder],
        );
        await selection.refresh();
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.patients.map((p) => p.id), ['tom', 'jane', 'p9']);
        expect(bloc.state.selectedPatientId, 'tom');
        expect(bloc.state.expandedPatientIds, {'tom'});
        expect(bloc.state.bloodTypes.keys, ['tom', 'jane', 'p9']);
      },
    );
  });

  group('selecting a patient directly', () {
    blocTest<PatientBloc, PatientState>(
      'moves them first, opens their card and selects their person',
      build: build,
      act: (bloc) async {
        bloc.add(const PatientInitialised());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PatientSelectionChanged(patientId: 'tom'));
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.patients.map((p) => p.id), ['tom', 'jane']);
        expect(bloc.state.selectedPatientId, 'tom');
        expect(bloc.state.expandedPatientIds, {'tom'});
        expect(selection.scope.holder?.id, 'tom');
      },
    );

    blocTest<PatientBloc, PatientState>(
      'shows a failure when the selection can\'t be saved',
      build: () {
        selection = _FailingHolderSelection(holders, prefs);
        return build();
      },
      act: (bloc) async {
        bloc.add(const PatientInitialised());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PatientSelectionChanged(patientId: 'jane'));
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.patients.map((p) => p.id), ['jane', 'tom']);
        expect(
          bloc.state.status.toString(),
          contains('preferences unavailable'),
        );
      },
    );
  });

  group('editing a patient', () {
    Future<void> load(PatientBloc bloc) async {
      bloc.add(const PatientInitialised());
      await Future<void>.delayed(Duration.zero);
    }

    PatientEditSaved edit(String patientId, {required String bloodType}) =>
        PatientEditSaved(
          patientId: patientId,
          family: 'Popescu',
          bloodType: bloodType,
          availableSources: const <Source>[],
        );

    blocTest<PatientBloc, PatientState>(
      'starting an edit holds the patient being edited',
      build: build,
      act: (bloc) async {
        await load(bloc);
        bloc.add(const PatientEditStarted('tom'));
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.isEditingPatient, isTrue);
        expect(bloc.state.editingPatient, tom);
      },
    );

    blocTest<PatientBloc, PatientState>(
      'an edit of a patient no longer listed holds the first one',
      build: build,
      act: (bloc) async {
        await load(bloc);
        bloc.add(const PatientEditStarted('gone'));
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) => expect(bloc.state.editingPatient, jane),
    );

    blocTest<PatientBloc, PatientState>(
      'cancelling an edit lets go of the patient',
      build: build,
      act: (bloc) async {
        await load(bloc);
        bloc
          ..add(const PatientEditStarted('jane'))
          ..add(const PatientEditCancelled());
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.isEditingPatient, isFalse);
        expect(bloc.state.editingPatient, isNull);
      },
    );

    blocTest<PatientBloc, PatientState>(
      'saving writes the details, keeps the blood type that did not change '
      'and keeps the open card open',
      build: build,
      act: (bloc) async {
        await load(bloc);
        bloc
          ..add(const PatientEditStarted('jane'))
          ..add(edit('jane', bloodType: 'A+'));
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(editService.saved, ['jane: Popescu']);
        expect(editService.bloodTypesWritten, isEmpty);
        expect(bloc.state.patients.map((p) => p.id), ['jane', 'tom']);
        expect(bloc.state.expandedPatientIds, {'jane'});
        expect(bloc.state.isEditingPatient, isFalse);
        expect(bloc.state.editingPatient, isNull);
        expect(bloc.state.animationPhase, PatientAnimationPhase.none);
        expect(bloc.state.status, const PatientStatus.success());
      },
    );

    blocTest<PatientBloc, PatientState>(
      'saving a changed blood type writes it and shows it',
      build: build,
      act: (bloc) async {
        await load(bloc);
        bloc.add(edit('jane', bloodType: 'B+'));
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(editService.bloodTypesWritten, ['jane: B+']);
        expect(bloc.state.bloodTypes['jane'], 'B+');
      },
    );

    blocTest<PatientBloc, PatientState>(
      'saving a patient whose card is closed leaves every card closed',
      build: build,
      act: (bloc) async {
        await load(bloc);
        bloc.add(edit('tom', bloodType: 'O+'));
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(editService.saved, ['tom: Popescu']);
        expect(bloc.state.expandedPatientIds, isEmpty);
        expect(bloc.state.patients.map((p) => p.id), ['jane', 'tom']);
      },
    );

    blocTest<PatientBloc, PatientState>(
      'saving a patient no longer listed fails and ends the edit',
      build: build,
      act: (bloc) async {
        await load(bloc);
        bloc
          ..add(const PatientEditStarted('jane'))
          ..add(edit('gone', bloodType: 'A+'));
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(editService.saved, isEmpty);
        expect(
          bloc.state.status.toString(),
          contains('Patient not found: gone'),
        );
        expect(bloc.state.isEditingPatient, isFalse);
        expect(bloc.state.editingPatient, isNull);
      },
    );
  });

  group('switching patient by tapping their card', () {
    const motion = PatientBloc.switchCardMotion;
    const settle = PatientBloc.switchCardSettle;
    const open = PatientBloc.switchCardOpen;
    const details = PatientBloc.switchDetailsDelay;
    const gap = PatientBloc.switchStepGap;

    /// Runs [body] in fake time with the patients read (Jane first, her
    /// card open) and every state shown recorded, with when it was shown.
    void inFakeTime(
      void Function(
        FakeAsync async,
        PatientBloc bloc,
        List<(Duration, String)> shown,
      )
      body, {
      bool cardOpen = true,
    }) {
      fakeAsync((async) {
        final bloc = build()
          ..add(PatientPatientsLoaded(preserveOrder: !cardOpen));
        async.flushMicrotasks();
        expect(bloc.state.expandedPatientIds, cardOpen ? {'jane'} : isEmpty);

        final start = async.elapsed;
        final shown = <(Duration, String)>[];
        final subscription = bloc.stream.listen((state) {
          final step = (async.elapsed - start, _shown(state));
          // The selection the switch saves comes back through
          // HolderSelection.changes and is shown again unchanged.
          if (shown.lastOrNull?.$2 != step.$2) shown.add(step);
        });

        body(async, bloc, shown);

        unawaited(subscription.cancel());
        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    }

    test('closes the open card, moves the tapped patient first, selects '
        'their person and opens their card, in under 1 s', () {
      inFakeTime((async, bloc, shown) {
        bloc.add(const PatientReorder('tom'));
        final whole = motion * 2 + settle + open + gap * 2;
        async.elapse(whole - const Duration(milliseconds: 1));
        expect(bloc.state.animationPhase, isNot(PatientAnimationPhase.none));

        async.elapse(const Duration(milliseconds: 1));

        expect(whole, const Duration(milliseconds: 910));
        expect(whole, lessThan(const Duration(seconds: 1)));
        expect(shown, [
          (
            Duration.zero,
            'collapsing, tapped tom, open {jane}, list jane,tom, '
                'selected jane',
          ),
          (
            Duration.zero,
            'collapsing, tapped tom, closing jane, open {jane}, '
                'list jane,tom, selected jane',
          ),
          (
            motion,
            'collapsing, tapped tom, open {}, list jane,tom, selected jane',
          ),
          (
            motion + settle,
            'swapping, tapped tom, swapping jane→tom, open {}, '
                'list jane,tom, selected jane',
          ),
          (
            motion + settle + gap,
            'swapping, tapped tom, open {}, list tom,jane, selected tom',
          ),
          (
            motion * 2 + settle + gap,
            'expanding, tapped tom, opening tom, open {tom}, '
                'list tom,jane, selected tom',
          ),
          (
            motion * 2 + settle + gap + details,
            'expanding, tapped tom, open {tom}, list tom,jane, selected tom',
          ),
          (whole, 'none, open {tom}, list tom,jane, selected tom'),
        ]);
        expect(selection.scope.holder?.id, 'tom');
        expect(prefs.getString('selected_holder_id'), 'tom');
      });
    });

    test('tapping the patient whose card is open does nothing', () {
      inFakeTime((async, bloc, shown) {
        bloc.add(const PatientReorder('jane'));
        async.elapse(const Duration(seconds: 1));

        expect(shown, isEmpty);
        expect(bloc.state.patients.map((p) => p.id), ['jane', 'tom']);
        expect(bloc.state.expandedPatientIds, {'jane'});
      });
    });

    test('with no card open, skips closing one', () {
      inFakeTime(cardOpen: false, (async, bloc, shown) {
        bloc.add(const PatientReorder('tom'));
        final whole = motion + open + gap * 2;
        async.elapse(whole - const Duration(milliseconds: 1));
        expect(bloc.state.animationPhase, isNot(PatientAnimationPhase.none));

        async.elapse(const Duration(milliseconds: 1));

        expect(shown, [
          (
            Duration.zero,
            'collapsing, tapped tom, open {}, list jane,tom, selected jane',
          ),
          (
            Duration.zero,
            'swapping, tapped tom, swapping jane→tom, open {}, '
                'list jane,tom, selected jane',
          ),
          (gap, 'swapping, tapped tom, open {}, list tom,jane, selected tom'),
          (
            gap + motion,
            'expanding, tapped tom, opening tom, open {tom}, '
                'list tom,jane, selected tom',
          ),
          (
            gap + motion + details,
            'expanding, tapped tom, open {tom}, list tom,jane, selected tom',
          ),
          (whole, 'none, open {tom}, list tom,jane, selected tom'),
        ]);
        expect(selection.scope.holder?.id, 'tom');
      });
    });

    test('a second tap while switching is ignored', () {
      inFakeTime((async, bloc, shown) {
        holders.directory = const HolderDirectory(
          holders: [janeHolder, tomHolder, annaHolder],
        );
        bloc.add(const PatientPatientsLoaded(preserveOrder: true));
        async.flushMicrotasks();

        bloc.add(const PatientReorder('tom'));
        async.elapse(motion);
        bloc.add(const PatientReorder('p9'));
        async.elapse(const Duration(seconds: 1));

        expect(bloc.state.patients.map((p) => p.id), ['tom', 'jane', 'p9']);
        expect(bloc.state.expandedPatientIds, {'tom'});
        expect(selection.scope.holder?.id, 'tom');
      });
    });

    test('a patient no longer listed leaves the first one selected and no '
        'card open', () {
      inFakeTime((async, bloc, shown) {
        bloc.add(const PatientReorder('gone'));
        async.elapse(const Duration(seconds: 1));

        expect(bloc.state.patients.map((p) => p.id), ['jane', 'tom']);
        expect(bloc.state.selectedPatientId, 'jane');
        expect(bloc.state.expandedPatientIds, {'gone'});
        expect(bloc.state.animationPhase, PatientAnimationPhase.none);
      });
    });
  });
}
