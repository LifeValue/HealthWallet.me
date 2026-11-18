import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_toolbar.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_view_toggle.dart';

/// Records the events the toolbar adds.
class _MockRecordsBloc extends MockBloc<RecordsEvent, RecordsState>
    implements RecordsBloc {
  final added = <RecordsEvent>[];

  @override
  void add(RecordsEvent event) => added.add(event);

  @override
  bool get isClosed => false;
}

void main() {
  late _MockRecordsBloc bloc;

  /// The toolbar, or with [shown] false the screen without it (another view
  /// or tab).
  Widget app({bool shown = true}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BlocProvider<RecordsBloc>.value(
        value: bloc,
        child: Column(
          children: [
            if (shown)
              RecordsToolbar(
                viewMode: RecordsViewMode.recordsList,
                onViewModeChanged: (_) {},
                onFilterTap: () {},
              ),
            const TextField(key: Key('elsewhere')),
          ],
        ),
      ),
    ),
  );

  void stubQuery(String query) => whenListen(
    bloc,
    const Stream<RecordsState>.empty(),
    initialState: RecordsState(searchQuery: query),
  );

  setUp(() => bloc = _MockRecordsBloc());

  testWidgets('leaving clears a search, which no box shows any more', (
    tester,
  ) async {
    stubQuery('insulin');
    await tester.pumpWidget(app());

    await tester.pumpWidget(app(shown: false));

    expect(bloc.added, [const RecordsSearch('')]);
  });

  testWidgets('leaving without a search reloads nothing', (tester) async {
    stubQuery('');
    await tester.pumpWidget(app());

    await tester.pumpWidget(app(shown: false));

    expect(bloc.added, isEmpty);
  });

  testWidgets('the search box stays open while it holds a search', (
    tester,
  ) async {
    stubQuery('');
    await tester.pumpWidget(app());
    final l10n = lookupAppLocalizations(const Locale('en'));

    // The search icon is the first tappable icon after the view toggle.
    await tester.tap(find.byType(GestureDetector).at(1));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, l10n.searchRecordsHint),
      'insulin',
    );
    await tester.tap(find.byKey(const Key('elsewhere')));
    await tester.pumpAndSettle();

    expect(find.text('insulin'), findsOneWidget);
  });
}
