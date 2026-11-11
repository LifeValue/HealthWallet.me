import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/load_model/bloc/load_model_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/load_model/load_model_page.dart';

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
}
