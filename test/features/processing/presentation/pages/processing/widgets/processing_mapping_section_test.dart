import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/features/desktop/handover/presentation/bloc/phone_handover_bloc.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/widgets/processing_mapping_section.dart';
import 'package:health_wallet/features/processing/presentation/widgets/custom_progress_indicator.dart';

/// Records where the section navigates.
class _FakeStackRouter extends Fake implements StackRouter {
  final pushed = <PageRouteInfo>[];
  var pops = 0;

  @override
  Future<T?> push<T extends Object?>(
    PageRouteInfo route, {
    OnNavigationFailure? onFailure,
  }) async {
    pushed.add(route);
    return null;
  }

  @override
  Future<bool> maybePop<T extends Object?>([T? result]) async {
    pops++;
    return true;
  }
}

/// Records the events the handed-over message sends.
class _MockPhoneHandoverBloc
    extends MockBloc<PhoneHandoverEvent, PhoneHandoverState>
    implements PhoneHandoverBloc {
  final added = <PhoneHandoverEvent>[];

  @override
  void add(PhoneHandoverEvent event) => added.add(event);
}

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  late _FakeStackRouter router;
  late _MockPhoneHandoverBloc phoneHandover;
  late List<String> actions;

  setUp(() {
    router = _FakeStackRouter();
    phoneHandover = _MockPhoneHandoverBloc();
    actions = [];
    getIt
      ..registerSingleton<AppPlatform>(AppPlatform.mobile)
      ..registerSingleton<PhoneHandoverBloc>(phoneHandover);
  });

  tearDown(getIt.reset);

  Future<void> pump(
    WidgetTester tester,
    ProcessingSession session, {
    PipelineStatus status = const PipelineStatus.initial(),
    PhoneHandoverState handover = const PhoneHandoverState(),
    Stream<PhoneHandoverState> handoverUpdates = const Stream.empty(),
  }) async {
    whenListen(phoneHandover, handoverUpdates, initialState: handover);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: Scaffold(
            body: SingleChildScrollView(
              child: ProcessingMappingSection(
                state: ProcessingState(status: status, sessions: [session]),
                displayedSession: session,
                sessionId: session.id,
                onShowAiSettings: () => actions.add('settings'),
                onRetryStep1: () => actions.add('retry1'),
                onRetryStep2: () => actions.add('retry2'),
                onCancel: () => actions.add('cancel'),
                checkModelExistence: () async => true,
                onProcessOnDesktop: () => actions.add('desktop'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a session the desktop processes shows its progress there and '
      'can be taken back', (tester) async {
    await pump(
      tester,
      const ProcessingSession(id: 's', status: ProcessingStatus.handedOver),
      handover: const PhoneHandoverState(desktopProgress: {'s': 0.4}),
    );

    expect(find.text(_en.handoverOnDesktopTitle), findsOne);
    expect(find.text(_en.handoverOnDesktopMessage), findsOne);
    expect(
      tester
          .widget<CustomProgressIndicator>(
            find.byType(CustomProgressIndicator),
          )
          .progress,
      0.4,
    );
    // Not offered again: the desktop already has it.
    expect(find.text(_en.processOnDesktop), findsNothing);

    await tester.tap(find.text(_en.handoverTakeBack));
    expect(phoneHandover.added, [
      const PhoneHandoverEvent.takeBackRequested(sessionId: 's'),
    ]);
  });

  testWidgets('a handed-over session starts at zero and follows the '
      'desktop\'s progress', (tester) async {
    final updates = StreamController<PhoneHandoverState>();
    addTearDown(updates.close);
    await pump(
      tester,
      const ProcessingSession(id: 's', status: ProcessingStatus.handedOver),
      handoverUpdates: updates.stream,
    );
    double progress() => tester
        .widget<CustomProgressIndicator>(find.byType(CustomProgressIndicator))
        .progress;
    expect(progress(), 0);

    // Another session's progress leaves this one as it is.
    updates.add(const PhoneHandoverState(desktopProgress: {'other': 0.9}));
    await tester.pump();
    expect(progress(), 0);

    updates.add(const PhoneHandoverState(desktopProgress: {'s': 0.7}));
    await tester.pump();
    expect(progress(), 0.7);
  });

  testWidgets('the patient step says it reads the basic details', (
    tester,
  ) async {
    await pump(
      tester,
      const ProcessingSession(
        id: 's',
        status: ProcessingStatus.processingPatient,
      ),
    );

    expect(find.text(_en.processingBasicDetails), findsOne);
    expect(find.text(_en.extractingPatientInfo), findsOne);
  });

  testWidgets('a queued session waits for the one being processed', (
    tester,
  ) async {
    await pump(tester, const ProcessingSession(id: 's'));
    await tester.pump();

    expect(find.text(_en.onlyOneSessionAtTime), findsOne);
    await tester.tap(find.text(_en.processOnDesktop));
    expect(actions, ['desktop']);
  });

  testWidgets('while processing, Focus Mode opens and Cancel cancels', (
    tester,
  ) async {
    await pump(
      tester,
      const ProcessingSession(id: 's', status: ProcessingStatus.processing),
    );

    await tester.tap(find.text(_en.focusMode));
    await tester.tap(find.text(_en.cancel));

    expect(router.pushed, [const FocusModeRoute()]);
    expect(actions, ['cancel']);
  });

  testWidgets('a step too long for the model offers more capacity or going '
      'back', (tester) async {
    await pump(
      tester,
      const ProcessingSession(id: 's', status: ProcessingStatus.processing),
      status: const PipelineStatus.capacityFailure(sessionId: 's'),
    );

    expect(find.text(_en.processingFailedCapacity), findsOne);
    await tester.tap(find.text(_en.increaseAiModelCapacity));
    await tester.tap(find.text(_en.goBack));

    expect(actions, ['settings']);
    expect(router.pops, 1);
  });
}
