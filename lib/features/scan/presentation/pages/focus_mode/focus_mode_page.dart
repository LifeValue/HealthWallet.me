import 'dart:async';
import 'package:another_flushbar/flushbar.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/notifications/notification_utils.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:health_wallet/features/scan/presentation/pages/focus_mode/bloc/focus_mode_bloc.dart';
import 'package:health_wallet/gen/assets.gen.dart';

@RoutePage()
class FocusModePage extends StatelessWidget {
  const FocusModePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<FocusModeBloc>()..add(const FocusModeEvent.started()),
      child: const _FocusModeView(),
    );
  }
}

class _FocusModeView extends StatefulWidget {
  const _FocusModeView();

  @override
  State<_FocusModeView> createState() => _FocusModeViewState();
}

class _FocusModeViewState extends State<_FocusModeView> {
  bool _isHiding = false;
  Flushbar? _currentFlushbar;

  void _handleScreenDarkened(bool isDarkened) {
    if (isDarkened) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  void _restoreScreen(BuildContext context) {
    context.read<FocusModeBloc>().add(const FocusModeEvent.screenRestored());
  }

  void _exitFocusMode(BuildContext context) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isHiding = true;
    });

    final currentState = context.read<FocusModeBloc>().state;
    if (currentState.isScreenDarkened) {
      context.read<FocusModeBloc>().add(const FocusModeEvent.screenRestored());
    }

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final wasScreenDarkened = currentState.isScreenDarkened;
      final delay = wasScreenDarkened
          ? const Duration(milliseconds: 300)
          : const Duration(milliseconds: 200);

      Future.delayed(delay, () {
        if (!mounted) {
          return;
        }

        try {
          final modalRoute = ModalRoute.of(context);

          if (modalRoute?.isCurrent == true || modalRoute?.isActive == true) {
            if (mounted && context.router.canPop()) {
              context.router.pop();
            } else if (Navigator.of(context, rootNavigator: false).canPop()) {
              Navigator.of(context, rootNavigator: false).pop();
            }
          }
        } catch (e) {
          if (mounted && context.router.canPop()) {
            context.router.pop();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _currentFlushbar?.dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<FocusModeBloc, FocusModeState>(
          listenWhen: (previous, current) =>
              current.shouldExit && !previous.shouldExit,
          listener: (context, state) {
            _handleScreenDarkened(state.isScreenDarkened);
            _exitFocusMode(context);
          },
        ),
        BlocListener<FocusModeBloc, FocusModeState>(
          listenWhen: (previous, current) =>
              previous.isScreenDarkened != current.isScreenDarkened,
          listener: (context, state) {
            _handleScreenDarkened(state.isScreenDarkened);
          },
        ),
        BlocListener<ScanBloc, ScanState>(
          listener: (context, state) {
            final focusModeState = context.read<FocusModeBloc>().state;

            if (focusModeState.waitingForNotification &&
                state.notification != null &&
                _currentFlushbar == null) {
              final notification = state.notification!;

              _currentFlushbar = showProcessingDoneNotification(
                context,
                notification,
                onStatusChanged: (status) {
                  if (status == FlushbarStatus.DISMISSED && mounted) {
                    _currentFlushbar = null;
                    setState(() {
                      _isHiding = true;
                    });
                    Timer(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        context
                            .read<FocusModeBloc>()
                            .add(const FocusModeEvent.notificationDisplayed());
                      }
                    });
                  }
                },
              );

              context
                  .read<ScanBloc>()
                  .add(const ScanNotificationAcknowledged());
              return;
            }

            if (state.sessions.isEmpty) {
              return;
            }

            final hasCompletedProcessing = state.sessions.any((session) =>
                session.status == ProcessingStatus.draft ||
                session.status == ProcessingStatus.patientExtracted);

            final noSessionsProcessing =
                state.sessions.every((session) => !session.isProcessing);

            if (hasCompletedProcessing &&
                noSessionsProcessing &&
                !focusModeState.waitingForNotification) {
              context
                  .read<FocusModeBloc>()
                  .add(const FocusModeEvent.processingCompleted());
            }
          },
        ),
      ],
      child: BlocBuilder<FocusModeBloc, FocusModeState>(
        builder: (context, state) {
          final body = SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 85),
                  _buildBatteryIllustration(context, state),
                  const SizedBox(height: 20),
                  _buildChargerIndicator(state),
                  const SizedBox(height: 80),
                  _buildContentSection(state.remainingSeconds),
                  const SizedBox(height: 24),
                  _buildProgressIndicator(),
                  const SizedBox(height: 80),
                  _buildExitButton(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );

          return Scaffold(
            backgroundColor: _isHiding
                ? context.colorScheme.surface
                : const Color(0xFF1E1E1E),
            body: _isHiding
                ? Center(
                    child: CircularProgressIndicator(
                      color: context.colorScheme.primary,
                    ),
                  )
                : (state.isScreenDarkened
                    ? GestureDetector(
                        onTap: () => _restoreScreen(context),
                        child: Container(
                          color: Colors.black,
                          width: double.infinity,
                          height: double.infinity,
                          child: Center(
                            child: Text(
                              'Tap anywhere to view progress',
                              style: AppTextStyle.bodyMedium.copyWith(
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                      )
                    : body),
          );
        },
      ),
    );
  }

  Widget _buildContentSection(int remainingSeconds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Focus mode',
              style: AppTextStyle.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              remainingSeconds > 0
                  ? 'The screen will darken in $remainingSeconds seconds.'
                  : 'The screen will darken in 0 seconds.',
              style: AppTextStyle.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Instructions section
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'While your documents are being processed:',
              style: AppTextStyle.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            _buildInstructionItem(
              icon: Assets.icons.warning.svg(
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
              text: 'Do not lock the screen or exit the app.',
            ),
            const SizedBox(height: 8),
            _buildInstructionItem(
              icon: Icon(
                Icons.power,
                size: 20,
                color: Colors.white,
              ),
              text: 'Plug in the charger.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInstructionItem({
    required Widget icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        icon,
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyle.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return BlocBuilder<ScanBloc, ScanState>(
      builder: (context, state) {
        ProcessingSession? processingSession;
        if (state.sessions.isNotEmpty) {
          processingSession = state.sessions.firstWhere(
            (session) => session.isProcessing,
            orElse: () => state.sessions.first,
          );
        }

        final progress = processingSession?.progress ?? 0.0;

        return Column(
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                context.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16)
          ],
        );
      },
    );
  }

  Widget _buildExitButton(BuildContext context) {
    return AppButton(
      label: 'Exit Focus Mode',
      variant: AppButtonVariant.outlined,
      backgroundColor: Colors.white,
      onPressed: () {
        context.read<FocusModeBloc>().add(const FocusModeEvent.disposed());
        _exitFocusMode(context);
      },
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 13,
      ),
    );
  }

  Widget _buildBatteryIllustration(
    BuildContext context,
    FocusModeState state,
  ) {
    final batteryAsset = state.isCharging
        ? Assets.images.batteryPluggedIn.path
        : Assets.images.batteryWarning.path;

    return SvgPicture.asset(
      batteryAsset,
    );
  }

  Widget _buildChargerIndicator(FocusModeState state) {
    if (state.isCharging) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Assets.icons.check.svg(
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(
              Colors.white,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'Charger pluged in.',
            style: AppTextStyle.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      );
    }

    return Text(
      'Plug in the charger...',
      style: AppTextStyle.bodySmall.copyWith(
        color: Colors.white.withOpacity(0.6),
        fontWeight: FontWeight.w400,
      ),
      textAlign: TextAlign.center,
    );
  }
}
