import 'dart:async';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/user/domain/entity/user.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/user/user_section.dart';

/// Records the events the section sends instead of running them.
class _MockUserBloc extends MockBloc<UserEvent, UserState> implements UserBloc {
  final events = <UserEvent>[];

  @override
  void add(UserEvent event) => events.add(event);
}

class _MockSyncBloc extends MockBloc<SyncEvent, SyncState>
    implements SyncBloc {}

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  late _MockUserBloc userBloc;
  late StreamController<UserState> userStates;

  setUp(() {
    userBloc = _MockUserBloc();
    userStates = StreamController<UserState>();
    whenListen(
      userBloc,
      userStates.stream,
      initialState: const UserState(user: User(name: 'Ana')),
    );
  });

  tearDown(() => userStates.close());

  Future<void> pumpSection(WidgetTester tester) async {
    final syncBloc = _MockSyncBloc();
    whenListen(
      syncBloc,
      const Stream<SyncState>.empty(),
      initialState: const SyncState(),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<UserBloc>.value(value: userBloc),
              BlocProvider<SyncBloc>.value(value: syncBloc),
            ],
            child: const UserSection(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the display name', (tester) async {
    await pumpSection(tester);

    expect(find.text(_en.displayName), findsOne);
    expect(find.text('Ana'), findsOne);
  });

  testWidgets('saving an edited name updates it', (tester) async {
    await pumpSection(tester);

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '  Ana Pop  ');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();

    expect(userBloc.events, [const UserNameUpdated('Ana Pop')]);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a blank name is not saved', (tester) async {
    await pumpSection(tester);

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();

    expect(userBloc.events, isEmpty);
    expect(find.byType(TextField), findsOne);
  });

  testWidgets('a failed update shows an error snackbar', (tester) async {
    await pumpSection(tester);

    const failure = UserStatus.failure('disk full');
    userStates.add(
      const UserState(
        user: User(name: 'Ana'),
        status: failure,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(AppSnackBar.cardKey),
        matching: find.text('${_en.failedToUpdateDisplayName}: $failure'),
      ),
      findsOne,
    );

    // Let the snackbar time out so no timer is left pending.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a successful update shows no snackbar', (tester) async {
    await pumpSection(tester);

    userStates.add(
      const UserState(
        user: User(name: 'Ana'),
        status: UserStatus.success(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(AppSnackBar.cardKey), findsNothing);
  });
}
