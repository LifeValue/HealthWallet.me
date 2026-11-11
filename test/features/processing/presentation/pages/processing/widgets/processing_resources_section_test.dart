import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/widgets/processing_resources_section.dart';
import 'package:health_wallet/features/processing/presentation/widgets/attach_to_encounter/attach_to_encounter_widget.dart';
import 'package:health_wallet/features/processing/presentation/widgets/attach_to_encounter/bloc/attach_to_encounter_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';

class _MockUserBloc extends MockBloc<UserEvent, UserState>
    implements UserBloc {}

/// Records the events it is sent instead of running them.
class _MockProcessingBloc extends MockBloc<ProcessingEvent, ProcessingState>
    implements ProcessingBloc {
  final added = <ProcessingEvent>[];

  @override
  void add(ProcessingEvent event) => added.add(event);
}

/// Opens with a patient and an encounter already picked, so its confirm
/// button returns them.
class _MockAttachToEncounterBloc
    extends MockBloc<AttachToEncounterEvent, AttachToEncounterState>
    implements AttachToEncounterBloc {
  @override
  void add(AttachToEncounterEvent event) {}
}

final _en = lookupAppLocalizations(const Locale('en'));

const _picked = (
  StagedPatient(draft: MappingPatient(id: 'p-picked')),
  StagedEncounter(draft: MappingEncounter(id: 'e-picked')),
);

const _linked = StagedPatient(
  existing: Patient(id: 'p1', title: 'Ana Pop'),
  mode: ImportMode.linkExisting,
);

const _extracted = ProcessingSession(
  id: 's',
  status: ProcessingStatus.patientExtracted,
);

void main() {
  setUpAll(initializeDateFormatting);

  late _MockProcessingBloc processingBloc;
  late int scrolledToErrors;
  late int saves;

  setUp(() {
    scrolledToErrors = 0;
    saves = 0;
    final attachBloc = _MockAttachToEncounterBloc();
    whenListen(
      attachBloc,
      const Stream<AttachToEncounterState>.empty(),
      initialState: AttachToEncounterState(
        status: AttachToEncounterStatus.success,
        patient: _picked.$1,
        encounter: _picked.$2,
      ),
    );
    getIt
      ..registerSingleton<AppPlatform>(AppPlatform.mobile)
      ..registerFactory<AttachToEncounterBloc>(() => attachBloc);
  });

  tearDown(getIt.reset);

  Future<void> pump(
    WidgetTester tester, {
    required ProcessingState state,
    ProcessingSession session = _extracted,
    DeviceAiCapability capability = DeviceAiCapability.full,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final userBloc = _MockUserBloc();
    whenListen(
      userBloc,
      const Stream<UserState>.empty(),
      initialState: const UserState(),
    );
    processingBloc = _MockProcessingBloc();
    whenListen(
      processingBloc,
      const Stream<ProcessingState>.empty(),
      initialState: state,
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<UserBloc>.value(value: userBloc),
            BlocProvider<ProcessingBloc>.value(value: processingBloc),
          ],
          child: Scaffold(
            body: SingleChildScrollView(
              child: ProcessingResourcesSection(
                state: state,
                displayedSession: session,
                sessionId: session.id,
                formKey: GlobalKey<FormState>(),
                encounterSectionKey: GlobalKey(),
                deviceCapability: capability,
                onScrollToFormErrors: () => scrolledToErrors++,
                onSaveResources: () => saves++,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  AppButton continueButton(WidgetTester tester) => tester.widget<AppButton>(
    find.widgetWithText(AppButton, _en.continueProcessing),
  );

  group('step two', () {
    testWidgets('a device without the memory for Deep Scan says so and still '
        'continues, from the text', (tester) async {
      await pump(
        tester,
        state: const ProcessingState(sessions: [_extracted], useVision: true),
        capability: DeviceAiCapability.basicOnly,
      );

      expect(find.text(_en.processingStep2NotAvailableTitle), findsOne);
      expect(find.text(_en.processingStep2NotEnoughRam), findsOne);
      expect(continueButton(tester).enabled, isTrue);

      await tester.tap(find.text(_en.continueProcessing));
      expect(processingBloc.added, [
        const ProcessRemainingResources(sessionId: 's'),
      ]);
    });

    testWidgets('a device with Deep Scan off has no notice', (tester) async {
      await pump(
        tester,
        state: const ProcessingState(sessions: [_extracted]),
        capability: DeviceAiCapability.basicOnly,
      );

      expect(find.text(_en.processingStep2NotAvailableTitle), findsNothing);
      expect(continueButton(tester).enabled, isTrue);
    });

    testWidgets('a device with the memory for Deep Scan has no notice', (
      tester,
    ) async {
      await pump(
        tester,
        state: const ProcessingState(sessions: [_extracted], useVision: true),
      );

      expect(find.text(_en.processingStep2NotAvailableTitle), findsNothing);
      expect(continueButton(tester).enabled, isTrue);
    });

    testWidgets('waits while another document is being processed', (
      tester,
    ) async {
      await pump(
        tester,
        state: const ProcessingState(
          sessions: [
            _extracted,
            ProcessingSession(id: 'busy', status: ProcessingStatus.processing),
          ],
        ),
      );

      expect(continueButton(tester).enabled, isFalse);
      await tester.tap(find.text(_en.continueProcessing));
      expect(processingBloc.added, isEmpty);
    });
  });

  testWidgets('shows nothing while the document is being read', (
    tester,
  ) async {
    const reading = ProcessingSession(
      id: 's',
      status: ProcessingStatus.processing,
    );
    await pump(
      tester,
      state: const ProcessingState(sessions: [reading]),
      session: reading,
    );

    expect(find.text(_en.continueProcessing), findsNothing);
    expect(find.text(_en.done), findsNothing);
  });

  group('a draft', () {
    const draft = ProcessingSession(id: 's', status: ProcessingStatus.draft);

    testWidgets('Done saves the records', (tester) async {
      await pump(
        tester,
        state: const ProcessingState(sessions: [draft]),
        session: draft,
      );

      await tapText(tester, _en.done);

      expect(saves, 1);
    });

    testWidgets('Done waits while the records are being saved', (
      tester,
    ) async {
      await pump(
        tester,
        state: const ProcessingState(
          sessions: [draft],
          status: PipelineStatus.savingResources(),
        ),
        session: draft,
      );

      await tester.tap(find.text(_en.done));

      expect(saves, 0);
    });

    testWidgets('adds the record types picked in the dialog', (tester) async {
      await pump(
        tester,
        state: const ProcessingState(sessions: [draft]),
        session: draft,
      );

      await tapText(tester, _en.addResources);
      expect(find.text(_en.addResourcesTitle), findsOne);
      await tapText(tester, _en.condition);
      await tapText(tester, _en.observation);
      await tapText(tester, _en.add);

      expect(processingBloc.added, [
        const ResourcesAdded(
          sessionId: 's',
          resourceTypes: ['Condition', 'Observation'],
        ),
      ]);
    });

    testWidgets('a closed dialog adds nothing', (tester) async {
      await pump(
        tester,
        state: const ProcessingState(sessions: [draft]),
        session: draft,
      );

      await tapText(tester, _en.addResources);
      await tapText(tester, _en.cancel);

      expect(processingBloc.added, isEmpty);
    });
  });

  group('after the patient step', () {
    testWidgets('a picked patient and visit attach the document at once', (
      tester,
    ) async {
      const ready = ProcessingSession(
        id: 's',
        status: ProcessingStatus.patientExtracted,
        patient: _linked,
        encounter: StagedEncounter(
          draft: MappingEncounter(
            id: 'e',
            encounterType: MappedProperty(value: 'Checkup'),
            periodStart: MappedProperty(value: '2024-03-01'),
            specialty: MappedProperty(value: 'Cardiology'),
          ),
          mode: ImportMode.createNew,
        ),
      );
      await pump(
        tester,
        state: const ProcessingState(sessions: [ready]),
        session: ready,
      );

      await tapText(tester, _en.attachToEncounter);

      expect(processingBloc.added, [
        const DocumentAttached(sessionId: 's'),
      ]);
    });

    testWidgets('a report attaches to its patient only', (tester) async {
      const report = ProcessingSession(
        id: 's',
        status: ProcessingStatus.patientExtracted,
        patient: _linked,
        diagnosticReport: StagedDiagnosticReport(
          draft: MappingDiagnosticReport(
            id: 'r',
            reportName: MappedProperty(value: 'CBC'),
            issuedDate: MappedProperty(value: '2024-03-01'),
          ),
        ),
      );
      await pump(
        tester,
        state: const ProcessingState(sessions: [report]),
        session: report,
      );

      await tapText(tester, _en.attachToPatient);

      expect(processingBloc.added, [
        const DocumentAttached(sessionId: 's'),
      ]);
    });

    testWidgets('a visit with a missing field shows the field instead', (
      tester,
    ) async {
      const incomplete = ProcessingSession(
        id: 's',
        status: ProcessingStatus.patientExtracted,
        patient: _linked,
        encounter: StagedEncounter(
          draft: MappingEncounter(id: 'e'),
          mode: ImportMode.createNew,
        ),
      );
      await pump(
        tester,
        state: const ProcessingState(sessions: [incomplete]),
        session: incomplete,
      );

      await tapText(tester, _en.attachToEncounter);

      expect(scrolledToErrors, 1);
      expect(processingBloc.added, isEmpty);
    });

    testWidgets('otherwise asks where the document goes, then attaches it', (
      tester,
    ) async {
      await pump(
        tester,
        state: const ProcessingState(sessions: [_extracted]),
      );

      await tapText(tester, _en.attachToEncounter);
      expect(find.byType(AttachToEncounterWidget), findsOne);
      await tapText(tester, _en.attachToEncounter);

      expect(processingBloc.added, [
        EncounterAttached(
          sessionId: 's',
          patient: _picked.$1,
          encounter: _picked.$2,
        ),
        const DocumentAttached(sessionId: 's'),
      ]);
    });

    testWidgets('a report with a new patient asks for the patient only', (
      tester,
    ) async {
      const report = ProcessingSession(
        id: 's',
        status: ProcessingStatus.patientExtracted,
        diagnosticReport: StagedDiagnosticReport(
          draft: MappingDiagnosticReport(
            id: 'r',
            reportName: MappedProperty(value: 'CBC'),
            issuedDate: MappedProperty(value: '2024-03-01'),
          ),
        ),
      );
      await pump(
        tester,
        state: const ProcessingState(sessions: [report]),
        session: report,
      );

      await tapText(tester, _en.attachToPatient);
      final dialog = tester.widget<AttachToEncounterWidget>(
        find.byType(AttachToEncounterWidget),
      );
      expect(dialog.patientOnly, isTrue);
      expect(dialog.confirmText, _en.attachToPatient);
      await tapText(tester, _en.attachToPatient);

      expect(processingBloc.added.last, const DocumentAttached(sessionId: 's'));
    });

    testWidgets('a closed dialog attaches nothing', (tester) async {
      await pump(
        tester,
        state: const ProcessingState(sessions: [_extracted]),
      );

      await tapText(tester, _en.attachToEncounter);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      expect(find.byType(AttachToEncounterWidget), findsOne);
      Navigator.of(
        tester.element(find.byType(AttachToEncounterWidget)),
      ).pop();
      await tester.pumpAndSettle();

      expect(processingBloc.added, isEmpty);
    });

    group('once attached, Done', () {
      testWidgets('asks first, then saves', (tester) async {
        const attached = ProcessingSession(
          id: 's',
          status: ProcessingStatus.patientExtracted,
          isDocumentAttached: true,
        );
        await pump(
          tester,
          state: const ProcessingState(sessions: [attached]),
          session: attached,
        );

        await tapText(tester, _en.done);
        expect(find.text(_en.finishProcessingMessage), findsOne);
        await tapText(tester, _en.done);

        expect(processingBloc.added, [
          const ResourceCreationInitiated(sessionId: 's'),
        ]);
      });

      testWidgets('warns that a changed patient is updated', (tester) async {
        const changed = ProcessingSession(
          id: 's',
          status: ProcessingStatus.patientExtracted,
          isDocumentAttached: true,
          patient: StagedPatient(
            draft: MappingPatient(id: 'p-draft'),
            existing: Patient(id: 'p1', title: 'Ana Pop'),
            mode: ImportMode.linkExisting,
          ),
        );
        await pump(
          tester,
          state: const ProcessingState(sessions: [changed]),
          session: changed,
        );

        await tapText(tester, _en.done);
        expect(find.text(_en.patientModifiedUpdating('Ana Pop')), findsOne);
        await tapText(tester, _en.save);

        expect(processingBloc.added, [
          const ResourceCreationInitiated(sessionId: 's'),
        ]);
      });
    });

    testWidgets('a document that can\'t be sent ignores the desktop link', (
      tester,
    ) async {
      await pump(
        tester,
        state: const ProcessingState(sessions: [_extracted]),
      );

      await tapText(tester, _en.continueProcessingOnDesktop);

      expect(find.byType(Dialog), findsNothing);
      expect(processingBloc.added, isEmpty);
    });

    testWidgets('the desktop has no link to itself', (tester) async {
      await getIt.unregister<AppPlatform>();
      getIt.registerSingleton<AppPlatform>(AppPlatform.desktop);
      await pump(
        tester,
        state: const ProcessingState(sessions: [_extracted]),
      );

      expect(find.text(_en.continueProcessingOnDesktop), findsNothing);
    });
  });
}
