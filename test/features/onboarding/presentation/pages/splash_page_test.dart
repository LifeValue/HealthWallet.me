import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/services/biometric_auth_service.dart';
import 'package:health_wallet/features/onboarding/presentation/pages/splash_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app_lock/app_lock_test_fakes.dart';

/// Records where the splash page sends the user.
class _FakeStackRouter extends Fake implements StackRouter {
  final replaced = <PageRouteInfo>[];

  @override
  Future<T?> replace<T extends Object?>(
    PageRouteInfo route, {
    OnNavigationFailure? onFailure,
  }) async {
    replaced.add(route);
    return null;
  }
}

void main() {
  late _FakeStackRouter router;
  late FakeLockAuthService auth;

  setUp(() async {
    router = _FakeStackRouter();
    // The lock is on and every prompt would fail: the splash must not ask.
    auth = FakeLockAuthService();
    await getIt.reset();
    getIt.registerSingleton<BiometricAuthService>(auth);
  });

  tearDown(getIt.reset);

  Future<void> pumpSplash(
    WidgetTester tester,
    Map<String, Object> prefs,
  ) async {
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(
      MaterialApp(
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: const SplashPage(),
        ),
      ),
    );
  }

  testWidgets('opens onboarding on first launch', (tester) async {
    await pumpSplash(tester, {});
    await tester.pump(const Duration(seconds: 1));

    expect(router.replaced.map((r) => r.routeName), [OnboardingRoute.name]);
  });

  testWidgets('opens onboarding while it is not finished', (tester) async {
    await pumpSplash(tester, {'hasSeenOnboarding': false});
    await tester.pump(const Duration(seconds: 1));

    expect(router.replaced.map((r) => r.routeName), [OnboardingRoute.name]);
  });

  testWidgets('opens the dashboard once onboarding is done', (tester) async {
    await pumpSplash(tester, {'hasSeenOnboarding': true});
    await tester.pump(const Duration(seconds: 1));

    expect(router.replaced.map((r) => r.routeName), [DashboardRoute.name]);
  });

  testWidgets(
    'opens the dashboard without asking for authentication when the lock is '
    'on (the app lock overlay does that)',
    (tester) async {
      await pumpSplash(tester, {
        'hasSeenOnboarding': true,
        'isBiometricAuthEnabled': true,
      });
      await tester.pump(const Duration(seconds: 1));

      expect(router.replaced.map((r) => r.routeName), [DashboardRoute.name]);
      expect(auth.authenticateCalls, 0);
    },
  );

  testWidgets('shows the logo for at least one second', (tester) async {
    await pumpSplash(tester, {'hasSeenOnboarding': true});

    expect(find.byType(Image), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    expect(router.replaced, isEmpty);

    await tester.pump(const Duration(milliseconds: 100));
    expect(router.replaced, hasLength(1));
  });

  testWidgets('does not navigate once it has been removed', (tester) async {
    await pumpSplash(tester, {'hasSeenOnboarding': true});
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));

    expect(router.replaced, isEmpty);
  });
}
