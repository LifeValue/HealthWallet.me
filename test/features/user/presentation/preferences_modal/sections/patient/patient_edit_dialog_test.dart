import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4 show HumanName;
import 'package:fhir_r4/fhir_r4.dart' show AdministrativeGender, FhirString;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/theme/theme.dart';
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/user/domain/services/patient_edit_service.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/patient_edit_dialog.dart';
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

/// Reports every save as a change, so the dialog's own comparison decides
/// what is written, and records the gender label it was asked about.
class _FakePatientEditService extends Fake implements PatientEditService {
  final checkedGenders = <String>[];

  @override
  Future<String?> getCurrentBloodType(Patient patient) async => 'A+';

  @override
  Future<bool> hasPatientChanges({
    required Patient currentPatient,
    required DateTime? newBirthDate,
    required String newGender,
    required String newBloodType,
    String? newIdentifierValue,
    required AppLocalizations l10n,
  }) async {
    checkedGenders.add(newGender);
    return true;
  }
}

final _en = lookupAppLocalizations(const Locale('en'));
final _de = lookupAppLocalizations(const Locale('de'));

Patient _patient(AdministrativeGender? gender) => Patient(
  id: 'patient-1',
  sourceId: 'wallet-1',
  gender: gender,
  name: [
    fhir_r4.HumanName(given: [FhirString('Maria')], family: FhirString('Doe')),
  ],
);

/// The app's locale and theme, which the tests change under an open dialog.
final _appSettings = ValueNotifier<(Locale, ThemeMode)>(
  (const Locale('en'), ThemeMode.light),
);

void main() {
  late _MockPatientBloc patientBloc;
  late _MockHomeBloc homeBloc;
  late _MockUserBloc userBloc;
  late _FakePatientEditService editService;

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

    editService = _FakePatientEditService();
    getIt.registerSingleton<PatientEditService>(editService);
  });

  tearDown(() => getIt.unregister<PatientEditService>());

  Future<void> openDialog(WidgetTester tester, Patient patient) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _App(
        patient: patient,
        patientBloc: patientBloc,
        homeBloc: homeBloc,
        userBloc: userBloc,
      ),
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
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();
  }

  Future<void> changeFamilyName(WidgetTester tester) => tester.enterText(
    find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == 'Doe',
    ),
    'Popescu',
  );

  PatientEditSaved savedEdit() =>
      patientBloc.events.whereType<PatientEditSaved>().single;

  testWidgets('shows the stored gender', (tester) async {
    await openDialog(tester, _patient(AdministrativeGender.female));

    expect(find.text(_en.female), findsOneWidget);
  });

  testWidgets('an edited gender stays when the language changes', (
    tester,
  ) async {
    await openDialog(tester, _patient(AdministrativeGender.male));
    await pickGender(tester, from: _en.male, to: _en.female);

    _appSettings.value = (const Locale('de'), ThemeMode.light);
    await tester.pumpAndSettle();

    expect(find.text(_de.female), findsOneWidget);
    expect(find.text(_de.male), findsNothing);

    await save(tester, _de);
    expect(editService.checkedGenders, [_de.female]);
    expect(savedEdit().gender, 'female');
  });

  testWidgets('an edited gender stays when the theme changes', (tester) async {
    await openDialog(tester, _patient(AdministrativeGender.female));
    await pickGender(tester, from: _en.female, to: _en.male);

    _appSettings.value = (const Locale('en'), ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(find.text(_en.male), findsOneWidget);
    expect(find.text(_en.female), findsNothing);

    await save(tester, _en);
    expect(savedEdit().gender, 'male');
  });

  testWidgets('the stored gender shows in the new language', (tester) async {
    await openDialog(tester, _patient(AdministrativeGender.female));

    _appSettings.value = (const Locale('de'), ThemeMode.light);
    await tester.pumpAndSettle();

    expect(find.text(_de.female), findsOneWidget);
  });

  testWidgets('changing to Prefer not to say saves unknown', (tester) async {
    await openDialog(tester, _patient(AdministrativeGender.male));
    await pickGender(tester, from: _en.male, to: _en.preferNotToSay);

    await save(tester, _en);

    expect(editService.checkedGenders, [_en.preferNotToSay]);
    expect(savedEdit().gender, 'unknown');
  });

  final unspecified = {
    'other': AdministrativeGender.other,
    'unknown': AdministrativeGender.unknown,
    'no': null,
  };
  for (final MapEntry(key: name, value: gender) in unspecified.entries) {
    testWidgets('a stored $name gender shows Prefer not to say and is left '
        'as stored when another field is saved', (tester) async {
      await openDialog(tester, _patient(gender));

      expect(find.text(_en.preferNotToSay), findsOneWidget);

      await changeFamilyName(tester);
      await save(tester, _en);

      expect(editService.checkedGenders, [_en.preferNotToSay]);
      expect(savedEdit().family, 'Popescu');
      expect(savedEdit().gender, isNull);
    });
  }

  testWidgets('shows and keeps the gender of the row shown for the person, '
      'their wallet copy, not the provider\'s', (tester) async {
    final provider = Patient(
      id: 'patient-1',
      sourceId: 'provider-1',
      gender: AdministrativeGender.male,
      name: [
        fhir_r4.HumanName(
          given: [FhirString('Maria')],
          family: FhirString('Doe'),
        ),
      ],
    );
    final wallet = Patient(
      id: 'patient-1-wallet',
      sourceId: 'wallet-1',
      gender: AdministrativeGender.female,
      name: [
        fhir_r4.HumanName(
          given: [FhirString('Maria')],
          family: FhirString('Doe'),
        ),
      ],
    );
    whenListen(
      patientBloc,
      const Stream<PatientState>.empty(),
      initialState: PatientState(
        patientGroups: {
          provider.id: Holder(
            id: provider.id,
            representativePatient: wallet,
            sourceIds: [provider.sourceId, wallet.sourceId],
            allPatientInstances: [provider, wallet],
          ),
        },
      ),
    );

    await openDialog(tester, provider);

    expect(find.text(_en.female), findsOneWidget);
    expect(find.text(_en.male), findsNothing);

    _appSettings.value = (const Locale('de'), ThemeMode.light);
    await tester.pumpAndSettle();

    expect(find.text(_de.female), findsOneWidget);

    await changeFamilyName(tester);
    await save(tester, _de);

    expect(savedEdit().patientId, wallet.id);
    expect(savedEdit().family, 'Popescu');
    expect(savedEdit().gender, isNull);
  });

  testWidgets('an untouched gender is not written', (tester) async {
    await openDialog(tester, _patient(AdministrativeGender.female));

    await changeFamilyName(tester);
    await save(tester, _en);

    expect(savedEdit().gender, isNull);
  });
}

/// The app around the dialog, opened the way the app opens it.
class _App extends StatelessWidget {
  final Patient patient;
  final PatientBloc patientBloc;
  final HomeBloc homeBloc;
  final UserBloc userBloc;

  const _App({
    required this.patient,
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
                onPressed: () => PatientEditDialog.show(context, patient),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
