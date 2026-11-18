import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/gen/assets.gen.dart';

/// The loading screen shown while the app starts, on mobile and desktop.
///
/// It continues the native launch screen (`branding/splash.yaml`): the same app
/// icon at the same size, centred on the same background, so nothing moves
/// when Flutter takes over. Only the app name appears, below the icon.
///
/// The native launch screen can only follow the system's light or dark mode,
/// not the app's own theme setting, so this screen follows the system too;
/// the app's theme takes over on the next page.
class AppLaunchScreen extends StatelessWidget {
  const AppLaunchScreen({super.key});

  /// Matches the 120 pt icon of the native launch screen.
  static const double iconSize = 120;

  @override
  Widget build(BuildContext context) {
    final isSystemDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return ColoredBox(
      color: isSystemDark ? AppColors.surfaceDark : AppColors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Center(
              child: Assets.images.appLaunchIcon.image(
                width: iconSize,
                height: iconSize,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: constraints.maxHeight / 2 + iconSize / 2 + Insets.medium,
              child: Text(
                'HealthWallet.me',
                textAlign: TextAlign.center,
                style: AppTextStyle.titleLarge.copyWith(
                  color: isSystemDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
