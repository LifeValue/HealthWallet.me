import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/theme.dart';
import 'package:health_wallet/core/widgets/app_launch_screen.dart';
import 'package:health_wallet/gen/assets.gen.dart';

void main() {
  Future<void> pumpLaunchScreen(
    WidgetTester tester, {
    required ThemeData theme,
    Brightness system = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = system;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      MaterialApp(theme: theme, home: const AppLaunchScreen()),
    );
  }

  Color background(WidgetTester tester) => tester
      .widget<ColoredBox>(
        find.descendant(
          of: find.byType(AppLaunchScreen),
          matching: find.byType(ColoredBox),
        ),
      )
      .color;

  testWidgets('shows the app icon at the native splash size, centred', (
    tester,
  ) async {
    await pumpLaunchScreen(tester, theme: AppTheme.lightTheme);

    final icon = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          (w.image as AssetImage).assetName == Assets.images.appLaunchIcon.path,
    );
    expect(icon, findsOneWidget);
    expect(tester.getSize(icon), const Size.square(AppLaunchScreen.iconSize));
    // Same place as the native launch screen, so nothing moves.
    expect(tester.getCenter(icon), const Offset(200, 400));
  });

  testWidgets('shows the app name below the icon', (tester) async {
    await pumpLaunchScreen(tester, theme: AppTheme.lightTheme);

    final name = find.text('HealthWallet.me');
    expect(name, findsOneWidget);
    expect(
      tester.getTopLeft(name).dy,
      greaterThan(400 + AppLaunchScreen.iconSize / 2),
    );
    expect(tester.getCenter(name).dx, 200);
  });

  testWidgets('uses the light native splash background in light mode', (
    tester,
  ) async {
    await pumpLaunchScreen(tester, theme: AppTheme.lightTheme);

    expect(background(tester), const Color(0xFFFFFFFF));
  });

  testWidgets('uses the dark native splash background in dark mode', (
    tester,
  ) async {
    await pumpLaunchScreen(
      tester,
      theme: AppTheme.lightTheme,
      system: Brightness.dark,
    );

    expect(background(tester), const Color(0xFF1E1E1E));
    final name = tester.widget<Text>(find.text('HealthWallet.me'));
    expect(name.style?.color, AppColors.textPrimaryDark);
  });

  testWidgets(
    'follows the system, not the app theme, like the native splash',
    (tester) async {
      await pumpLaunchScreen(tester, theme: AppTheme.darkTheme);

      expect(background(tester), const Color(0xFFFFFFFF));
    },
  );
}
