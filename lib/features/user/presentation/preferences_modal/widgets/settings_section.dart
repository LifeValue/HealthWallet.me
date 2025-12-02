import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/widgets/theme_toggle_button.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/widgets/biometric_toggle_button.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/widgets/biometrics_setup_dialog.dart';
import 'package:health_wallet/core/widgets/dialogs/confirmation_dialog.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.normal),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  context.read<UserBloc>().add(const UserThemeToggled());
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.small),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.theme,
                        style: AppTextStyle.bodySmall,
                      ),
                      const ThemeToggleButton(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Insets.medium),
              InkWell(
                onTap: () {
                  if (state.isBiometricAuthEnabled) {
                    ConfirmationDialog.show(
                      context: context,
                      title: context.l10n.confirmDisableBiometric,
                      confirmText: context.l10n.disable,
                      cancelText: context.l10n.cancel,
                      onConfirm: () {
                        context
                            .read<UserBloc>()
                            .add(UserBiometricAuthToggled(false));
                      },
                    );
                  } else {
                    context
                        .read<UserBloc>()
                        .add(UserBiometricAuthToggled(true));
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.small),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.biometricAuthentication,
                        style: AppTextStyle.bodySmall,
                      ),
                      const BiometricToggleButton(),
                    ],
                  ),
                ),
              ),
              BlocListener<UserBloc, UserState>(
                listenWhen: (previous, current) {
                  return current.shouldShowBiometricsSetup &&
                      !current.isBiometricAuthEnabled;
                },
                listener: (context, state) {
                  context
                      .read<UserBloc>()
                      .add(const UserBiometricsSetupShown());
                  showDialog(
                    context: context,
                    builder: (context) => const BiometricsSetupDialog(),
                  );
                },
                child: const SizedBox.shrink(),
              ),
              const SizedBox(height: Insets.medium),
              InkWell(
                onTap: () {
                  context.appRouter.push(const PrivacyPolicyRoute());
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.small),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.privacyPolicy,
                        style: AppTextStyle.bodySmall,
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: context.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
