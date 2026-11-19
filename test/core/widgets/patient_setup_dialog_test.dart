import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:fhir_r4/fhir_r4.dart' show AdministrativeGender;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/theme/theme.dart';
import 'package:health_wallet/core/widgets/patient_setup_dialog.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/user/domain/services/id_card_extractor.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/mixins/id_card_scan_mixin.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the events sent to it instead of running them.
class _MockPatientBloc extends MockBloc<PatientEvent, PatientState>
    implements PatientBloc {
  final events = <PatientEvent>[];

  @override
  void add(PatientEvent event) => events.add(event);
}

class _MockHomeBloc extends MockBloc<HomeEvent, HomeState>
    implements HomeBloc {}

class _MockUserBloc extends MockBloc<UserEvent, UserState>
    implements UserBloc {}

final _en = lookupAppLocalizations(const Locale('en'));
final _de = lookupAppLocalizations(const Locale('de'));

const _patient = Patient(
  id: 'patient-1',
  sourceId: 'wallet-1',
  gender: AdministrativeGender.female,
);

/// The app's locale and theme, which the tests change under an open dialog.
final _appSettings = ValueNotifier<(Locale, ThemeMode)>(
  (const Locale('en'), ThemeMode.light),
);

void main() {
  late _MockPatientBloc patientBloc;
  late _MockHomeBloc homeBloc;
  late _MockUserBloc userBloc;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _appSettings.value = (const Locale('en'), ThemeMode.light);

    patientBloc = _MockPatientBloc();
    homeBloc = _MockHomeBloc();
    userBloc = _MockUserBloc();
    whenListen(
      patientBloc,
      const Stream<PatientState>.empty(),
      initialState: const PatientState(),
    );
    whenListen(
      homeBloc,
      const Stream<HomeState>.empty(),
      initialState: const HomeState(),
    );
    whenListen(
      userBloc,
      const Stream<UserState>.empty(),
      initialState: const UserState(),
    );
  });

  Future<void> openDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _App(patientBloc: patientBloc, homeBloc: homeBloc, userBloc: userBloc),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> pickGender(
    WidgetTester tester, {
    required String from,
    required String to,
  }) async {
    await tester.tap(find.text(from));
    await tester.pumpAndSettle();
    await tester.tap(find.text(to).last);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester, AppLocalizations l10n) async {
    await tester.tap(find.text(l10n.done));
    await tester.pumpAndSettle();
  }

  /// Applies an ID scan result as the scan mixin does, inside `setState`.
  Future<void> scan(WidgetTester tester, String? gender) async {
    final state = tester.state(find.byType(PatientSetupDialog));
    // ignore: invalid_use_of_protected_member, the scan mixin applies its result the same way
    state.setState(
      () => (state as IdCardScanMixin).onScanResultApplied(
        IdCardExtractionResult(gender: gender),
      ),
    );
    await tester.pumpAndSettle();
  }

  String? savedGender() =>
      patientBloc.events.whereType<PatientEditSaved>().single.gender;

  testWidgets('starts on Prefer not to say', (tester) async {
    await openDialog(tester);

    expect(find.text(_en.preferNotToSay), findsOneWidget);
  });

  testWidgets('a picked gender stays when the language changes', (
    tester,
  ) async {
    await openDialog(tester);
    await pickGender(tester, from: _en.preferNotToSay, to: _en.female);
    expect(find.text(_en.female), findsOneWidget);

    _appSettings.value = (const Locale('de'), ThemeMode.light);
    await tester.pumpAndSettle();

    expect(find.text(_de.female), findsOneWidget);
    expect(find.text(_de.preferNotToSay), findsNothing);

    await save(tester, _de);
    expect(savedGender(), 'female');
  });

  testWidgets('a picked gender stays when the theme changes', (tester) async {
    await openDialog(tester);
    await pickGender(tester, from: _en.preferNotToSay, to: _en.male);

    _appSettings.value = (const Locale('en'), ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(find.text(_en.male), findsOneWidget);
    expect(find.text(_en.preferNotToSay), findsNothing);

    await save(tester, _en);
    expect(savedGender(), 'male');
  });

  testWidgets('a scanned gender stays when the language changes', (
    tester,
  ) async {
    await openDialog(tester);
    await scan(tester, 'male');
    expect(find.text(_en.male), findsOneWidget);

    _appSettings.value = (const Locale('de'), ThemeMode.light);
    await tester.pumpAndSettle();

    expect(find.text(_de.male), findsOneWidget);

    await save(tester, _de);
    expect(savedGender(), 'male');
  });

  for (final scanned in ['other', 'unknown', 'OTHER']) {
    testWidgets('a scanned "$scanned" shows Prefer not to say and saves '
        'unknown', (tester) async {
      await openDialog(tester);
      await scan(tester, scanned);

      expect(find.text(_en.preferNotToSay), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Maria');
      await save(tester, _en);
      expect(savedGender(), 'unknown');
    });
  }

  testWidgets('no gender picked saves unknown with the other fields', (
    tester,
  ) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextField).first, 'Maria');
    await save(tester, _en);

    expect(savedGender(), 'unknown');
  });

  testWidgets('picking Prefer not to say after a gender saves unknown', (
    tester,
  ) async {
    await openDialog(tester);
    await pickGender(tester, from: _en.preferNotToSay, to: _en.female);
    await pickGender(tester, from: _en.female, to: _en.preferNotToSay);

    await tester.enterText(find.byType(TextField).first, 'Maria');
    await save(tester, _en);

    expect(savedGender(), 'unknown');
  });

  testWidgets('nothing filled in saves nothing', (tester) async {
    await openDialog(tester);

    await save(tester, _en);

    expect(patientBloc.events.whereType<PatientEditSaved>(), isEmpty);
    expect(find.byType(PatientSetupDialog), findsNothing);
  });
}

/// The app around the dialog, opened the way the app opens it.
class _App extends StatelessWidget {
  final PatientBloc patientBloc;
  final HomeBloc homeBloc;
  final UserBloc userBloc;

  const _App({
    required this.patientBloc,
    required this.homeBloc,
    required this.userBloc,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PatientBloc>.value(value: patientBloc),
        BlocProvider<HomeBloc>.value(value: homeBloc),
        BlocProvider<UserBloc>.value(value: userBloc),
      ],
      child: ValueListenableBuilder(
        valueListenable: _appSettings,
        builder: (context, settings, _) => MaterialApp(
          locale: settings.$1,
          themeMode: settings.$2,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => PatientSetupDialog.show(context, _patient),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
