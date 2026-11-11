import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/dashboard_tab.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/presentation/bloc/attachment_browse_bloc.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/pages/records_attachments_body.dart';
import 'package:health_wallet/features/records/presentation/pages/records_page.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_active_filters_bar.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_view_toggle.dart';
import 'package:health_wallet/features/records/presentation/widgets/vision_prescription_table.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/user/domain/entity/user.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:intl/date_symbol_data_local.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';
import '../../../../helpers/log_capture.dart';

class _MockHomeBloc extends MockBloc<HomeEvent, HomeState>
    implements HomeBloc {}

/// Keeps what the page asks of the records.
class _MockRecordsBloc extends MockBloc<RecordsEvent, RecordsState>
    implements RecordsBloc {
  final added = <RecordsEvent>[];

  @override
  void add(RecordsEvent event) => added.add(event);
}

/// Keeps what the page asks of the attachments.
class _MockAttachmentBrowseBloc
    extends MockBloc<AttachmentBrowseEvent, AttachmentBrowseState>
    implements AttachmentBrowseBloc {
  final added = <AttachmentBrowseEvent>[];

  @override
  void add(AttachmentBrowseEvent event) => added.add(event);
}

class _MockSyncBloc extends MockBloc<SyncEvent, SyncState>
    implements SyncBloc {}

class _MockLwwSyncBloc extends MockBloc<LwwSyncEvent, LwwSyncState>
    implements LwwSyncBloc {}

class _MockUserBloc extends MockBloc<UserEvent, UserState> implements UserBloc {
  final added = <UserEvent>[];

  @override
  void add(UserEvent event) => added.add(event);
}

/// Keeps the documents the page hands over for processing.
class _MockPatientBloc extends MockBloc<PatientEvent, PatientState>
    implements PatientBloc {}

class _MockProcessingBloc extends MockBloc<ProcessingEvent, ProcessingState>
    implements ProcessingBloc {
  final added = <ProcessingEvent>[];

  @override
  void add(ProcessingEvent event) => added.add(event);
}

/// Answers the desktop details panel's question for related records.
class _FakeRecordsRepository extends Fake implements RecordsRepository {
  _FakeRecordsRepository({this.related = const [], this.fails = false});

  final List<IFhirResource> related;
  final bool fails;
  final encounterRequests = <String>[];

  @override
  Future<List<IFhirResource>> getRelatedResourcesForEncounter({
    required String encounterId,
    String? sourceId,
  }) async {
    encounterRequests.add(encounterId);
    if (fails) throw StateError('database closed');
    return related;
  }
}

/// Keeps the pages the records page opens.
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

/// A file picker that fails the way a denied or broken picker does.
class _FailingFilePicker extends FilePickerPlatform {
  var calls = 0;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    calls++;
    throw PlatformException(code: 'unknown_path', message: 'no access');
  }
}

/// A file picker that hands back the given file, as if the user chose it.
class _PickingFilePicker extends _FailingFilePicker {
  _PickingFilePicker(this.path);

  final String path;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    calls++;
    return [_PickedFile('report.pdf', Uri.file(path))];
  }
}

/// A picked file at [uri].
final class _PickedFile extends PlatformFile {
  _PickedFile(this.name, this.uri);

  @override
  final String name;

  @override
  final Uri uri;

  @override
  XFile get xFile => XFile(uri.toString());

  @override
  int? lengthSync() => null;

  @override
  Future<int?> length() async => null;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);

  @override
  Stream<Uint8List> readAsByteStream() => const Stream.empty();
}

const _imagePickerChannel = MethodChannel('plugins.flutter.io/image_picker');
const _permissionChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);

const _jane = Holder(
  id: 'jane',
  representativePatient: Patient(id: 'jane', sourceId: 'wallet-jane'),
  sourceIds: ['epic', 'wallet-jane'],
  allPatientInstances: [
    Patient(id: 'jane', sourceId: 'wallet-jane'),
    Patient(id: 'p1', sourceId: 'epic'),
  ],
);

const _tom = Holder(
  id: 'tom',
  representativePatient: Patient(id: 'tom', sourceId: 'wallet-tom'),
  sourceIds: ['wallet-tom'],
  allPatientInstances: [Patient(id: 'tom', sourceId: 'wallet-tom')],
);

/// [holder] selected in a wallet with Jane and Tom.
HolderScope _scopeOf(Holder holder, {String? sourceFilter}) => HolderScope(
  directory: const HolderDirectory(holders: [_jane, _tom]),
  holder: holder,
  sourceFilter: sourceFilter,
  loaded: true,
);

/// The records of [personId] from [sourceIds], or [sourceId] alone.
Matcher _sourceChanged({
  String? sourceId,
  List<String>? sourceIds,
  String? personId,
}) => isA<RecordsSourceChanged>()
    .having((e) => e.sourceId, 'sourceId', sourceId)
    .having((e) => e.sourceIds, 'sourceIds', sourceIds)
    .having((e) => e.personId, 'personId', personId);

/// The attachments of [sourceIds] (or [sourceId]) of [resourceTypes], for
/// [specialty] if one is chosen.
Matcher _browseOpened({
  String? sourceId,
  List<String>? sourceIds,
  List<FhirType> resourceTypes = const [],
  MedicalSpecialty? specialty,
}) => isA<AttachmentBrowseInitialised>()
    .having((e) => e.sourceId, 'sourceId', sourceId)
    .having((e) => e.sourceIds, 'sourceIds', sourceIds)
    .having((e) => e.resourceTypes, 'resourceTypes', resourceTypes)
    .having((e) => e.specialty, 'specialty', specialty);

/// The icon drawn from [icon].
Finder _icon(SvgGenImage icon) => find.byWidgetPredicate(
  (w) =>
      w is SvgPicture &&
      w.bytesLoader is SvgAssetLoader &&
      (w.bytesLoader as SvgAssetLoader).assetName == icon.path,
);

void main() {
  setUpAll(initializeDateFormatting);

  final l10n = lookupAppLocalizations(const Locale('en'));
  final logs = captureLogs();
  late FilePickerPlatform realFilePicker;
  late _MockProcessingBloc processingBloc;
  late _MockRecordsBloc recordsBloc;
  late _MockAttachmentBrowseBloc browseBloc;
  late _MockUserBloc userBloc;
  late _FakeStackRouter router;
  late PageViewNavigationController nav;
  late SharedPreferences prefs;
  late StreamController<HomeState> homeStates;
  late StreamController<RecordsState> recordsStates;
  late StreamController<SyncState> syncStates;
  late StreamController<LwwSyncState> lwwStates;
  late StreamController<AttachmentBrowseState> browseStates;

  setUp(() => realFilePicker = FilePickerPlatform.instance);

  tearDown(() => FilePickerPlatform.instance = realFilePicker);
  // After the last page is unmounted: its dispose reads getIt.
  tearDownAll(getIt.reset);

  /// A weight observation saved from a provider, recorded in an encounter.
  IFhirResource weight(String id, num value, String unit) =>
      IFhirResource.fromLocalDto(
        FhirResourceLocalDto(
          id: id,
          resourceId: id,
          resourceType: 'Observation',
          sourceId: 'src-1',
          encounterId: 'enc-1',
          title: '',
          resourceRaw: jsonEncode(
            observationJson(
              id: id,
              code: '29463-7',
              codeDisplay: 'Body Weight',
              value: {'valueQuantity': quantity(value, unit: unit)},
            ),
          ),
        ),
      );

  /// Opens the records page.
  Future<void> pumpPage(
    WidgetTester tester, {
    required Size screen,
    RecordsViewMode viewMode = RecordsViewMode.attachments,
    AttachmentBrowseState browseState = const AttachmentBrowseState(),
    RecordsRepository? repository,
    RegionPreset region = RegionPreset.europe,
    AppPlatform platform = AppPlatform.mobile,
    RecordsState recordsState = const RecordsState(
      status: RecordsStatus.success(),
    ),
    HolderScope scope = const HolderScope(),
    User user = const User(),
    List<FhirType>? initFilters,
    bool onRecordsPage = false,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      SharedPrefsConstants.recordsViewMode: viewMode.name,
    });
    prefs = await SharedPreferences.getInstance();
    await getIt.reset();

    homeStates = StreamController.broadcast();
    recordsStates = StreamController.broadcast();
    syncStates = StreamController.broadcast();
    lwwStates = StreamController.broadcast();
    browseStates = StreamController.broadcast();
    addTearDown(() async {
      await homeStates.close();
      await recordsStates.close();
      await syncStates.close();
      await lwwStates.close();
      await browseStates.close();
    });

    browseBloc = _MockAttachmentBrowseBloc();
    whenListen(browseBloc, browseStates.stream, initialState: browseState);
    final lwwSyncBloc = _MockLwwSyncBloc();
    whenListen(
      lwwSyncBloc,
      lwwStates.stream,
      initialState: const LwwSyncState(),
    );
    nav = PageViewNavigationController();
    // The dashboard is showing the Records page.
    if (onRecordsPage) nav.currentPageNotifier.value = 1;
    getIt
      ..registerSingleton<SharedPreferences>(prefs)
      ..registerSingleton<AppPlatform>(platform)
      ..registerSingleton<PageViewNavigationController>(nav)
      ..registerSingleton<LwwSyncBloc>(lwwSyncBloc)
      ..registerFactory<AttachmentBrowseBloc>(() => browseBloc)
      ..registerSingleton<RecordsRepository>(
        repository ?? _FakeRecordsRepository(),
      );

    final homeBloc = _MockHomeBloc();
    whenListen(
      homeBloc,
      homeStates.stream,
      // Records on the home page show the import actions on the empty list.
      initialState: HomeState(
        recentRecords: [weight('obs-home', 70, 'kg')],
        scope: scope,
      ),
    );
    recordsBloc = _MockRecordsBloc();
    whenListen(recordsBloc, recordsStates.stream, initialState: recordsState);
    final syncBloc = _MockSyncBloc();
    whenListen(syncBloc, syncStates.stream, initialState: const SyncState());
    processingBloc = _MockProcessingBloc();
    whenListen(
      processingBloc,
      const Stream<ProcessingState>.empty(),
      initialState: const ProcessingState(),
    );
    final patientBloc = _MockPatientBloc();
    whenListen(
      patientBloc,
      const Stream<PatientState>.empty(),
      initialState: const PatientState(),
    );
    userBloc = _MockUserBloc();
    whenListen(
      userBloc,
      const Stream<UserState>.empty(),
      initialState: UserState(regionPreset: region, user: user),
    );
    router = _FakeStackRouter();

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
              BlocProvider<SyncBloc>.value(value: syncBloc),
              BlocProvider<ProcessingBloc>.value(value: processingBloc),
              BlocProvider<UserBloc>.value(value: userBloc),
              BlocProvider<PatientBloc>.value(value: patientBloc),
            ],
            child: Stack(
              children: [
                // The dashboard's pages, so the page can move between them.
                Offstage(
                  child: PageView(
                    controller: nav.pageController,
                    children: List.filled(4, const SizedBox()),
                  ),
                ),
                RecordsPage(initFilters: initFilters),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Lets the snackbar slide in.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
  }

  group('importing from the empty records list', () {
    Future<void> openList(WidgetTester tester) => pumpPage(
      tester,
      screen: const Size(390, 844),
      viewMode: RecordsViewMode.recordsList,
    );

    testWidgets('a file picker that fails says the files could not be '
        'opened, and nothing is imported', (tester) async {
      final picker = _FailingFilePicker();
      FilePickerPlatform.instance = picker;
      await openList(tester);

      await tester.tap(find.text(l10n.importDocument));
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester);

      expect(picker.calls, 1);
      expect(find.widgetWithText(SnackBar, l10n.importFilesFailed), findsOne);
      expect(
        logs,
        contains(
          isA<LogEvent>()
              .having((e) => e.level, 'level', Level.error)
              .having(
                (e) => '${e.message}',
                'message',
                contains('Could not import the picked documents'),
              ),
        ),
      );
      expect(processingBloc.added, isEmpty);
      expect(nav.targetPage, isNull, reason: 'stays on the records page');
    });

    testWidgets('a gallery that fails says the same, and nothing is '
        'imported', (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      var calls = 0;
      messenger.setMockMethodCallHandler(_imagePickerChannel, (call) async {
        calls++;
        throw PlatformException(code: 'photo_access_denied');
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(_imagePickerChannel, null),
      );
      await openList(tester);

      await tester.tap(find.text(l10n.pickImageFromGallery));
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester);

      expect(calls, 1);
      expect(find.widgetWithText(SnackBar, l10n.importFilesFailed), findsOne);
      expect(
        logs,
        contains(
          isA<LogEvent>()
              .having((e) => e.level, 'level', Level.error)
              .having(
                (e) => '${e.message}',
                'message',
                contains('Could not import the picked images'),
              ),
        ),
      );
      expect(processingBloc.added, isEmpty);
    });
  });

  group('the empty records list on each platform', () {
    late String picked;

    setUp(() {
      final dir = Directory.systemTemp.createTempSync('records_import');
      addTearDown(() => dir.deleteSync(recursive: true));
      picked = (File('${dir.path}/report.pdf')..writeAsStringSync('%PDF')).path;
    });

    Future<void> openList(WidgetTester tester, AppPlatform platform) =>
        pumpPage(
          tester,
          screen: platform.isDesktop
              ? const Size(1440, 900)
              : const Size(390, 844),
          viewMode: RecordsViewMode.recordsList,
          platform: platform,
        );

    /// Picks [picked] through Import Document; the file check is real I/O.
    Future<void> importDocument(WidgetTester tester) async {
      FilePickerPlatform.instance = _PickingFilePicker(picked);
      await tester.runAsync(() async {
        await tester.tap(find.text(l10n.importDocument));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await settle(tester);
      expect(find.text(l10n.importFilesFailed), findsNothing);
    }

    testWidgets('the phone offers import, gallery and scan', (tester) async {
      await openList(tester, AppPlatform.mobile);

      expect(find.text(l10n.importDocument), findsOne);
      expect(find.text(l10n.pickImageFromGallery), findsOne);
      expect(find.text(l10n.scanDocument), findsOne);
    });

    testWidgets('the desktop has no scanner, so Scan is not offered', (
      tester,
    ) async {
      await openList(tester, AppPlatform.desktop);

      expect(find.text(l10n.importDocument), findsOne);
      expect(find.text(l10n.pickImageFromGallery), findsOne);
      expect(find.text(l10n.scanDocument), findsNothing);
    });

    testWidgets('on the phone, an imported document opens the Import page', (
      tester,
    ) async {
      await openList(tester, AppPlatform.mobile);
      await importDocument(tester);

      expect(
        processingBloc.added.single,
        isA<DocumentImported>().having((e) => e.filePaths, 'paths', [picked]),
      );
      expect(nav.currentPage, DashboardTab.import(isDesktop: false));
      expect(nav.currentPage, 3);
    });

    testWidgets('on the desktop, an imported document opens the Import page, '
        'not the handover page after it', (tester) async {
      await openList(tester, AppPlatform.desktop);
      await importDocument(tester);

      expect(processingBloc.added.single, isA<DocumentImported>());
      expect(nav.currentPage, DashboardTab.import(isDesktop: true));
      expect(nav.currentPage, 2);
    });

    testWidgets('on the phone, images picked from the gallery are imported, '
        'leaving out any that are gone, and open the Import page', (
      tester,
    ) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        _imagePickerChannel,
        (call) async => [picked, '${File(picked).parent.path}/gone.jpg'],
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(_imagePickerChannel, null),
      );
      await openList(tester, AppPlatform.mobile);

      await tester.runAsync(() async {
        await tester.tap(find.text(l10n.pickImageFromGallery));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await settle(tester);

      expect(
        processingBloc.added.single,
        isA<DocumentImported>().having((e) => e.filePaths, 'paths', [picked]),
      );
      expect(nav.currentPage, DashboardTab.import(isDesktop: false));
      expect(find.text(l10n.importFilesFailed), findsNothing);
    });

    testWidgets('images that are gone by the time they are picked import '
        'nothing', (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        _imagePickerChannel,
        (call) async => ['${File(picked).parent.path}/gone.jpg'],
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(_imagePickerChannel, null),
      );
      await openList(tester, AppPlatform.mobile);

      await tester.runAsync(() async {
        await tester.tap(find.text(l10n.pickImageFromGallery));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await settle(tester);

      expect(processingBloc.added, isEmpty);
      expect(nav.targetPage, isNull, reason: 'stays on the records page');
    });

    /// Taps Scan, with the camera [allowed] or not when asked.
    Future<void> scan(WidgetTester tester, {required bool allowed}) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        _permissionChannel,
        // The plugin answers 1 for granted, 0 for denied.
        (call) async => {Permission.camera.value: allowed ? 1 : 0},
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(_permissionChannel, null),
      );
      await openList(tester, AppPlatform.mobile);

      await tester.tap(find.text(l10n.scanDocument));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('Scan opens the Scan page and starts the camera once it is '
        'allowed', (tester) async {
      await scan(tester, allowed: true);

      expect(nav.currentPage, DashboardTab.scan);
      expect(processingBloc.added, [const CaptureButtonPressed()]);
    });

    testWidgets('Scan without the camera allowed opens the Scan page but '
        'does not start the camera', (tester) async {
      await scan(tester, allowed: false);

      expect(nav.currentPage, DashboardTab.scan);
      expect(processingBloc.added, isEmpty);
    });
  });

  group('the desktop details panel', () {
    const desktop = Size(1440, 900);
    // Still loading the list, so only the panel shows the selected record.
    AttachmentBrowseState selected(IFhirResource record) =>
        AttachmentBrowseState(
          selectedDetail: AttachmentBrowseDetail(record: record),
        );

    testWidgets('shows the record\'s values in the user\'s region and its '
        'related records', (tester) async {
      await pumpPage(
        tester,
        screen: desktop,
        browseState: selected(weight('obs-1', 70, 'kg')),
        repository: _FakeRecordsRepository(
          related: [
            const Encounter(id: 'enc-1', title: 'Annual check-up'),
            weight('obs-2', 70, 'kg'),
          ],
        ),
        region: RegionPreset.us,
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.recordDetails), findsOne);
      expect(find.text(l10n.encounterDetails), findsOne);
      expect(find.text(l10n.relatedResources), findsOne);
      // The record's card and the related weight.
      expect(find.text('Value: 154.32 lbs'), findsNWidgets(2));
      expect(find.textContaining(' kg'), findsNothing);
    });

    testWidgets('when the related records cannot be loaded, shows the record '
        'alone and logs why', (tester) async {
      await pumpPage(
        tester,
        screen: desktop,
        browseState: selected(weight('obs-1', 200, 'lbs')),
        repository: _FakeRecordsRepository(fails: true),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Value: 90.72 kg'), findsOne);
      expect(find.text(l10n.relatedResources), findsNothing);
      expect(
        logs,
        loggedWarning('Could not load the resources related to obs-1'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('with nothing selected, asks to select a record; selecting '
        'one shows its details', (tester) async {
      await pumpPage(tester, screen: desktop);

      expect(find.text(l10n.selectRecordToViewDetails), findsOne);
      expect(find.text(l10n.recordDetails), findsNothing);

      browseStates.add(selected(weight('obs-1', 70, 'kg')));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.selectRecordToViewDetails), findsNothing);
      expect(find.text(l10n.recordDetails), findsOne);
      expect(find.textContaining('Value: 70'), findsOne);
    });

    testWidgets('keeps the selected record, without reading its related '
        'records again, while the attachments reload', (tester) async {
      final repository = _FakeRecordsRepository();
      final state = selected(weight('obs-1', 70, 'kg'));
      await pumpPage(
        tester,
        screen: desktop,
        browseState: state,
        repository: repository,
      );
      await tester.pump();
      await tester.pump();
      expect(repository.encounterRequests, ['enc-1']);

      browseStates.add(state.copyWith(status: AttachmentBrowseStatus.success));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.recordDetails), findsOne);
      expect(repository.encounterRequests, ['enc-1']);
    });

    testWidgets('a selected encounter lists the records made in it, without '
        'an encounter section of its own', (tester) async {
      final repository = _FakeRecordsRepository(
        related: [
          const Encounter(id: 'enc-9', resourceId: 'enc-9', title: 'Visit'),
          weight('obs-2', 70, 'kg'),
        ],
      );
      await pumpPage(
        tester,
        screen: desktop,
        browseState: selected(
          const Encounter(id: 'enc-9', resourceId: 'enc-9', title: 'Visit'),
        ),
        repository: repository,
      );
      await tester.pump();
      await tester.pump();

      expect(repository.encounterRequests, ['enc-9']);
      expect(find.text(l10n.relatedResources), findsOne);
      expect(find.text(l10n.encounterDetails), findsNothing);
    });

    testWidgets('a selected vision prescription shows its per-eye table', (
      tester,
    ) async {
      await pumpPage(
        tester,
        screen: desktop,
        browseState: selected(entityFromJson(visionPrescriptionJson())),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(VisionPrescriptionTable), findsOne);
    });

    testWidgets('can be dragged wider or narrower, between 280 and 800 '
        'pixels', (tester) async {
      await pumpPage(tester, screen: desktop);
      double panelWidth() =>
          desktop.width -
          tester.getSize(find.byKey(const ValueKey('attachments_body'))).width;
      // Inside the panel: the parts of the handles left of it take no taps.
      final edge = find.byWidgetPredicate(
        (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
      );
      final knob = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onHorizontalDragEnd != null,
      );
      expect(panelWidth(), 400);

      await tester.dragFrom(
        tester.getCenter(edge) + const Offset(2, 0),
        const Offset(-150, 0),
      );
      await tester.pump();
      expect(panelWidth(), greaterThan(400));
      expect(panelWidth(), lessThanOrEqualTo(550));

      await tester.dragFrom(
        tester.getCenter(knob) + const Offset(9, 0),
        const Offset(1000, 0),
      );
      await tester.pump();
      expect(panelWidth(), 280);

      await tester.dragFrom(
        tester.getCenter(edge) + const Offset(2, 0),
        const Offset(-1000, 0),
      );
      await tester.pump();
      expect(panelWidth(), 800);
    });
  });

  group('whose records the page shows', () {
    const phone = Size(390, 844);

    testWidgets('opening the page asks for the selected person\'s records '
        'with their id, so their own saved filters apply', (tester) async {
      await pumpPage(tester, screen: phone, scope: _scopeOf(_jane));

      expect(
        recordsBloc.added.first,
        _sourceChanged(sourceIds: ['epic', 'wallet-jane'], personId: 'jane'),
      );
      expect(
        browseBloc.added.whereType<AttachmentBrowseInitialised>().single,
        _browseOpened(sourceIds: ['epic', 'wallet-jane']),
      );
    });

    testWidgets('a chosen source narrows the records to that source, still '
        'for the same person', (tester) async {
      await pumpPage(
        tester,
        screen: phone,
        scope: _scopeOf(_jane, sourceFilter: 'epic'),
      );

      expect(
        recordsBloc.added.first,
        _sourceChanged(sourceId: 'epic', sourceIds: ['epic'], personId: 'jane'),
      );
    });

    testWidgets('before the people are read, no one\'s records are asked for '
        'and no person id is sent', (tester) async {
      await pumpPage(tester, screen: phone);

      expect(
        recordsBloc.added.first,
        _sourceChanged(sourceIds: const [], personId: null),
      );
    });

    testWidgets('choosing another person asks for their records with their '
        'id, and leaves the attachments to follow the records', (
      tester,
    ) async {
      await pumpPage(tester, screen: phone, scope: _scopeOf(_jane));
      recordsBloc.added.clear();
      browseBloc.added.clear();

      homeStates.add(HomeState(scope: _scopeOf(_tom)));
      await tester.pump();

      expect(recordsBloc.added, [
        _sourceChanged(sourceIds: ['wallet-tom'], personId: 'tom'),
      ]);
      expect(browseBloc.added, isEmpty);
    });

    testWidgets('opened with record types, applies them and shows those '
        'attachments', (tester) async {
      await pumpPage(
        tester,
        screen: phone,
        scope: _scopeOf(_jane),
        initFilters: [FhirType.Observation],
      );

      expect(
        recordsBloc.added.whereType<RecordsFiltersApplied>().single.filters,
        [FhirType.Observation],
      );
      expect(
        browseBloc.added.whereType<AttachmentBrowseInitialised>().single,
        _browseOpened(
          sourceIds: ['epic', 'wallet-jane'],
          resourceTypes: [FhirType.Observation],
        ),
      );
    });

    testWidgets('otherwise the attachments open with the record types already '
        'chosen', (tester) async {
      await pumpPage(
        tester,
        screen: phone,
        recordsState: const RecordsState(
          status: RecordsStatus.success(),
          activeFilters: [FhirType.Observation],
        ),
      );

      expect(
        browseBloc.added.whereType<AttachmentBrowseInitialised>().single,
        _browseOpened(
          sourceIds: const [],
          resourceTypes: [FhirType.Observation],
        ),
      );
      expect(recordsBloc.added.whereType<RecordsFiltersApplied>(), isEmpty);
    });

    testWidgets('with a specialty chosen too, the attachments open for that '
        'specialty within the chosen record types', (tester) async {
      await pumpPage(
        tester,
        screen: phone,
        recordsState: const RecordsState(
          status: RecordsStatus.success(),
          activeFilters: [FhirType.Observation],
          activeSpecialties: [MedicalSpecialty.cardiology],
        ),
      );

      expect(
        browseBloc.added.whereType<AttachmentBrowseInitialised>().single,
        _browseOpened(
          sourceIds: const [],
          resourceTypes: [FhirType.Observation],
          specialty: MedicalSpecialty.cardiology,
        ),
      );
    });
  });

  group('reading the records again', () {
    const phone = Size(390, 844);
    const filtered = RecordsState(
      status: RecordsStatus.success(),
      activeFilters: [FhirType.Encounter],
    );

    Future<void> open(WidgetTester tester) async {
      await pumpPage(
        tester,
        screen: phone,
        scope: _scopeOf(_jane),
        recordsState: filtered,
      );
      recordsBloc.added.clear();
      browseBloc.added.clear();
    }

    final reloaded = [
      _sourceChanged(sourceIds: ['epic', 'wallet-jane'], personId: 'jane'),
    ];
    final browseReloaded = [
      _browseOpened(
        sourceIds: ['epic', 'wallet-jane'],
        resourceTypes: [FhirType.Encounter],
      ),
    ];

    testWidgets('synced records reload the list and the attachments with the '
        'person\'s filters', (tester) async {
      await open(tester);

      syncStates.add(const SyncState(hasSyncedData: true));
      await tester.pump();

      expect(recordsBloc.added, reloaded);
      expect(browseBloc.added, browseReloaded);
    });

    testWidgets('loaded demo records reload them too', (tester) async {
      await open(tester);

      syncStates.add(const SyncState(hasDemoData: true));
      await tester.pump();

      expect(recordsBloc.added, reloaded);
      expect(browseBloc.added, browseReloaded);
    });

    testWidgets('a finished sync with nothing in the wallet reloads nothing', (
      tester,
    ) async {
      await open(tester);

      syncStates.add(const SyncState(syncStatus: SyncStatus.synced));
      await tester.pump();

      expect(recordsBloc.added, isEmpty);
      expect(browseBloc.added, isEmpty);
    });

    testWidgets('records arriving from the paired device reload both views', (
      tester,
    ) async {
      await open(tester);

      lwwStates.add(const LwwSyncState(recordsVersion: 1));
      await tester.pump();

      expect(recordsBloc.added, reloaded);
      expect(browseBloc.added, browseReloaded);
    });

    testWidgets('after a delete, the attachments are read again with the '
        'current filters', (tester) async {
      await open(tester);

      recordsStates.add(
        filtered.copyWith(status: const RecordsStatus.deleted()),
      );
      await tester.pump();

      expect(browseBloc.added, browseReloaded);
      expect(recordsBloc.added, isEmpty);
    });

    testWidgets('a new scope, filter or specialty in the records reloads the '
        'attachments to match', (tester) async {
      await open(tester);

      recordsStates.add(
        filtered.copyWith(
          sourceIds: ['epic'],
          activeFilters: [FhirType.Observation],
          activeSpecialties: [MedicalSpecialty.cardiology],
        ),
      );
      await tester.pump();

      expect(browseBloc.added, [
        _browseOpened(
          sourceIds: ['epic'],
          resourceTypes: [FhirType.Observation],
          specialty: MedicalSpecialty.cardiology,
        ),
      ]);
    });

    testWidgets('a new date range reloads the attachments; a new search alone '
        'does not', (tester) async {
      await open(tester);

      recordsStates.add(filtered.copyWith(searchQuery: 'weight'));
      await tester.pump();
      expect(browseBloc.added, isEmpty);

      recordsStates.add(
        filtered.copyWith(dateFilter: const DateFilter(fromYear: 2024)),
      );
      await tester.pump();
      expect(browseBloc.added, [
        _browseOpened(resourceTypes: [FhirType.Encounter]),
      ]);
    });
  });

  group('switching between attachments and the records list', () {
    const phone = Size(390, 844);

    testWidgets('switching to the list remembers it and lets the dashboard '
        'swipe again', (tester) async {
      await pumpPage(tester, screen: phone, onRecordsPage: true);
      expect(
        nav.swipeEnabledNotifier.value,
        isFalse,
        reason: 'attachments scroll sideways, so the dashboard holds still',
      );

      await tester.tap(find.byType(RecordsViewToggle));
      await tester.pump();

      expect(
        prefs.getString(SharedPrefsConstants.recordsViewMode),
        RecordsViewMode.recordsList.name,
      );
      expect(nav.swipeEnabledNotifier.value, isTrue);
      expect(find.byKey(const ValueKey('records_body')), findsOne);
    });

    testWidgets('switching back to attachments remembers it, holds the '
        'dashboard still and reads the attachments with the current filters', (
      tester,
    ) async {
      await pumpPage(
        tester,
        screen: phone,
        viewMode: RecordsViewMode.recordsList,
        onRecordsPage: true,
        recordsState: const RecordsState(
          status: RecordsStatus.success(),
          activeFilters: [FhirType.Observation],
        ),
      );
      expect(nav.swipeEnabledNotifier.value, isTrue);
      browseBloc.added.clear();

      await tester.tap(find.byType(RecordsViewToggle));
      await tester.pump();

      expect(
        prefs.getString(SharedPrefsConstants.recordsViewMode),
        RecordsViewMode.attachments.name,
      );
      expect(nav.swipeEnabledNotifier.value, isFalse);
      expect(find.byKey(const ValueKey('attachments_body')), findsOne);
      expect(browseBloc.added, [
        _browseOpened(
          sourceIds: const [],
          resourceTypes: [FhirType.Observation],
        ),
      ]);
    });

    testWidgets('the attachments asking for attachments again reads them '
        'again with the current filters', (tester) async {
      await pumpPage(
        tester,
        screen: phone,
        recordsState: const RecordsState(
          status: RecordsStatus.success(),
          activeFilters: [FhirType.Observation],
        ),
      );
      browseBloc.added.clear();

      tester
          .widget<RecordsAttachmentsBody>(find.byType(RecordsAttachmentsBody))
          .onViewModeChanged(RecordsViewMode.attachments);
      await tester.pump();

      expect(browseBloc.added, [
        _browseOpened(
          sourceIds: const [],
          resourceTypes: [FhirType.Observation],
        ),
      ]);
      expect(find.byKey(const ValueKey('attachments_body')), findsOne);
    });
  });

  group('leaving the Records page', () {
    const phone = Size(390, 844);

    testWidgets('moving to another dashboard page ends the visit once, so '
        'filters a Home card set give way to the person\'s own', (
      tester,
    ) async {
      await pumpPage(tester, screen: phone, onRecordsPage: true);

      nav.currentPageNotifier.value = 0;
      nav.currentPageNotifier.value = 2;

      expect(recordsBloc.added.whereType<RecordsVisitEnded>(), hasLength(1));
      expect(nav.swipeEnabledNotifier.value, isTrue);
    });

    testWidgets('moving between other pages without visiting Records ends '
        'nothing', (tester) async {
      await pumpPage(tester, screen: phone);

      nav.currentPageNotifier.value = 2;
      nav.currentPageNotifier.value = 0;

      expect(recordsBloc.added.whereType<RecordsVisitEnded>(), isEmpty);
    });

    testWidgets('switching views while on Records does not end the visit', (
      tester,
    ) async {
      await pumpPage(tester, screen: phone, onRecordsPage: true);

      await tester.tap(find.byType(RecordsViewToggle));
      await tester.pump();

      expect(recordsBloc.added.whereType<RecordsVisitEnded>(), isEmpty);
    });
  });

  group('the filter sheet', () {
    // Wide enough for the sheet's buttons in the test font.
    const tablet = Size(800, 1000);
    const chosen = RecordsState(
      status: RecordsStatus.success(),
      activeFilters: [FhirType.Observation],
      activeSpecialties: [MedicalSpecialty.cardiology],
    );

    Future<void> applySheet(WidgetTester tester) async {
      await tester.tap(_icon(Assets.icons.filter));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(l10n.applyFilters), findsOne);

      await tester.tap(find.text(l10n.applyFilters));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    void expectApplied() {
      final filters = recordsBloc.added.whereType<RecordsFiltersApplied>();
      expect(filters.single.filters, [FhirType.Observation]);
      expect(filters.single.dateFilter, isNull);
      expect(
        recordsBloc.added.whereType<RecordsSpecialtyApplied>().single,
        const RecordsSpecialtyApplied([MedicalSpecialty.cardiology]),
      );
      expect(find.text(l10n.applyFilters), findsNothing);
    }

    testWidgets('over the attachments, applies the record types, date range '
        'and specialties chosen in it', (tester) async {
      await pumpPage(tester, screen: tablet, recordsState: chosen);

      await applySheet(tester);

      expectApplied();
    });

    testWidgets('over the records list, does the same', (tester) async {
      await pumpPage(
        tester,
        screen: tablet,
        viewMode: RecordsViewMode.recordsList,
        recordsState: chosen,
      );

      await applySheet(tester);

      expectApplied();
    });
  });

  group('choosing and sharing records on the phone', () {
    const phone = Size(390, 844);
    final first = weight('obs-1', 70, 'kg');
    final second = weight('obs-2', 71, 'kg');

    RecordsState choosing(
      Set<String> selected, {
      List<FhirType> filters = const [],
    }) => RecordsState(
      status: const RecordsStatus.success(),
      isSelectionMode: true,
      selectedResourceIds: selected,
      resources: [first, second],
      activeFilters: filters,
    );

    Finder shareButton() => find.ancestor(
      of: _icon(Assets.icons.shareNearby),
      matching: find.byType(IconButton),
    );

    testWidgets('Select starts choosing records', (tester) async {
      await pumpPage(tester, screen: phone);
      expect(find.text(l10n.noRecordsSelected), findsOne);

      await tester.tap(find.text(l10n.select));

      expect(recordsBloc.added.last, const RecordsSelectionModeToggled());
    });

    testWidgets('while choosing, the title counts the chosen records and '
        'Cancel stops choosing', (tester) async {
      await pumpPage(
        tester,
        screen: phone,
        recordsState: choosing({'obs-1', 'obs-2'}),
      );

      expect(find.text(l10n.recordsSelectedCount(2)), findsOne);
      expect(find.text(l10n.select), findsNothing);

      await tester.tap(find.text(l10n.cancel));

      expect(recordsBloc.added.last, const RecordsSelectionModeToggled());
    });

    testWidgets('Share with nothing chosen explains that records must be '
        'chosen first, until the tip is tapped', (tester) async {
      await pumpPage(tester, screen: phone);

      await tester.tap(shareButton());
      await tester.pump();

      expect(find.text(l10n.selectRecordsBeforeSharing), findsOne);
      expect(router.pushed, isEmpty);
      expect(userBloc.added, isEmpty);

      await tester.tap(find.text(l10n.selectRecordsBeforeSharing));
      await tester.pump();

      expect(find.text(l10n.selectRecordsBeforeSharing), findsNothing);
    });

    // The test host is a computer, where sharing needs no permission.
    testWidgets('sharing the chosen records turns receive mode on and opens '
        'the share page with them and the record types filtered on', (
      tester,
    ) async {
      await pumpPage(
        tester,
        screen: phone,
        recordsState: choosing({'obs-2'}, filters: [FhirType.Observation]),
      );

      await tester.tap(shareButton());
      await tester.pump();

      expect(userBloc.added, [const UserReceiveModeToggled(true)]);
      final args = router.pushed.single.args as ShareRecordsSendRouteArgs;
      expect(router.pushed.single.routeName, ShareRecordsSendRoute.name);
      expect(args.preSelectedResources, [second]);
      expect(args.appliedFilters, [FhirType.Observation]);
    });

    testWidgets('with receive mode already on and no record types filtered '
        'on, sharing just opens the share page', (tester) async {
      await pumpPage(
        tester,
        screen: phone,
        recordsState: choosing({'obs-1', 'obs-2'}),
        user: const User(isReceiveModeEnabled: true),
      );

      await tester.tap(shareButton());
      await tester.pump();

      expect(userBloc.added, isEmpty);
      final args = router.pushed.single.args as ShareRecordsSendRouteArgs;
      expect(args.preSelectedResources, [first, second]);
      expect(args.appliedFilters, isNull);
    });
  });

  group('the records list', () {
    const phone = Size(390, 844);
    final many = [for (var i = 0; i < 40; i++) weight('obs-$i', 70, 'kg')];

    Future<void> openList(
      WidgetTester tester, {
      bool hasMorePages = false,
    }) => pumpPage(
      tester,
      screen: phone,
      viewMode: RecordsViewMode.recordsList,
      recordsState: RecordsState(
        status: const RecordsStatus.success(),
        resources: many,
        hasMorePages: hasMorePages,
      ),
    );

    ScrollPosition listPosition(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

    /// Scrolls to the end of the list.
    Future<void> scrollToEnd(WidgetTester tester) async {
      await tester.drag(find.byType(ListView), const Offset(0, -100000));
      await tester.pump();
    }

    testWidgets('while the records load, shows a spinner', (tester) async {
      await pumpPage(
        tester,
        screen: phone,
        viewMode: RecordsViewMode.recordsList,
        recordsState: const RecordsState(status: RecordsStatus.loading()),
      );

      expect(find.byType(CircularProgressIndicator), findsOne);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('scrolling down shows a button that brings the list back to '
        'the top', (tester) async {
      await openList(tester);
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();
      // Lets the button grow in.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(FloatingActionButton), findsOne);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(listPosition(tester).pixels, 0);
      // Lets the button shrink away.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('reaching the end asks for the next page once, after the '
        'scrolling has rested', (tester) async {
      await openList(tester, hasMorePages: true);

      await scrollToEnd(tester);
      await scrollToEnd(tester);
      expect(recordsBloc.added.whereType<RecordsLoadMore>(), isEmpty);

      // Long enough for the list to spring back from the end and rest.
      await tester.pump(const Duration(seconds: 2));
      expect(recordsBloc.added.whereType<RecordsLoadMore>(), hasLength(1));
    });

    testWidgets('a page already loading is not asked for again', (
      tester,
    ) async {
      await openList(tester, hasMorePages: true);

      await scrollToEnd(tester);
      recordsStates.add(
        RecordsState(
          status: const RecordsStatus.loading(),
          resources: many,
          hasMorePages: true,
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(recordsBloc.added.whereType<RecordsLoadMore>(), isEmpty);
    });

    testWidgets('with no more pages, reaching the end asks for nothing', (
      tester,
    ) async {
      await openList(tester);

      await scrollToEnd(tester);
      await tester.pump(const Duration(seconds: 2));

      expect(recordsBloc.added.whereType<RecordsLoadMore>(), isEmpty);
    });

    testWidgets('records that arrive while the list is open are shown', (
      tester,
    ) async {
      final first = weight('obs-a', 70, 'kg');
      await pumpPage(
        tester,
        screen: phone,
        viewMode: RecordsViewMode.recordsList,
        recordsState: RecordsState(
          status: const RecordsStatus.success(),
          resources: [first],
        ),
      );
      Finder entry(String id, int index) =>
          find.byKey(ValueKey('timeline-${FhirType.Observation}-$id-$index'));
      expect(entry('obs-a', 0), findsOne);

      recordsStates.add(
        RecordsState(
          status: const RecordsStatus.success(),
          resources: [first, weight('obs-b', 71, 'kg')],
        ),
      );
      await tester.pump();

      expect(entry('obs-a', 0), findsOne);
      expect(entry('obs-b', 1), findsOne);
    });

    testWidgets('record types filtered on later show above the list', (
      tester,
    ) async {
      await openList(tester);

      recordsStates.add(
        RecordsState(
          status: const RecordsStatus.success(),
          resources: many,
          activeFilters: [FhirType.Observation],
        ),
      );
      await tester.pump();

      expect(
        tester
            .widget<RecordsActiveFiltersBar>(
              find.byType(RecordsActiveFiltersBar),
            )
            .activeFilters,
        [FhirType.Observation],
      );
    });

    testWidgets('tapping outside the search field closes it', (tester) async {
      await openList(tester);
      await tester.tap(_icon(Assets.icons.search));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(TextField), findsOne);

      await tester.tap(find.text(l10n.noRecordsSelected));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TextField), findsNothing);
    });
  });
}
