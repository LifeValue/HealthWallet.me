import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/load_model/bloc/load_model_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/load_model/load_model_page.dart';

import '../../../../../helpers/log_capture.dart';

class _MockLoadModelBloc extends MockBloc<LoadModelEvent, LoadModelState>
    implements LoadModelBloc {}

class _MockCommunicationBloc
    extends MockBloc<CommunicationEvent, DesktopSyncState>
    implements CommunicationBloc {}

void main() {
  final logs = captureLogs();
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

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoadModelPage(),
      ),
    );
    await tester.pump();
  }

  testWidgets('offers processing on the desktop on an unsupported device', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text(en.aiModelUnlockTitle), findsOneWidget);
    expect(find.text(en.processOnDesktop), findsOneWidget);
  });

  testWidgets('a failed send to the desktop is logged and shown', (
    tester,
  ) async {
    // ProcessingBloc is not registered, so reading the pending sessions fails.
    await pumpPage(tester);

    await tester.tap(find.text(en.processOnDesktop));
    await tester.pump();

    expect(find.text(en.handoverSendFailed), findsOneWidget);
    expect(logs, loggedWarning('Could not send the pending document'));
  });
}
