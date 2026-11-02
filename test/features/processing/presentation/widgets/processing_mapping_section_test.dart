import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/widgets/processing_mapping_section.dart';

final _ro = lookupAppLocalizations(const Locale('ro'));

void main() {
  late List<String> calls;

  setUp(() => calls = []);

  tearDown(() async {
    if (getIt.isRegistered<AppPlatform>()) {
      await getIt.unregister<AppPlatform>();
    }
  });

  Future<void> pump(
    WidgetTester tester, {
    required PipelineStatus status,
    ProcessingSession session = const ProcessingSession(id: 's'),
    AppPlatform platform = AppPlatform.mobile,
    bool modelExists = true,
    bool withDesktopLink = false,
    bool withAttach = true,
  }) async {
    getIt.registerSingleton<AppPlatform>(platform);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ro'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProcessingMappingSection(
              state: ProcessingState(status: status),
              displayedSession: session,
              sessionId: session.id,
              onShowAiSettings: () => calls.add('settings'),
              onRetryStep1: () => calls.add('retry1'),
              onRetryStep2: () => calls.add('retry2'),
              onCancel: () => calls.add('cancel'),
              checkModelExistence: () async => modelExists,
              onProcessOnDesktop: withDesktopLink
                  ? () => calls.add('desktop')
                  : null,
              onAttachWithoutProcessing: withAttach
                  ? () => calls.add('attach')
                  : null,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('failure', () {
    for (final reason in PipelineFailureReason.values.where(
      (r) => r != PipelineFailureReason.modelNotFound,
    )) {
      testWidgets('${reason.name} shows its message, never the error text', (
        tester,
      ) async {
        await pump(
          tester,
          status: PipelineStatus.failure(
            error: 'Exception: secret at /var/mobile/x.gguf',
            reason: reason,
          ),
        );

        expect(find.text(_ro.processingFailed), findsOneWidget);
        expect(find.text(reason.localizedMessage(_ro)), findsOneWidget);
        expect(find.textContaining('secret'), findsNothing);
        expect(find.text(_ro.attachWithoutProcessing), findsNothing);
      });
    }

    testWidgets('retry runs step one again', (tester) async {
      await pump(
        tester,
        status: const PipelineStatus.failure(error: 'x'),
      );

      await tester.tap(find.text(_ro.retry));

      expect(calls, ['retry1']);
    });

    testWidgets('no retry once the patient step is done', (tester) async {
      await pump(
        tester,
        status: const PipelineStatus.failure(error: 'x'),
        session: const ProcessingSession(
          id: 's',
          status: ProcessingStatus.patientExtracted,
        ),
      );

      expect(find.text(_ro.retry), findsNothing);
    });

    testWidgets('no model offers attaching without processing', (
      tester,
    ) async {
      await pump(
        tester,
        status: const PipelineStatus.failure(
          error: 'x',
          reason: PipelineFailureReason.modelNotFound,
        ),
      );

      expect(find.text(_ro.noAiModel), findsOneWidget);
      await tester.tap(find.text(_ro.attachWithoutProcessing));
      expect(calls, ['attach']);
      expect(find.text(_ro.retry), findsNothing);
    });

    testWidgets('no model without an attach action shows no button', (
      tester,
    ) async {
      await pump(
        tester,
        status: const PipelineStatus.failure(
          error: 'x',
          reason: PipelineFailureReason.modelNotFound,
        ),
        withAttach: false,
      );

      expect(find.text(_ro.attachWithoutProcessing), findsNothing);
    });
  });

  testWidgets('a capacity failure offers the AI settings', (tester) async {
    await pump(
      tester,
      status: const PipelineStatus.capacityFailure(sessionId: 's'),
    );

    expect(find.text(_ro.processingFailedCapacity), findsOneWidget);
    expect(find.text(_ro.processingFailedCapacitySuggestion), findsOneWidget);
    expect(find.text(_ro.goBack), findsOneWidget);
    await tester.tap(find.text(_ro.increaseAiModelCapacity));
    expect(calls, ['settings']);
  });

  testWidgets('a cancelled session offers a retry', (tester) async {
    await pump(
      tester,
      status: const PipelineStatus.initial(),
      session: const ProcessingSession(
        id: 's',
        status: ProcessingStatus.cancelled,
      ),
    );

    expect(find.text(_ro.processingCancelled), findsOneWidget);
    await tester.tap(find.text(_ro.retry));
    expect(calls, ['retry1']);
  });

  group('processing', () {
    testWidgets('the patient step shows its progress and cancels', (
      tester,
    ) async {
      await pump(
        tester,
        status: const PipelineStatus.loading(),
        session: const ProcessingSession(
          id: 's',
          status: ProcessingStatus.processingPatient,
        ),
      );

      expect(find.text(_ro.processingBasicDetails), findsOneWidget);
      expect(find.text(_ro.extractingPatientInfo), findsOneWidget);
      expect(find.text(_ro.focusMode), findsOneWidget);
      await tester.tap(find.text(_ro.cancel));
      expect(calls, ['cancel']);
    });

    testWidgets('the resource step shows the pages text', (tester) async {
      await pump(
        tester,
        status: const PipelineStatus.loading(),
        session: const ProcessingSession(
          id: 's',
          status: ProcessingStatus.processing,
        ),
      );

      expect(find.text(_ro.processingPages), findsOneWidget);
      expect(find.text(_ro.pleaseWait), findsOneWidget);
    });
  });

  group('queued', () {
    const pending = ProcessingSession(id: 's');

    testWidgets('waits for the other session when a model exists', (
      tester,
    ) async {
      await pump(tester, status: const PipelineStatus.initial());

      expect(find.text(_ro.onlyOneSessionAtTime), findsOneWidget);
    });

    testWidgets('says the model is missing otherwise', (tester) async {
      await pump(
        tester,
        status: const PipelineStatus.initial(),
        session: pending,
        modelExists: false,
      );

      expect(find.text(_ro.aiModelNotAvailable), findsOneWidget);
    });
  });

  testWidgets('a draft shows nothing', (tester) async {
    await pump(
      tester,
      status: const PipelineStatus.initial(),
      session: const ProcessingSession(id: 's', status: ProcessingStatus.draft),
      withDesktopLink: true,
    );

    expect(find.text(_ro.processOnDesktop), findsNothing);
    expect(find.text(_ro.retry), findsNothing);
    expect(find.text(_ro.processingFailed), findsNothing);
  });

  group('process on desktop', () {
    testWidgets('mobile offers it for a session not yet processed', (
      tester,
    ) async {
      await pump(
        tester,
        status: const PipelineStatus.initial(),
        withDesktopLink: true,
      );

      await tester.tap(find.text(_ro.processOnDesktop));
      expect(calls, ['desktop']);
    });

    testWidgets('the desktop itself does not offer it', (tester) async {
      await pump(
        tester,
        status: const PipelineStatus.initial(),
        platform: AppPlatform.desktop,
        withDesktopLink: true,
      );

      expect(find.text(_ro.processOnDesktop), findsNothing);
    });
  });
}
