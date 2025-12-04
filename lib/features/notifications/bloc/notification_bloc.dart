import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'notification_event.dart';
part 'notification_state.dart';
part 'notification_bloc.freezed.dart';

@lazySingleton
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
    on<NotificationProgressUpdated>(_onNotificationProgressUpdated);
    on<NotificationTypeUpdated>(_onNotificationTypeUpdated);
    on<NotificationRemovedById>(_onNotificationRemovedById);

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
      _prefs.remove(_storageKey);
    }
  }

  void _saveNotifications(List<Notification> notifications) {
    try {
      final persistableNotifications = notifications
          .where((n) => n.type != NotificationType.progress)
          .toList();
      final jsonList = persistableNotifications.map((n) => _toJson(n)).toList();
      _prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {}
  }

  Map<String, dynamic> _toJson(Notification n) => {
        'id': n.id,
        'text': n.text,
        'description': n.description,
        'read': n.read,
        'time': n.time?.toIso8601String(),
        'type': n.type.name,
        'progress': n.progress,
      };

  Notification _fromJson(Map<String, dynamic> json) {
    NotificationType type = NotificationType.normal;
    if (json['type'] != null) {
      type = NotificationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => NotificationType.normal,
      );
    }

    return Notification(
      id: json['id'] as String?,
      text: json['text'] as String? ?? '',
      description: json['description'] as String?,
      read: json['read'] as bool? ?? false,
      time: json['time'] != null
          ? DateTime.tryParse(json['time'] as String)
          : null,
      type: type,
      progress: json['progress'] as double?,
    );
  }

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
    if (event.notification.id != null) {
      final existingIndex =
          state.notifications.indexWhere((n) => n.id == event.notification.id);
      if (existingIndex != -1) {
        final newList = [...state.notifications];
        newList[existingIndex] = event.notification;
        emit(state.copyWith(notifications: newList));
        _saveNotifications(newList);
        return;
      }
    }

    final newList = [event.notification, ...state.notifications];
    emit(state.copyWith(notifications: newList));
    _saveNotifications(newList);
  }

  void _onNotificationPopupOpened(
    NotificationPopupOpened event,
    Emitter<NotificationState> emit,
  ) {
    final readList =
        state.notifications.map((n) => n.copyWith(read: true)).toList();
    emit(state.copyWith(notifications: readList));
    _saveNotifications(readList);
  }

  void _onNotificationPopupClosed(
    NotificationPopupClosed event,
    Emitter<NotificationState> emit,
  ) {}

  void _onNotificationCleared(
    NotificationCleared event,
    Emitter<NotificationState> emit,
  ) {
    final progressNotifications = state.notifications
        .where((n) => n.type == NotificationType.progress)
        .toList();
    emit(state.copyWith(notifications: progressNotifications));
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

  void _onNotificationProgressUpdated(
    NotificationProgressUpdated event,
    Emitter<NotificationState> emit,
  ) {
    final index = state.notifications.indexWhere((n) => n.id == event.id);
    if (index == -1) return;

    final newList = [...state.notifications];
    newList[index] = newList[index].copyWith(progress: event.progress);
    emit(state.copyWith(notifications: newList));
  }

  void _onNotificationTypeUpdated(
    NotificationTypeUpdated event,
    Emitter<NotificationState> emit,
  ) {
    final index = state.notifications.indexWhere((n) => n.id == event.id);
    if (index == -1) return;

    final newList = [...state.notifications];
    newList[index] = newList[index].copyWith(
      type: event.type,
      text: event.text ?? newList[index].text,
      description: event.description ?? newList[index].description,
    );
    emit(state.copyWith(notifications: newList));
    _saveNotifications(newList);
  }

  void _onNotificationRemovedById(
    NotificationRemovedById event,
    Emitter<NotificationState> emit,
  ) {
    final newList = state.notifications.where((n) => n.id != event.id).toList();
    emit(state.copyWith(notifications: newList));
    _saveNotifications(newList);
  }
}
