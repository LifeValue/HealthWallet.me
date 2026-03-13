import 'package:flutter/material.dart';

import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class PeerSearchStatusView extends StatelessWidget {
  final bool hasTimedOut;
  final bool wifiToggleNeeded;
  final VoidCallback onRetry;
  final Widget bottomBar;

  const PeerSearchStatusView({
    super.key,
    required this.hasTimedOut,
    required this.wifiToggleNeeded,
    required this.onRetry,
    required this.bottomBar,
  });

  @override
  Widget build(BuildContext context) {
    if (wifiToggleNeeded) {
      return _buildWifiToggleView(context);
    }

    if (hasTimedOut) {
      return _buildNoDevicesFoundView(context);
    }

    return _buildSearchingView(context);
  }

  Widget _buildSearchingView(BuildContext context) {
    return Column(
      children: [
        _DiscoveryHintHeader(
          title: 'Searching for nearby devices...',
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: context.theme.dividerColor,
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          color: AppColors.primary.withValues(alpha: 0.3),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Assets.images.device.svg(
                          colorFilter: ColorFilter.mode(
                            AppColors.primary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'Search for devices...',
                  style: AppTextStyle.bodyLarge.copyWith(
                    color: context.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomBar,
      ],
    );
  }

  Widget _buildNoDevicesFoundView(BuildContext context) {
    return Column(
      children: [
        _DiscoveryHintHeader(
          title: 'No Devices Found',
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: context.theme.dividerColor,
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Assets.images.noDeviceFound.svg(),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: Insets.normal),
                  child: AppButton(
                    onPressed: onRetry,
                    label: 'Retry',
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomBar,
      ],
    );
  }

  Widget _buildWifiToggleView(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.normal,
            Insets.small,
            Insets.normal,
            Insets.normal,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connection Issue',
                style: AppTextStyle.titleMedium.copyWith(
                  color: context.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'WiFi Direct is unresponsive on this device.',
                style: AppTextStyle.bodyMedium.copyWith(
                  color:
                      context.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: context.theme.dividerColor,
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: Insets.normal),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(Insets.normal),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off, color: AppColors.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'WiFi Direct unresponsive. Toggle WiFi off/on, then tap Retry.',
                            style: AppTextStyle.bodySmall.copyWith(
                              color: context.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    onPressed: onRetry,
                    label: 'Retry',
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomBar,
      ],
    );
  }
}

class _DiscoveryHintHeader extends StatelessWidget {
  final String title;

  const _DiscoveryHintHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.normal,
        Insets.small,
        Insets.normal,
        Insets.normal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyle.titleMedium.copyWith(
              color: context.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: AppTextStyle.bodyMedium.copyWith(
                color:
                    context.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              children: [
                const TextSpan(text: 'Make sure the other device has the '),
                TextSpan(
                  text: 'HealthWallet.me',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const TextSpan(text: ' opened'),
              ],
            ),
          ),
          const SizedBox(height: Insets.small),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Assets.icons.information.svg(
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                    AppColors.warning,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: AppTextStyle.labelLarge.copyWith(
                        color: context.colorScheme.onSurface,
                      ),
                      children: [
                        const TextSpan(text: 'The '),
                        TextSpan(
                          text: 'receiving device',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                        const TextSpan(text: ' must have '),
                        TextSpan(
                          text: 'Share Proximity',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: 'ON',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                        const TextSpan(
                            text: ' in Preferences to be discoverable.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
