import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHolderService extends Fake implements HolderService {
  HolderDirectory directory = const HolderDirectory();

  @override
  Future<HolderDirectory> load() async => directory;
}

const jane = Holder(
  id: 'jane',
  representativePatient: Patient(id: 'jane', sourceId: 'wallet-jane'),
  sourceIds: ['epic', 'wallet-jane'],
  allPatientInstances: [
    Patient(id: 'jane', sourceId: 'wallet-jane'),
    Patient(id: 'p1', sourceId: 'epic'),
  ],
);
const tom = Holder(
  id: 'tom',
  representativePatient: Patient(id: 'tom', sourceId: 'wallet-tom'),
  sourceIds: ['wallet-tom'],
  allPatientInstances: [Patient(id: 'tom', sourceId: 'wallet-tom')],
);

void main() {
  late _FakeHolderService holders;
  late SharedPreferences prefs;
  late HolderSelection selection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    holders = _FakeHolderService()
      ..directory = const HolderDirectory(holders: [jane, tom]);
    selection = HolderSelection(holders, prefs);
  });

  group('the records shown', () {
    test('are none before the people are read', () {
      expect(selection.scope.sourceIds, isEmpty);
    });

    test('are all records when the wallet has no one', () async {
      holders.directory = const HolderDirectory();
      expect((await selection.refresh()).sourceIds, isNull);
    });

    test("are the selected person's sources, or the one filtered on", () async {
      final scope = await selection.refresh();
      expect(scope.holder, same(jane));
      expect(scope.sourceIds, ['epic', 'wallet-jane']);
      expect(scope.patient!.id, 'jane');

      await selection.filter('epic');
      expect(selection.scope.sourceIds, ['epic']);
      expect(selection.scope.patient!.id, 'p1');
    });

    test("a filter outside the person's sources shows all of them", () async {
      await selection.refresh();
      await selection.filter('wallet-tom');
      expect(selection.scope.sourceFilter, isNull);
      expect(selection.scope.sourceIds, ['epic', 'wallet-jane']);
    });
  });

  test('another person drops a filter that is not theirs', () async {
    await selection.refresh();
    await selection.filter('epic');
    await selection.select('tom');
    expect(selection.scope.holder, same(tom));
    expect(selection.scope.sourceFilter, isNull);
  });

  test('the selection is kept for the next start', () async {
    await selection.refresh();
    await selection.select('tom');
    await selection.filter('wallet-tom');

    final next = await HolderSelection(holders, prefs).refresh();
    expect(next.holder, same(tom));
    expect(next.sourceFilter, 'wallet-tom');
  });

  test(
    'a Patient row id saved by an older version selects its person',
    () async {
      await prefs.setString('selected_patient_id', 'p1');
      expect((await selection.refresh()).holder, same(jane));
    },
  );

  test(
    'a person not read yet is selected once the people are read again',
    () async {
      await selection.refresh();
      await selection.select('anna');
      expect(selection.scope.holder, same(jane));

      const anna = Holder(
        id: 'anna',
        representativePatient: Patient(id: 'anna', sourceId: 'wallet-anna'),
        sourceIds: ['wallet-anna'],
        allPatientInstances: [],
      );
      holders.directory = const HolderDirectory(holders: [jane, tom, anna]);
      expect((await selection.refresh()).holder, same(anna));
    },
  );

  test(
    'a deleted source no longer filters once the people are read again',
    () async {
      await selection.refresh();
      await selection.filter('epic');
      holders.directory = const HolderDirectory(
        holders: [
          Holder(
            id: 'jane',
            representativePatient: Patient(id: 'jane', sourceId: 'wallet-jane'),
            sourceIds: ['wallet-jane'],
            allPatientInstances: [],
          ),
          tom,
        ],
      );
      expect((await selection.refresh()).sourceFilter, isNull);
    },
  );

  test('every change is published', () async {
    final seen = <String?>[];
    selection.changes.listen((s) => seen.add(s.sourceFilter ?? s.holder?.id));
    await selection.refresh();
    await selection.filter('epic');
    await selection.select('tom');
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['jane', 'epic', 'tom']);
  });
}
