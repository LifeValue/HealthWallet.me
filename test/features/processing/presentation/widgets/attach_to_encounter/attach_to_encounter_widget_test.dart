import 'dart:async';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/presentation/widgets/attach_to_encounter/attach_to_encounter_widget.dart';
import 'package:health_wallet/features/processing/presentation/widgets/attach_to_encounter/bloc/attach_to_encounter_bloc.dart';
import 'package:health_wallet/features/processing/presentation/widgets/attach_to_encounter/encounter_selector.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

/// Records the events the dialog sends instead of running them.
class _MockAttachToEncounterBloc
    extends MockBloc<AttachToEncounterEvent, AttachToEncounterState>
    implements AttachToEncounterBloc {
  final events = <AttachToEncounterEvent>[];

  @override
  void add(AttachToEncounterEvent event) => events.add(event);
}

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  late _MockAttachToEncounterBloc bloc;
  late StreamController<AttachToEncounterState> states;

  setUp(() {
    bloc = _MockAttachToEncounterBloc();
    states = StreamController<AttachToEncounterState>();
    whenListen(
      bloc,
      states.stream,
      initialState: const AttachToEncounterState(
        status: AttachToEncounterStatus.success,
      ),
    );
    getIt.registerFactory<AttachToEncounterBloc>(() => bloc);
  });

  tearDown(() async {
    await states.close();
    await getIt.reset();
  });

  Future<void> pumpDialog(
    WidgetTester tester, {
    bool patientOnly = false,
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AttachToEncounterWidget(
            confirmText: 'Confirm',
            patientOnly: patientOnly,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starts the bloc with empty selections', (tester) async {
    await pumpDialog(tester);

    expect(find.text(_en.attachToEncounter), findsOne);
    expect(bloc.events.first, isA<AttachToEncounterStarted>());
  });

  testWidgets('a failure shows its message in a snackbar', (tester) async {
    await pumpDialog(tester);

    states.add(
      const AttachToEncounterState(
        status: AttachToEncounterStatus.failure,
        errorMessage: 'Could not load the encounters',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(AppSnackBar.cardKey),
        matching: find.text('Could not load the encounters'),
      ),
      findsOne,
    );

    // Let the snackbar time out so no timer is left pending.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a failure without a message shows no snackbar', (tester) async {
    await pumpDialog(tester);

    states.add(
      const AttachToEncounterState(status: AttachToEncounterStatus.failure),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(AppSnackBar.cardKey), findsNothing);
  });

  group('with a patient chosen and no encounter', () {
    const chosen = AttachToEncounterState(
      status: AttachToEncounterStatus.success,
      patient: StagedPatient(
        existing: Patient(id: 'p1', title: 'Alexandru, Szilagyi'),
        mode: ImportMode.linkExisting,
      ),
    );

    bool confirmEnabled(WidgetTester tester) =>
        tester
            .widget<ElevatedButton>(
              find.ancestor(
                of: find.text('Confirm'),
                matching: find.byType(ElevatedButton),
              ),
            )
            .onPressed !=
        null;

    testWidgets('a scan filed under a report only picks the patient, and can '
        'be saved', (tester) async {
      await pumpDialog(tester, patientOnly: true);
      states.add(chosen);
      await tester.pumpAndSettle();

      expect(find.text(_en.attachToPatient), findsOne);
      expect(find.text(_en.attachToEncounter), findsNothing);
      expect(find.byType(EncounterSelector), findsNothing);
      expect(confirmEnabled(tester), isTrue);
    });

    testWidgets('a scan filed under an encounter still needs one', (
      tester,
    ) async {
      await pumpDialog(tester);
      states.add(chosen);
      await tester.pumpAndSettle();

      expect(find.byType(EncounterSelector), findsOne);
      expect(confirmEnabled(tester), isFalse);
    });
  });
}
