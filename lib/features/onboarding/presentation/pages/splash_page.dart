import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    if (!hasSeenOnboarding) {
      context.appRouter.replace(const OnboardingRoute());
      return;
    }

    final isBiometricAuthEnabled =
        await _userRepository.isBiometricAuthEnabled();

    if (!isBiometricAuthEnabled) {
      context.appRouter.replace(DashboardRoute());
      return;
    }

    final isBiometricAvailable =
        await _biometricAuthService.isBiometricAvailable();

    if (!isBiometricAvailable) {
      context.appRouter.replace(DashboardRoute());
      return;
    }

    final didAuthenticate = await _biometricAuthService.authenticate();
    if (didAuthenticate) {
      context.appRouter.replace(DashboardRoute());
    } else {
      context.appRouter.replace(const OnboardingRoute());
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
