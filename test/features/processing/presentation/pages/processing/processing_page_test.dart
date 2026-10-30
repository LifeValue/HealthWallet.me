import 'dart:async';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/processing_page.dart';

import '../../../../../helpers/log_capture.dart';

/// Records the events the page sends instead of running them.
class _MockProcessingBloc extends MockBloc<ProcessingEvent, ProcessingState>
    implements ProcessingBloc {
  final events = <ProcessingEvent>[];

  @override
  void add(ProcessingEvent event) => events.add(event);
}

class _FakeDeviceCapabilityService extends Fake
    implements DeviceCapabilityService {
  @override
  Future<DeviceAiCapability> getCapability() async => DeviceAiCapability.full;
}

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  final logs = captureLogs();
  late _MockProcessingBloc bloc;
  late StreamController<ProcessingState> states;

  const session = ProcessingSession(id: 's1');

  setUp(() {
    bloc = _MockProcessingBloc();
    states = StreamController<ProcessingState>();
    whenListen(
      bloc,
      states.stream,
      initialState: const ProcessingState(sessions: [session]),
    );
    // No LwwSyncBloc: the desktop sync is not available.
    getIt
      ..registerSingleton<AppPlatform>(AppPlatform.mobile)
      ..registerSingleton<PageViewNavigationController>(
        PageViewNavigationController(),
      )
      ..registerSingleton<DeviceCapabilityService>(
        _FakeDeviceCapabilityService(),
      );
  });

  tearDown(() async {
    await states.close();
    await getIt.reset();
  });

  testWidgets('saved records are confirmed even when the desktop sync '
      'cannot start, and that failure is logged', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<ProcessingBloc>.value(
          value: bloc,
          child: const ProcessingPage(sessionId: 's1'),
        ),
      ),
    );
    expect(bloc.events, [const SessionActivated(sessionId: 's1')]);

    states.add(
      const ProcessingState(
        sessions: [session],
        status: PipelineStatus.success(),
      ),
    );
    // The page shows a spinner while it prepares, so pump frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      logs,
      loggedWarning('Could not start a desktop sync after processing'),
    );
    expect(find.text(_en.recordsSavedTitle), findsOne);
  });
}
