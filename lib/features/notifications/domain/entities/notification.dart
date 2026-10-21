import 'package:auto_route/auto_route.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification.freezed.dart';

enum NotificationType {
  normal,
  progress,
  error,
  success,
}

@freezed
abstract class Notification with _$Notification {
  const Notification._();

  const factory Notification({
    String? id,
    @Default('') String text,
    String? description,
    @Default(PageRouteInfo('')) PageRouteInfo route,
    @Default(false) bool read,
    DateTime? time,
    @Default(NotificationType.normal) NotificationType type,
    double? progress,
  }) = _Notification;

  bool get isProgress => type == NotificationType.progress;

  bool get isError => type == NotificationType.error;

  bool get isSuccess => type == NotificationType.success;
}
