import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart'
    as notification_entity;

void showProcessingDoneNotification(
  BuildContext context,
  notification_entity.Notification notification, {
  VoidCallback? onDismissed,
}) {
  if (!context.mounted) return;

  try {
    Flushbar(
      title: context.l10n.processingDone,
      message: notification.text,
      duration: const Duration(seconds: 3),
      flushbarPosition: FlushbarPosition.TOP,
      titleColor: Colors.white,
      messageColor: Colors.white,
      backgroundColor: AppColors.primary,
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(20),
      onTap: (_) {
        // A notification about something already gone (a draft saved on the
        // other device) leads nowhere.
        if (context.mounted && notification.route.routeName.isNotEmpty) {
          context.appRouter.push(notification.route);
        }
      },
      onStatusChanged: (status) {
        if (status == FlushbarStatus.DISMISSED) {
          onDismissed?.call();
        }
      },
    ).show(context).catchError((Object e) {
      logger.w('The processing notification failed while showing', e);
      return null;
    });
  } catch (e) {
    logger.w('Could not show the processing notification', e);
  }
}
