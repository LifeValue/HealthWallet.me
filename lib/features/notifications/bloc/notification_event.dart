part of 'notification_bloc.dart';

abstract class NotificationEvent {
  const NotificationEvent();
}

@freezed
abstract class NotificationAdded extends NotificationEvent with _$NotificationAdded {
  const NotificationAdded._();

  const factory NotificationAdded({
    required Notification notification,
  }) = _NotificationAdded;
}

@freezed
abstract class NotificationPopupOpened extends NotificationEvent
    with _$NotificationPopupOpened {
  const NotificationPopupOpened._();

  const factory NotificationPopupOpened() = _NotificationPopupOpened;
}

@freezed
abstract class NotificationPopupClosed extends NotificationEvent
    with _$NotificationPopupClosed {
  const NotificationPopupClosed._();

  const factory NotificationPopupClosed() = _NotificationPopupClosed;
}

@freezed
abstract class NotificationCleared extends NotificationEvent with _$NotificationCleared {
  const NotificationCleared._();

  const factory NotificationCleared() = _NotificationCleared;
}

@freezed
abstract class NotificationRemoved extends NotificationEvent with _$NotificationRemoved {
  const NotificationRemoved._();

  const factory NotificationRemoved({
    required Notification notification,
  }) = _NotificationRemoved;
}

@freezed
abstract class NotificationMarkedAsRead extends NotificationEvent
    with _$NotificationMarkedAsRead {
  const NotificationMarkedAsRead._();

  const factory NotificationMarkedAsRead({
    required Notification notification,
  }) = _NotificationMarkedAsRead;
}

class NotificationsLoaded extends NotificationEvent {
  final List<Notification> notifications;
  const NotificationsLoaded({required this.notifications});
}

@freezed
abstract class NotificationProgressUpdated extends NotificationEvent
    with _$NotificationProgressUpdated {
  const NotificationProgressUpdated._();

  const factory NotificationProgressUpdated({
    required String id,
    required double progress,
  }) = _NotificationProgressUpdated;
}

@freezed
abstract class NotificationTypeUpdated extends NotificationEvent
    with _$NotificationTypeUpdated {
  const NotificationTypeUpdated._();

  const factory NotificationTypeUpdated({
    required String id,
    required NotificationType type,
    String? text,
    String? description,
  }) = _NotificationTypeUpdated;
}

@freezed
abstract class NotificationRemovedById extends NotificationEvent
    with _$NotificationRemovedById {
  const NotificationRemovedById._();

  const factory NotificationRemovedById({
    required String id,
  }) = _NotificationRemovedById;
}
