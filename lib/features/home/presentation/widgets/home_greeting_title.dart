import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/notifications/notification_widget.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/preference_modal.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class HomeGreetingTitle extends StatelessWidget {
  final HomeState homeState;

  const HomeGreetingTitle({super.key, required this.homeState});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BlocBuilder<UserBloc, UserState>(
                builder: (context, userState) {
                  return BlocBuilder<SyncBloc, SyncState>(
                    builder: (context, syncState) {
                      final displayName = userState.user.name.isNotEmpty
                          ? userState.user.name
                          : (syncState.syncQrData?.tokenMeta.fullName
                                      .isNotEmpty ==
                                  true
                              ? syncState.syncQrData!.tokenMeta.fullName
                              : 'User');
                      return RichText(
                        text: TextSpan(
                          style: AppTextStyle.titleMedium.copyWith(
                            color: context.colorScheme.onSurface,
                          ),
                          children: [
                            TextSpan(text: context.l10n.homeHi),
                            TextSpan(
                                text: displayName,
                                style: TextStyle(
                                    color: context.colorScheme.primary)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        _HomeActions(editMode: homeState.editMode),
      ],
    );
  }
}

class _HomeActions extends StatelessWidget {
  final bool editMode;

  const _HomeActions({required this.editMode});

  @override
  Widget build(BuildContext context) {
    if (editMode) {
      return TextButton(
        onPressed: () =>
            context.read<HomeBloc>().add(const HomeEditModeChanged(false)),
        style: TextButton.styleFrom(
          foregroundColor: context.colorScheme.primary,
        ),
        child: Text(context.l10n.done),
      );
    }

    return Row(
      children: [
        const NotificationWidget(),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
          ),
          child: IconButton(
            icon: Assets.icons.settings.svg(
              colorFilter: ColorFilter.mode(
                context.colorScheme.onSurface,
                BlendMode.srcIn,
              ),
            ),
            onPressed: () {
              PreferenceModal.show(context);
            },
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
