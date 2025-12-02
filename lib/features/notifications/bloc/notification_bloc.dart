import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/home/domain/entities/wallet_notification.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'notification_event.dart';
part 'notification_state.dart';
part 'notification_bloc.freezed.dart';

@injectable
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final SharedPreferences _prefs;
  static const String _storageKey = 'wallet_notifications';

  NotificationBloc(this._prefs) : super(const NotificationState()) {
    on<NotificationAdded>(_onNotificationAdded);
    on<NotificationPopupOpened>(_onNotificationPopupOpened);
    on<NotificationPopupClosed>(_onNotificationPopupClosed);
    on<NotificationCleared>(_onNotificationCleared);
    on<NotificationRemoved>(_onNotificationRemoved);
    on<NotificationMarkedAsRead>(_onNotificationMarkedAsRead);
    on<NotificationsLoaded>(_onNotificationsLoaded);

    // Load persisted notifications on startup
    _loadNotifications();
  }

  void _loadNotifications() {
    try {
      final jsonString = _prefs.getString(_storageKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        final notifications = jsonList
            .map((json) => _fromJson(json as Map<String, dynamic>))
            .toList();
        add(NotificationsLoaded(notifications: notifications));
      }
    } catch (e) {
      // If loading fails, start fresh
      _prefs.remove(_storageKey);
    }
  }

  void _saveNotifications(List<WalletNotification> notifications) {
    try {
      final jsonList = notifications.map((n) => _toJson(n)).toList();
      _prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      // Silently fail - app continues working
    }
  }

  Map<String, dynamic> _toJson(WalletNotification n) => {
        'text': n.text,
        'read': n.read,
        'time': n.time?.toIso8601String(),
      };

  WalletNotification _fromJson(Map<String, dynamic> json) => WalletNotification(
        text: json['text'] as String? ?? '',
        read: json['read'] as bool? ?? false,
        time: json['time'] != null
            ? DateTime.tryParse(json['time'] as String)
            : null,
      );

  void _onNotificationsLoaded(
    NotificationsLoaded event,
    Emitter<NotificationState> emit,
  ) {
    emit(state.copyWith(notifications: event.notifications));
  }

  void _onNotificationAdded(
    NotificationAdded event,
    Emitter<NotificationState> emit,
  ) {
    final newList = [event.notification, ...state.notifications];
    emit(state.copyWith(notifications: newList));
    _saveNotifications(newList);
  }

  void _onNotificationPopupOpened(
    NotificationPopupOpened event,
    Emitter<NotificationState> emit,
  ) {
    // Mark all notifications as read when popup is opened
    final readList =
        state.notifications.map((n) => n.copyWith(read: true)).toList();
    emit(state.copyWith(notifications: readList));
    _saveNotifications(readList);
  }

  void _onNotificationPopupClosed(
    NotificationPopupClosed event,
    Emitter<NotificationState> emit,
  ) {
    // No action needed - read status already saved
  }

  void _onNotificationCleared(
    NotificationCleared event,
    Emitter<NotificationState> emit,
  ) {
    emit(state.copyWith(notifications: []));
    _saveNotifications([]);
  }

  void _onNotificationRemoved(
    NotificationRemoved event,
    Emitter<NotificationState> emit,
  ) {
    final newList =
        state.notifications.where((n) => n != event.notification).toList();
    emit(state.copyWith(notifications: newList));
    _saveNotifications(newList);
  }

  void _onNotificationMarkedAsRead(
    NotificationMarkedAsRead event,
    Emitter<NotificationState> emit,
  ) {
    final newList = state.notifications
        .map((n) => n == event.notification ? n.copyWith(read: true) : n)
        .toList();
    emit(state.copyWith(notifications: newList));
    _saveNotifications(newList);
  }
}
