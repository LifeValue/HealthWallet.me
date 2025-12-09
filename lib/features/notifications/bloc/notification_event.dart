part of 'notification_bloc.dart';

abstract class NotificationEvent {
  const NotificationEvent();
}

@freezed
class NotificationAdded extends NotificationEvent with _$NotificationAdded {
  const factory NotificationAdded({
    required Notification notification,
  }) = _NotificationAdded;
}

@freezed
class NotificationPopupOpened extends NotificationEvent
    with _$NotificationPopupOpened {
  const factory NotificationPopupOpened() = _NotificationPopupOpened;
}

@freezed
class NotificationPopupClosed extends NotificationEvent
    with _$NotificationPopupClosed {
  const factory NotificationPopupClosed() = _NotificationPopupClosed;
}

@freezed
class NotificationCleared extends NotificationEvent with _$NotificationCleared {
  const factory NotificationCleared() = _NotificationCleared;
}

@freezed
class NotificationRemoved extends NotificationEvent with _$NotificationRemoved {
  const factory NotificationRemoved({
    required Notification notification,
  }) = _NotificationRemoved;
}

@freezed
class NotificationMarkedAsRead extends NotificationEvent
    with _$NotificationMarkedAsRead {
  const factory NotificationMarkedAsRead({
    required Notification notification,
  }) = _NotificationMarkedAsRead;
}

class NotificationsLoaded extends NotificationEvent {
  final List<Notification> notifications;
  const NotificationsLoaded({required this.notifications});
}

@freezed
class NotificationProgressUpdated extends NotificationEvent
    with _$NotificationProgressUpdated {
  const factory NotificationProgressUpdated({
    required String id,
    required double progress,
  }) = _NotificationProgressUpdated;
}

@freezed
class NotificationTypeUpdated extends NotificationEvent
    with _$NotificationTypeUpdated {
  const factory NotificationTypeUpdated({
    required String id,
    required NotificationType type,
    String? text,
    String? description,
  }) = _NotificationTypeUpdated;
}

@freezed
class NotificationRemovedById extends NotificationEvent
    with _$NotificationRemovedById {
  const factory NotificationRemovedById({
    required String id,
  }) = _NotificationRemovedById;
}
