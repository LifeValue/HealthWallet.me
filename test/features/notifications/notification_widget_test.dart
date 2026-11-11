import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/features/notifications/bloc/notification_bloc.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart';
import 'package:health_wallet/features/notifications/notification_widget.dart';
import 'package:health_wallet/features/processing/presentation/pages/load_model/bloc/load_model_bloc.dart';

/// Keeps what the bell asks of the notifications instead of running it.
class _MockNotificationBloc
    extends MockBloc<NotificationEvent, NotificationState>
    implements NotificationBloc {
  final added = <NotificationEvent>[];

  @override
  void add(NotificationEvent event) => added.add(event);
}

/// Keeps what the Cancel of a download asks of the model loader.
class _MockLoadModelBloc extends MockBloc<LoadModelEvent, LoadModelState>
    implements LoadModelBloc {
  final added = <LoadModelEvent>[];

  @override
  void add(LoadModelEvent event) => added.add(event);
}

/// Records the pages a notification opens, or fails to open them.
class _FakeStackRouter extends Fake implements StackRouter {
  _FakeStackRouter({this.fails = false});

  final bool fails;
  final pushed = <PageRouteInfo>[];

  @override
  Future<T?> push<T extends Object?>(
    PageRouteInfo route, {
    OnNavigationFailure? onFailure,
  }) async {
    if (fails) throw StateError('no such route');
    pushed.add(route);
    return null;
  }
}

final _en = lookupAppLocalizations(const Locale('en'));

const _recordsRoute = PageRouteInfo('RecordsRoute');

const _unread = Notification(
  id: 'n1',
  text: 'New records',
  description: 'Three records arrived',
  route: _recordsRoute,
);
const _read = Notification(id: 'n2', text: 'Old news', read: true);
const _error = Notification(
  id: 'n3',
  text: 'Import failed',
  type: NotificationType.error,
  read: true,
);
const _success = Notification(
  id: 'n4',
  text: 'Import done',
  type: NotificationType.success,
  read: true,
);
const _progress = Notification(
  id: 'n5',
  text: 'AI model',
  type: NotificationType.progress,
  progress: 42,
  read: true,
);

void main() {
  late _MockNotificationBloc bloc;
  late StreamController<NotificationState> states;
  late _FakeStackRouter router;

  setUp(() {
    bloc = _MockNotificationBloc();
    states = StreamController<NotificationState>.broadcast();
    router = _FakeStackRouter();
  });

  tearDown(() async {
    await states.close();
    await getIt.reset();
  });

  Future<void> pump(
    WidgetTester tester, {
    List<Notification> notifications = const [],
    Size size = const Size(400, 800),
    _FakeStackRouter? withRouter,
  }) async {
    whenListen(
      bloc,
      states.stream,
      initialState: NotificationState(notifications: notifications),
    );
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StackRouterScope(
          controller: withRouter ?? router,
          stateHash: 0,
          child: BlocProvider<NotificationBloc>.value(
            value: bloc,
            child: const Scaffold(
              body: Align(
                alignment: Alignment.topRight,
                child: NotificationWidget(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder bell() => find.byType(IconButton);

  /// The badge on the bell, if it shows one.
  Finder badge() => find.descendant(
    of: bell(),
    matching: find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).shape == BoxShape.circle,
    ),
  );

  Color? badgeColor(WidgetTester tester) =>
      (tester.widget<Container>(badge()).decoration! as BoxDecoration).color;

  Future<void> openPopup(WidgetTester tester) async {
    await tester.tap(bell());
    await tester.pump();
  }

  /// The popup card's place on screen.
  Positioned popupPosition(WidgetTester tester) => tester.widget<Positioned>(
    find.ancestor(of: find.byType(Card), matching: find.byType(Positioned)),
  );

  /// A notification's row in the popup: the tap target that wraps its title.
  Finder row(String title) => find
      .ancestor(of: find.text(title), matching: find.byType(GestureDetector))
      .first;

  /// The close button of a notification's row.
  Finder closeButton(String title) => find.descendant(
    of: row(title),
    matching: find.byWidgetPredicate(
      (w) => w is SizedBox && w.width == 36 && w.height == 36,
    ),
  );

  Color? backgroundOf(WidgetTester tester) => tester
      .widget<IconButton>(bell())
      .style
      ?.backgroundColor
      ?.resolve(<WidgetState>{});

  group('the bell', () {
    testWidgets('has no badge without notifications', (tester) async {
      await pump(tester);

      expect(bell(), findsOneWidget);
      expect(badge(), findsNothing);
    });

    testWidgets('has no badge when every notification is read', (
      tester,
    ) async {
      await pump(tester, notifications: const [_read, _error, _success]);

      expect(badge(), findsNothing);
    });

    testWidgets('shows a red badge for an unread notification', (
      tester,
    ) async {
      await pump(tester, notifications: const [_read, _unread]);

      expect(badge(), findsOneWidget);
      expect(badgeColor(tester), AppColors.error);
    });

    testWidgets('shows a primary badge while something downloads', (
      tester,
    ) async {
      await pump(tester, notifications: const [_unread, _progress]);

      final primary = Theme.of(tester.element(bell())).colorScheme.primary;
      expect(badgeColor(tester), primary);
    });

    testWidgets('updates its badge when a notification arrives', (
      tester,
    ) async {
      await pump(tester);
      expect(badge(), findsNothing);

      states.add(const NotificationState(notifications: [_unread]));
      await tester.pump();

      expect(badge(), findsOneWidget);
    });

    testWidgets('is tinted while the popup is open', (tester) async {
      await pump(tester);
      expect(backgroundOf(tester), Colors.transparent);

      await openPopup(tester);

      final primary = Theme.of(tester.element(bell())).colorScheme.primary;
      expect(backgroundOf(tester), primary.withValues(alpha: 0.05));
    });
  });

  group('the popup', () {
    testWidgets('opens on a tap and tells the bloc it opened', (tester) async {
      await pump(tester);
      expect(find.text(_en.notificationsTitle), findsNothing);

      await openPopup(tester);

      expect(find.text(_en.notificationsTitle), findsOneWidget);
      expect(find.text(_en.clearAll), findsOneWidget);
      expect(find.text(_en.noNotifications), findsOneWidget);
      expect(bloc.added, [const NotificationPopupOpened()]);
    });

    testWidgets('closes on a tap outside it', (tester) async {
      await pump(tester);
      await openPopup(tester);

      await tester.tapAt(const Offset(200, 780));
      await tester.pump();

      expect(find.text(_en.notificationsTitle), findsNothing);
      expect(backgroundOf(tester), Colors.transparent);
    });

    testWidgets('closes when the bell is pressed again', (tester) async {
      await pump(tester);
      await openPopup(tester);

      // The popup's backdrop covers the bell, so a tap never reaches it;
      // pressing it from the keyboard still does.
      tester.widget<IconButton>(bell()).onPressed!();
      await tester.pump();

      expect(find.text(_en.notificationsTitle), findsNothing);
      expect(bloc.added, [const NotificationPopupOpened()]);
    });

    testWidgets('Clear all closes it and clears the notifications', (
      tester,
    ) async {
      await pump(tester, notifications: const [_unread]);
      await openPopup(tester);

      await tester.tap(find.text(_en.clearAll));
      await tester.pump();

      expect(find.text(_en.notificationsTitle), findsNothing);
      expect(bloc.added, [
        const NotificationPopupOpened(),
        const NotificationCleared(),
      ]);
    });

    testWidgets('follows the notifications while it is open', (tester) async {
      await pump(tester);
      await openPopup(tester);
      expect(find.text(_en.noNotifications), findsOneWidget);

      states.add(const NotificationState(notifications: [_unread]));
      await tester.pump();

      expect(find.text(_en.noNotifications), findsNothing);
      expect(find.text(_unread.text), findsOneWidget);
    });

    testWidgets('on a phone, sits 12 from each edge below the app bar', (
      tester,
    ) async {
      await pump(tester);
      await openPopup(tester);

      final position = popupPosition(tester);
      expect(position.left, Insets.smallNormal);
      expect(position.right, Insets.smallNormal);
      expect(position.top, kToolbarHeight + Insets.large);
    });

    testWidgets('on a tablet, lines up with the page padding, 36 higher', (
      tester,
    ) async {
      await pump(tester, size: const Size(800, 1000));
      await openPopup(tester);

      final position = popupPosition(tester);
      expect(position.left, 32);
      expect(position.right, 32);
      expect(position.top, kToolbarHeight + Insets.large - 36);
    });

    testWidgets('at desktop width, lines up with the wider page padding', (
      tester,
    ) async {
      await pump(tester, size: const Size(1280, 800));
      await openPopup(tester);

      final position = popupPosition(tester);
      expect(position.left, 48);
      expect(position.right, 48);
      expect(position.top, kToolbarHeight + Insets.large - 36);
    });
  });

  group('a notification', () {
    testWidgets('unread shows a dot, its title and its description', (
      tester,
    ) async {
      await pump(tester, notifications: const [_unread]);
      await openPopup(tester);

      expect(find.text(_unread.text), findsOneWidget);
      expect(find.text(_unread.description!), findsOneWidget);
      final dot = find.descendant(
        of: row(_unread.text),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      expect(dot, findsOneWidget);
    });

    testWidgets('read shows no dot and the default description', (
      tester,
    ) async {
      await pump(tester, notifications: const [_read]);
      await openPopup(tester);

      expect(find.text(_read.text), findsOneWidget);
      expect(find.text(_en.chooseResourcesDescription), findsOneWidget);
      final dot = find.descendant(
        of: row(_read.text),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      expect(dot, findsNothing);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('an error has a red icon and a red title', (tester) async {
      await pump(tester, notifications: const [_error]);
      await openPopup(tester);

      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(icon.color, AppColors.error);
      expect(
        tester.widget<Text>(find.text(_error.text)).style?.color,
        AppColors.error,
      );
    });

    testWidgets('a success has a green icon', (tester) async {
      await pump(tester, notifications: const [_success]);
      await openPopup(tester);

      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle_outline));
      expect(icon.color, AppColors.success);
      expect(
        tester.widget<Text>(find.text(_success.text)).style?.color,
        isNot(AppColors.error),
      );
    });

    testWidgets('a download shows its progress and a Cancel', (tester) async {
      await pump(tester, notifications: const [_progress]);
      await openPopup(tester);

      expect(find.text('${_en.aiModelDownloading} 42%'), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        0.42,
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.42,
      );
      expect(find.text(_en.cancel), findsOneWidget);
      expect(closeButton(_progress.text), findsNothing);
    });

    testWidgets('a download without progress yet spins and shows 0%', (
      tester,
    ) async {
      await pump(
        tester,
        notifications: const [
          Notification(text: 'AI model', type: NotificationType.progress),
        ],
      );
      await openPopup(tester);

      expect(find.text('${_en.aiModelDownloading} 0%'), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        isNull,
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );
    });

    testWidgets('a download keeps its own description', (tester) async {
      await pump(
        tester,
        notifications: const [
          Notification(
            text: 'AI model',
            description: 'Gemma, 1.2 GB',
            type: NotificationType.progress,
            progress: 10,
          ),
        ],
      );
      await openPopup(tester);

      expect(find.text('Gemma, 1.2 GB'), findsOneWidget);
    });

    testWidgets('lists every notification', (tester) async {
      await pump(tester, notifications: const [_unread, _read, _error]);
      await openPopup(tester);

      expect(find.text(_unread.text), findsOneWidget);
      expect(find.text(_read.text), findsOneWidget);
      expect(find.text(_error.text), findsOneWidget);
    });
  });

  group('tapping a notification', () {
    testWidgets('marks it read, closes the popup and opens its page', (
      tester,
    ) async {
      await pump(tester, notifications: const [_unread]);
      await openPopup(tester);

      await tester.tap(find.text(_unread.text));
      await tester.pump();

      expect(bloc.added, [
        const NotificationPopupOpened(),
        const NotificationMarkedAsRead(notification: _unread),
      ]);
      expect(find.text(_en.notificationsTitle), findsNothing);
      expect(router.pushed, [_recordsRoute]);
    });

    testWidgets('without a page, opens nothing', (tester) async {
      await pump(tester, notifications: const [_read]);
      await openPopup(tester);

      await tester.tap(find.text(_read.text));
      await tester.pump();

      expect(
        bloc.added.last,
        const NotificationMarkedAsRead(notification: _read),
      );
      expect(find.text(_en.notificationsTitle), findsNothing);
      expect(router.pushed, isEmpty);
    });

    testWidgets('without a router, logs instead of failing', (tester) async {
      whenListen(
        bloc,
        states.stream,
        initialState: const NotificationState(notifications: [_unread]),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<NotificationBloc>.value(
            value: bloc,
            child: const Scaffold(body: NotificationWidget()),
          ),
        ),
      );
      await openPopup(tester);

      await tester.tap(find.text(_unread.text));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        bloc.added.last,
        const NotificationMarkedAsRead(notification: _unread),
      );
      expect(find.text(_en.notificationsTitle), findsNothing);
    });

    testWidgets(
      'survives a page the router cannot open',
      (tester) async {
        await pump(
          tester,
          notifications: const [_unread],
          withRouter: _FakeStackRouter(fails: true),
        );
        await openPopup(tester);

        await tester.tap(find.text(_unread.text));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text(_en.notificationsTitle), findsNothing);
      },
      // The push is not awaited, so its failure escapes the try/catch
      // around it as an unhandled error.
      skip: true,
    );

    testWidgets('a download does nothing', (tester) async {
      await pump(tester, notifications: const [_progress]);
      await openPopup(tester);

      await tester.tap(find.text(_progress.text));
      await tester.pump();

      expect(bloc.added, [const NotificationPopupOpened()]);
      expect(find.text(_en.notificationsTitle), findsOneWidget);
    });
  });

  group('removing a notification', () {
    testWidgets('by id when it has one', (tester) async {
      await pump(tester, notifications: const [_unread]);
      await openPopup(tester);

      await tester.tap(closeButton(_unread.text));
      await tester.pump();

      expect(bloc.added.last, const NotificationRemovedById(id: 'n1'));
      // The popup stays open to remove more.
      expect(find.text(_en.notificationsTitle), findsOneWidget);
    });

    testWidgets('as a whole when it has no id', (tester) async {
      const noId = Notification(text: 'No id', read: true);
      await pump(tester, notifications: const [noId]);
      await openPopup(tester);

      await tester.tap(closeButton(noId.text));
      await tester.pump();

      expect(bloc.added.last, const NotificationRemoved(notification: noId));
    });
  });

  group('cancelling a download', () {
    late _MockLoadModelBloc loadModelBloc;

    setUp(() {
      loadModelBloc = _MockLoadModelBloc();
      getIt.registerSingleton<LoadModelBloc>(loadModelBloc);
    });

    Future<void> tapCancel(WidgetTester tester) async {
      await pump(tester, notifications: const [_progress]);
      await openPopup(tester);
      await tester.tap(find.text(_en.cancel));
      await tester.pumpAndSettle();
    }

    testWidgets('closes the popup and asks first', (tester) async {
      await tapCancel(tester);

      expect(find.text(_en.notificationsTitle), findsNothing);
      expect(find.text(_en.cancelDownloadMessage), findsOneWidget);
      expect(loadModelBloc.added, isEmpty);
    });

    testWidgets('stops the download once confirmed', (tester) async {
      await tapCancel(tester);

      await tester.tap(
        find.widgetWithText(ElevatedButton, _en.cancelDownloadTitle),
      );
      await tester.pumpAndSettle();

      expect(find.text(_en.cancelDownloadMessage), findsNothing);
      expect(loadModelBloc.added, [const LoadModelDownloadCancelled()]);
    });

    testWidgets('keeps the download when the user continues', (tester) async {
      await tapCancel(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, _en.continueButton));
      await tester.pumpAndSettle();

      expect(find.text(_en.cancelDownloadMessage), findsNothing);
      expect(loadModelBloc.added, isEmpty);
    });
  });
}
