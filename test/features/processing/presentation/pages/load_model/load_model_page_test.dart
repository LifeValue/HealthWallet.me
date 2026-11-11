import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/handover/presentation/bloc/phone_handover_bloc.dart';
import 'package:health_wallet/features/desktop/handover/presentation/widgets/handover_send_dialog.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/load_model/bloc/load_model_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/load_model/load_model_page.dart';
import 'package:health_wallet/features/processing/presentation/widgets/custom_progress_indicator.dart';
import 'package:health_wallet/features/processing/presentation/widgets/model_management_dialog.dart';

import '../../../../desktop/handover/handover_test_fakes.dart';

class _MockLoadModelBloc extends MockBloc<LoadModelEvent, LoadModelState>
    implements LoadModelBloc {}

/// Records the results the page leaves with.
class _FakeStackRouter extends Fake implements StackRouter {
  final popped = <Object?>[];

  @override
  Future<bool> maybePop<T extends Object?>([T? result]) async {
    popped.add(result);
    return true;
  }
}

class _MockCommunicationBloc
    extends MockBloc<CommunicationEvent, DesktopSyncState>
    implements CommunicationBloc {}

class _MockPhoneHandoverBloc
    extends MockBloc<PhoneHandoverEvent, PhoneHandoverState>
    implements PhoneHandoverBloc {}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  setUp(() async {
    await getIt.reset();
    final loadModelBloc = _MockLoadModelBloc();
    whenListen(
      loadModelBloc,
      const Stream<LoadModelState>.empty(),
      initialState: const LoadModelState(
        status: LoadModelStatus.modelAbsent,
        deviceCapability: DeviceAiCapability.unsupported,
      ),
    );
    final communicationBloc = _MockCommunicationBloc();
    whenListen(
      communicationBloc,
      const Stream<DesktopSyncState>.empty(),
      initialState: const DesktopSyncState(
        connectionStatus: ConnectionStatus.connected,
      ),
    );
    getIt
      ..registerSingleton<LoadModelBloc>(loadModelBloc)
      ..registerSingleton<CommunicationBloc>(communicationBloc);
  });

  tearDown(getIt.reset);

  Future<void> pumpPage(WidgetTester tester, {String? sessionId}) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoadModelPage(sessionId: sessionId),
      ),
    );
    await tester.pump();
  }

  testWidgets('a model that finishes downloading while the model list is '
      'open closes the list and leaves the page ready to read', (
    tester,
  ) async {
    final states = StreamController<LoadModelState>();
    addTearDown(states.close);
    final loadModelBloc = _MockLoadModelBloc();
    whenListen(
      loadModelBloc,
      states.stream,
      initialState: const LoadModelState(
        status: LoadModelStatus.loading,
        deviceCapability: DeviceAiCapability.full,
      ),
    );
    getIt
      ..unregister<LoadModelBloc>()
      ..registerSingleton<LoadModelBloc>(loadModelBloc);
    final router = _FakeStackRouter();
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: const LoadModelPage(),
        ),
      ),
    );
    await tester.pump();
    unawaited(
      showDialog<void>(
        context: tester.element(find.byType(LoadModelPage)),
        builder: (_) => const Dialog(child: Text('model list')),
      ),
    );
    // The page shows a spinner while loading: no settling.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('model list'), findsOne);

    states.add(
      const LoadModelState(
        status: LoadModelStatus.modelLoaded,
        deviceCapability: DeviceAiCapability.full,
      ),
    );
    // The page shows a spinner while loading: no settling.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('model list'), findsNothing);
    expect(router.popped, [true]);
  });

  testWidgets('offers processing on the desktop on an unsupported device', (
    tester,
  ) async {
    await pumpPage(tester, sessionId: 's');

    expect(find.text(en.aiModelUnlockTitle), findsOneWidget);
    expect(find.text(en.processOnDesktop), findsOneWidget);
  });

  testWidgets('without a document there is nothing to send to the desktop', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text(en.processOnDesktop), findsNothing);
  });

  testWidgets('a document that is gone is not sent, and that is shown', (
    tester,
  ) async {
    getIt.registerSingleton<ProcessingBloc>(FakeProcessingBloc());
    await pumpPage(tester, sessionId: 'deleted-meanwhile');

    await tester.tap(find.text(en.processOnDesktop));
    await tester.pump();

    expect(find.text(en.handoverSendFailed), findsOneWidget);
  });

  /// Replaces the page's bloc with one that starts at [initial] and then
  /// moves through [states].
  void stubLoadModel(
    LoadModelState initial, [
    Stream<LoadModelState> states = const Stream.empty(),
  ]) {
    final loadModelBloc = _MockLoadModelBloc();
    whenListen(loadModelBloc, states, initialState: initial);
    getIt
      ..unregister<LoadModelBloc>()
      ..registerSingleton<LoadModelBloc>(loadModelBloc);
  }

  /// Pumps the page under a router that records what it leaves with.
  Future<_FakeStackRouter> pumpRoutedPage(
    WidgetTester tester, {
    bool canAttachToEncounter = false,
    String? sessionId,
  }) async {
    final router = _FakeStackRouter();
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: LoadModelPage(
            canAttachToEncounter: canAttachToEncounter,
            sessionId: sessionId,
          ),
        ),
      ),
    );
    await tester.pump();
    return router;
  }

  /// A phone that is linked to the desktop and holds [session].
  void registerHandover(ProcessingSession session) {
    getIt.registerSingleton<ProcessingBloc>(
      FakeProcessingBloc(ProcessingState(sessions: [session])),
    );
    final handoverBloc = _MockPhoneHandoverBloc();
    whenListen(
      handoverBloc,
      const Stream<PhoneHandoverState>.empty(),
      initialState: const PhoneHandoverState(),
    );
    getIt.registerSingleton<PhoneHandoverBloc>(handoverBloc);
  }

  const document = ProcessingSession(id: 'doc', filePaths: ['page.jpg']);

  group('before the model is downloaded', () {
    testWidgets('shows the title, the bolded privacy note and the download '
        'information', (tester) async {
      await pumpPage(tester);

      expect(find.text(en.aiModelTitle), findsOneWidget);
      expect(find.text(en.aiModelUnlockTitle), findsOneWidget);
      expect(find.text(en.aiModelDownloadInfo), findsOneWidget);
      final description = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText() ==
                  en.aiModelUnlockDescription.replaceAll('**', ''),
        ),
      );
      final spans = (description.text as TextSpan).children!.cast<TextSpan>();
      expect(spans[1].text, 'Your data stays private on your device.');
      expect(spans[1].style!.fontWeight, FontWeight.w700);
      expect(spans[0].style, isNull);
    });

    testWidgets('on a capable device offers Choose & Download and a cancel '
        'button, and no warning', (tester) async {
      stubLoadModel(
        const LoadModelState(
          status: LoadModelStatus.modelAbsent,
          deviceCapability: DeviceAiCapability.full,
        ),
      );
      await pumpRoutedPage(tester);

      expect(find.text(en.aiModelEnableDownload), findsOneWidget);
      expect(find.text(en.cancel), findsOneWidget);
      expect(find.text(en.aiModelNotAvailableForDevice), findsNothing);
      expect(find.text(en.processOnDesktop), findsNothing);
    });

    testWidgets('a device that can only run the basic model is offered the '
        'download too', (tester) async {
      stubLoadModel(
        const LoadModelState(
          status: LoadModelStatus.modelAbsent,
          deviceCapability: DeviceAiCapability.basicOnly,
        ),
      );
      await pumpRoutedPage(tester);

      expect(find.text(en.aiModelEnableDownload), findsOneWidget);
      expect(find.text(en.aiModelNotAvailableForDevice), findsNothing);
    });

    testWidgets('Choose & Download opens the model list', (tester) async {
      stubLoadModel(
        const LoadModelState(
          status: LoadModelStatus.modelAbsent,
          deviceCapability: DeviceAiCapability.full,
        ),
      );
      await pumpRoutedPage(tester);

      await tester.tap(find.text(en.aiModelEnableDownload));
      await tester.pumpAndSettle();

      expect(find.byType(ModelManagementDialog), findsOneWidget);
    });

    testWidgets('cancel leaves the page saying the model is not ready', (
      tester,
    ) async {
      stubLoadModel(
        const LoadModelState(
          status: LoadModelStatus.modelAbsent,
          deviceCapability: DeviceAiCapability.full,
        ),
      );
      final router = await pumpRoutedPage(tester);

      await tester.tap(find.text(en.cancel));
      await tester.pump();

      expect(router.popped, [false]);
    });

    testWidgets('"I want to attach the document without processing" leaves '
        'the page saying the model is not ready', (tester) async {
      stubLoadModel(
        const LoadModelState(
          status: LoadModelStatus.modelAbsent,
          deviceCapability: DeviceAiCapability.full,
        ),
      );
      final router = await pumpRoutedPage(tester, canAttachToEncounter: true);

      expect(find.text(en.cancel), findsNothing);
      await tester.tap(find.text(en.attachWithoutProcessing));
      await tester.pump();

      expect(router.popped, [false]);
    });

    testWidgets('on a capable device with a document, Process on Desktop '
        'sends the document to the linked desktop', (tester) async {
      stubLoadModel(
        const LoadModelState(
          status: LoadModelStatus.modelAbsent,
          deviceCapability: DeviceAiCapability.full,
        ),
      );
      registerHandover(document);
      await pumpRoutedPage(tester, sessionId: document.id);

      expect(find.byIcon(Icons.computer), findsOneWidget);
      await tester.tap(find.text(en.processOnDesktop));
      // The send dialog's bar runs until the transfer starts: no settling.
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HandoverSendDialog), findsOneWidget);
      expect(find.text(en.desktopHandoverSendingToDesktop), findsOneWidget);
    });

    testWidgets('on a capable device, a document that is gone is not sent, '
        'and that is shown', (tester) async {
      stubLoadModel(
        const LoadModelState(
          status: LoadModelStatus.modelAbsent,
          deviceCapability: DeviceAiCapability.full,
        ),
      );
      getIt.registerSingleton<ProcessingBloc>(FakeProcessingBloc());
      await pumpRoutedPage(tester, sessionId: 'deleted-meanwhile');

      await tester.tap(find.text(en.processOnDesktop));
      await tester.pump();

      expect(find.text(en.handoverSendFailed), findsOneWidget);
      expect(find.byType(HandoverSendDialog), findsNothing);
    });
  });

  group('on a device that cannot run the model', () {
    testWidgets('warns that the model is not available and offers no '
        'download', (tester) async {
      await pumpRoutedPage(tester);

      expect(find.text(en.aiModelNotAvailableForDevice), findsOneWidget);
      expect(
        find.text(en.aiModelNotAvailableForDeviceDescription),
        findsOneWidget,
      );
      expect(find.text(en.aiModelEnableDownload), findsNothing);
    });

    testWidgets('cancel leaves the page saying the model is not ready', (
      tester,
    ) async {
      final router = await pumpRoutedPage(tester);

      await tester.tap(find.text(en.cancel));
      await tester.pump();

      expect(router.popped, [false]);
    });

    testWidgets('"I want to attach the document without processing" leaves '
        'the page saying the model is not ready', (tester) async {
      final router = await pumpRoutedPage(tester, canAttachToEncounter: true);

      await tester.tap(find.text(en.attachWithoutProcessing));
      await tester.pump();

      expect(router.popped, [false]);
    });

    testWidgets('Process on Desktop sends the document to the linked '
        'desktop', (tester) async {
      registerHandover(document);
      await pumpRoutedPage(tester, sessionId: document.id);

      await tester.tap(find.text(en.processOnDesktop));
      // The send dialog's bar runs until the transfer starts: no settling.
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HandoverSendDialog), findsOneWidget);
      expect(find.text(en.desktopHandoverSendingToDesktop), findsOneWidget);
    });
  });

  group('while the model downloads', () {
    testWidgets('shows only a spinner until the download reports progress', (
      tester,
    ) async {
      stubLoadModel(const LoadModelState(status: LoadModelStatus.loading));
      await pumpRoutedPage(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(en.aiModelUnlockTitle), findsNothing);
    });

    testWidgets('shows the download progress, that it continues in the '
        'background, and a way to keep using the app', (tester) async {
      stubLoadModel(
        const LoadModelState(
          status: LoadModelStatus.loading,
          downloadProgress: 40,
          deviceCapability: DeviceAiCapability.full,
        ),
      );
      await pumpRoutedPage(tester);

      final progress = tester.widget<CustomProgressIndicator>(
        find.byType(CustomProgressIndicator),
      );
      expect(progress.progress, 0.4);
      expect(progress.text, en.aiModelDownloading);
      expect(find.text(en.downloadContinuesInBackground), findsOneWidget);
      expect(find.text(en.continueUsingApp), findsOneWidget);
      expect(find.text(en.aiModelEnableDownload), findsNothing);
    });

    testWidgets('a download running in the background with no progress yet '
        'shows the bar empty', (tester) async {
      stubLoadModel(
        const LoadModelState(
          status: LoadModelStatus.loading,
          isBackgroundDownload: true,
        ),
      );
      await pumpRoutedPage(tester);

      final progress = tester.widget<CustomProgressIndicator>(
        find.byType(CustomProgressIndicator),
      );
      expect(progress.progress, 0);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Continue using app leaves the page without a result', (
      tester,
    ) async {
      stubLoadModel(
        const LoadModelState(
          status: LoadModelStatus.loading,
          downloadProgress: 10,
        ),
      );
      final router = await pumpRoutedPage(tester);

      await tester.tap(find.text(en.continueUsingApp));
      // The progress bar shimmers forever: no settling.
      await tester.pump(const Duration(milliseconds: 100));

      expect(router.popped, [null]);
    });

    testWidgets('with a document waiting, offers to continue without the AI '
        'and leaves without a result', (tester) async {
      stubLoadModel(
        const LoadModelState(
          status: LoadModelStatus.loading,
          downloadProgress: 10,
        ),
      );
      final router = await pumpRoutedPage(tester, canAttachToEncounter: true);

      expect(find.text(en.continueUsingApp), findsNothing);
      await tester.tap(find.text(en.continueWithoutAi));
      // The progress bar shimmers forever: no settling.
      await tester.pump(const Duration(milliseconds: 100));

      expect(router.popped, [null]);
    });
  });

  group('when the download fails', () {
    testWidgets('without internet, says so in a dialog that OK closes', (
      tester,
    ) async {
      stubLoadModel(
        const LoadModelState(
          status: LoadModelStatus.modelAbsent,
          deviceCapability: DeviceAiCapability.full,
        ),
        Stream.value(
          const LoadModelState(
            status: LoadModelStatus.error,
            errorMessage: kNoInternetErrorKey,
            deviceCapability: DeviceAiCapability.full,
          ),
        ),
      );
      await pumpRoutedPage(tester);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.text(en.noInternetConnectionTitle), findsOneWidget);
      expect(find.text(en.noInternetConnectionDescription), findsOneWidget);
      expect(find.text(en.errorTitle), findsNothing);

      await tester.tap(find.text(en.ok));
      await tester.pumpAndSettle();

      expect(find.text(en.noInternetConnectionTitle), findsNothing);
      expect(find.text(en.aiModelEnableDownload), findsOneWidget);
    });

    testWidgets('for any other reason, shows the error message', (
      tester,
    ) async {
      stubLoadModel(
        const LoadModelState(
          status: LoadModelStatus.modelAbsent,
          deviceCapability: DeviceAiCapability.full,
        ),
        Stream.value(
          const LoadModelState(
            status: LoadModelStatus.error,
            errorMessage: 'disk full',
            deviceCapability: DeviceAiCapability.full,
          ),
        ),
      );
      await pumpRoutedPage(tester);
      await tester.pumpAndSettle();

      expect(find.text(en.errorTitle), findsOneWidget);
      expect(find.text('disk full'), findsOneWidget);
      expect(find.text(en.noInternetConnectionTitle), findsNothing);
    });

    testWidgets('without a message, shows no dialog', (tester) async {
      stubLoadModel(
        const LoadModelState(
          status: LoadModelStatus.modelAbsent,
          deviceCapability: DeviceAiCapability.full,
        ),
        Stream.value(
          const LoadModelState(
            status: LoadModelStatus.error,
            deviceCapability: DeviceAiCapability.full,
          ),
        ),
      );
      await pumpRoutedPage(tester);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(en.aiModelEnableDownload), findsOneWidget);
    });
  });

  testWidgets('a model that is ready leaves the page saying so', (
    tester,
  ) async {
    stubLoadModel(
      const LoadModelState(
        status: LoadModelStatus.modelAbsent,
        deviceCapability: DeviceAiCapability.full,
      ),
      Stream.value(
        const LoadModelState(
          status: LoadModelStatus.modelLoaded,
          deviceCapability: DeviceAiCapability.full,
        ),
      ),
    );
    final router = await pumpRoutedPage(tester);
    await tester.pumpAndSettle();

    expect(router.popped, [true]);
  });

  testWidgets('the back button in the app bar closes the page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LoadModelPage()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(LoadModelPage), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(LoadModelPage), findsNothing);
  });
}
