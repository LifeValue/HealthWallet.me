import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/holders/domain/services/holder_linker.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/user/domain/services/patient_edit_service.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHolderService extends Fake implements HolderService {
  _FakeHolderService(this.directory);

  HolderDirectory directory;
  final answers = <String>[];

  @override
  Future<HolderDirectory> load() async => directory;

  @override
  Future<void> answer(HolderQuestion question, {String? holderId}) async =>
      answers.add('${question.sourceIds.join(',')} → $holderId');
}

class _FakePatientEditService extends Fake implements PatientEditService {
  @override
  Future<String?> getCurrentBloodType(Patient patient) async =>
      patient.id == 'jane' ? 'A+' : null;
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

void main() {
  late _FakeHolderService holders;
  late SharedPreferences prefs;

  PatientBloc build() => PatientBloc(
    holders,
    HolderSelection(holders, prefs),
    _FakePatientEditService(),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    holders = _FakeHolderService(
      const HolderDirectory(holders: [janeHolder, tomHolder]),
    );
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
}
