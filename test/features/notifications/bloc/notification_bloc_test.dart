import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/notifications/bloc/notification_bloc.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/log_capture.dart';

const _key = 'wallet_notifications';

void main() {
  final logs = captureLogs();
  late SharedPreferences prefs;

  Future<NotificationBloc> open([Map<String, Object> saved = const {}]) async {
    SharedPreferences.setMockInitialValues(saved);
    prefs = await SharedPreferences.getInstance();
    final bloc = NotificationBloc(prefs);
    addTearDown(bloc.close);
    await pumpEventQueue();
    return bloc;
  }

  Future<NotificationState> run(
    NotificationBloc bloc,
    NotificationEvent event,
  ) async {
    bloc.add(event);
    await pumpEventQueue();
    return bloc.state;
  }

  List<Map<String, dynamic>> saved() => [
    for (final n in jsonDecode(prefs.getString(_key) ?? '[]') as List)
      n as Map<String, dynamic>,
  ];

  final scan = Notification(
    id: 'scan',
    text: 'Scan finished',
    description: 'Lab report',
    time: DateTime.utc(2026, 11, 3, 9),
    type: NotificationType.success,
  );
  const download = Notification(
    id: 'download',
    text: 'Downloading',
    type: NotificationType.progress,
    progress: 10,
  );

  group('saving', () {
    test('a new notification goes first and is saved', () async {
      final bloc = await open();
      await run(bloc, const NotificationAdded(notification: download));

      final state = await run(bloc, NotificationAdded(notification: scan));

      expect(state.notifications.map((n) => n.id), ['scan', 'download']);
      expect(saved().map((n) => n['id']), ['scan'], reason: 'progress is not');
    });

    test('a notification with a known id replaces it in place', () async {
      final bloc = await open();
      await run(bloc, NotificationAdded(notification: scan));
      await run(bloc, const NotificationAdded(notification: download));

      final state = await run(
        bloc,
        NotificationAdded(notification: scan.copyWith(text: 'Scan saved')),
      );

      expect(state.notifications.map((n) => n.text), [
        'Downloading',
        'Scan saved',
      ]);
    });

    test('saved notifications come back on the next start', () async {
      final bloc = await open();
      await run(bloc, NotificationAdded(notification: scan));

      final reopened = await open({_key: prefs.getString(_key)!});

      expect(reopened.state.notifications, [scan]);
    });

    test('BUG: the route of a saved notification is lost on restart, so '
        'tapping it does nothing', () async {
      final bloc = await open();
      await run(
        bloc,
        NotificationAdded(
          notification: scan.copyWith(route: const PageRouteInfo('Records')),
        ),
      );

      final reopened = await open({_key: prefs.getString(_key)!});

      expect(reopened.state.notifications.single.route.routeName, 'Records');
    }, skip: 'BUG: B6 in mobile-stabilization.md');

    test('an unknown type is read as a normal notification', () async {
      final bloc = await open({
        _key: jsonEncode([
          {'id': 'x', 'text': 'Old', 'type': 'retired'},
        ]),
      });

      expect(bloc.state.notifications.single.type, NotificationType.normal);
    });

    test('unreadable saved notifications are logged and dropped', () async {
      final bloc = await open({_key: 'not json'});

      expect(bloc.state.notifications, isEmpty);
      expect(prefs.containsKey(_key), isFalse);
      expect(logs, loggedWarning('Reading the saved notifications failed'));
    });
  });

  group('reading and removing', () {
    test('opening the list marks every notification read', () async {
      final bloc = await open();
      await run(bloc, NotificationAdded(notification: scan));
      await run(bloc, const NotificationAdded(notification: download));

      final state = await run(bloc, const NotificationPopupOpened());

      expect(state.notifications.every((n) => n.read), isTrue);
      expect(saved().single['read'], isTrue);
    });

    test('one notification can be marked read', () async {
      final bloc = await open();
      await run(bloc, NotificationAdded(notification: scan));
      await run(bloc, const NotificationAdded(notification: download));

      final state = await run(
        bloc,
        NotificationMarkedAsRead(notification: scan),
      );

      expect(state.notifications.map((n) => n.read), [false, true]);
    });

    test('clearing keeps the running downloads only', () async {
      final bloc = await open();
      await run(bloc, NotificationAdded(notification: scan));
      await run(bloc, const NotificationAdded(notification: download));

      final state = await run(bloc, const NotificationCleared());

      expect(state.notifications, [download]);
      expect(saved(), isEmpty);
    });

    test('removing by value or by id', () async {
      final bloc = await open();
      await run(bloc, NotificationAdded(notification: scan));
      await run(bloc, const NotificationAdded(notification: download));

      await run(bloc, NotificationRemoved(notification: scan));
      final state = await run(
        bloc,
        const NotificationRemovedById(id: 'download'),
      );

      expect(state.notifications, isEmpty);
    });

    test('closing the list changes nothing', () async {
      final bloc = await open();
      await run(bloc, NotificationAdded(notification: scan));

      final state = await run(bloc, const NotificationPopupClosed());

      expect(state.notifications, [scan]);
    });
  });

  group('progress', () {
    test('progress updates a known download and ignores others', () async {
      final bloc = await open();
      await run(bloc, const NotificationAdded(notification: download));

      await run(
        bloc,
        const NotificationProgressUpdated(id: 'download', progress: 60),
      );
      final state = await run(
        bloc,
        const NotificationProgressUpdated(id: 'gone', progress: 99),
      );

      expect(state.notifications.single.progress, 60);
    });

    test('a finished download becomes a saved notification with its new '
        'text', () async {
      final bloc = await open();
      await run(bloc, const NotificationAdded(notification: download));

      final state = await run(
        bloc,
        const NotificationTypeUpdated(
          id: 'download',
          type: NotificationType.success,
          text: 'Model ready',
        ),
      );
      await run(
        bloc,
        const NotificationTypeUpdated(
          id: 'gone',
          type: NotificationType.error,
        ),
      );

      expect(state.notifications.single.text, 'Model ready');
      expect(state.notifications.single.isSuccess, isTrue);
      expect(saved().single['text'], 'Model ready');
    });
  });
}
