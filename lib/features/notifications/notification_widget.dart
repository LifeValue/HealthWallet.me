import 'dart:io' show Platform;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart';
import 'package:health_wallet/features/notifications/bloc/notification_bloc.dart';
import 'package:health_wallet/features/scan/presentation/pages/load_model/bloc/load_model_bloc.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class NotificationWidget extends StatefulWidget {
  const NotificationWidget({super.key});

  @override
  State<NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<NotificationWidget> {
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;
  bool _isOverlayOpen = false;

  void _showOverlay(NotificationState state) {
    final overlay = Overlay.of(context);
    final colorScheme = context.colorScheme;
    final dividerColor = context.borderColor;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final platformOffset = Platform.isIOS ? Insets.extraLarge : Insets.large;
        final tabletExtra = context.isTablet ? -36.0 : 0.0;
        final topPadding =
            MediaQuery.of(context).viewPadding.top + kToolbarHeight + platformOffset + tabletExtra;
        return BlocBuilder<NotificationBloc, NotificationState>(
          bloc: context.read<NotificationBloc>(),
          builder: (blocContext, currentState) {
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _hideOverlay,
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
                Positioned(
                  top: topPadding,
                  left: context.isTablet ? context.screenHorizontalPadding : Insets.smallNormal,
                  right: context.isTablet ? context.screenHorizontalPadding : Insets.smallNormal,
                  child: Card(
                    child: Container(
                      height: 368,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(Insets.smallNormal),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              Insets.normal,
                              Insets.normal,
                              Insets.small,
                              Insets.small,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Notifications",
                                  style: AppTextStyle.bodyMedium.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _hideOverlay();
                                    context
                                        .read<NotificationBloc>()
                                        .add(const NotificationCleared());
                                  },
                                  style: TextButton.styleFrom(
                                    visualDensity: const VisualDensity(
                                      horizontal: -4.0,
                                      vertical: -4.0,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: Insets.small,
                                      vertical: Insets.smaller,
                                    ),
                                  ),
                                  child: Text(
                                    "Clear all",
                                    style: AppTextStyle.regular.copyWith(
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: dividerColor,
                          ),
                          Expanded(
                            child: currentState.notifications.isEmpty
                                ? Center(
                                    child: Text(
                                      "No notifications",
                                      style: AppTextStyle.bodySmall.copyWith(
                                        color: colorScheme.onSurface
                                            .withOpacity(0.6),
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: EdgeInsets.zero,
                                    itemCount:
                                        currentState.notifications.length,
                                    separatorBuilder: (context, index) =>
                                        Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: dividerColor,
                                    ),
                                    itemBuilder: (context, index) {
                                      final notification =
                                          currentState.notifications[index];
                                      return _buildNotificationItem(
                                        notification,
                                        colorScheme,
                                        dividerColor,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    overlay.insert(_overlayEntry!);
    setState(() {
      _isOverlayOpen = true;
    });
    context.read<NotificationBloc>().add(const NotificationPopupOpened());
  }

  Widget _buildNotificationItem(
    Notification notification,
    ColorScheme colorScheme,
    Color dividerColor,
  ) {
    final isUnread = !notification.read;
    final title = notification.text;
    final description = notification.description;

    Widget? leadingIcon;
    Color? iconColor;

    switch (notification.type) {
      case NotificationType.progress:
        iconColor = colorScheme.primary;
        leadingIcon = SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: notification.progress != null
                ? notification.progress! / 100
                : null,
            color: iconColor,
          ),
        );
        break;
      case NotificationType.error:
        iconColor = AppColors.error;
        leadingIcon = Icon(
          Icons.error_outline,
          size: 18,
          color: iconColor,
        );
        break;
      case NotificationType.success:
        iconColor = AppColors.success;
        leadingIcon = Icon(
          Icons.check_circle_outline,
          size: 18,
          color: iconColor,
        );
        break;
      case NotificationType.normal:
        if (isUnread) {
          leadingIcon = Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
          );
        }
        break;
    }

    return GestureDetector(
      onTap: () {
        if (notification.type == NotificationType.progress) {
          return;
        }

        context.read<NotificationBloc>().add(
              NotificationMarkedAsRead(notification: notification),
            );
        _hideOverlay();
        try {
          if (notification.route.routeName.isNotEmpty) {
            context.router.push(notification.route);
          }
        } catch (e) {}
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.normal,
          vertical: Insets.smallNormal,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (leadingIcon != null) ...[
                        leadingIcon,
                        const SizedBox(width: Insets.small),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyle.semiBold.copyWith(
                            color: notification.type == NotificationType.error
                                ? AppColors.error
                                : colorScheme.onSurface,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description ??
                        (notification.type == NotificationType.progress
                            ? 'Downloading... ${notification.progress?.toStringAsFixed(0) ?? 0}%'
                            : 'Choose the resources you want to add for processing.'),
                    style: AppTextStyle.regular.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  if (notification.type == NotificationType.progress) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: notification.progress != null
                            ? notification.progress! / 100
                            : null,
                        minHeight: 6,
                        backgroundColor: colorScheme.primary.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: notification.type == NotificationType.progress
                  ? GestureDetector(
                      onTap: () {
                        _hideOverlay();
                        AppSimpleDialog.showConfirmation(
                          context: context,
                          title: 'Cancel Download',
                          message:
                              'Are you sure you want to cancel the AI Model download? You can restart it later.',
                          confirmText: 'Cancel Download',
                          cancelText: 'Continue',
                          onConfirm: () {
                            GetIt.instance
                                .get<LoadModelBloc>()
                                .add(const LoadModelDownloadCancelled());
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTextStyle.labelSmall.copyWith(
                            color: AppColors.error,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: () {
                        if (notification.id != null) {
                          context.read<NotificationBloc>().add(
                                NotificationRemovedById(id: notification.id!),
                              );
                        } else {
                          context.read<NotificationBloc>().add(
                                NotificationRemoved(notification: notification),
                              );
                        }
                      },
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: Assets.icons.close.svg(
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(
                              colorScheme.onSurface,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isOverlayOpen = false;
    });
  }

  void _toggleOverlay(NotificationState state) {
    if (_overlayEntry == null) {
      _showOverlay(state);
    } else {
      _hideOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationBloc, NotificationState>(
      builder: (context, state) {
        final hasUnread =
            state.notifications.any((notification) => !notification.read);
        final hasProgress =
            state.notifications.any((n) => n.type == NotificationType.progress);
        final colorScheme = context.colorScheme;

        return CompositedTransformTarget(
          link: _layerLink,
          child: IconButton(
            highlightColor: colorScheme.surfaceContainerHighest,
            onPressed: () => _toggleOverlay(state),
            style: IconButton.styleFrom(
              backgroundColor: _isOverlayOpen
                  ? colorScheme.primary.withOpacity(0.05)
                  : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Assets.icons.notificationBell.svg(
                  colorFilter: ColorFilter.mode(
                    colorScheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
                if (hasUnread || hasProgress)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color:
                            hasProgress ? colorScheme.primary : AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
