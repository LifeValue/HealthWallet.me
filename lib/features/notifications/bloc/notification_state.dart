part of 'notification_bloc.dart';

@freezed
abstract class NotificationState with _$NotificationState {
  const factory NotificationState({
    @Default([]) List<Notification> notifications,
  }) = _NotificationState;
}
