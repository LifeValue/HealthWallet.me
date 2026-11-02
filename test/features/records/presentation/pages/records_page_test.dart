import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/presentation/bloc/attachment_browse_bloc.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/pages/records_page.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_view_toggle.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';
import '../../../../helpers/log_capture.dart';

class _MockHomeBloc extends MockBloc<HomeEvent, HomeState>
    implements HomeBloc {}

class _MockRecordsBloc extends MockBloc<RecordsEvent, RecordsState>
    implements RecordsBloc {}

class _MockAttachmentBrowseBloc
    extends MockBloc<AttachmentBrowseEvent, AttachmentBrowseState>
    implements AttachmentBrowseBloc {}

class _MockSyncBloc extends MockBloc<SyncEvent, SyncState>
    implements SyncBloc {}

class _MockLwwSyncBloc extends MockBloc<LwwSyncEvent, LwwSyncState>
    implements LwwSyncBloc {}

class _MockUserBloc extends MockBloc<UserEvent, UserState>
    implements UserBloc {}

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

  @override
  Future<List<IFhirResource>> getRelatedResourcesForEncounter({
    required String encounterId,
    String? sourceId,
  }) async {
    if (fails) throw StateError('database closed');
    return related;
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

const _imagePickerChannel = MethodChannel('plugins.flutter.io/image_picker');

void main() {
  setUpAll(initializeDateFormatting);

  final l10n = lookupAppLocalizations(const Locale('en'));
  final logs = captureLogs();
  late FilePickerPlatform realFilePicker;
  late _MockProcessingBloc processingBloc;
  late PageViewNavigationController nav;

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
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      SharedPrefsConstants.recordsViewMode: viewMode.name,
    });
    final prefs = await SharedPreferences.getInstance();
    await getIt.reset();

    final browseBloc = _MockAttachmentBrowseBloc();
    whenListen(
      browseBloc,
      const Stream<AttachmentBrowseState>.empty(),
      initialState: browseState,
    );
    final lwwSyncBloc = _MockLwwSyncBloc();
    whenListen(
      lwwSyncBloc,
      const Stream<LwwSyncState>.empty(),
      initialState: const LwwSyncState(),
    );
    nav = PageViewNavigationController();
    getIt
      ..registerSingleton<SharedPreferences>(prefs)
      ..registerSingleton<AppPlatform>(AppPlatform.mobile)
      ..registerSingleton<PageViewNavigationController>(nav)
      ..registerSingleton<LwwSyncBloc>(lwwSyncBloc)
      ..registerFactory<AttachmentBrowseBloc>(() => browseBloc)
      ..registerSingleton<RecordsRepository>(
        repository ?? _FakeRecordsRepository(),
      );

    final homeBloc = _MockHomeBloc();
    whenListen(
      homeBloc,
      const Stream<HomeState>.empty(),
      // Records on the home page show the import actions on the empty list.
      initialState: HomeState(recentRecords: [weight('obs-home', 70, 'kg')]),
    );
    final recordsBloc = _MockRecordsBloc();
    whenListen(
      recordsBloc,
      const Stream<RecordsState>.empty(),
      initialState: const RecordsState(status: RecordsStatus.success()),
    );
    final syncBloc = _MockSyncBloc();
    whenListen(
      syncBloc,
      const Stream<SyncState>.empty(),
      initialState: const SyncState(),
    );
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
    final userBloc = _MockUserBloc();
    whenListen(
      userBloc,
      const Stream<UserState>.empty(),
      initialState: UserState(regionPreset: region),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<HomeBloc>.value(value: homeBloc),
            BlocProvider<RecordsBloc>.value(value: recordsBloc),
            BlocProvider<SyncBloc>.value(value: syncBloc),
            BlocProvider<ProcessingBloc>.value(value: processingBloc),
            BlocProvider<UserBloc>.value(value: userBloc),
            BlocProvider<PatientBloc>.value(value: patientBloc),
          ],
          child: const RecordsPage(),
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
  });
}
