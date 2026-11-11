import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/capture/scan/presentation/pages/scan_page.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/load_model/bloc/load_model_bloc.dart';

class _MockProcessingBloc extends MockBloc<ProcessingEvent, ProcessingState>
    implements ProcessingBloc {
  final added = <ProcessingEvent>[];

  @override
  void add(ProcessingEvent event) => added.add(event);
}

class _MockLoadModelBloc extends MockBloc<LoadModelEvent, LoadModelState>
    implements LoadModelBloc {
  @override
  void add(LoadModelEvent event) {}
}

const _permissions = MethodChannel('flutter.baseflow.com/permissions/methods');

/// permission_handler's indexes: Permission.camera, and the statuses.
const _camera = 1;
const _denied = 0;
const _granted = 1;
const _permanentlyDenied = 4;

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  late _MockProcessingBloc processingBloc;
  late _MockLoadModelBloc loadModelBloc;

  setUp(() async {
    await getIt.reset();
    getIt
      ..registerSingleton<AppPlatform>(AppPlatform.mobile)
      ..registerSingleton(PageViewNavigationController());
    processingBloc = _MockProcessingBloc();
    loadModelBloc = _MockLoadModelBloc();
  });

  tearDown(getIt.reset);

  /// The camera permission answers [status] when asked.
  void cameraAnswers(WidgetTester tester, int status) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_permissions, (call) async {
      return switch (call.method) {
        'requestPermissions' => {_camera: status},
        'checkPermissionStatus' => status,
        _ => null,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_permissions, null));
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    ProcessingState processing = const ProcessingState(),
    LoadModelState model = const LoadModelState(
      status: LoadModelStatus.modelAbsent,
    ),
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    whenListen(
      processingBloc,
      const Stream<ProcessingState>.empty(),
      initialState: processing,
    );
    whenListen(
      loadModelBloc,
      const Stream<LoadModelState>.empty(),
      initialState: model,
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ProcessingBloc>.value(value: processingBloc),
            BlocProvider<LoadModelBloc>.value(value: loadModelBloc),
          ],
          child: const ScanView(),
        ),
      ),
    );
    await tester.pump();
  }

  group('without scans', () {
    testWidgets('invites a first scan', (tester) async {
      await pumpPage(tester);

      expect(find.text(en.noScansYet), findsOneWidget);
      expect(find.text(en.scanDocument), findsOneWidget);
    });

    testWidgets('scanning with the camera allowed opens the scanner', (
      tester,
    ) async {
      cameraAnswers(tester, _granted);
      await pumpPage(tester);

      await tester.tap(find.text(en.scanDocument));
      await tester.pumpAndSettle();

      expect(processingBloc.added, [const CaptureButtonPressed()]);
    });

    testWidgets('a camera refused for good points to the settings', (
      tester,
    ) async {
      cameraAnswers(tester, _permanentlyDenied);
      await pumpPage(tester);

      await tester.tap(find.text(en.scanDocument));
      await tester.pumpAndSettle();

      expect(find.text(en.cameraPermissionDenied), findsOneWidget);
      expect(processingBloc.added, isEmpty);
    });

    testWidgets('a refused camera asks again', (tester) async {
      cameraAnswers(tester, _denied);
      await pumpPage(tester);

      await tester.tap(find.text(en.scanDocument));
      await tester.pumpAndSettle();

      expect(find.text(en.cameraPermissionRequired), findsOneWidget);
      expect(processingBloc.added, isEmpty);
    });

    testWidgets('says the scanner is opening while it loads', (tester) async {
      await pumpPage(
        tester,
        processing: const ProcessingState(status: PipelineStatus.loading()),
      );

      expect(find.text(en.openingScanner), findsOneWidget);
    });
  });

  testWidgets('lists the scan sessions, not the imports', (tester) async {
    final created = DateTime(2026, 11, 3, 9);
    await pumpPage(
      tester,
      processing: ProcessingState(
        sessions: [
          ProcessingSession(
            id: 'scan-1',
            origin: ProcessingOrigin.scan,
            createdAt: created,
          ),
          ProcessingSession(
            id: 'import-1',
            origin: ProcessingOrigin.import,
            createdAt: created,
          ),
        ],
      ),
    );

    expect(find.text(en.activeScanSessions), findsOneWidget);
    expect(find.text(en.noScansYet), findsNothing);
  });

  group('the AI model button', () {
    testWidgets('offers the model while there is none', (tester) async {
      await pumpPage(tester);

      expect(find.text(en.onboardingAiModelTitle), findsOneWidget);
    });

    testWidgets('shows the download progress', (tester) async {
      await pumpPage(
        tester,
        model: const LoadModelState(downloadProgress: 40),
      );

      expect(find.text('40%'), findsOneWidget);
      expect(find.text(en.onboardingAiModelTitle), findsNothing);
    });

    testWidgets('is gone once the model is loaded', (tester) async {
      await pumpPage(
        tester,
        model: const LoadModelState(status: LoadModelStatus.modelLoaded),
      );

      expect(find.text(en.onboardingAiModelTitle), findsNothing);
    });
  });
}
