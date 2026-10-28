import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_launch_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shows the [AppLaunchScreen] for a second, then opens onboarding or the dashboard.
///
/// The app lock is not checked here: `AppLockOverlay` covers every route,
/// so a failed or cancelled check can no longer lead to onboarding.
@RoutePage()
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _openNextPage();
  }

  Future<void> _openNextPage() async {
    final minSplash = Future.delayed(const Duration(seconds: 1));

    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding =
        prefs.getBool(SharedPrefsConstants.hasSeenOnboarding) ?? false;
    final PageRouteInfo destination = hasSeenOnboarding
        ? const DashboardRoute()
        : const OnboardingRoute();

    await minSplash;
    if (!mounted) return;
    unawaited(context.appRouter.replace(destination));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: AppLaunchScreen());
  }
}
