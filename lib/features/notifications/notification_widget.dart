import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/home/domain/entities/wallet_notification.dart';
import 'package:health_wallet/features/notifications/bloc/notification_bloc.dart';
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
    final isDarkMode = context.isDarkMode;
    final dividerColor = isDarkMode ? AppColors.borderDark : AppColors.border;

    _overlayEntry = OverlayEntry(
      builder: (context) {
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
              top: 115,
              left: Insets.smallNormal,
              right: Insets.smallNormal,
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
                      // Header
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
                      // Divider below header
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: dividerColor,
                      ),
                      Expanded(
                        child: state.notifications.isEmpty
                            ? Center(
                                child: Text(
                                  "No notifications",
                                  style: AppTextStyle.bodySmall.copyWith(
                                    color:
                                        colorScheme.onSurface.withOpacity(0.6),
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: state.notifications.length,
                                separatorBuilder: (context, index) => Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: dividerColor,
                                ),
                                itemBuilder: (context, index) {
                                  final notification =
                                      state.notifications[index];
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

    overlay.insert(_overlayEntry!);
    setState(() {
      _isOverlayOpen = true;
    });
    context.read<NotificationBloc>().add(const NotificationPopupOpened());
  }

  Widget _buildNotificationItem(
    WalletNotification notification,
    ColorScheme colorScheme,
    Color dividerColor,
  ) {
    final isUnread = !notification.read;
    final title = notification.text;

    return GestureDetector(
      onTap: () {
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
                      if (isUnread)
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(right: Insets.small),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyle.semiBold.copyWith(
                            color: colorScheme.onSurface,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Choose the resources you want to add for processing.",
                    style: AppTextStyle.regular.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            // X dismiss button (top-right corner)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  context.read<NotificationBloc>().add(
                        NotificationRemoved(notification: notification),
                      );
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
                if (hasUnread)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
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
