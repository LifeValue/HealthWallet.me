import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/widgets/biometrics_setup_dialog.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class OnboardingScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final String? content;
  final String? bottom;
  final SvgGenImage image;
  final bool showBiometricToggle;
  final Widget? customWidget;

  const OnboardingScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.description,
    this.content,
    this.bottom,
    required this.image,
    this.showBiometricToggle = false,
    this.customWidget,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserBloc, UserState>(
      buildWhen: (previous, current) {
        return previous.isBiometricAuthEnabled !=
                current.isBiometricAuthEnabled ||
            previous.status != current.status;
      },
      builder: (context, userState) {
        return BlocBuilder<OnboardingBloc, OnboardingState>(
          builder: (context, onboardingState) {
            return MultiBlocListener(
              listeners: [
                BlocListener<UserBloc, UserState>(
                  listenWhen: (previous, current) {
                    return current.shouldShowBiometricsSetup &&
                        !current.isBiometricAuthEnabled;
                  },
                  listener: (context, userState) {
                    context
                        .read<UserBloc>()
                        .add(const UserBiometricsSetupShown());
                    showDialog(
                      context: context,
                      builder: (context) => const BiometricsSetupDialog(),
                    );
                  },
                ),
              ],
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableHeight = constraints.maxHeight;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: availableHeight - 40,
                      ),
                      child: Column(
                        children: [
                          image.svg(height: 250),
                          if (!showBiometricToggle)
                            const SizedBox(height: Insets.large),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: AppTextStyle.titleLarge.copyWith(
                              color: context.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: Insets.large),
                          _buildRichSubtitle(context, subtitle),
                          const SizedBox(height: Insets.large),
                          if (content != null) ...[
                            SizedBox(
                              height: (availableHeight - 600).clamp(0.0, 200.0),
                            ),
                            _buildRichDescription(
                                context, content!, TextAlign.left),
                            if (bottom != null) ...[
                              const SizedBox(height: Insets.medium),
                              _buildRichDescription(
                                  context, bottom!, TextAlign.center),
                            ],
                          ] else ...[
                            _buildRichDescription(
                                context, description, TextAlign.center),
                          ],
                          if (showBiometricToggle) ...[
                            const SizedBox(height: Insets.large),
                            BlocBuilder<UserBloc, UserState>(
                              builder: (context, userState) {
                                return TextButton(
                                  onPressed: () {
                                    final isEnabled =
                                        userState.isBiometricAuthEnabled;
                                    if (isEnabled) {
                                      AppSimpleDialog.showConfirmation(
                                        context: context,
                                        title: context
                                            .l10n.confirmDisableBiometric,
                                        confirmText: context.l10n.disable,
                                        cancelText: context.l10n.cancel,
                                        onConfirm: () {
                                          context.read<UserBloc>().add(
                                              UserBiometricAuthToggled(false));
                                        },
                                      );
                                    } else {
                                      context
                                          .read<UserBloc>()
                                          .add(UserBiometricAuthToggled(true));
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        context.colorScheme.primary,
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    userState.isBiometricAuthEnabled
                                        ? context.l10n.disableBiometricAuth
                                        : context.l10n.enableBiometricAuth,
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              },
                            ),
                          ],
                          if (customWidget != null) ...[
                            const SizedBox(height: Insets.large),
                            customWidget!,
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRichSubtitle(BuildContext context, String subtitle) {
    if (subtitle.contains('<link>') && subtitle.contains('</link>')) {
      final parts = subtitle.split('<link>');
      final linkParts = parts[1].split('</link>');
      final beforeLink = parts[0];
      final linkText = linkParts[0];
      final afterLink = linkParts[1];

      return BlocListener<OnboardingBloc, OnboardingState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppTextStyle.regular.copyWith(
              color: context.colorScheme.onSurface.withOpacity(0.7),
            ),
            children: [
              TextSpan(text: beforeLink),
              TextSpan(
                text: linkText,
                style: AppTextStyle.regular.copyWith(
                  color: context.colorScheme.onSurface.withOpacity(0.7),
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    final url = linkText == 'HealthWallet.me'
                        ? 'https://healthwallet.me'
                        : 'https://github.com/fastenhealth/fasten-onprem';
                    context.read<OnboardingBloc>().add(
                          OnboardingLaunchUrl(url),
                        );
                  },
              ),
              TextSpan(text: afterLink),
            ],
          ),
        ),
      );
    } else if (subtitle.contains('**') && subtitle.split('**').length >= 3) {
      final parts = subtitle.split('**');
      final beforeBold = parts[0];
      final boldText = parts[1];
      final afterBold = parts.length > 2 ? parts[2] : '';

      return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: AppTextStyle.regular.copyWith(
            color: context.colorScheme.onSurface.withOpacity(0.7),
          ),
          children: [
            TextSpan(text: beforeBold),
            TextSpan(
              text: boldText,
              style: AppTextStyle.regular.copyWith(
                color: context.colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(text: afterBold),
          ],
        ),
      );
    } else {
      return Text(
        subtitle,
        textAlign: TextAlign.center,
        style: AppTextStyle.regular.copyWith(
          color: context.colorScheme.onSurface.withOpacity(0.7),
        ),
      );
    }
  }

  Widget _buildRichDescription(
    BuildContext context,
    String description,
    TextAlign textAlign,
  ) {
    if (description.contains('•')) {
      return _buildBulletPointText(context, description, textAlign);
    }

    if (description.contains('<link>') && description.contains('</link>')) {
      final parts = description.split('<link>');
      final linkParts = parts[1].split('</link>');
      final beforeLink = parts[0];
      final linkText = linkParts[0];
      final afterLink = linkParts[1];

      return BlocListener<OnboardingBloc, OnboardingState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        child: RichText(
          textAlign: textAlign,
          text: TextSpan(
            style: AppTextStyle.regular.copyWith(
              color: context.colorScheme.onSurface.withOpacity(0.7),
            ),
            children: [
              TextSpan(text: beforeLink),
              TextSpan(
                text: linkText,
                style: AppTextStyle.regular.copyWith(
                  color: context.colorScheme.onSurface.withOpacity(0.7),
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    final url = linkText == 'HealthWallet.me'
                        ? 'https://healthwallet.me'
                        : 'https://github.com/fastenhealth/fasten-onprem';
                    context.read<OnboardingBloc>().add(
                          OnboardingLaunchUrl(url),
                        );
                  },
              ),
              TextSpan(text: afterLink),
            ],
          ),
        ),
      );
    } else if (description.contains('**')) {
      final segments = description.split('**');
      final spans = <TextSpan>[];
      for (int i = 0; i < segments.length; i++) {
        spans.add(TextSpan(
          text: segments[i],
          style: i.isOdd
              ? AppTextStyle.regular.copyWith(
                  color: context.colorScheme.onSurface.withOpacity(0.85),
                  fontWeight: FontWeight.w700,
                )
              : null,
        ));
      }
      return RichText(
        textAlign: textAlign,
        text: TextSpan(
          style: AppTextStyle.regular.copyWith(
            color: context.colorScheme.onSurface.withOpacity(0.7),
          ),
          children: spans,
        ),
      );
    } else {
      return Text(
        description,
        textAlign: textAlign,
        style: AppTextStyle.regular.copyWith(
          color: context.colorScheme.onSurface.withOpacity(0.7),
        ),
      );
    }
  }

  Widget _buildBulletPointText(
    BuildContext context,
    String text,
    TextAlign textAlign,
  ) {
    final lines = text.split('\n');
    final inlineSpans = <InlineSpan>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().startsWith('•')) {
        final bulletIndex = line.indexOf('•');
        final afterBullet = line.substring(bulletIndex + 1).trimLeft();
        final beforeBullet = line.substring(0, bulletIndex);

        if (beforeBullet.isNotEmpty) {
          inlineSpans.add(TextSpan(text: beforeBullet));
        }
        inlineSpans.add(TextSpan(text: '•'));
        inlineSpans.add(WidgetSpan(
          child: SizedBox(width: 8),
        ));

        if (afterBullet.contains('<link>') && afterBullet.contains('</link>')) {
          final parts = afterBullet.split('<link>');
          final linkParts = parts[1].split('</link>');
          final beforeLink = parts[0];
          final linkText = linkParts[0];
          final afterLink = linkParts[1];

          inlineSpans.add(TextSpan(text: beforeLink));
          inlineSpans.add(
            TextSpan(
              text: linkText,
              style: AppTextStyle.regular.copyWith(
                color: context.colorScheme.onSurface.withOpacity(0.7),
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  final url = linkText == 'HealthWallet.me'
                      ? 'https://healthwallet.me'
                      : 'https://github.com/fastenhealth/fasten-onprem';
                  context.read<OnboardingBloc>().add(
                        OnboardingLaunchUrl(url),
                      );
                },
            ),
          );
          inlineSpans.add(TextSpan(text: afterLink));
        } else {
          inlineSpans.add(TextSpan(text: afterBullet));
        }
      } else {
        inlineSpans.add(TextSpan(text: line));
      }

      if (i < lines.length - 1) {
        inlineSpans.add(const TextSpan(text: '\n'));
      }
    }

    return BlocListener<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: RichText(
        textAlign: textAlign,
        text: TextSpan(
          style: AppTextStyle.regular.copyWith(
            color: context.colorScheme.onSurface.withOpacity(0.7),
            height: 1.4,
          ),
          children: inlineSpans,
        ),
      ),
    );
  }
}

