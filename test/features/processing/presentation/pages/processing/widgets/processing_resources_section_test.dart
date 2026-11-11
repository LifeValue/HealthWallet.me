import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/widgets/processing_resources_section.dart';
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

final _en = lookupAppLocalizations(const Locale('en'));

const _extracted = ProcessingSession(
  id: 's',
  status: ProcessingStatus.patientExtracted,
);

void main() {
  setUpAll(initializeDateFormatting);

  late _MockProcessingBloc processingBloc;

  setUp(() {
    getIt.registerSingleton<AppPlatform>(AppPlatform.mobile);
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
                onScrollToFormErrors: () {},
                onSaveResources: () {},
              ),
            ),
          ),
        ),
      ),
    );
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
}
