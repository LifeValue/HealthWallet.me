import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/ai-model/ai_model_section.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/user/user_section.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/patient_section.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/sync/sync_section.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/widgets/settings_section.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

class PreferenceModal extends StatelessWidget {
  const PreferenceModal({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(
              value: BlocProvider.of<UserBloc>(context),
            ),
            BlocProvider.value(
              value: BlocProvider.of<PatientBloc>(context),
            ),
          ],
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: const PreferenceModal(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = context.theme.dividerColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(Insets.medium),
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.normal,
                vertical: Insets.small,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.preferences,
                    style: AppTextStyle.bodyMedium,
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: IconButton(
                      icon: Assets.icons.close.svg(
                        colorFilter: ColorFilter.mode(
                          context.colorScheme.onSurface,
                          BlendMode.srcIn,
                        ),
                      ),
                      onPressed: () {
                        context.popDialog();
                      },
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: borderColor,
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: Insets.normal),
                    const UserSection(),
                    const SizedBox(height: Insets.medium),
                    const PatientSection(),
                    const SizedBox(height: Insets.medium),
                    const SyncSection(),
                    const SizedBox(height: Insets.medium),
                    const AiModelSection(),
                    const SizedBox(height: Insets.medium),
                    const SettingsSection(),
                    const SizedBox(height: Insets.medium),
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snap) => !snap.hasData
                          ? const SizedBox(height: 40)
                          : Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: Insets.normal),
                              child: Text(
                                '${context.l10n.version}: v${snap.data!.version} (${snap.data!.buildNumber})',
                                style: AppTextStyle.labelSmall.copyWith(
                                  color: context.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: Insets.normal),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
