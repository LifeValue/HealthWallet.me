import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/core/utils/date_format_utils.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/core/widgets/app_message_card.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extraction_service.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/processing_page.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/widgets/processing_mapping_section.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/widgets/processing_resources_section.dart';
import 'package:health_wallet/features/processing/presentation/widgets/attach_to_encounter/attach_to_encounter_widget.dart';
import 'package:health_wallet/features/processing/presentation/widgets/attach_to_encounter/bloc/attach_to_encounter_bloc.dart';
import 'package:health_wallet/features/processing/presentation/widgets/preview_card.dart';
import 'package:health_wallet/features/processing/presentation/widgets/summary_card.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:image/image.dart' as img;

/// Records the events the page sends instead of running them.
class _MockProcessingBloc extends MockBloc<ProcessingEvent, ProcessingState>
    implements ProcessingBloc {
  final events = <ProcessingEvent>[];

  @override
  void add(ProcessingEvent event) => events.add(event);
}

class _MockUserBloc extends MockBloc<UserEvent, UserState>
    implements UserBloc {}

/// Opens with a patient and an encounter already picked, so its confirm
/// button returns them.
class _MockAttachToEncounterBloc
    extends MockBloc<AttachToEncounterEvent, AttachToEncounterState>
    implements AttachToEncounterBloc {
  @override
  void add(AttachToEncounterEvent event) {}
}

class _FakeDeviceCapabilityService extends Fake
    implements DeviceCapabilityService {
  @override
  Future<DeviceAiCapability> getCapability() async => DeviceAiCapability.full;
}

/// Records the dashboard page the screen jumps to.
class _FakeNavigation extends Fake implements PageViewNavigationController {
  final jumps = <int>[];

  @override
  void jumpToPage(int pageIndex) => jumps.add(pageIndex);
}

class _FakeProcessingRepository extends Fake implements ProcessingRepository {
  @override
  Future<bool> checkModelExistence() async => false;
}

/// No model and no known layout: the session can't be processed here.
class _FakeLayoutExtractionService extends Fake
    implements LayoutExtractionService {
  @override
  Future<bool> canProcess(
    String sessionId, {
    required List<String> filePaths,
    List<String>? imagePaths,
  }) async => false;
}

final _en = lookupAppLocalizations(const Locale('en'));

const _picked = (
  StagedPatient(draft: MappingPatient(id: 'p-picked')),
  StagedEncounter(draft: MappingEncounter(id: 'e-picked')),
);

void main() {
  late _MockProcessingBloc bloc;
  late StreamController<ProcessingState> states;
  late _FakeNavigation navigation;
  late Directory dir;
  late String pagePath;

  setUp(() {
    bloc = _MockProcessingBloc();
    states = StreamController<ProcessingState>();
    navigation = _FakeNavigation();
    dir = Directory.systemTemp.createTempSync('hw_processing_page_');
    pagePath = '${dir.path}/page.png';
    File(
      pagePath,
    ).writeAsBytesSync(img.encodePng(img.Image(width: 4, height: 2)));
  });

  tearDown(() async {
    await states.close();
    await getIt.reset();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<void> pumpPage(
    WidgetTester tester,
    ProcessingState initial, {
    AppPlatform platform = AppPlatform.mobile,
    bool attachOnly = false,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

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
    final userBloc = _MockUserBloc();
    whenListen(
      userBloc,
      const Stream<UserState>.empty(),
      initialState: const UserState(),
    );
    whenListen(bloc, states.stream, initialState: initial);
    getIt
      ..registerSingleton<AppPlatform>(platform)
      ..registerSingleton<PageViewNavigationController>(navigation)
      ..registerSingleton<DeviceCapabilityService>(
        _FakeDeviceCapabilityService(),
      )
      ..registerSingleton<ProcessingRepository>(_FakeProcessingRepository())
      ..registerSingleton<LayoutExtractionService>(
        _FakeLayoutExtractionService(),
      )
      ..registerFactory<AttachToEncounterBloc>(() => attachBloc);

    // Built at run time, as the router builds it.
    final sessionId = ['s', '1'].join();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ProcessingBloc>.value(value: bloc),
            BlocProvider<UserBloc>.value(value: userBloc),
          ],
          child: ProcessingPage(sessionId: sessionId, attachOnly: attachOnly),
        ),
      ),
    );
    // Lets the device check and file lookups finish; spinners never settle.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(bloc.events.first, SessionActivated(sessionId: sessionId));
    bloc.events.clear();
  }

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await frames(tester);
  }

  ProcessingState stateWith(
    ProcessingSession session, {
    PipelineStatus status = const PipelineStatus.initial(),
    bool withPages = true,
  }) => ProcessingState(
    status: status,
    sessions: [session],
    sessionImagePaths: {
      if (withPages) 's1': [pagePath],
    },
  );

  /// A widget test that unmounts the page at the end, so the preview's image
  /// retries stop before the test checks for pending timers.
  void testPage(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  Finder retryButton() => find.widgetWithIcon(IconButton, Icons.refresh);

  IconButton tuneButton(WidgetTester tester) =>
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.tune));

  group('states', () {
    testPage('a session that is gone says so', (tester) async {
      await pumpPage(tester, const ProcessingState());

      expect(find.text(_en.sessionNotFound), findsOne);
      expect(retryButton(), findsNothing);
      expect(tuneButton(tester).onPressed, isNotNull);
    });

    testPage('a queued session without pages shows the preview is being '
        'prepared', (tester) async {
      await pumpPage(
        tester,
        const ProcessingState(sessions: [ProcessingSession(id: 's1')]),
      );

      expect(find.text(_en.preparingPreview), findsOne);
      expect(find.byType(SummaryCard), findsNothing);
    });

    testPage('converting the PDFs shows the preview is being prepared, '
        'even for a draft', (tester) async {
      await pumpPage(
        tester,
        stateWith(
          const ProcessingSession(id: 's1', status: ProcessingStatus.draft),
          status: const PipelineStatus.convertingPdfs(),
          withPages: false,
        ),
      );

      expect(find.text(_en.preparingPreview), findsOne);
    });

    testPage('a queued session with pages shows them and waits for the '
        'model', (tester) async {
      await pumpPage(tester, stateWith(const ProcessingSession(id: 's1')));

      expect(find.byType(SummaryCard), findsOne);
      expect(find.byType(PreviewCard), findsOne);
      expect(find.text(_en.aiModelNotAvailable), findsOne);
      expect(retryButton(), findsNothing);
    });

    testPage('a draft without pages shows the review form without a '
        'preview', (tester) async {
      await pumpPage(
        tester,
        stateWith(
          const ProcessingSession(id: 's1', status: ProcessingStatus.draft),
          withPages: false,
        ),
      );

      expect(find.byType(SummaryCard), findsOne);
      expect(find.byType(PreviewCard), findsNothing);
      expect(find.text(_en.done), findsOne);
    });
  });

  group('app bar', () {
    testPage('a draft retries step two', (tester) async {
      await pumpPage(
        tester,
        stateWith(
          const ProcessingSession(id: 's1', status: ProcessingStatus.draft),
        ),
      );

      expect(
        tester.widget<IconButton>(retryButton()).tooltip,
        _en.retryStep(2),
      );
      await tester.tap(retryButton());
      await tester.pump();

      expect(bloc.events, [const ProcessRemainingResources(sessionId: 's1')]);
    });

    testPage('a session past step one retries step one', (tester) async {
      await pumpPage(
        tester,
        stateWith(
          const ProcessingSession(
            id: 's1',
            status: ProcessingStatus.patientExtracted,
          ),
        ),
      );

      expect(
        tester.widget<IconButton>(retryButton()).tooltip,
        _en.retryStep(1),
      );
      await tester.tap(retryButton());
      await tester.pump();

      expect(bloc.events, [const MappingInitiated(sessionId: 's1')]);
    });

    testPage('while processing there is no retry, the AI settings are '
        'off, and Cancel cancels', (tester) async {
      await pumpPage(
        tester,
        stateWith(
          const ProcessingSession(
            id: 's1',
            status: ProcessingStatus.processing,
          ),
        ),
      );

      expect(retryButton(), findsNothing);
      expect(tuneButton(tester).onPressed, isNull);

      await tapText(tester, _en.cancel);

      expect(bloc.events, [const MappingCancelled(sessionId: 's1')]);
    });
  });

  group('mapping section', () {
    testPage('a failed step one is retried from the failure', (
      tester,
    ) async {
      await pumpPage(
        tester,
        stateWith(
          const ProcessingSession(id: 's1'),
          status: const PipelineStatus.failure(error: 'boom'),
        ),
      );

      expect(find.text(_en.processingFailed), findsOne);
      await tapText(tester, _en.retry);

      expect(bloc.events, [const MappingInitiated(sessionId: 's1')]);
    });

    testPage('without a model the document can be attached as it is', (
      tester,
    ) async {
      await pumpPage(
        tester,
        stateWith(
          const ProcessingSession(id: 's1'),
          status: const PipelineStatus.failure(
            error: 'no model',
            reason: PipelineFailureReason.modelNotFound,
          ),
        ),
      );

      await tapText(tester, _en.attachWithoutProcessing);
      expect(find.byType(AttachToEncounterWidget), findsOne);
      await tapText(tester, _en.save);

      expect(bloc.events, [
        EncounterAttached(
          sessionId: 's1',
          patient: _picked.$1,
          encounter: _picked.$2,
        ),
        const ResourceCreationInitiated(sessionId: 's1'),
      ]);
    });

    testPage('attached from the no-model notice, the saved message names '
        'the visit', (tester) async {
      const failed = PipelineStatus.failure(
        error: 'no model',
        reason: PipelineFailureReason.modelNotFound,
      );
      const session = ProcessingSession(
        id: 's1',
        origin: ProcessingOrigin.import,
      );
      await pumpPage(tester, stateWith(session, status: failed));

      await tapText(tester, _en.attachWithoutProcessing);
      await tapText(tester, _en.save);
      states.add(
        stateWith(
          session.copyWith(
            encounter: const StagedEncounter(
              existing: Encounter(id: 'e1', title: 'Checkup'),
            ),
          ),
          status: const PipelineStatus.success(sessionId: 's1'),
        ),
      );
      await frames(tester);

      expect(find.text(_en.recordsSavedTitle), findsOne);
      expect(find.text(_en.documentAttachedTo('Checkup')), findsOne);
    });

    testPage('closing the attach dialog without a choice sends nothing', (
      tester,
    ) async {
      await pumpPage(
        tester,
        stateWith(
          const ProcessingSession(id: 's1'),
          status: const PipelineStatus.failure(
            error: 'no model',
            reason: PipelineFailureReason.modelNotFound,
          ),
        ),
      );

      await tapText(tester, _en.attachWithoutProcessing);
      await tapText(tester, _en.cancel);

      expect(find.byType(AttachToEncounterWidget), findsNothing);
      expect(bloc.events, isEmpty);
    });

    testPage('a session without files is not handed to the desktop', (
      tester,
    ) async {
      await pumpPage(tester, stateWith(const ProcessingSession(id: 's1')));

      await tapText(tester, _en.processOnDesktop);

      expect(find.byType(Dialog), findsNothing);
      expect(bloc.events, isEmpty);
    });

    testPage('the section and the preview send their changes for this '
        'session', (tester) async {
      await pumpPage(tester, stateWith(const ProcessingSession(id: 's1')));

      tester
          .widget<ProcessingMappingSection>(
            find.byType(ProcessingMappingSection),
          )
          .onRetryStep2();
      final preview = tester.widget<PreviewCard>(find.byType(PreviewCard));
      preview.onPagesChanged!(['/b.png', '/a.png']);
      preview.onPageRotated!(pagePath, 3);

      expect(bloc.events, [
        const ProcessRemainingResources(sessionId: 's1'),
        const PagesReordered(
          sessionId: 's1',
          reorderedPaths: ['/b.png', '/a.png'],
        ),
        PageRotated(sessionId: 's1', previewPath: pagePath, quarterTurns: 3),
      ]);
    });
  });

  group('Done', () {
    const encounter = StagedEncounter(
      draft: MappingEncounter(
        id: 'e1',
        encounterType: MappedProperty(value: 'Checkup'),
        periodStart: MappedProperty(value: '2024-03-01'),
        specialty: MappedProperty(value: 'Cardiology'),
      ),
    );

    testPage('with nothing picked it asks where to attach, then saves', (
      tester,
    ) async {
      await pumpPage(
        tester,
        stateWith(
          const ProcessingSession(id: 's1', status: ProcessingStatus.draft),
        ),
      );

      await tapText(tester, _en.done);
      expect(find.byType(AttachToEncounterWidget), findsOne);
      await tapText(tester, _en.attachToEncounter);

      expect(bloc.events, [
        EncounterAttached(
          sessionId: 's1',
          patient: _picked.$1,
          encounter: _picked.$2,
        ),
        const ResourceCreationInitiated(sessionId: 's1'),
      ]);
    });

    testPage('a report with nothing picked asks only whose it is', (
      tester,
    ) async {
      await pumpPage(
        tester,
        stateWith(
          const ProcessingSession(
            id: 's1',
            status: ProcessingStatus.draft,
            diagnosticReport: StagedDiagnosticReport(
              draft: MappingDiagnosticReport(
                id: 'r1',
                reportName: MappedProperty(value: 'CBC'),
                issuedDate: MappedProperty(value: '2024-03-01'),
              ),
            ),
          ),
        ),
      );

      await tapText(tester, _en.done);
      final dialog = tester.widget<AttachToEncounterWidget>(
        find.byType(AttachToEncounterWidget),
      );
      expect(dialog.patientOnly, isTrue);
      expect(dialog.confirmText, _en.attachToPatient);
    });

    testPage('closing the attach dialog saves nothing', (tester) async {
      await pumpPage(
        tester,
        stateWith(
          const ProcessingSession(id: 's1', status: ProcessingStatus.draft),
        ),
      );

      await tapText(tester, _en.done);
      await tapText(tester, _en.cancel);

      expect(bloc.events, isEmpty);
    });

    testPage('a new patient with an encounter is saved at once', (
      tester,
    ) async {
      await pumpPage(
        tester,
        stateWith(
          const ProcessingSession(
            id: 's1',
            status: ProcessingStatus.draft,
            patient: StagedPatient(draft: MappingPatient(id: 'p1')),
            encounter: encounter,
          ),
        ),
      );

      await tapText(tester, _en.done);

      expect(find.byType(Dialog), findsNothing);
      expect(bloc.events, [const ResourceCreationInitiated(sessionId: 's1')]);
    });

    testPage('a new patient with a report is saved at once', (tester) async {
      await pumpPage(
        tester,
        stateWith(
          const ProcessingSession(
            id: 's1',
            status: ProcessingStatus.draft,
            patient: StagedPatient(draft: MappingPatient(id: 'p1')),
            diagnosticReport: StagedDiagnosticReport(
              draft: MappingDiagnosticReport(
                id: 'r1',
                reportName: MappedProperty(value: 'CBC'),
                issuedDate: MappedProperty(value: '2024-03-01'),
              ),
            ),
          ),
        ),
      );

      await tapText(tester, _en.done);

      expect(find.byType(Dialog), findsNothing);
      expect(bloc.events, [const ResourceCreationInitiated(sessionId: 's1')]);
    });

    testPage('an empty encounter name blocks the save', (tester) async {
      await pumpPage(
        tester,
        stateWith(
          const ProcessingSession(
            id: 's1',
            status: ProcessingStatus.draft,
            patient: StagedPatient(draft: MappingPatient(id: 'p1')),
            encounter: StagedEncounter(draft: MappingEncounter(id: 'e1')),
          ),
        ),
      );

      await tapText(tester, _en.done);

      expect(find.byType(Dialog), findsNothing);
      expect(bloc.events, isEmpty);
    });

    group('an edited existing patient', () {
      const edited = ProcessingSession(
        id: 's1',
        status: ProcessingStatus.draft,
        patient: StagedPatient(
          draft: MappingPatient(id: 'p1'),
          existing: Patient(id: 'p1', title: 'Ana Pop'),
          mode: ImportMode.linkExisting,
        ),
        encounter: encounter,
      );

      testPage('is saved after the user confirms the update', (
        tester,
      ) async {
        await pumpPage(tester, stateWith(edited));

        await tapText(tester, _en.done);
        // The form's banner says the same, so look in the dialog.
        expect(find.text(_en.actionCannotBeUndone), findsOne);
        expect(
          find.text(_en.patientModifiedUpdating('Ana Pop')),
          findsNWidgets(2),
        );
        await tapText(tester, _en.save);

        expect(bloc.events, [
          const ResourceCreationInitiated(sessionId: 's1'),
        ]);
      });

      testPage('is not saved when the user cancels', (tester) async {
        await pumpPage(tester, stateWith(edited));

        await tapText(tester, _en.done);
        await tapText(tester, _en.cancel);

        expect(bloc.events, isEmpty);
      });
    });
  });

  group('saved records', () {
    Future<void> saved(
      WidgetTester tester,
      ProcessingOrigin origin, {
      AppPlatform platform = AppPlatform.mobile,
    }) async {
      final session = ProcessingSession(
        id: 's1',
        status: ProcessingStatus.draft,
        origin: origin,
      );
      await pumpPage(tester, stateWith(session), platform: platform);
      states.add(
        stateWith(session, status: const PipelineStatus.success()),
      );
      await frames(tester);
      expect(find.text(_en.recordsSavedTitle), findsOne);
      expect(find.text(_en.whatNextQuestion), findsOne);
    }

    testPage('a document that was read names no visit', (tester) async {
      const session = ProcessingSession(
        id: 's1',
        status: ProcessingStatus.draft,
        origin: ProcessingOrigin.import,
        encounter: StagedEncounter(
          existing: Encounter(id: 'e1', title: 'Checkup'),
        ),
      );
      await pumpPage(tester, stateWith(session));
      states.add(stateWith(session, status: const PipelineStatus.success()));
      await frames(tester);

      expect(find.text(_en.recordsSavedTitle), findsOne);
      expect(find.text(_en.documentAttachedTo('Checkup')), findsNothing);
    });

    testPage('after a scan the user can continue scanning', (
      tester,
    ) async {
      await saved(tester, ProcessingOrigin.scan);

      await tapText(tester, _en.continueScanning);

      expect(bloc.events.single, isA<SessionCleared>());
      expect((bloc.events.single as SessionCleared).session.id, 's1');
      expect(navigation.jumps, isEmpty);
    });

    testPage('after a scan the user can go to the records', (
      tester,
    ) async {
      await saved(tester, ProcessingOrigin.scan);

      await tapText(tester, _en.goToRecords);

      expect(bloc.events.single, isA<SessionCleared>());
      expect(navigation.jumps, [1]);
    });

    testPage('after an import or a handover the user continues '
        'importing', (tester) async {
      await saved(tester, ProcessingOrigin.handover);

      expect(find.text(_en.continueImporting), findsOne);
      await tapText(tester, _en.continueImporting);

      expect(bloc.events.single, isA<SessionCleared>());
      expect(navigation.jumps, isEmpty);
    });

    testPage('on a desktop the only choice goes to the records', (
      tester,
    ) async {
      await saved(
        tester,
        ProcessingOrigin.import,
        platform: AppPlatform.desktop,
      );

      expect(find.text(_en.continueImporting), findsNothing);
      await tapText(tester, _en.goToRecords);

      expect(bloc.events.single, isA<SessionCleared>());
      expect(navigation.jumps, [1]);
    });

    testPage('a success for a session that is gone shows nothing', (
      tester,
    ) async {
      await pumpPage(tester, const ProcessingState());

      states.add(const ProcessingState(status: PipelineStatus.success()));
      await frames(tester);

      expect(find.text(_en.recordsSavedTitle), findsNothing);
    });
  });

  group('attach without the AI', () {
    // Why the user is here: the session was found to have no model.
    const noModel = PipelineStatus.failure(
      error: 'no model',
      reason: PipelineFailureReason.modelNotFound,
      sessionId: 's1',
    );
    const pending = ProcessingSession(
      id: 's1',
      origin: ProcessingOrigin.import,
    );

    testPage('shows the pages and the attach action, nothing of the AI', (
      tester,
    ) async {
      await pumpPage(
        tester,
        stateWith(pending, status: noModel),
        attachOnly: true,
      );

      expect(find.byType(PreviewCard), findsOne);
      expect(find.text(_en.attachToEncounter), findsNWidgets(2));
      expect(find.byType(SummaryCard), findsNothing);
      expect(find.byType(ProcessingMappingSection), findsNothing);
      expect(find.byType(ProcessingResourcesSection), findsNothing);
      expect(find.byType(AppMessageCard), findsNothing);
      expect(find.widgetWithIcon(IconButton, Icons.tune), findsNothing);
      expect(retryButton(), findsNothing);
    });

    testPage('asks where the document goes, then saves it there', (
      tester,
    ) async {
      await pumpPage(
        tester,
        stateWith(pending, status: noModel),
        attachOnly: true,
      );

      await tester.tap(find.widgetWithText(AppButton, _en.attachToEncounter));
      await frames(tester);
      expect(find.byType(AttachToEncounterWidget), findsOne);
      await tapText(tester, _en.save);

      expect(bloc.events, [
        EncounterAttached(
          sessionId: 's1',
          patient: _picked.$1,
          encounter: _picked.$2,
        ),
        const ResourceCreationInitiated(sessionId: 's1'),
      ]);
    });

    testPage('closing the picker saves nothing', (tester) async {
      await pumpPage(
        tester,
        stateWith(pending, status: noModel),
        attachOnly: true,
      );

      await tester.tap(find.widgetWithText(AppButton, _en.attachToEncounter));
      await frames(tester);
      await tapText(tester, _en.cancel);

      expect(bloc.events, isEmpty);
    });

    testPage('cannot be tapped again while saving', (tester) async {
      await pumpPage(
        tester,
        stateWith(pending, status: const PipelineStatus.savingResources()),
        attachOnly: true,
      );

      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, _en.attachToEncounter),
      );
      expect(button.enabled, isFalse);
    });

    testPage('a failed save says why, in plain words, and can be tried '
        'again', (tester) async {
      await pumpPage(
        tester,
        stateWith(pending, status: noModel),
        attachOnly: true,
      );

      states.add(
        stateWith(
          pending,
          status: const PipelineStatus.failure(
            error: 'Exception: Not enough memory',
            reason: PipelineFailureReason.notEnoughMemory,
            sessionId: 's1',
          ),
        ),
      );
      await frames(tester);

      expect(
        find.text(PipelineFailureReason.notEnoughMemory.localizedMessage(_en)),
        findsOne,
      );
      expect(find.textContaining('Exception'), findsNothing);
      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, _en.attachToEncounter),
      );
      expect(button.enabled, isTrue);
    });

    testPage('another session\'s failure is not shown', (tester) async {
      await pumpPage(
        tester,
        stateWith(
          pending,
          status: const PipelineStatus.failure(
            error: 'boom',
            reason: PipelineFailureReason.other,
            sessionId: 'other',
          ),
        ),
        attachOnly: true,
      );

      expect(find.byType(AppMessageCard), findsNothing);
    });

    group('once saved', () {
      Future<void> savedUnder(
        WidgetTester tester,
        StagedEncounter encounter,
      ) async {
        final session = pending.copyWith(encounter: encounter);
        await pumpPage(
          tester,
          stateWith(session, status: noModel),
          attachOnly: true,
        );
        states.add(
          stateWith(
            session,
            status: const PipelineStatus.success(sessionId: 's1'),
          ),
        );
        await frames(tester);
        expect(find.text(_en.recordsSavedTitle), findsOne);
        expect(find.text(_en.whatNextQuestion), findsOne);
      }

      final region = const UserState().regionPreset;

      testPage('says the visit it went to, with its date', (tester) async {
        final date = DateTime(2026, 11, 3);
        await savedUnder(
          tester,
          StagedEncounter(
            existing: Encounter(id: 'e1', title: 'Checkup', date: date),
          ),
        );

        expect(
          find.text(
            _en.documentAttachedTo(
              'Checkup, ${DateFormatUtils.formatDate(date, region)}',
            ),
          ),
          findsOne,
        );
      });

      testPage('names a new visit by its type and start', (tester) async {
        await savedUnder(
          tester,
          const StagedEncounter(
            draft: MappingEncounter(
              id: 'e-new',
              encounterType: MappedProperty(value: 'Dental visit'),
              periodStart: MappedProperty(value: '2026-11-03'),
            ),
          ),
        );

        expect(
          find.text(
            _en.documentAttachedTo(
              'Dental visit, '
              '${DateFormatUtils.formatIsoForDisplay('2026-11-03', region)}',
            ),
          ),
          findsOne,
        );
      });

      testPage('a visit without a date is named alone', (tester) async {
        await savedUnder(
          tester,
          const StagedEncounter(
            existing: Encounter(id: 'e1', title: 'Checkup'),
          ),
        );

        expect(find.text(_en.documentAttachedTo('Checkup')), findsOne);
      });

      testPage('lets the user continue importing or go to the records', (
        tester,
      ) async {
        await savedUnder(
          tester,
          const StagedEncounter(
            existing: Encounter(id: 'e1', title: 'Checkup'),
          ),
        );

        await tapText(tester, _en.goToRecords);

        expect(bloc.events.single, isA<SessionCleared>());
        expect(navigation.jumps, [1]);
      });
    });
  });
}
