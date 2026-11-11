import 'dart:async';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4 show HumanName;
import 'package:fhir_r4/fhir_r4.dart' show FhirString;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/theme.dart';
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/widgets/patient_card_details.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/widgets/unified_patient_card.dart';

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

const _border = Color(0xFF123456);
const _icon = Color(0xFF654321);
const _text = Color(0xFF222222);

final maria = Patient(
  id: 'maria',
  sourceId: 'epic',
  title: 'Maria at Epic',
  name: [
    fhir_r4.HumanName(given: [FhirString('Maria')], family: FhirString('Doe')),
  ],
);
const tom = Patient(id: 'tom', sourceId: 'wallet-tom', title: 'Tom');

void main() {
  late _MockPatientBloc patientBloc;
  late _MockHomeBloc homeBloc;
  late _MockUserBloc userBloc;
  late StreamController<PatientState> patientStates;

  setUp(() {
    patientBloc = _MockPatientBloc();
    homeBloc = _MockHomeBloc();
    userBloc = _MockUserBloc();
    patientStates = StreamController<PatientState>();
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

  tearDown(() => patientStates.close());

  Future<void> showCard(
    WidgetTester tester, {
    Patient? patient,
    PatientState state = const PatientState(),
    bool isCollapsing = false,
    bool isExpanding = false,
    bool isAnimating = false,
  }) async {
    whenListen(patientBloc, patientStates.stream, initialState: state);
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
              child: UnifiedPatientCard(
                patient: patient ?? maria,
                index: 0,
                borderColor: _border,
                iconColor: _icon,
                textColor: _text,
                isCollapsing: isCollapsing,
                isExpanding: isExpanding,
                isAnimating: isAnimating,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The card's own box: the first one under it (the edit button has its
  /// own).
  Finder card() => find
      .descendant(
        of: find.byType(UnifiedPatientCard),
        matching: find.byType(AnimatedContainer),
      )
      .first;

  BoxDecoration decoration(WidgetTester tester) =>
      tester.widget<AnimatedContainer>(card()).decoration! as BoxDecoration;

  Color borderColor(WidgetTester tester) =>
      (decoration(tester).border! as Border).top.color;

  double arrowTurns(WidgetTester tester) =>
      tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns;

  double scale(WidgetTester tester) =>
      tester.widget<AnimatedContainer>(card()).transform!.getMaxScaleOnAxis();

  testWidgets('a closed card shows the name family first, an arrow pointing '
      'down and no details', (tester) async {
    await showCard(tester);

    expect(find.text('Doe, Maria'), findsOneWidget);
    expect(arrowTurns(tester), 0.0);
    expect(find.byType(PatientCardDetails), findsNothing);
    expect(find.text(_en.editDetails), findsNothing);
    expect(decoration(tester).color, Colors.transparent);
    expect(borderColor(tester), _border);
    expect(scale(tester), 1.0);
  });

  testWidgets('a patient without a structured name shows their title', (
    tester,
  ) async {
    await showCard(tester, patient: tom);

    expect(find.text('Tom'), findsOneWidget);
  });

  testWidgets('shows the person\'s own row, not the provider\'s', (
    tester,
  ) async {
    const wallet = Patient(
      id: 'maria-wallet',
      sourceId: 'wallet-maria',
      title: 'Maria Popescu',
    );
    await showCard(
      tester,
      state: PatientState(
        patientGroups: {
          'maria': Holder(
            id: 'maria',
            representativePatient: wallet,
            sourceIds: const ['epic', 'wallet-maria'],
            allPatientInstances: [maria, wallet],
          ),
        },
      ),
    );

    expect(find.text('Maria Popescu'), findsOneWidget);
    expect(find.text('Doe, Maria'), findsNothing);
  });

  testWidgets('an open card shows the details with the blood type, the '
      'arrow pointing up and a highlighted border', (tester) async {
    await showCard(
      tester,
      state: PatientState(
        patients: [maria],
        expandedPatientIds: const {'maria'},
        bloodTypes: const {'maria': 'A+'},
      ),
    );

    expect(find.byType(PatientCardDetails), findsOneWidget);
    expect(find.text('${_en.bloodType}: A+'), findsOneWidget);
    expect(find.text(_en.editDetails), findsOneWidget);
    expect(arrowTurns(tester), 0.5);
    expect(decoration(tester).color, AppColors.primary.withValues(alpha: 0.1));
    expect(borderColor(tester), AppColors.primary);
  });

  testWidgets('the blood type shows as loading until it is read, and N/A '
      'when there is none', (tester) async {
    await showCard(
      tester,
      state: const PatientState(expandedPatientIds: {'maria'}),
    );
    expect(find.text('${_en.bloodType}: ${_en.loading}'), findsOneWidget);

    patientStates.add(
      const PatientState(
        expandedPatientIds: {'maria'},
        bloodTypes: {'maria': null},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('${_en.bloodType}: ${_en.homeNA}'), findsOneWidget);
  });

  testWidgets('opening the card turns the arrow up and shows the details', (
    tester,
  ) async {
    await showCard(tester);

    patientStates.add(const PatientState(expandedPatientIds: {'maria'}));
    // The new state arrives after the first frame and is drawn on the next.
    await tester.pump();
    await tester.pump();
    expect(arrowTurns(tester), 0.5);

    double shownTurns() => tester
        .widget<RotationTransition>(
          find.descendant(
            of: find.byType(AnimatedRotation),
            matching: find.byType(RotationTransition),
          ),
        )
        .turns
        .value;

    await tester.pump(const Duration(milliseconds: 75));
    expect(shownTurns(), greaterThan(0.0));
    expect(shownTurns(), lessThan(0.5));

    await tester.pump(const Duration(milliseconds: 75));
    expect(shownTurns(), 0.5);

    await tester.pumpAndSettle();
    expect(find.text(_en.editDetails), findsOneWidget);
  });

  testWidgets('a card opening shows its details while still closed, grows '
      'a little and is lightly highlighted', (tester) async {
    await showCard(tester, isExpanding: true);

    expect(find.byType(PatientCardDetails), findsOneWidget);
    expect(scale(tester), closeTo(1.02, 0.0001));
    expect(
      decoration(tester).color,
      AppColors.primary.withValues(alpha: 0.05),
    );
    expect(borderColor(tester), AppColors.primary.withValues(alpha: 0.5));
  });

  testWidgets('a card closing loses its highlight even while still open', (
    tester,
  ) async {
    await showCard(
      tester,
      isCollapsing: true,
      state: const PatientState(expandedPatientIds: {'maria'}),
    );

    expect(decoration(tester).color, Colors.transparent);
    expect(borderColor(tester), _border);
    expect(arrowTurns(tester), 0.5);
  });

  testWidgets('the tapped card is highlighted while the patients switch', (
    tester,
  ) async {
    await showCard(tester, isAnimating: true);

    expect(
      decoration(tester).color,
      AppColors.primary.withValues(alpha: 0.15),
    );
    expect(borderColor(tester), AppColors.primary.withValues(alpha: 0.5));
    expect(find.byType(PatientCardDetails), findsNothing);
  });

  testWidgets('a blood type saved from the details reads the blood types '
      'again', (tester) async {
    await showCard(
      tester,
      state: const PatientState(expandedPatientIds: {'maria'}),
    );

    tester
        .widget<PatientCardDetails>(find.byType(PatientCardDetails))
        .onBloodTypeUpdated();

    expect(patientBloc.events, [const PatientBloodTypesRequested()]);
  });
}
