import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/app_lock/presentation/bloc/app_lock_bloc.dart';
import 'package:health_wallet/features/app_lock/presentation/widgets/app_lock_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_lock_test_fakes.dart';

/// A one-page router, so the back button goes through a
/// [RootBackButtonDispatcher] as it does with the app's auto_route router.
class _TestRouterDelegate extends RouterDelegate<Object>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
  _TestRouterDelegate(this.home);

  final Widget home;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    pages: [MaterialPage<void>(child: home)],
    onDidRemovePage: (_) {},
  );

  @override
  Future<void> setNewRoutePath(Object configuration) async {}
}

class _Page extends StatelessWidget {
  const _Page(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextButton(onPressed: onTap, child: Text(label)),
        const TextField(key: Key('field')),
      ],
    ),
  );
}

void main() {
  late FakeLockAuthService auth;
  late FakeLockUserRepository users;
  late SharedPreferences prefs;
  late AppLockBloc bloc;
  late FakeAppLockClock clock;
  late _TestRouterDelegate delegate;
  late int dashboardTaps;

  final lockTitle = find.text('HealthWallet is locked');
  final lockOverlay = find.byKey(const Key('app_lock_overlay'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({'hasSeenOnboarding': true});
    prefs = await SharedPreferences.getInstance();
    auth = FakeLockAuthService();
    users = FakeLockUserRepository();
    clock = FakeAppLockClock();
    dashboardTaps = 0;
    delegate = _TestRouterDelegate(
      _Page('Dashboard', () => dashboardTaps++),
    );
  });

  Future<void> pumpApp(WidgetTester tester) async {
    // Built inside the test's zone, so its handlers run on the fake clock.
    bloc = AppLockBloc(auth, users, prefs, clock);
    // Not awaited: close() waits on handlers that the fake clock never
    // finishes once the test body is done.
    addTearDown(() => unawaited(bloc.close()));
    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: MaterialApp.router(
          routerConfig: RouterConfig<Object>(
            routerDelegate: delegate,
            backButtonDispatcher: RootBackButtonDispatcher(),
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => AppLockOverlay(child: child!),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> start(WidgetTester tester) async {
    bloc.add(const AppLockStarted());
    await tester.pumpAndSettle();
  }

  testWidgets('covers the app with the splash while it checks', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(bloc.state.status, AppLockStatus.checking);
    expect(lockOverlay, findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(lockTitle, findsNothing);

    await tester.tap(find.text('Dashboard'), warnIfMissed: false);
    expect(dashboardTaps, 0);
  });

  testWidgets('Lock fails: the lock screen stays up and blocks taps', (
    tester,
  ) async {
    auth.results.add(false);
    await pumpApp(tester);
    await start(tester);

    expect(bloc.state.status, AppLockStatus.locked);
    expect(lockTitle, findsOneWidget);
    expect(find.text('Unlock to view your health records'), findsOneWidget);

    await tester.tap(find.text('Dashboard'), warnIfMissed: false);
    expect(dashboardTaps, 0);
  });

  testWidgets('Retry calls authenticate and uncovers the app', (tester) async {
    auth.results.addAll([false, true]);
    await pumpApp(tester);
    await start(tester);
    expect(auth.authenticateCalls, 1);

    await tester.tap(find.widgetWithText(AppButton, 'Unlock'));
    await tester.pumpAndSettle();

    expect(auth.authenticateCalls, 2);
    expect(lockOverlay, findsNothing);
    await tester.tap(find.text('Dashboard'));
    expect(dashboardTaps, 1);
  });

  testWidgets('disables Unlock while the prompt is open', (tester) async {
    auth.pending = Completer<bool>();
    await pumpApp(tester);
    bloc.add(const AppLockStarted());
    await tester.pump();
    await tester.pump();

    final button = tester.widget<AppButton>(find.byType(AppButton));
    expect(button.enabled, isFalse);

    auth.pending!.complete(true);
    await tester.pumpAndSettle();
    expect(lockOverlay, findsNothing);
  });

  testWidgets('shows nothing over an app without a lock', (tester) async {
    users.lockEnabled = false;
    await pumpApp(tester);
    await start(tester);

    expect(lockOverlay, findsNothing);
    await tester.tap(find.text('Dashboard'));
    expect(dashboardTaps, 1);
  });

  testWidgets('swallows the back button on the route below while locked', (
    tester,
  ) async {
    await pumpApp(tester);
    await start(tester);
    unawaited(
      delegate.navigatorKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => _Page('Record', () {})),
      ),
    );
    await tester.pumpAndSettle();

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(delegate.navigatorKey.currentState!.canPop(), isTrue);

    // Once unlocked, the back button reaches the router again.
    auth.results.add(true);
    bloc.add(const AppLockUnlockRequested());
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(delegate.navigatorKey.currentState!.canPop(), isFalse);
  });

  testWidgets('swallows the predictive back gesture only while locked', (
    tester,
  ) async {
    await pumpApp(tester);
    await start(tester);
    final observer =
        tester.state(find.byType(AppLockOverlay)) as WidgetsBindingObserver;
    final event = PredictiveBackEvent.fromMap(const <String?, Object?>{
      'touchOffset': <double>[0, 0],
      'progress': 0.0,
      'swipeEdge': 0,
    });

    expect(observer.handleStartBackGesture(event), isTrue);

    auth.results.add(true);
    bloc.add(const AppLockUnlockRequested());
    await tester.pumpAndSettle();

    expect(observer.handleStartBackGesture(event), isFalse);
    expect(await observer.didPopRoute(), isFalse);
  });

  testWidgets(
    'Deep link or share intent while locked: a route opened behind the lock '
    'stays covered until unlock',
    (tester) async {
      await pumpApp(tester);
      await start(tester);

      var recordTaps = 0;
      unawaited(
        delegate.navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => _Page('Record', () => recordTaps++),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(lockTitle, findsOneWidget);
      await tester.tap(find.text('Record'), warnIfMissed: false);
      expect(recordTaps, 0);

      auth.results.add(true);
      await tester.tap(find.widgetWithText(AppButton, 'Unlock'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record'));
      expect(recordTaps, 1);
    },
  );

  testWidgets('hides the routes below from screen readers while locked', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    auth.results.add(false);
    await pumpApp(tester);
    await start(tester);

    expect(find.bySemanticsLabel(RegExp('Dashboard')), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('HealthWallet is locked')),
      findsOneWidget,
    );

    auth.results.add(true);
    await tester.tap(find.widgetWithText(AppButton, 'Unlock'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Dashboard')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('takes keyboard focus away from the routes below', (
    tester,
  ) async {
    auth.results.add(true);
    await pumpApp(tester);
    await start(tester);
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.focusNode.hasFocus, isTrue);

    // Locks again on a resume after more than 30 s.
    auth.pending = Completer<bool>();
    bloc.add(const AppLockLifecycleChanged(AppLifecycleState.paused));
    await tester.pump();
    clock.advance(const Duration(seconds: 31));
    bloc.add(const AppLockLifecycleChanged(AppLifecycleState.resumed));
    await tester.pump();
    await tester.pump();

    expect(lockTitle, findsOneWidget);
    expect(field.focusNode.hasFocus, isFalse);

    auth.pending!.complete(true);
    await tester.pumpAndSettle();
  });
}
