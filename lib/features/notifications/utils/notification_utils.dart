import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart'
    as notification_entity;

Flushbar showProcessingDoneNotification(
  BuildContext context,
  notification_entity.Notification notification, {
  FlushbarStatusCallback? onStatusChanged,
  bool disableTap = false,
}) {
  final flushbar = Flushbar(
    title: "Processing done",
    message: notification.text,
    duration: const Duration(seconds: 3),
    flushbarPosition: FlushbarPosition.TOP,
    titleColor: Colors.white,
    messageColor: Colors.white,
    backgroundColor: AppColors.primary,
    borderRadius: BorderRadius.circular(12),
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.all(20),
    onTap:
        disableTap ? null : (_) => context.appRouter.push(notification.route),
    onStatusChanged: onStatusChanged,
  )..show(context);

  return flushbar;
}
