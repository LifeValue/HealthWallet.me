import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/core/widgets/app_launch_screen.dart';
import 'package:health_wallet/features/app_lock/presentation/bloc/app_lock_bloc.dart';

/// Covers [child] (the app's router) while [AppLockBloc] isn't unlocked.
///
/// It sits in the `MaterialApp.router` builder, above the Navigator, so it
/// guards every route, including ones opened by a deep link or a share
/// intent. While it covers the app it is opaque, takes every tap, keeps
/// focus and semantics away from the routes below and swallows the back
/// button.
class AppLockOverlay extends StatefulWidget {
  const AppLockOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends State<AppLockOverlay>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Registered before the Router below adds its back button dispatcher,
    // so this observer sees the back button first.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _coversApp => context.read<AppLockBloc>().state.coversApp;

  @override
  Future<bool> didPopRoute() async => _coversApp;

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) => _coversApp;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppLockBloc, AppLockState>(
      builder: (context, state) {
        final covered = state.coversApp;
        return Stack(
          children: [
            ExcludeFocus(excluding: covered, child: widget.child),
            if (covered)
              Positioned.fill(
                child: BlockSemantics(
                  child: _LockScreen(state: state),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.state});

  final AppLockState state;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('app_lock_overlay'),
      color: context.colorScheme.surface,
      child: state.status == AppLockStatus.checking
          // Same screen as the splash page, so start-up doesn't flicker.
          ? const AppLaunchScreen()
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.screenHorizontalPadding,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: Insets.extraLarge,
                          color: context.colorScheme.primary,
                        ),
                        const SizedBox(height: Insets.medium),
                        Text(
                          context.l10n.appLockTitle,
                          textAlign: TextAlign.center,
                          style: AppTextStyle.titleLarge.copyWith(
                            color: context.primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: Insets.small),
                        Text(
                          context.l10n.appLockMessage,
                          textAlign: TextAlign.center,
                          style: AppTextStyle.bodyMedium.copyWith(
                            color: context.secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: Insets.large),
                        AppButton(
                          label: context.l10n.appLockUnlock,
                          icon: const Icon(Icons.lock_open),
                          enabled: !state.isAuthenticating,
                          onPressed: () => context.read<AppLockBloc>().add(
                            const AppLockUnlockRequested(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
