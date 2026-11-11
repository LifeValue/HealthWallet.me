import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:fhir_r4/fhir_r4.dart'
    show
        AdministrativeGender,
        ContactPoint,
        ContactPointSystem,
        FhirDate,
        FhirString,
        PatientContact;
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4 show HumanName;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/theme/theme.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/user/domain/services/patient_edit_service.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/patient_edit_dialog.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/widgets/patient_card_details.dart';
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

/// Gives the edit dialog a blood type to show; nothing is saved here.
class _FakePatientEditService extends Fake implements PatientEditService {
  @override
  Future<String?> getCurrentBloodType(Patient patient) async => 'A+';
}

final _en = lookupAppLocalizations(const Locale('en'));

Patient _patient({
  AdministrativeGender? gender,
  String? birthDate,
  String? emergencyPhone,
}) => Patient(
  id: 'maria',
  sourceId: 'wallet-maria',
  gender: gender,
  birthDate: birthDate == null ? null : FhirDate.fromString(birthDate),
  contact: emergencyPhone == null
      ? null
      : [
          PatientContact(
            telecom: [
              ContactPoint(
                system: ContactPointSystem.phone,
                value: FhirString(emergencyPhone),
              ),
            ],
          ),
        ],
  name: [
    fhir_r4.HumanName(given: [FhirString('Maria')], family: FhirString('Doe')),
  ],
);

void main() {
  late _MockPatientBloc patientBloc;
  late _MockHomeBloc homeBloc;
  late _MockUserBloc userBloc;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
    getIt.registerSingleton<PatientEditService>(_FakePatientEditService());
  });

  tearDown(() => getIt.unregister<PatientEditService>());

  Future<void> showDetails(
    WidgetTester tester,
    Patient patient, {
    double width = 800,
    VoidCallback? onBloodTypeUpdated,
  }) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<PatientBloc>.value(value: patientBloc),
          BlocProvider<HomeBloc>.value(value: homeBloc),
          BlocProvider<UserBloc>.value(value: userBloc),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PatientCardDetails(
                displayPatient: patient,
                currentPatient: patient,
                iconColor: Colors.black,
                textColor: Colors.black,
                isExpanding: false,
                isCollapsing: false,
                bloodTypeDisplay: 'B+',
                onBloodTypeUpdated: onBloodTypeUpdated ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String genderRow(String value) => '${_en.gender}: $value';

  group('the gender row', () {
    for (final (gender, label) in [
      (AdministrativeGender.male, _en.male),
      (AdministrativeGender.female, _en.female),
      (AdministrativeGender.unknown, _en.preferNotToSay),
      (AdministrativeGender.other, 'other'),
    ]) {
      testWidgets('reads "$label" for ${gender.valueString}', (tester) async {
        await showDetails(tester, _patient(gender: gender));

        expect(find.text(genderRow(label)), findsOne);
      });
    }

    testWidgets('reads "Prefer not to say" when there is no gender', (
      tester,
    ) async {
      await showDetails(tester, _patient());

      expect(find.text(genderRow(_en.preferNotToSay)), findsOne);
    });
  });

  testWidgets('the birth date shows next to the age, and nothing in the '
      'brackets when there is none', (tester) async {
    await showDetails(tester, _patient(birthDate: '1980-03-14'));
    expect(find.textContaining('14'), findsWidgets);
    expect(find.textContaining('1980'), findsOne);

    await showDetails(tester, _patient());
    expect(find.textContaining('()'), findsOne);
  });

  testWidgets('the emergency phone shows formatted, and "-" when there is '
      'none', (tester) async {
    await showDetails(tester, _patient(emergencyPhone: '+447700900123'));
    expect(
      find.text('${_en.emergencyContact}: +44 7700 900123'),
      findsOne,
    );

    await showDetails(tester, _patient());
    expect(find.text('${_en.emergencyContact}: -'), findsOne);
  });

  testWidgets('the rows use a smaller text on a narrow screen', (tester) async {
    await showDetails(tester, _patient(), width: 360);
    final narrow = tester.widget<Text>(
      find.text('${_en.bloodType}: B+'),
    );

    await showDetails(tester, _patient());
    final wide = tester.widget<Text>(find.text('${_en.bloodType}: B+'));

    expect(narrow.style!.fontSize, 11);
    expect(wide.style!.fontSize, isNot(11));
  });

  testWidgets('Edit details starts the edit and opens the edit dialog', (
    tester,
  ) async {
    await showDetails(tester, _patient(gender: AdministrativeGender.female));

    await tester.tap(find.text(_en.editDetails));
    await tester.pumpAndSettle();

    expect(patientBloc.events, [const PatientEditStarted('maria')]);
    expect(find.byType(PatientEditDialog), findsOne);
  });
}
