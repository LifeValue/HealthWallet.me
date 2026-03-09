import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/services/biometric_auth_service.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/user/domain/repository/user_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

@RoutePage()
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final UserRepository _userRepository = getIt<UserRepository>();
  final BiometricAuthService _biometricAuthService =
      getIt<BiometricAuthService>();

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final minSplash = Future.delayed(const Duration(seconds: 1));

    final destination = await _resolveDestination();

    await minSplash;
    if (!mounted) return;
    context.appRouter.replace(destination);
  }

  Future<PageRouteInfo> _resolveDestination() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    if (!hasSeenOnboarding) return const OnboardingRoute();

    final isBiometricAuthEnabled =
        await _userRepository.isBiometricAuthEnabled();
    if (!isBiometricAuthEnabled) return DashboardRoute();

    final isBiometricAvailable =
        await _biometricAuthService.isBiometricAvailable();
    if (!isBiometricAvailable) return DashboardRoute();

    final didAuthenticate = await _biometricAuthService.authenticate();
    return didAuthenticate ? DashboardRoute() : const OnboardingRoute();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: Center(
        child: Image.asset('assets/images/splash.png', width: 200),
      ),
    );
  }
}
