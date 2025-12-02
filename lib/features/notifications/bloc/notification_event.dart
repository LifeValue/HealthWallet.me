part of 'notification_bloc.dart';

abstract class NotificationEvent {
  const NotificationEvent();
}

@freezed
class NotificationAdded extends NotificationEvent with _$NotificationAdded {
  const factory NotificationAdded({
    required WalletNotification notification,
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
    required WalletNotification notification,
  }) = _NotificationRemoved;
}

@freezed
class NotificationMarkedAsRead extends NotificationEvent
    with _$NotificationMarkedAsRead {
  const factory NotificationMarkedAsRead({
    required WalletNotification notification,
  }) = _NotificationMarkedAsRead;
}

class NotificationsLoaded extends NotificationEvent {
  final List<WalletNotification> notifications;
  const NotificationsLoaded({required this.notifications});
}
