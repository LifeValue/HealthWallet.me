import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/core/l10n/l10n.dart';

class UserSection extends StatefulWidget {
  const UserSection({super.key});

  @override
  State<UserSection> createState() => _UserSectionState();
}

class _UserSectionState extends State<UserSection> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  bool _isEditing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _startEditing(String currentName) {
    setState(() {
      _isEditing = true;
      _nameController.text = currentName;
    });
    _nameFocusNode.requestFocus();
  }

  void _saveName() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty) {
      setState(() {
        _isEditing = false;
      });
      _nameFocusNode.unfocus();

      // Update the user name through BLoC
      context.read<UserBloc>().add(UserNameUpdated(newName));
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = context.isDarkMode
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return BlocListener<UserBloc, UserState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status.runtimeType.toString().contains('Failure'),
      listener: (context, state) {
        if (state.status.runtimeType.toString().contains('Failure')) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${context.l10n.failedToUpdateDisplayName}: ${state.status.toString()}'),
              backgroundColor: context.colorScheme.error,
            ),
          );
        }
      },
      child: BlocBuilder<UserBloc, UserState>(
        builder: (context, userState) {
          return BlocBuilder<SyncBloc, SyncState>(
            builder: (context, syncState) {
              final user = userState.user;
              final displayName = user.name.isNotEmpty
                  ? user.name
                  : (syncState.syncQrData?.tokenMeta.fullName.isNotEmpty == true
                      ? syncState.syncQrData!.tokenMeta.fullName
                      : 'User');

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.normal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Assets.icons.information.svg(
                          width: 16,
                          height: 16,
                          colorFilter: ColorFilter.mode(
                            iconColor,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: Insets.extraSmall),
                        Text(
                          context.l10n.displayName,
                          style: AppTextStyle.labelMedium.copyWith(
                            color: iconColor,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _isEditing
                              ? TextField(
                                  controller: _nameController,
                                  focusNode: _nameFocusNode,
                                  style: AppTextStyle.bodyLarge,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onSubmitted: (_) => _saveName(),
                                  onEditingComplete: _saveName,
                                )
                              : Text(
                                  displayName,
                                  style: AppTextStyle.bodyLarge,
                                ),
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            icon: _isEditing
                                ? const Icon(
                                    Icons.check,
                                    color: AppColors.primary,
                                    size: 21,
                                  )
                                : Assets.icons.edit.svg(
                                    width: 21,
                                    height: 19.5,
                                    colorFilter: const ColorFilter.mode(
                                      AppColors.primary,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                            onPressed: _isEditing
                                ? _saveName
                                : () => _startEditing(user.name.isNotEmpty
                                    ? user.name
                                    : displayName),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
