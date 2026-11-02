import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/home/presentation/widgets/source/source_selector_widget.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';

import '../../../../../helpers/log_capture.dart';

class _MockPatientBloc extends MockBloc<PatientEvent, PatientState>
    implements PatientBloc {}

const _sources = [
  Source(id: 'clinic', labelSource: 'City Clinic'),
  Source(id: 'lab', labelSource: 'Lab Results'),
];

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  final logs = captureLogs();
  late _MockPatientBloc patientBloc;
  late List<(String, List<String>?)> changes;

  setUp(() {
    changes = [];
    patientBloc = _MockPatientBloc();
    whenListen(
      patientBloc,
      const Stream<PatientState>.empty(),
      initialState: const PatientState(
        selectedPatientId: 'p1',
        patientGroups: {
          'p1': Holder(
            id: 'p1',
            representativePatient: Patient(id: 'p1'),
            sourceIds: ['clinic', 'lab'],
            allPatientInstances: [],
          ),
        },
      ),
    );
  });

  Widget selector() => SourceSelectorWidget(
    sources: _sources,
    selectedSource: 'clinic',
    onSourceChanged: (id, sourceIds) => changes.add((id, sourceIds)),
  );

  /// The home screen, with the selector shown while [showSelector] is true.
  Widget app(ValueNotifier<bool> showSelector) =>
      BlocProvider<PatientBloc>.value(
        value: patientBloc,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: showSelector,
                builder: (_, show, _) => show ? selector() : const SizedBox(),
              ),
            ),
          ),
        ),
      );

  Future<void> openList(WidgetTester tester) async {
    await tester.tap(find.text('City Clinic'));
    await tester.pumpAndSettle();
  }

  testWidgets('picking All passes the selected patient\'s sources', (
    tester,
  ) async {
    await tester.pumpWidget(app(ValueNotifier(true)));
    await openList(tester);

    await tester.tap(find.text(_en.all));
    await tester.pumpAndSettle();

    final (id, sourceIds) = changes.single;
    expect(id, 'All');
    expect(sourceIds, ['clinic', 'lab']);
  });

  testWidgets('picking one source passes no source filter', (tester) async {
    await tester.pumpWidget(app(ValueNotifier(true)));
    await openList(tester);

    await tester.tap(find.text('Lab Results').last);
    await tester.pumpAndSettle();

    expect(changes, [('lab', null)]);
  });

  testWidgets('when the patients cannot be read any more, All is still '
      'picked, without a filter, and the failure is logged', (tester) async {
    final showSelector = ValueNotifier(true);
    addTearDown(showSelector.dispose);
    await tester.pumpWidget(app(showSelector));
    await openList(tester);

    // The page under the open list rebuilds without the selector.
    showSelector.value = false;
    await tester.pump();
    await tester.tap(find.text(_en.all));
    await tester.pumpAndSettle();

    expect(changes, [('All', null)]);
    expect(logs, loggedWarning('Could not read the selected patient sources'));
  });
}
