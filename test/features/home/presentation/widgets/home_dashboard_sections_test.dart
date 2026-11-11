import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/widgets/dialogs/app_dialog.dart';
import 'package:health_wallet/core/widgets/overlay_annotations/overlay_annotations.dart';
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/home/core/constants/home_constants.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/entities/overview_card.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';
import 'package:health_wallet/features/home/domain/entities/specialty_card.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/home/presentation/sections/medical_records_section.dart';
import 'package:health_wallet/features/home/presentation/sections/recent_records_section.dart';
import 'package:health_wallet/features/home/presentation/sections/specialties_section.dart';
import 'package:health_wallet/features/home/presentation/sections/vitals_section.dart';
import 'package:health_wallet/features/home/presentation/widgets/home_dashboard_sections.dart';
import 'package:health_wallet/features/home/presentation/widgets/home_overview_toggle.dart';
import 'package:health_wallet/features/home/presentation/widgets/home_section_header.dart';
import 'package:health_wallet/features/home/presentation/widgets/section_info_modal.dart';
import 'package:health_wallet/features/home/presentation/widgets/source/source_selector_widget.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';

/// Keeps what the dashboard asks of Home.
class _MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {
  final added = <HomeEvent>[];

  @override
  void add(HomeEvent event) => added.add(event);
}

/// Keeps what the dashboard asks of Records.
class _MockRecordsBloc extends MockBloc<RecordsEvent, RecordsState>
    implements RecordsBloc {
  final added = <RecordsEvent>[];

  @override
  void add(RecordsEvent event) => added.add(event);
}

class _MockUserBloc extends MockBloc<UserEvent, UserState>
    implements UserBloc {}

/// Records the pages the dashboard opens.
class _FakeStackRouter extends Fake implements StackRouter {
  final pushed = <PageRouteInfo>[];

  @override
  Future<T?> push<T extends Object?>(
    PageRouteInfo route, {
    OnNavigationFailure? onFailure,
  }) async {
    pushed.add(route);
    return null;
  }
}

final _en = lookupAppLocalizations(const Locale('en'));

const _recordsPageText = 'Records tab';

const _heartRate = PatientVital(title: 'Heart Rate', value: '72', unit: 'bpm');
const _bloodPressure = PatientVital(
  title: 'Blood Pressure',
  value: '120/80',
  unit: 'mmHg',
);
const _temperature = PatientVital(
  title: 'Temperature',
  value: '36.6',
  unit: '°C',
);
const _bloodOxygen = PatientVital(
  title: 'Blood Oxygen',
  value: '98',
  unit: '%',
);
const _weight = PatientVital(title: 'Weight', value: '70', unit: 'kg');

const _sources = [
  Source(id: 'clinic', labelSource: 'City Clinic', platformType: 'fasten'),
  Source(id: 'lab', labelSource: 'Lab Results', platformType: 'fasten'),
];

final _cardiology = MedicalSpecialty.cardiology.localizedName(_en);
final _dental = MedicalSpecialty.dental.localizedName(_en);
final _allergies = HomeRecordsCategory.allergies.localizedName(_en);
final _medications = HomeRecordsCategory.medications.localizedName(_en);

final _condition = entityFromJson(conditionJson());

HomeState _loaded({
  OverviewViewMode mode = OverviewViewMode.specialties,
  bool vitalsExpanded = false,
  Map<MedicalSpecialty, bool>? selectedSpecialties,
  Map<HomeRecordsCategory, bool>? selectedRecordTypes,
}) {
  const defaults = HomeState();
  return HomeState(
    hasDataLoaded: true,
    overviewViewMode: mode,
    vitalsExpanded: vitalsExpanded,
    patientVitals: const [_heartRate, _bloodPressure],
    allAvailableVitals: const [
      _heartRate,
      _bloodPressure,
      _temperature,
      _bloodOxygen,
      _weight,
    ],
    specialtyCards: const [
      SpecialtyCard(specialty: MedicalSpecialty.cardiology, count: 3),
      SpecialtyCard(specialty: MedicalSpecialty.dental, count: 5),
    ],
    overviewCards: [
      OverviewCard(category: HomeRecordsCategory.allergies, count: '2'),
      OverviewCard(category: HomeRecordsCategory.medications, count: '4'),
    ],
    recentRecords: [_condition],
    sources: _sources,
    selectedSpecialties: selectedSpecialties ?? defaults.selectedSpecialties,
    selectedRecordTypes: selectedRecordTypes ?? defaults.selectedRecordTypes,
  );
}

/// The app's Matter font, so the headers measure as they do in the app
/// rather than in the test font's wide square glyphs.
Future<void> _loadMatterFont() async {
  final loader = FontLoader('Matter');
  for (final file in const [
    'Matter-Regular.ttf',
    'Matter-Medium.ttf',
    'Matter-SemiBold.ttf',
    'Matter-Bold.ttf',
  ]) {
    loader.addFont(rootBundle.load('assets/font/matter-font/$file'));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await _loadMatterFont();
  });

  late _MockHomeBloc homeBloc;
  late _MockRecordsBloc recordsBloc;
  late _MockUserBloc userBloc;
  late _FakeStackRouter router;
  late PageController pageController;
  late HomeHighlightController highlight;

  setUp(() {
    homeBloc = _MockHomeBloc();
    recordsBloc = _MockRecordsBloc();
    userBloc = _MockUserBloc();
    whenListen(
      userBloc,
      const Stream<UserState>.empty(),
      initialState: const UserState(),
    );
    router = _FakeStackRouter();
    highlight = HomeHighlightController();
  });

  Future<void> pump(
    WidgetTester tester,
    HomeState state, {
    bool editMode = false,
    Size size = const Size(400, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    pageController = PageController();
    addTearDown(pageController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<HomeBloc>.value(value: homeBloc),
              BlocProvider<RecordsBloc>.value(value: recordsBloc),
              BlocProvider<UserBloc>.value(value: userBloc),
            ],
            child: Scaffold(
              body: PageView(
                controller: pageController,
                children: [
                  CustomScrollView(
                    slivers: [
                      HomeDashboardSections(
                        state: state,
                        editMode: editMode,
                        highlightController: highlight,
                        pageController: pageController,
                      ),
                    ],
                  ),
                  const Center(child: Text(_recordsPageText)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The heights of the gaps between the dashboard's sections, in order.
  List<double?> gapHeights(WidgetTester tester) => tester
      .widgetList<SizedBox>(
        find.descendant(
          of: find.byType(HomeDashboardSections),
          matching: find.byType(SizedBox),
        ),
      )
      .map((box) => box.height)
      .toList();

  /// Opens a dialog while edit mode keeps the cards shaking forever.
  Future<void> settleDialog(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Finder infoIcon(int section) => find
      .descendant(
        of: find.byType(HomeSectionHeader).at(section),
        matching: find.byWidgetPredicate(
          (w) => w is GestureDetector && w.child is SvgPicture,
        ),
      )
      .first;

  group('layout', () {
    testWidgets('shows no section until the data has loaded', (tester) async {
      await pump(tester, const HomeState());

      expect(find.byType(HomeSectionHeader), findsNothing);
      expect(gapHeights(tester), [
        Insets.small,
        Insets.large,
        Insets.large,
        HomeConstants.bottomPadding,
      ]);
    });

    testWidgets('edit mode shows every section before the data has loaded', (
      tester,
    ) async {
      await pump(tester, const HomeState(), editMode: true);

      expect(find.byType(HomeSectionHeader), findsNWidgets(3));
      expect(find.byType(VitalsSection), findsOne);
      expect(find.byType(SpecialtiesSection), findsOne);
      expect(find.text(_en.recentRecords), findsOne);
    });

    testWidgets('sections sit closer together on a short phone', (
      tester,
    ) async {
      await pump(tester, const HomeState(), size: const Size(400, 650));

      expect(gapHeights(tester), [
        Insets.small,
        Insets.medium,
        Insets.medium,
        HomeConstants.bottomPadding,
      ]);
    });

    testWidgets('a short phone still shows every loaded section', (
      tester,
    ) async {
      await pump(tester, _loaded(), size: const Size(400, 650));

      expect(find.text(_en.homeVitalSigns), findsOne);
      expect(find.byType(HomeOverviewToggle), findsOne);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tablet uses the tablet gap between sections', (
      tester,
    ) async {
      await pump(tester, const HomeState(), size: const Size(800, 1200));

      expect(gapHeights(tester), [
        Insets.small,
        Insets.normal,
        Insets.normal,
        HomeConstants.bottomPadding,
      ]);
    });

    testWidgets('loaded data shows vitals, specialties and recent records', (
      tester,
    ) async {
      await pump(tester, _loaded());

      expect(find.text(_en.homeVitalSigns), findsOne);
      expect(find.text('72'), findsOne);
      expect(find.text(_cardiology), findsOne);
      expect(find.text(_dental), findsOne);
      expect(find.text(_en.recentRecords), findsOne);
      expect(find.text(_condition.displayTitle), findsOne);
      expect(find.byKey(highlight.firstVitalCardKey), findsOne);
      expect(find.byKey(highlight.firstSpecialtyCardKey), findsOne);
    });
  });

  group('vitals', () {
    testWidgets('collapsed, only the chosen vitals show', (tester) async {
      final state = _loaded();
      await pump(tester, state);

      final section = tester.widget<VitalsSection>(find.byType(VitalsSection));
      expect(section.vitals, state.patientVitals);
      expect(section.allAvailableVitals, state.allAvailableVitals);
      expect(section.vitalsExpanded, isFalse);
      expect(section.editMode, isFalse);
      expect(section.selectedVitals, {
        for (final e in state.selectedVitals.entries) e.key.title: e.value,
      });
    });

    testWidgets('expanded, every available vital shows', (tester) async {
      final state = _loaded(vitalsExpanded: true);
      await pump(tester, state);

      final section = tester.widget<VitalsSection>(find.byType(VitalsSection));
      expect(section.vitals, state.allAvailableVitals);
      expect(section.vitalsExpanded, isTrue);
      expect(find.text('70'), findsOne);
    });

    testWidgets('Show All asks Home to expand the vitals', (tester) async {
      await pump(tester, _loaded());

      await tester.tap(find.text(_en.showAll));
      await tester.pump();

      expect(homeBloc.added, [const HomeVitalsExpansionToggled()]);
    });

    testWidgets('long-pressing a vital turns edit mode on', (tester) async {
      await pump(tester, _loaded());

      await tester.longPress(find.text('72'));
      await tester.pump();

      expect(homeBloc.added, [const HomeEditModeChanged(true)]);
    });

    testWidgets('a reordered vital is passed to Home', (tester) async {
      await pump(tester, _loaded(vitalsExpanded: true), editMode: true);

      tester.widget<VitalsSection>(find.byType(VitalsSection)).onReorder!(3, 1);

      expect(homeBloc.added, [const HomeVitalsReordered(3, 1)]);
    });

    testWidgets('the info icon explains the vitals section', (tester) async {
      await pump(tester, _loaded());

      await tester.tap(infoIcon(0));
      await tester.pumpAndSettle();

      final modal = tester.widget<SectionInfoModal>(
        find.byType(SectionInfoModal),
      );
      expect(modal.title, _en.vitalSigns);
      expect(find.text(_en.longPressToReorder), findsOne);
    });

    testWidgets('outside edit mode the vitals have no filter', (tester) async {
      await pump(tester, _loaded());

      expect(find.text(_en.vitals), findsOne, reason: 'the title only');
    });

    testWidgets('in edit mode the vitals filter saves the chosen vitals', (
      tester,
    ) async {
      final state = _loaded();
      await pump(tester, state, editMode: true);

      // The title and the filter read the same; the filter comes last.
      await tester.tap(find.text(_en.vitals).last);
      await settleDialog(tester);
      expect(find.byType(AppDialog), findsOne);

      await tester.tap(find.text(_en.save));
      await settleDialog(tester);

      // Every vital type, chosen as before.
      expect(homeBloc.added, [
        HomeVitalsFiltersChanged({
          for (final type in PatientVitalType.values)
            type: state.selectedVitals[type] ?? false,
        }),
      ]);
    });

    testWidgets('the vitals filter is off while every vital is shown', (
      tester,
    ) async {
      await pump(tester, _loaded(vitalsExpanded: true), editMode: true);

      await tester.tap(find.text(_en.vitals).last);
      await settleDialog(tester);

      expect(find.byType(AppDialog), findsNothing);
      expect(homeBloc.added, isEmpty);
    });
  });

  group('overview: specialties', () {
    testWidgets('shows only the specialties the person chose', (tester) async {
      await pump(
        tester,
        _loaded(
          selectedSpecialties: const {
            MedicalSpecialty.cardiology: true,
            MedicalSpecialty.dental: false,
          },
        ),
      );

      expect(find.text(_cardiology), findsOne);
      expect(find.text(_dental), findsNothing);
      expect(find.byType(MedicalRecordsSection), findsNothing);
    });

    testWidgets('a specialty card filters Records to it for this visit and '
        'opens Records', (tester) async {
      await pump(tester, _loaded());

      await tester.tap(find.text(_dental));
      await tester.pumpAndSettle();

      expect(recordsBloc.added, [
        const RecordsSpecialtyApplied([
          MedicalSpecialty.dental,
        ], remember: false),
      ]);
      expect(homeBloc.added, isEmpty);
      expect(pageController.page, 1);
      expect(find.text(_recordsPageText), findsOne);
    });

    testWidgets('long-pressing a specialty card turns edit mode on', (
      tester,
    ) async {
      await pump(tester, _loaded());

      await tester.longPress(find.text(_cardiology));
      await tester.pump();

      expect(homeBloc.added, [const HomeEditModeChanged(true)]);
      expect(recordsBloc.added, isEmpty);
    });

    testWidgets('a reordered specialty is passed to Home', (tester) async {
      await pump(tester, _loaded(), editMode: true);

      final section = tester.widget<SpecialtiesSection>(
        find.byType(SpecialtiesSection),
      );
      expect(section.editMode, isTrue);
      section.onReorder!(0, 1);

      expect(homeBloc.added, [const HomeSpecialtiesReordered(0, 1)]);
    });

    testWidgets('the toggle switches to records', (tester) async {
      await pump(tester, _loaded());

      await tester.tap(find.byType(HomeOverviewToggle));
      await tester.pump();

      expect(homeBloc.added, [
        const HomeOverviewViewModeChanged(OverviewViewMode.resources),
      ]);
    });

    testWidgets('in edit mode the Specialty filter saves the chosen '
        'specialties', (tester) async {
      final state = _loaded();
      await pump(tester, state, editMode: true);

      expect(find.text(_en.records), findsNothing);
      await tester.tap(find.text(_en.specialty));
      await settleDialog(tester);
      expect(find.byType(AppDialog), findsOne);

      await tester.tap(find.text(_en.save));
      await settleDialog(tester);

      expect(homeBloc.added, [
        HomeSpecialtiesFiltersChanged(state.selectedSpecialties),
      ]);
    });

    testWidgets('the info icon explains the overview section', (tester) async {
      await pump(tester, _loaded());

      await tester.tap(infoIcon(1));
      await tester.pumpAndSettle();

      final modal = tester.widget<SectionInfoModal>(
        find.byType(SectionInfoModal),
      );
      expect(modal.title, _en.overview);
      expect(find.text(_en.longPressToReorder), findsOne);
    });
  });

  group('overview: records', () {
    testWidgets('shows only the record types the person chose', (
      tester,
    ) async {
      await pump(
        tester,
        _loaded(
          mode: OverviewViewMode.resources,
          selectedRecordTypes: const {
            HomeRecordsCategory.allergies: false,
            HomeRecordsCategory.medications: true,
          },
        ),
      );

      expect(find.byType(SpecialtiesSection), findsNothing);
      expect(find.text(_medications), findsOne);
      expect(find.text(_allergies), findsNothing);
      expect(find.byKey(highlight.firstOverviewCardKey), findsOne);
    });

    testWidgets('a records card clears the specialty and filters Records to '
        'its types for this visit, then opens Records', (tester) async {
      await pump(tester, _loaded(mode: OverviewViewMode.resources));

      await tester.tap(find.text(_allergies));
      await tester.pumpAndSettle();

      expect(recordsBloc.added, [
        const RecordsSpecialtyApplied([], remember: false),
        RecordsFiltersApplied(
          HomeRecordsCategory.allergies.resourceTypes,
          remember: false,
        ),
      ]);
      expect(homeBloc.added, isEmpty);
      expect(pageController.page, 1);
    });

    testWidgets('long-pressing a records card turns edit mode on', (
      tester,
    ) async {
      await pump(tester, _loaded(mode: OverviewViewMode.resources));

      await tester.longPress(find.text(_medications));
      await tester.pump();

      expect(homeBloc.added, [const HomeEditModeChanged(true)]);
      expect(recordsBloc.added, isEmpty);
    });

    testWidgets('a reordered records card is passed to Home', (tester) async {
      await pump(
        tester,
        _loaded(mode: OverviewViewMode.resources),
        editMode: true,
      );

      final section = tester.widget<MedicalRecordsSection>(
        find.byType(MedicalRecordsSection),
      );
      expect(section.editMode, isTrue);
      section.onReorder!(1, 0);

      expect(homeBloc.added, [const HomeRecordsReordered(1, 0)]);
    });

    testWidgets('the toggle switches back to specialties', (tester) async {
      await pump(tester, _loaded(mode: OverviewViewMode.resources));

      await tester.tap(find.byType(HomeOverviewToggle));
      await tester.pump();

      expect(homeBloc.added, [
        const HomeOverviewViewModeChanged(OverviewViewMode.specialties),
      ]);
    });

    testWidgets('in edit mode the Records filter saves the chosen record '
        'types', (tester) async {
      final state = _loaded(mode: OverviewViewMode.resources);
      await pump(tester, state, editMode: true);

      expect(find.text(_en.specialty), findsNothing);
      await tester.tap(find.text(_en.records));
      await settleDialog(tester);
      expect(find.byType(AppDialog), findsOne);

      await tester.tap(find.text(_en.save));
      await settleDialog(tester);

      expect(homeBloc.added, [
        HomeRecordsFiltersChanged(state.selectedRecordTypes),
      ]);
    });
  });

  group('sources', () {
    SourceSelectorWidget selector(WidgetTester tester) =>
        tester.widget<SourceSelectorWidget>(find.byType(SourceSelectorWidget));

    testWidgets("the selector gets Home's sources and selection", (
      tester,
    ) async {
      final state = _loaded().copyWith(selectedSource: 'lab');
      await pump(tester, state);

      final widget = selector(tester);
      expect(widget.sources, _sources);
      expect(widget.selectedSource, 'lab');
      expect(widget.holderSourceIds, isNull);
      expect(widget.holderName, isNull);
      expect(widget.currentPatient, isNull);
    });

    testWidgets('edit mode hides the source selector', (tester) async {
      await pump(tester, _loaded(), editMode: true);

      expect(find.byType(SourceSelectorWidget), findsNothing);
    });

    testWidgets('picking a source tells Home', (tester) async {
      await pump(tester, _loaded());

      await tester.tap(find.byType(SourceSelectorWidget));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lab Results').last);
      await tester.pumpAndSettle();

      expect(homeBloc.added, [const HomeSourceChanged('lab')]);
    });

    testWidgets('a renamed source is passed to Home, a cleared name as empty', (
      tester,
    ) async {
      await pump(tester, _loaded());

      selector(
        tester,
      ).onSourceLabelEdit!(const Source(id: 'lab', labelSource: 'Synevo'));
      selector(tester).onSourceLabelEdit!(const Source(id: 'clinic'));

      expect(homeBloc.added, [
        const HomeSourceLabelUpdated('lab', 'Synevo'),
        const HomeSourceLabelUpdated('clinic', ''),
      ]);
    });

    testWidgets('a deleted source is passed to Home', (tester) async {
      await pump(tester, _loaded());

      selector(tester).onSourceDelete!(_sources.last);

      expect(homeBloc.added, [const HomeSourceDeleted('lab')]);
    });
  });

  group('recent records', () {
    testWidgets('tapping a record opens its details', (tester) async {
      await pump(tester, _loaded());

      await tester.tap(find.text(_condition.displayTitle));
      await tester.pump();

      final route = router.pushed.single;
      expect(route.routeName, RecordDetailsRoute.name);
      expect((route.args! as RecordDetailsRouteArgs).resource, _condition);
    });

    testWidgets('View all opens Records without filtering it', (
      tester,
    ) async {
      await pump(tester, _loaded());

      await tester.tap(find.text(_en.viewAll));
      await tester.pumpAndSettle();

      expect(pageController.page, 1);
      expect(recordsBloc.added, isEmpty);
      expect(homeBloc.added, isEmpty);
    });

    // RecentRecordsSection shows no View all of its own today; the
    // dashboard still hands it one that opens Records.
    testWidgets("the section's own View all opens Records too", (
      tester,
    ) async {
      await pump(tester, _loaded());

      final section = tester.widget<RecentRecordsSection>(
        find.byType(RecentRecordsSection),
      );
      expect(section.recentRecords, [_condition]);
      section.onViewAll!();
      await tester.pumpAndSettle();

      expect(pageController.page, 1);
      expect(recordsBloc.added, isEmpty);
    });
  });

  group('a Home card names the person shown', () {
    const jane = Holder(
      id: 'jane',
      representativePatient: Patient(id: 'jane', sourceId: 'wallet-jane'),
      sourceIds: ['wallet-jane'],
      allPatientInstances: [Patient(id: 'jane', sourceId: 'wallet-jane')],
    );
    HomeState shownFor(OverviewViewMode mode) => _loaded(
      mode: mode,
    ).copyWith(scope: const HolderScope(holder: jane, loaded: true));

    testWidgets('a specialty card', (tester) async {
      await pump(tester, shownFor(OverviewViewMode.specialties));

      await tester.tap(find.text(_dental));
      await tester.pumpAndSettle();

      expect(recordsBloc.added, [
        const RecordsSpecialtyApplied(
          [MedicalSpecialty.dental],
          remember: false,
          personId: 'jane',
        ),
      ]);
    });

    testWidgets('a records card', (tester) async {
      await pump(tester, shownFor(OverviewViewMode.resources));

      await tester.tap(find.text(_allergies));
      await tester.pumpAndSettle();

      expect(recordsBloc.added, [
        const RecordsSpecialtyApplied([], remember: false, personId: 'jane'),
        RecordsFiltersApplied(
          HomeRecordsCategory.allergies.resourceTypes,
          remember: false,
          personId: 'jane',
        ),
      ]);
    });
  });
}
