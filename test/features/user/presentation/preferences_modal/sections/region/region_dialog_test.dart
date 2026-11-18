import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/region/region_dialog.dart';

class _MockUserBloc extends MockBloc<UserEvent, UserState> implements UserBloc {
  final added = <UserEvent>[];

  @override
  void add(UserEvent event) => added.add(event);
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  late _MockUserBloc userBloc;

  Future<void> openDialog(
    WidgetTester tester, {
    RegionPreset region = RegionPreset.us,
    Locale? locale,
  }) async {
    userBloc = _MockUserBloc();
    whenListen(
      userBloc,
      const Stream<UserState>.empty(),
      initialState: UserState(regionPreset: region, appLocale: locale),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<UserBloc>.value(
          value: userBloc,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => RegionDialog.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the region\'s formats and units', (tester) async {
    await openDialog(tester, region: RegionPreset.europe);

    final europe = RegionPreset.europe;
    expect(find.text(en.regionAndUnits), findsOneWidget);
    expect(
      find.text(
        '${europe.dateFormat}  ·  ${europe.weightUnit}  ·  '
        '${europe.temperatureUnit}  ·  ${europe.glucoseUnit}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping a region chooses it', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text(en.regionEurope));
    await tester.pump();

    expect(userBloc.added, [
      const UserRegionPresetChanged(RegionPreset.europe),
    ]);
  });

  testWidgets('choosing a language sets it, and the system default clears '
      'it', (tester) async {
    await openDialog(tester, locale: const Locale('en'));

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.systemDefault).last);
    await tester.pumpAndSettle();

    expect(userBloc.added, [
      const UserLocaleChanged(Locale('de')),
      const UserLocaleChanged(null),
    ]);
  });
}
