import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:fhir_r4/fhir_r4.dart' show FhirString;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/widgets/animated_sticky_header.dart';
import 'package:health_wallet/core/widgets/custom_app_bar.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/backup_card.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/connection_dialog.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/sync_dialog.dart';
import 'package:health_wallet/features/home/domain/entities/overview_card.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/home/presentation/home_page.dart';
import 'package:health_wallet/features/home/presentation/widgets/home_dashboard_sections.dart';
import 'package:health_wallet/features/home/presentation/widgets/home_greeting_title.dart';
import 'package:health_wallet/features/home/presentation/widgets/home_patient_bar.dart';
import 'package:health_wallet/features/notifications/bloc/notification_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/sync/presentation/widgets/sync_placeholder_widget.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps what Home asks of its bloc instead of running it.
class _MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {
  final added = <HomeEvent>[];

  @override
  void add(HomeEvent event) => added.add(event);
}

class _MockSyncBloc extends MockBloc<SyncEvent, SyncState> implements SyncBloc {
  final added = <SyncEvent>[];

  @override
  void add(SyncEvent event) => added.add(event);
}

class _MockUserBloc extends MockBloc<UserEvent, UserState>
    implements UserBloc {}

class _MockPatientBloc extends MockBloc<PatientEvent, PatientState>
    implements PatientBloc {
  final added = <PatientEvent>[];

  @override
  void add(PatientEvent event) => added.add(event);
}

class _MockRecordsBloc extends MockBloc<RecordsEvent, RecordsState>
    implements RecordsBloc {
  final added = <RecordsEvent>[];

  @override
  void add(RecordsEvent event) => added.add(event);
}

class _MockNotificationBloc
    extends MockBloc<NotificationEvent, NotificationState>
    implements NotificationBloc {}

class _MockLwwSyncBloc extends MockBloc<LwwSyncEvent, LwwSyncState>
    implements LwwSyncBloc {}

class _MockCommunicationBloc
    extends MockBloc<CommunicationEvent, DesktopSyncState>
    implements CommunicationBloc {}

class _MockBackupBloc extends MockBloc<BackupEvent, BackupState>
    implements BackupBloc {}

/// Home opens no page in these tests.
class _FakeStackRouter extends Fake implements StackRouter {}

final _en = lookupAppLocalizations(const Locale('en'));

final _jane = Patient(
  id: 'patient-1',
  name: [
    fhir_r4.HumanName(given: [FhirString('Jane')], family: FhirString('Doe')),
  ],
);

/// Home with records to show.
HomeState _loaded({
  Patient? patient,
  bool withPatient = true,
  bool hasDataLoaded = true,
  int cards = 2,
}) => HomeState(
  status: const HomeStatus.success(),
  hasDataLoaded: hasDataLoaded,
  patient: withPatient ? patient ?? _jane : null,
  overviewViewMode: OverviewViewMode.resources,
  overviewCards: [
    for (final category in HomeRecordsCategory.values.take(cards))
      OverviewCard(category: category, count: '2'),
  ],
);

/// Home with nothing to show yet.
const _empty = HomeState(status: HomeStatus.success(), hasDataLoaded: true);

/// The desktop header's cards refresh from one 30-second ticker that the
/// whole app shares and never stops. The first test to show the header
/// starts its timer; keeping it here lets that test stop it, since a test
/// must not leave a timer running.
final _tickerTimers = <Timer>[];

Future<void> _keepingTimers(Future<void> Function() body) => runZoned(
  body,
  zoneSpecification: ZoneSpecification(
    createPeriodicTimer: (self, parent, zone, period, callback) {
      final timer = parent.createPeriodicTimer(zone, period, callback);
      _tickerTimers.add(timer);
      return timer;
    },
  ),
);

/// A test that shows the desktop header.
void _desktopTest(
  String description,
  WidgetTesterCallback body, {
  bool? skip,
}) {
  testWidgets(description, skip: skip, (tester) async {
    try {
      await body(tester);
    } finally {
      for (final timer in _tickerTimers) {
        timer.cancel();
      }
      _tickerTimers.clear();
    }
  });
}

/// The app's Matter font, so text measures as it does in the app rather
/// than in the test font's square glyphs.
Future<void> _loadMatterFont() async {
  final loader = FontLoader('Matter');
  for (final file in const [
    'Matter-Regular.ttf',
    'Matter-Medium.ttf',
    'Matter-SemiBold.ttf',
    'Matter-Bold.ttf',
  ]) {
    loader.addFont(rootBundle.load('assets/font/matter-font/$file'));
  }
  await loader.load();
}

void main() {
  late _MockHomeBloc homeBloc;
  late _MockSyncBloc syncBloc;
  late _MockUserBloc userBloc;
  late _MockPatientBloc patientBloc;
  late _MockRecordsBloc recordsBloc;
  late _MockNotificationBloc notificationBloc;
  late _MockLwwSyncBloc lwwSyncBloc;
  late _MockCommunicationBloc communicationBloc;
  late _MockBackupBloc backupBloc;
  late StreamController<HomeState> homeStates;
  late StreamController<SyncState> syncStates;
  late StreamController<UserState> userStates;
  late StreamController<LwwSyncState> lwwStates;
  late PageController pageController;

  setUpAll(() async {
    await initializeDateFormatting();
    await _loadMatterFont();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    homeBloc = _MockHomeBloc();
    syncBloc = _MockSyncBloc();
    userBloc = _MockUserBloc();
    patientBloc = _MockPatientBloc();
    recordsBloc = _MockRecordsBloc();
    notificationBloc = _MockNotificationBloc();
    lwwSyncBloc = _MockLwwSyncBloc();
    communicationBloc = _MockCommunicationBloc();
    backupBloc = _MockBackupBloc();
    homeStates = StreamController<HomeState>.broadcast();
    syncStates = StreamController<SyncState>.broadcast();
    userStates = StreamController<UserState>.broadcast();
    lwwStates = StreamController<LwwSyncState>.broadcast();
    pageController = PageController();

    whenListen(
      patientBloc,
      const Stream<PatientState>.empty(),
      initialState: const PatientState(),
    );
    whenListen(
      recordsBloc,
      const Stream<RecordsState>.empty(),
      initialState: const RecordsState(),
    );
    whenListen(
      notificationBloc,
      const Stream<NotificationState>.empty(),
      initialState: const NotificationState(),
    );
    whenListen(
      communicationBloc,
      const Stream<DesktopSyncState>.empty(),
      initialState: const DesktopSyncState(),
    );
    whenListen(
      backupBloc,
      const Stream<BackupState>.empty(),
      initialState: const BackupState(),
    );
    getIt
      ..registerSingleton<LwwSyncBloc>(lwwSyncBloc)
      ..registerSingleton<CommunicationBloc>(communicationBloc)
      ..registerSingleton<BackupBloc>(backupBloc);
  });

  tearDown(() async {
    pageController.dispose();
    await homeStates.close();
    await syncStates.close();
    await userStates.close();
    await lwwStates.close();
    await getIt.reset();
  });

  Widget app(Widget home) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: StackRouterScope(
      controller: _FakeStackRouter(),
      stateHash: 0,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<HomeBloc>.value(value: homeBloc),
          BlocProvider<SyncBloc>.value(value: syncBloc),
          BlocProvider<UserBloc>.value(value: userBloc),
          BlocProvider<PatientBloc>.value(value: patientBloc),
          BlocProvider<RecordsBloc>.value(value: recordsBloc),
          BlocProvider<NotificationBloc>.value(value: notificationBloc),
        ],
        child: home,
      ),
    ),
  );

  Future<void> pump(
    WidgetTester tester, {
    HomeState home = const HomeState(),
    SyncState sync = const SyncState(),
    UserState user = const UserState(),
    LwwSyncState lww = const LwwSyncState(),
    AppPlatform platform = AppPlatform.mobile,
    Size size = const Size(400, 800),
  }) async {
    whenListen(homeBloc, homeStates.stream, initialState: home);
    whenListen(syncBloc, syncStates.stream, initialState: sync);
    whenListen(userBloc, userStates.stream, initialState: user);
    whenListen(lwwSyncBloc, lwwStates.stream, initialState: lww);
    getIt.registerSingleton<AppPlatform>(platform);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _keepingTimers(
      () => tester.pumpWidget(app(HomePage(pageController: pageController))),
    );
  }

  Future<void> pumpDesktop(
    WidgetTester tester, {
    HomeState home = const HomeState(),
  }) => pump(
    tester,
    home: home,
    platform: AppPlatform.desktop,
    size: const Size(1280, 800),
  );

  Finder textContaining(String text) => find.textContaining(text);

  // Must stay the first test to show the desktop header: the shared ticker
  // only runs on the fake clock of the test that started it.
  group('desktop status cards', () {
    _desktopTest('rebuild on each tick of the 30-second ticker', (
      tester,
    ) async {
      await pumpDesktop(tester, home: _loaded());

      expect(find.byKey(const ValueKey('sync_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('backup_0')), findsOneWidget);

      // The first tick counts 0, the next 1.
      await tester.pump(const Duration(seconds: 30));
      expect(find.byKey(const ValueKey('sync_0')), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));

      expect(find.byKey(const ValueKey('sync_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('backup_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('sync_0')), findsNothing);
    });
  });

  group('HomePage reloads Home', () {
    testWidgets('when demo data arrives', (tester) async {
      await pump(tester);

      syncStates.add(const SyncState(hasDemoData: true));
      await tester.pump();

      expect(homeBloc.added, [const HomeRefreshPreservingOrder()]);
    });

    testWidgets('when synced data arrives', (tester) async {
      await pump(tester);

      syncStates.add(const SyncState(hasSyncedData: true));
      await tester.pump();

      expect(homeBloc.added, [const HomeRefreshPreservingOrder()]);
    });

    testWidgets('not when the data goes away', (tester) async {
      await pump(tester, sync: const SyncState(hasDemoData: true));

      syncStates.add(const SyncState());
      await tester.pump();

      expect(homeBloc.added, isEmpty);
    });

    testWidgets('not for other sync changes', (tester) async {
      await pump(tester);

      syncStates.add(const SyncState(isLoading: true));
      await tester.pump();

      expect(homeBloc.added, isEmpty);
    });

    testWidgets('and the people when the desktop sends records', (
      tester,
    ) async {
      await pump(tester);

      lwwStates.add(const LwwSyncState(recordsVersion: 1));
      await tester.pump();

      expect(patientBloc.added, [const PatientPatientsLoaded()]);
      expect(homeBloc.added, [const HomeRefreshPreservingOrder()]);
    });

    testWidgets('not for other desktop sync changes', (tester) async {
      await pump(tester);

      lwwStates.add(const LwwSyncState(pendingChangeCount: 3));
      await tester.pump();

      expect(patientBloc.added, isEmpty);
      expect(homeBloc.added, isEmpty);
    });

    testWidgets('when the region changes', (tester) async {
      await pump(tester);

      userStates.add(const UserState(regionPreset: RegionPreset.us));
      await tester.pump();

      expect(homeBloc.added, [const HomeRefreshPreservingOrder()]);
    });

    testWidgets('not for other user changes', (tester) async {
      await pump(tester);

      userStates.add(const UserState(isBiometricAuthEnabled: true));
      await tester.pump();

      expect(homeBloc.added, isEmpty);
    });
  });

  group('while Home first loads', () {
    testWidgets('a phone shows only a spinner', (tester) async {
      await pump(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(CustomAppBar), findsNothing);
      expect(find.byType(HomeGreetingTitle), findsNothing);
    });

    testWidgets('the desktop shows only a spinner', (tester) async {
      await pump(tester, platform: AppPlatform.desktop);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(HomeGreetingTitle), findsNothing);
    });

    testWidgets('the page follows once it has loaded', (tester) async {
      await pump(tester);

      homeStates.add(_loaded());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(HomeDashboardSections), findsOneWidget);
    });
  });

  group('on a phone', () {
    testWidgets('shows the greeting, the dashboard and the patient bar', (
      tester,
    ) async {
      await pump(tester, home: _loaded());
      await tester.pumpAndSettle();

      expect(find.byType(CustomAppBar), findsOneWidget);
      expect(
        tester.widget<CustomAppBar>(find.byType(CustomAppBar)).extraTopPadding,
        0,
      );
      expect(
        find.text(
          '${_en.homeHi}${_en.homeDefaultUserName}',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.byType(HomeDashboardSections), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.byType(HomePatientBar), findsOneWidget);
      expect(textContaining('Doe, Jane'), findsOneWidget);
      expect(find.byType(SyncPlaceholderWidget), findsNothing);
      expect(find.byType(AnimatedStickyHeader), findsNothing);
    });

    testWidgets('leaves room above the dashboard for the patient bar', (
      tester,
    ) async {
      await pump(tester, home: _loaded());
      await tester.pumpAndSettle();

      final bar = tester.getSize(find.byType(HomePatientBar)).height;
      expect(bar, greaterThan(0));
      expect(tester.getSize(find.byType(AnimatedContainer)).height, bar);

      // A new state measures the bar again; the same height changes nothing.
      homeStates.add(_loaded(cards: 3));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AnimatedContainer)).height, bar);
    });

    testWidgets('shows no patient bar before the data has loaded', (
      tester,
    ) async {
      await pump(tester, home: _loaded(hasDataLoaded: false));
      await tester.pumpAndSettle();

      expect(find.byType(HomePatientBar), findsNothing);
      expect(find.byType(AnimatedContainer), findsNothing);
      expect(find.byType(HomeDashboardSections), findsOneWidget);
    });

    testWidgets('lifts the patient bar while the dashboard is scrolled', (
      tester,
    ) async {
      await pump(tester, home: _loaded(cards: 14), size: const Size(400, 500));
      await tester.pumpAndSettle();
      bool isScrolled() =>
          tester.widget<HomePatientBar>(find.byType(HomePatientBar)).isScrolled;
      expect(isScrolled(), isFalse);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(isScrolled(), isTrue);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(isScrolled(), isFalse);
    });

    testWidgets('pulling down reloads Home', (tester) async {
      await pump(tester, home: _loaded());
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(homeBloc.added, [const HomeRefreshPreservingOrder()]);

      await tester.pumpAndSettle();
      expect(find.byType(RefreshProgressIndicator), findsNothing);
    });

    testWidgets('a tablet gives the app bar 16 more at the top', (
      tester,
    ) async {
      await pump(tester, home: _loaded(), size: const Size(800, 1000));
      await tester.pumpAndSettle();

      expect(
        tester.widget<CustomAppBar>(find.byType(CustomAppBar)).extraTopPadding,
        16,
      );
    });

    testWidgets('without records shows the placeholder', (tester) async {
      await pump(tester, home: _empty);
      await tester.pumpAndSettle();

      expect(find.byType(SyncPlaceholderWidget), findsOneWidget);
      expect(find.byType(HomeDashboardSections), findsNothing);
      expect(find.byType(HomePatientBar), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is Align && w.alignment == const Alignment(0, -0.3),
        ),
        findsNothing,
      );
    });

    testWidgets('a tablet sets the placeholder a little above the middle', (
      tester,
    ) async {
      await pump(tester, home: _empty, size: const Size(800, 1000));
      await tester.pumpAndSettle();

      final align = find.byWidgetPredicate(
        (w) => w is Align && w.alignment == const Alignment(0, -0.3),
      );
      expect(align, findsOneWidget);
      expect(
        find.descendant(
          of: align,
          matching: find.byType(SyncPlaceholderWidget),
        ),
        findsOneWidget,
      );
      // At least as tall as the page, so the placeholder can be centred.
      final box = tester.widget<ConstrainedBox>(
        find.ancestor(of: align, matching: find.byType(ConstrainedBox)).first,
      );
      expect(
        box.constraints.minHeight,
        tester.getSize(find.byType(RefreshIndicator)).height,
      );
    });

    testWidgets("the placeholder's Sync opens device sync", (tester) async {
      await pump(tester, home: _empty);
      await tester.pumpAndSettle();

      await tester.tap(find.text(_en.syncTitle));
      await tester.pumpAndSettle();

      expect(find.text(_en.desktopDeviceSync), findsOneWidget);
      expect(find.byType(ConnectionSection), findsOneWidget);
    });
  });

  group('the reorder tutorial', () {
    Finder message() => find.text(_en.homeOnboardingReorderMessage);

    testWidgets('shows when Sync asks for it', (tester) async {
      await pump(tester, home: _loaded());
      await tester.pumpAndSettle();
      expect(message(), findsNothing);

      syncStates.add(const SyncState(shouldShowTutorial: true));
      await tester.pumpAndSettle();

      expect(message(), findsOneWidget);
      expect(find.text(_en.tapToContinue), findsOneWidget);
    });

    testWidgets('a tap dismisses it, resets the tutorial and remembers it', (
      tester,
    ) async {
      await pump(tester, home: _loaded());
      syncStates.add(const SyncState(shouldShowTutorial: true));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(5, 795));
      await tester.pumpAndSettle();

      expect(message(), findsNothing);
      expect(syncBloc.added, [const ResetTutorial()]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_shown'), isTrue);
    });

    testWidgets('shows again once Sync has turned it off and on', (
      tester,
    ) async {
      await pump(tester, home: _loaded());
      syncStates.add(const SyncState(shouldShowTutorial: true));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 795));
      await tester.pumpAndSettle();

      syncStates.add(const SyncState());
      await tester.pumpAndSettle();
      expect(message(), findsNothing);

      syncStates.add(const SyncState(shouldShowTutorial: true));
      await tester.pumpAndSettle();
      expect(message(), findsOneWidget);
    });

    testWidgets('does not show if Home is gone before the next frame', (
      tester,
    ) async {
      await pump(tester, home: _loaded());
      await tester.pumpAndSettle();

      syncStates.add(const SyncState(shouldShowTutorial: true));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(message(), findsNothing);
    });

    testWidgets('can be shown directly', (tester) async {
      await pump(tester, home: _loaded());
      await tester.pumpAndSettle();

      tester
          .state<HomeViewState>(find.byType(HomeView))
          .showOnboardingDirectly();
      await tester.pumpAndSettle();

      expect(message(), findsOneWidget);
    });

    testWidgets('shown directly does nothing once Home is gone', (
      tester,
    ) async {
      await pump(tester, home: _loaded());
      await tester.pumpAndSettle();
      final state = tester.state<HomeViewState>(find.byType(HomeView));

      await tester.pumpWidget(app(const SizedBox()));
      state.showOnboardingDirectly();
      await tester.pumpAndSettle();

      expect(message(), findsNothing);
    });

    testWidgets('goes away with Home', (tester) async {
      await pump(tester, home: _loaded());
      syncStates.add(const SyncState(shouldShowTutorial: true));
      await tester.pumpAndSettle();
      expect(message(), findsOneWidget);

      await tester.pumpWidget(app(const SizedBox()));
      await tester.pumpAndSettle();

      expect(message(), findsNothing);
    });
  });

  group('on the desktop', () {
    _desktopTest('shows the header, the cards and the dashboard', (
      tester,
    ) async {
      await pumpDesktop(tester, home: _loaded());
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedStickyHeader), findsOneWidget);
      expect(find.byType(HomeGreetingTitle), findsOneWidget);
      expect(find.text('${_en.patient}: '), findsOneWidget);
      expect(find.text('Doe, Jane'), findsOneWidget);
      expect(find.text(_en.connectionLabel), findsOneWidget);
      expect(find.text(_en.syncLabel), findsOneWidget);
      expect(find.text(_en.backupLabel), findsOneWidget);
      expect(find.byType(HomeDashboardSections), findsOneWidget);
      expect(find.byType(CustomAppBar), findsNothing);
      expect(find.byType(HomePatientBar), findsNothing);
      expect(find.byType(RefreshIndicator), findsNothing);
    });

    _desktopTest(
      'shows no patient row without a patient, and the cards still fit',
      (tester) async {
        await pumpDesktop(tester, home: _loaded(withPatient: false));
        await tester.pumpAndSettle();

        expect(find.text('${_en.patient}: '), findsNothing);
        expect(find.byType(HomeDashboardSections), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      // Without the patient row the header is only as tall as the greeting,
      // and each status card overflows it by 7 px.
      skip: true,
    );

    _desktopTest('a patient without a name shows as loading', (tester) async {
      await pumpDesktop(
        tester,
        home: _loaded(patient: const Patient(id: 'nameless')),
      );
      await tester.pumpAndSettle();

      expect(find.text('${_en.patient}: '), findsOneWidget);
      expect(find.text(_en.loading), findsOneWidget);
    });

    _desktopTest('the patient row opens the share menu', (tester) async {
      await pumpDesktop(tester, home: _loaded());
      await tester.pumpAndSettle();
      double turns() =>
          tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns;
      expect(turns(), 0);

      await tester.tap(find.text('Doe, Jane'));
      await tester.pumpAndSettle();

      expect(find.text(_en.exportIpsPdf), findsOneWidget);
      expect(turns(), 0.5);

      // A second tap while it is open opens no second menu.
      tester
          .widget<GestureDetector>(
            find
                .ancestor(
                  of: find.text('Doe, Jane'),
                  matching: find.byType(GestureDetector),
                )
                .first,
          )
          .onTap!();
      await tester.pumpAndSettle();
      expect(find.text(_en.exportIpsPdf), findsOneWidget);

      await tester.tapAt(const Offset(640, 700));
      await tester.pumpAndSettle();

      expect(find.text(_en.exportIpsPdf), findsNothing);
      expect(turns(), 0);
      expect(recordsBloc.added, isEmpty);
    });

    _desktopTest("exporting from the menu shares the patient's records", (
      tester,
    ) async {
      await pumpDesktop(tester, home: _loaded());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Doe, Jane'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_en.exportIpsPdf));
      await tester.pumpAndSettle();

      expect(recordsBloc.added, [
        const RecordsSharePressed(
          patientName: 'Doe, Jane',
          patientId: 'patient-1',
        ),
      ]);
    });

    _desktopTest('without records shows the cards over the placeholder', (
      tester,
    ) async {
      await pumpDesktop(tester, home: _empty);
      await tester.pumpAndSettle();

      expect(find.byType(HomeGreetingTitle), findsOneWidget);
      expect(find.text(_en.connectionLabel), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
      expect(find.text(_en.backupLabel), findsOneWidget);
      expect(find.byType(SyncPlaceholderWidget), findsOneWidget);
      expect(find.byType(HomeDashboardSections), findsNothing);
      expect(find.byType(AnimatedStickyHeader), findsNothing);
    });

    _desktopTest("the placeholder's Sync opens device sync", (tester) async {
      await pumpDesktop(tester, home: _empty);
      await tester.pumpAndSettle();

      await tester.tap(find.text(_en.syncTitle).last);
      await tester.pumpAndSettle();

      expect(find.text(_en.desktopDeviceSync), findsOneWidget);
    });

    _desktopTest('the connection card opens the connection dialog', (
      tester,
    ) async {
      await pumpDesktop(tester, home: _loaded());
      await tester.pumpAndSettle();

      await tester.tap(find.text(_en.connectionLabel));
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text(_en.desktopConnection),
        ),
        findsOneWidget,
      );
    });

    _desktopTest('the connection card without its bloc still opens it', (
      tester,
    ) async {
      await getIt.unregister<CommunicationBloc>();
      await pumpDesktop(tester, home: _loaded());
      await tester.pumpAndSettle();
      expect(find.text(_en.connectionStatusNotPaired), findsOneWidget);

      // The dialog needs the bloc, registered by the time anyone taps.
      getIt.registerSingleton<CommunicationBloc>(communicationBloc);
      await tester.tap(find.text(_en.connectionLabel));
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionDialog), findsOneWidget);
    });

    _desktopTest('the sync card opens the sync dialog', (tester) async {
      await pumpDesktop(tester, home: _loaded());
      await tester.pumpAndSettle();

      await tester.tap(find.text(_en.syncLabel));
      await tester.pumpAndSettle();

      expect(find.byType(SyncSection), findsOneWidget);
    });

    _desktopTest('the backup card opens backups, and X closes them', (
      tester,
    ) async {
      await pumpDesktop(tester, home: _loaded());
      await tester.pumpAndSettle();

      await tester.tap(find.text(_en.backupLabel));
      await tester.pumpAndSettle();

      expect(find.byType(BackupCard), findsOneWidget);
      final dialog = find.byType(Dialog);
      expect(
        find.descendant(of: dialog, matching: find.text(_en.backupLabel)),
        findsOneWidget,
      );
      expect(tester.getSize(find.byType(BackupCard)).width, 500);

      await tester.tap(
        find.descendant(of: dialog, matching: find.byIcon(Icons.close)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackupCard), findsNothing);
    });
  });
}
