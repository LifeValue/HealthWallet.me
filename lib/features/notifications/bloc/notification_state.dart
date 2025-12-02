part of 'notification_bloc.dart';

@freezed
class NotificationState with _$NotificationState {
  const factory NotificationState({
    @Default([]) List<WalletNotification> notifications,
  }) = _NotificationState;
}
