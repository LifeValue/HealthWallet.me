import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:flutter/widgets.dart' hide Notification;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/processing/domain/deep_scan_defaults.dart';
import 'package:health_wallet/features/processing/domain/entity/extraction_output_mode.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_observation.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_vision_prescription.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extraction_service.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extractor_registry.dart';
import 'package:health_wallet/features/processing/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fake_device_capability_service.dart';
import '../../../../helpers/log_capture.dart';

final _en = lookupAppLocalizations(const Locale('en'));

/// What the step-one and step-two calls were given.
typedef _AiCall = ({
  List<String> input,
  int? maxTokens,
  ExtractionOutputMode outputMode,
  String? documentCategory,
  bool? useVision,
});

class _FakeProcessingRepository extends Fake implements ProcessingRepository {
  final edited = <ProcessingSession>[];
  final basicInfoCalls = <_AiCall>[];
  final containerOnlyCalls = <_AiCall>[];
  final remainingCalls = <_AiCall>[];
  int disposes = 0;
  bool cancelRequested = false;
  bool modelExists = false;
  MappingPatient extractedPatient = const MappingPatient(
    id: 'p-draft',
    givenName: MappedProperty(value: 'Ana'),
    familyName: MappedProperty(value: 'Pop'),
  );
  MappingResource container = const MappingEncounter(
    id: 'enc-draft',
    encounterType: MappedProperty(value: 'Checkup'),
  );
  Exception? basicInfoError;

  /// Holds the step-one AI call until completed, when set.
  Completer<void>? basicInfoGate;

  /// The step-two stream, fed by each test.
  // ignore: close_sinks, closed in the test's tearDown.
  final remaining = StreamController<MappingResourcesWithProgress>();

  @override
  bool get shouldCancelGeneration => cancelRequested;

  @override
  Future<int> editProcessingSession(ProcessingSession session) async {
    edited.add(session);
    return 1;
  }

  @override
  Future<void> disposeModel() async => disposes++;

  int cancels = 0;

  /// Holds [waitForStreamCompletion] until completed, when set.
  Completer<void>? stopGate;

  Exception? cancelError;

  @override
  Future<void> cancelGeneration() async {
    cancels++;
    if (cancelError != null) throw cancelError!;
  }

  @override
  Future<void> waitForStreamCompletion() async => stopGate?.future;

  @override
  Future<bool> checkModelExistence() async => modelExists;

  @override
  Future<MappingResource> mapContainerOnly(
    String ocrText, {
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
    ExtractionOutputMode outputMode = ExtractionOutputMode.defaultMode,
  }) async {
    containerOnlyCalls.add((
      input: [ocrText],
      maxTokens: maxTokens,
      outputMode: outputMode,
      documentCategory: null,
      useVision: null,
    ));
    await containerGate?.future;
    return container;
  }

  /// Holds the container-only AI call until completed, when set.
  Completer<void>? containerGate;

  @override
  Future<(MappingPatient, MappingResource)> mapBasicInfo(
    List<String> imagePaths, {
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
    ExtractionOutputMode outputMode = ExtractionOutputMode.defaultMode,
  }) async {
    basicInfoCalls.add((
      input: imagePaths,
      maxTokens: maxTokens,
      outputMode: outputMode,
      documentCategory: null,
      useVision: null,
    ));
    await basicInfoGate?.future;
    if (basicInfoError != null) throw basicInfoError!;
    return (extractedPatient, container);
  }

  @override
  Stream<MappingResourcesWithProgress> mapRemainingResources(
    List<String> imagePaths, {
    String? documentCategory,
    bool useVision = false,
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
    ExtractionOutputMode outputMode = ExtractionOutputMode.defaultMode,
  }) {
    remainingCalls.add((
      input: imagePaths,
      maxTokens: maxTokens,
      outputMode: outputMode,
      documentCategory: documentCategory,
      useVision: useVision,
    ));
    return remaining.stream;
  }
}

class _FakeOcrProcessingHelper extends Fake implements OcrProcessingHelper {
  String text = 'Discharge letter';

  /// Hold the OCR and the page preparation until completed, when set.
  Completer<void>? ocrGate;
  Completer<void>? prepareGate;

  @override
  Future<String> processOcrForImages(List<String> imagePaths) async {
    await ocrGate?.future;
    return text;
  }

  @override
  Future<List<String>> prepareAllImages({
    required List<String> filePaths,
    double dpi = 72,
  }) async {
    await prepareGate?.future;
    return filePaths;
  }

  @override
  Future<Map<String, String>> prepareOcrPages({
    required String sessionId,
    required List<String> filePaths,
    required List<String> previewPaths,
  }) async => const {};

  final discarded = <String>[];

  @override
  Future<void> discardOcrPages({
    required String sessionId,
    Iterable<String> ocrPages = const [],
  }) async => discarded.add(sessionId);
}

class _FakeRecordsRepository extends Fake implements RecordsRepository {
  List<IFhirResource> patients = const [];
  Exception? error;

  /// Holds the holder lookups until completed, when set.
  Completer<void>? gate;

  @override
  Future<List<IFhirResource>> getResources({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 20,
    int offset = 0,
    DateFilter? dateFilter,
  }) async {
    if (error != null) throw error!;
    return patients;
  }
}

/// The people in the wallet are the Patient rows of [records], one each.
class _FakeHolderService extends Fake implements HolderService {
  _FakeHolderService(this.records);

  final _FakeRecordsRepository records;
  Patient? match;
  final candidates = <List<Patient>>[];
  final wallets = <String>[];
  final linked = <({String patientId, MappingPatient? scanned})>[];

  static String holderOf(String patientId) => 'holder-$patientId';

  var loads = 0;

  /// Holds the loads after the first (the OCR pre-match's) until completed,
  /// when set.
  Completer<void>? laterLoadGate;

  @override
  Future<HolderDirectory> load() async {
    loads++;
    await records.gate?.future;
    if (loads > 1) await laterLoadGate?.future;
    if (records.error != null) throw records.error!;
    return HolderDirectory(
      holders: [
        for (final p in records.patients.whereType<Patient>())
          Holder(
            id: holderOf(p.id),
            representativePatient: p,
            sourceIds: [p.sourceId],
            allPatientInstances: [p],
          ),
      ],
    );
  }

  @override
  Holder? matchScanned(MappingPatient scanned, HolderDirectory directory) {
    candidates.add([
      for (final h in directory.holders) h.representativePatient,
    ]);
    final found = match;
    return found == null
        ? null
        : Holder(
            id: holderOf(found.id),
            representativePatient: found,
            sourceIds: [found.sourceId],
            allPatientInstances: [found],
          );
  }

  @override
  bool isUnnamed(Holder holder) => false;

  @override
  Future<Source> walletSourceOf(String holderId) async {
    wallets.add(holderId);
    return Source(id: 'wallet-$holderId', holderId: holderId);
  }

  @override
  Future<({Patient patient, String holderId})> walletPatientOf(
    String patientId, {
    MappingPatient? scanned,
  }) async {
    linked.add((patientId: patientId, scanned: scanned));
    return (
      patient: Patient(id: patientId, sourceId: 'wallet-$patientId'),
      holderId: holderOf(patientId),
    );
  }
}

class _FakeHolderSelection extends Fake implements HolderSelection {
  final selected = <String>[];

  @override
  Future<void> select(String holderId) async => selected.add(holderId);
}

class _FakeSyncRepository extends Fake implements SyncRepository {
  final saved = <List<IFhirResource>>[];

  @override
  Future<List<Source>> getSources() async => const [];

  @override
  Future<void> saveResources(List<IFhirResource> resources) async {
    saved.add(List.of(resources));
  }
}

typedef _DocumentsCall = ({
  String sessionId,
  List<String> filePaths,
  String patientId,
  Encounter? encounter,
  String sourceId,
  String? title,
});

class _FakeDocumentReferenceService extends Fake
    implements DocumentReferenceService {
  final calls = <_DocumentsCall>[];
  Exception? error;

  @override
  Future<List<String>> replaceSessionDocuments({
    required String sessionId,
    required List<String> filePaths,
    required String patientId,
    Encounter? encounter,
    required String sourceId,
    String? title,
  }) async {
    if (error != null) throw error!;
    calls.add((
      sessionId: sessionId,
      filePaths: filePaths,
      patientId: patientId,
      encounter: encounter,
      sourceId: sourceId,
      title: title,
    ));
    return const [];
  }
}

Patient _patient(String id, {String? identifier, String title = ''}) => Patient(
  id: id,
  sourceId: 'src-$id',
  title: title,
  identifier: identifier == null
      ? null
      : [fhir_r4.Identifier(value: fhir_r4.FhirString(identifier))],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final logs = captureLogs();

  final isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  late _FakeProcessingRepository repository;
  late _FakeOcrProcessingHelper ocr;
  late _FakeRecordsRepository records;
  late _FakeHolderService holders;
  late _FakeSyncRepository sync;
  late _FakeHolderSelection selection;
  late _FakeDocumentReferenceService documents;
  late SharedPreferences prefs;
  late ProcessingBloc bloc;
  late FakeDeviceCapabilityService capability;
  late List<ProcessingState> states;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = _FakeProcessingRepository();
    ocr = _FakeOcrProcessingHelper();
    records = _FakeRecordsRepository();
    sync = _FakeSyncRepository();
    holders = _FakeHolderService(records);
    selection = _FakeHolderSelection();
    documents = _FakeDocumentReferenceService();
    capability = FakeDeviceCapabilityService();
    bloc = ProcessingBloc(
      repository,
      ocr,
      sync,
      documents,
      holders,
      selection,
      records,
      prefs,
      AppStringsProvider.forLocale(const Locale('en')),
      LayoutExtractionService(
        repository,
        ocr,
        LayoutExtractorRegistry(const []),
        holders,
        records,
      ),
      capability,
    );
    states = [];
    final subscription = bloc.stream.listen(states.add);
    addTearDown(subscription.cancel);
  });

  tearDown(() async {
    // Not awaited: the close of a stream nobody listened to never completes.
    unawaited(repository.remaining.close());
    await bloc.close();
  });

  // Seeding the state directly starts a step without running the steps
  // before it.
  void seed(ProcessingState state) {
    // ignore: invalid_use_of_visible_for_testing_member
    bloc.emit(state);
  }

  Future<void> settle() => pumpEventQueue();

  ProcessingSession session(String id) =>
      bloc.state.sessions.firstWhere((s) => s.id == id);

  String? routeSessionId(PageRouteInfo? route) =>
      (route as ProcessingRoute?)?.args?.sessionId;

  group('step one', () {
    const pending = ProcessingSession(id: 's', filePaths: ['/p.jpg']);
    const withPages = ProcessingState(
      sessions: [pending],
      sessionImagePaths: {
        's': ['/p.jpg'],
      },
    );

    test('an unknown session is ignored', () async {
      bloc.add(const MappingInitiated(sessionId: 'x'));
      await settle();

      expect(states, isEmpty);
      expect(repository.basicInfoCalls, isEmpty);
    });

    test('a draft or a session past step one is not mapped again', () async {
      for (final status in [
        ProcessingStatus.draft,
        ProcessingStatus.patientExtracted,
      ]) {
        seed(
          ProcessingState(
            sessions: [pending.copyWith(status: status)],
            sessionImagePaths: withPages.sessionImagePaths,
          ),
        );
        bloc.add(const MappingInitiated(sessionId: 's'));
        await settle();

        expect(bloc.state.status, const PipelineStatus.initial());
        expect(session('s').status, status);
      }
      expect(repository.basicInfoCalls, isEmpty);
    });

    test('waits while another session is processing', () async {
      seed(
        withPages.copyWith(
          sessions: [
            pending,
            const ProcessingSession(
              id: 'busy',
              status: ProcessingStatus.processing,
            ),
          ],
        ),
      );

      bloc.add(const MappingInitiated(sessionId: 's'));
      await settle();

      expect(bloc.state.status, const PipelineStatus.loading());
      expect(session('s').status, ProcessingStatus.pending);
      expect(repository.basicInfoCalls, isEmpty);
    });

    test('a document whose text is only whitespace becomes a draft', () async {
      ocr.text = '  \n\t ';
      seed(withPages);

      bloc.add(const MappingInitiated(sessionId: 's'));
      await settle();

      expect(session('s').status, ProcessingStatus.draft);
      expect(repository.basicInfoCalls, isEmpty);
    });

    test('a new patient is staged as a draft with the encounter, saved, and '
        'announced', () async {
      seed(withPages);

      bloc.add(const MappingInitiated(sessionId: 's'));
      await settle();

      expect(
        states.map((s) => s.sessions.firstOrNull?.status),
        contains(ProcessingStatus.processingPatient),
      );
      final staged = session('s');
      expect(staged.status, ProcessingStatus.patientExtracted);
      expect(staged.patient.mode, ImportMode.createNew);
      expect(staged.patient.draft, repository.extractedPatient);
      expect(staged.encounter.draft, repository.container);
      expect(staged.isDiagnosticReportContainer, isFalse);
      expect(repository.edited.last.status, ProcessingStatus.patientExtracted);
      expect(repository.basicInfoCalls.single.input, ['/p.jpg']);

      final notification = bloc.state.notification!;
      expect(
        notification.text,
        _en.processingPatientInfoExtracted(_en.processingOriginScan),
      );
      expect(routeSessionId(notification.route), 's');
    });

    test('a known patient is linked and a report container is staged as '
        'the report', () async {
      final known = _patient('p-known', title: 'Ana Pop');
      records.patients = [known];
      holders.match = known;
      repository.container = const MappingDiagnosticReport(
        id: 'rep',
        reportName: MappedProperty(value: 'CBC'),
      );
      seed(withPages);

      bloc.add(const MappingInitiated(sessionId: 's'));
      await settle();

      final staged = session('s');
      expect(staged.patient.mode, ImportMode.linkExisting);
      expect(staged.patient.existing, known);
      expect(staged.patient.draft, isNull);
      expect(staged.diagnosticReport?.draft, repository.container);
      expect(staged.isDiagnosticReportContainer, isTrue);
      expect(holders.candidates.single, [known]);
    });

    test('the saved AI settings are passed on, except the load settings on '
        'a desktop', () async {
      await prefs.setInt(SharedPrefsConstants.aiMaxTokens, 1234);
      await prefs.setString(SharedPrefsConstants.aiOutputMode, 'grammar');
      seed(withPages);

      bloc.add(const MappingInitiated(sessionId: 's'));
      await settle();

      final call = repository.basicInfoCalls.single;
      expect(call.outputMode, ExtractionOutputMode.grammar);
      expect(call.maxTokens, isDesktop ? isNull : 1234);
    });

    test('a cancelled generation is not announced', () async {
      repository.cancelRequested = true;
      seed(withPages);

      bloc.add(const MappingInitiated(sessionId: 's'));
      await settle();

      expect(session('s').status, ProcessingStatus.patientExtracted);
      expect(bloc.state.notification, isNull);
    });

    test('the next queued session is opened when step one ends', () async {
      seed(
        withPages.copyWith(
          sessions: [
            pending,
            const ProcessingSession(id: 'q', filePaths: ['/q.jpg']),
          ],
        ),
      );

      bloc.add(const MappingInitiated(sessionId: 's'));
      await settle();

      expect(session('s').status, ProcessingStatus.patientExtracted);
      expect(bloc.state.displayedSessionId, 'q');
      expect(bloc.state.sessionImagePaths['q'], ['/q.jpg']);
      // No AI model in this test, so the queued session stops there.
      expect(
        (bloc.state.status as Failure).reason,
        PipelineFailureReason.modelNotFound,
      );
    });

    test('a damaged model fails as modelCorrupted and requeues the '
        'session', () async {
      repository.basicInfoError = Exception(
        'Model file is corrupted. Please re-download.',
      );
      seed(withPages);

      bloc.add(const MappingInitiated(sessionId: 's'));
      await settle();

      final failure = bloc.state.status as Failure;
      expect(failure.reason, PipelineFailureReason.modelCorrupted);
      expect(failure.error, contains('corrupted'));
      expect(session('s').status, ProcessingStatus.pending);
      expect(repository.edited.last.status, ProcessingStatus.pending);
      expect(logs, loggedWarning('patient extraction failed'));
    });

    test('a step-one prompt that is too long is a capacity failure', () async {
      repository.basicInfoError = Exception('Prompt too long for context');
      seed(withPages);

      bloc.add(const MappingInitiated(sessionId: 's'));
      await settle();

      expect(
        bloc.state.status,
        const PipelineStatus.capacityFailure(sessionId: 's'),
      );
      expect(session('s').status, ProcessingStatus.pending);
    });

    test('a handover whose patient step failed is not reopened when the next '
        'session ends', () async {
      repository.basicInfoError = Exception('decode error');
      seed(
        const ProcessingState(
          sessions: [
            ProcessingSession(
              id: 'h',
              filePaths: ['/h.jpg'],
              origin: ProcessingOrigin.handover,
            ),
            ProcessingSession(id: 'q', filePaths: ['/q.jpg']),
          ],
          sessionImagePaths: {
            'h': ['/h.jpg'],
            'q': ['/q.jpg'],
          },
        ),
      );

      bloc.add(const MappingInitiated(sessionId: 'h'));
      await settle();
      expect(session('h').status, ProcessingStatus.pending);
      expect((bloc.state.status as Failure).sessionId, 'h');

      repository.basicInfoError = null;
      bloc.add(const MappingInitiated(sessionId: 'q'));
      await settle();

      expect(session('q').status, ProcessingStatus.patientExtracted);
      // The handover waits for the user to retry it.
      expect(session('h').status, ProcessingStatus.pending);
      expect(bloc.state.displayedSessionId, isNull);
      expect(repository.basicInfoCalls.map((c) => c.input), [
        ['/h.jpg'],
        ['/q.jpg'],
      ]);
    });

    test('a session removed while its patient is read is neither staged nor '
        'announced', () async {
      repository.basicInfoGate = Completer<void>();
      seed(withPages);
      bloc.add(const MappingInitiated(sessionId: 's'));
      await settle();
      expect(session('s').status, ProcessingStatus.processingPatient);

      // The session is gone (cleared) before the AI answers.
      seed(const ProcessingState());
      repository.basicInfoGate!.complete();
      await settle();

      expect(bloc.state.sessions, isEmpty);
      expect(bloc.state.notification, isNull);
      expect(repository.edited, isEmpty);
    });

    test('a document without a patient opens the review with an empty new '
        'patient, matched to nobody', () async {
      repository.extractedPatient = const MappingPatient(
        id: 'p-none',
        dateOfBirth: MappedProperty(value: '1980-01-01'),
      );
      holders.match = _patient('p-known');
      seed(withPages);

      bloc.add(const MappingInitiated(sessionId: 's'));
      await settle();

      final staged = session('s');
      expect(staged.status, ProcessingStatus.patientExtracted);
      expect(staged.patient.draft?.id, 'p-none');
      expect(staged.patient.existing, isNull);
      expect(staged.patient.mode, ImportMode.createNew);
      expect(holders.candidates, isEmpty);
      expect(bloc.state.status, isNot(isA<Failure>()));
    });

    test('a session removed while its patient is matched is neither staged '
        'nor announced', () async {
      final lookup = Completer<void>();
      holders.laterLoadGate = lookup;
      seed(withPages);
      bloc.add(const MappingInitiated(sessionId: 's'));
      await settle();
      expect(repository.basicInfoCalls, hasLength(1));

      seed(const ProcessingState());
      lookup.complete();
      await settle();

      expect(bloc.state.notification, isNull);
      expect(repository.edited, isEmpty);
    });

    test('a cancel while the AI reads the patient stages nothing when the AI '
        'returns', () async {
      repository.basicInfoGate = Completer<void>();
      seed(withPages);
      bloc.add(const MappingInitiated(sessionId: 's'));
      await settle();
      expect(session('s').status, ProcessingStatus.processingPatient);

      bloc.add(const MappingCancelled(sessionId: 's'));
      await settle();
      expect(repository.cancels, 1);
      repository.basicInfoGate!.complete();
      await settle();

      expect(session('s').status, ProcessingStatus.cancelled);
      expect(session('s').patient.hasSelection, isFalse);
      expect(bloc.state.notification, isNull);
      expect(
        repository.edited.map((s) => s.status),
        isNot(contains(ProcessingStatus.patientExtracted)),
      );
    });

    test('a cancel while the page is read does not start the AI', () async {
      ocr.ocrGate = Completer<void>();
      seed(withPages);
      bloc.add(const MappingInitiated(sessionId: 's'));
      await settle();

      bloc.add(const MappingCancelled(sessionId: 's'));
      await settle();
      ocr.ocrGate!.complete();
      await settle();

      expect(session('s').status, ProcessingStatus.cancelled);
      expect(repository.basicInfoCalls, isEmpty);
      expect(repository.containerOnlyCalls, isEmpty);
    });

    group('OCR pre-match', () {
      Future<void> run() async {
        seed(withPages);
        bloc.add(const MappingInitiated(sessionId: 's'));
        await settle();
      }

      test('an identifier printed on the page links the patient and maps '
          'only the encounter', () async {
        final known = _patient('p-known', identifier: '1850101123456');
        records.patients = [known];
        ocr.text = 'Patient: Ana Pop CNP: 1850101123456';

        await run();

        expect(repository.basicInfoCalls, isEmpty);
        expect(repository.containerOnlyCalls.single.input, [ocr.text]);
        final staged = session('s');
        expect(staged.status, ProcessingStatus.patientExtracted);
        expect(staged.patient.existing, known);
        expect(staged.patient.mode, ImportMode.linkExisting);
        expect(staged.encounter.draft, repository.container);
        expect(repository.edited.last.patient.existing, known);
        final notification = bloc.state.notification!;
        expect(
          notification.text,
          _en.processingPatientMatched(_en.processingOriginScan),
        );
        expect(routeSessionId(notification.route), 's');
      });

      test('the identifier matches by its digits when the page drops the '
          'dashes', () async {
        final known = _patient('p-known', identifier: '185-0101-123456');
        records.patients = [known];
        ocr.text = 'CNP 1850101123456';

        await run();

        expect(session('s').patient.existing, known);
        expect(repository.basicInfoCalls, isEmpty);
      });

      test('a long identifier matches without its last digit', () async {
        final known = _patient('p-known', identifier: '18501011234567');
        records.patients = [known];
        ocr.text = 'CNP 1850101123456?';

        await run();

        expect(session('s').patient.existing, known);
      });

      test('a report container is staged as the report, and a cancelled '
          'generation is not announced', () async {
        records.patients = [_patient('p-known', identifier: 'MRN-99881')];
        ocr.text = 'MRN-99881 Hemoleucograma';
        repository.container = const MappingDiagnosticReport(id: 'rep');
        repository.cancelRequested = true;

        await run();

        final staged = session('s');
        expect(staged.diagnosticReport?.draft, repository.container);
        expect(staged.encounter.draft, isNull);
        expect(bloc.state.notification, isNull);
      });

      test('a cancel while the container is read stages nothing', () async {
        final known = _patient('p-known', identifier: '1850101123456');
        records.patients = [known];
        ocr.text = 'Patient: Ana Pop CNP: 1850101123456';
        repository.containerGate = Completer<void>();

        await run();
        expect(repository.containerOnlyCalls, hasLength(1));
        bloc.add(const MappingCancelled(sessionId: 's'));
        await settle();
        repository.containerGate!.complete();
        await settle();

        expect(session('s').status, ProcessingStatus.cancelled);
        expect(session('s').patient.hasSelection, isFalse);
        expect(bloc.state.notification, isNull);
      });

      test('a cancel while the identifiers are matched does not start the '
          'AI', () async {
        records.patients = [_patient('p-known', identifier: '1850101123456')];
        ocr.text = 'Patient: Ana Pop CNP: 1850101123456';
        final lookup = Completer<void>();
        records.gate = lookup;

        await run();
        bloc.add(const MappingCancelled(sessionId: 's'));
        await settle();
        lookup.complete();
        await settle();

        expect(session('s').status, ProcessingStatus.cancelled);
        expect(repository.containerOnlyCalls, isEmpty);
        expect(repository.basicInfoCalls, isEmpty);
      });

      test('short, missing or unmatched identifiers fall back to the AI '
          'patient step', () async {
        records.patients = [
          _patient('no-id'),
          _patient('short', identifier: 'A12'),
          _patient('few-digits', identifier: 'ABCDE-12'),
          _patient('other', identifier: '9999999999'),
        ];
        ocr.text = 'Patient A12 ABCDE 12 1234567';

        await run();

        expect(repository.containerOnlyCalls, isEmpty);
        expect(repository.basicInfoCalls, hasLength(1));
        expect(holders.candidates.single, hasLength(4));
        expect(session('s').patient.mode, ImportMode.createNew);
      });

      test('a failed patient lookup is logged and the AI patient is staged '
          'as new', () async {
        records.error = Exception('db closed');

        await run();

        expect(logs, loggedWarning('OCR patient pre-match failed'));
        expect(logs, loggedWarning('Error matching patient'));
        expect(repository.basicInfoCalls, hasLength(1));
        expect(holders.candidates, isEmpty);
        final staged = session('s');
        expect(staged.patient.mode, ImportMode.createNew);
        expect(staged.patient.draft, repository.extractedPatient);
      });
    });
  });

  group('step two', () {
    const kept = MappingObservation(
      id: 'kept',
      observationName: MappedProperty(value: 'Glucose'),
    );
    const first = MappingObservation(
      id: 'first',
      observationName: MappedProperty(value: 'Sodium'),
    );
    const second = MappingObservation(
      id: 'second',
      observationName: MappedProperty(value: 'Potassium'),
    );
    const extracted = ProcessingSession(
      id: 's',
      filePaths: ['/p.jpg'],
      status: ProcessingStatus.patientExtracted,
      origin: ProcessingOrigin.import,
      resources: [kept],
    );
    ProcessingState withPages(ProcessingSession s) => ProcessingState(
      sessions: [s],
      sessionImagePaths: const {
        's': ['/p.jpg'],
      },
    );

    test('an unknown session only shows loading', () async {
      bloc.add(const ProcessRemainingResources(sessionId: 'x'));
      await settle();

      expect(bloc.state.status, const PipelineStatus.loading());
      expect(repository.remainingCalls, isEmpty);
    });

    test('waits while another session is processing', () async {
      seed(
        withPages(extracted).copyWith(
          sessions: [
            extracted,
            const ProcessingSession(
              id: 'busy',
              status: ProcessingStatus.processingPatient,
            ),
          ],
        ),
      );

      bloc.add(const ProcessRemainingResources(sessionId: 's'));
      await settle();

      expect(session('s').status, ProcessingStatus.patientExtracted);
      expect(repository.remainingCalls, isEmpty);
    });

    test('each snapshot replaces the last on top of the starting resources, '
        'and the end makes a draft and announces it', () async {
      seed(withPages(extracted));

      bloc.add(const ProcessRemainingResources(sessionId: 's'));
      await settle();
      expect(session('s').status, ProcessingStatus.processing);

      repository.remaining.add(([first], 0.5));
      await settle();
      expect(session('s').resources, [kept, first]);
      expect(session('s').progress, 0.5);

      repository.remaining.add(([first, second], 1.0));
      await settle();
      expect(session('s').resources, [kept, first, second]);

      await repository.remaining.close();
      await settle();

      final done = session('s');
      expect(done.status, ProcessingStatus.draft);
      expect(done.resources, [kept, first, second]);
      expect(repository.edited.last.status, ProcessingStatus.draft);
      expect(repository.edited.last.resources, hasLength(3));
      final notification = bloc.state.notification!;
      expect(
        notification.text,
        _en.processingFinished(_en.processingOriginImport),
      );
      expect(routeSessionId(notification.route), 's');
    });

    test('an encounter document is read as a visit with the saved Deep Scan '
        'and output mode', () async {
      await prefs.setBool(SharedPrefsConstants.aiUseVision, !isDesktop);
      await prefs.setString(SharedPrefsConstants.aiOutputMode, 'schemaDraft');
      await prefs.setInt(SharedPrefsConstants.aiMaxTokens, 4096);
      seed(withPages(extracted));

      bloc.add(const ProcessRemainingResources(sessionId: 's'));
      await settle();

      final call = repository.remainingCalls.single;
      expect(call.input, ['/p.jpg']);
      expect(call.documentCategory, 'visit');
      expect(call.useVision, !isDesktop);
      expect(call.outputMode, ExtractionOutputMode.schemaDraft);
      expect(call.maxTokens, isDesktop ? isNull : 4096);
    });

    test('a report document is read as a lab report, with Deep Scan on by '
        'default only on a desktop', () async {
      seed(
        withPages(
          extracted.copyWith(
            diagnosticReport: const StagedDiagnosticReport(
              draft: MappingDiagnosticReport(id: 'rep'),
            ),
          ),
        ),
      );

      bloc.add(const ProcessRemainingResources(sessionId: 's'));
      await settle();

      final call = repository.remainingCalls.single;
      expect(call.documentCategory, 'lab_report');
      expect(call.useVision, defaultDeepScan(isDesktop));
      expect(call.outputMode, ExtractionOutputMode.defaultMode);
    });

    test(
      'Deep Scan reads the pages on a device with the memory for it',
      () async {
        await prefs.setBool(SharedPrefsConstants.aiUseVision, true);
        seed(withPages(extracted));

        bloc.add(const ProcessRemainingResources(sessionId: 's'));
        await settle();

        expect(repository.remainingCalls.single.useVision, isTrue);
      },
    );

    test('Deep Scan on a device without the memory for it reads the text '
        'instead of stopping', () async {
      await prefs.setBool(SharedPrefsConstants.aiUseVision, true);
      capability.capability = DeviceAiCapability.basicOnly;
      seed(withPages(extracted));

      bloc.add(const ProcessRemainingResources(sessionId: 's'));
      await settle();

      expect(session('s').status, ProcessingStatus.processing);
      expect(repository.remainingCalls.single.useVision, isFalse);
    });

    test('snapshots after a cancel are dropped', () async {
      seed(withPages(extracted));
      bloc.add(const ProcessRemainingResources(sessionId: 's'));
      await settle();
      repository.remaining.add(([first], 0.3));
      await settle();

      bloc.add(const MappingCancelled(sessionId: 's'));
      await settle();
      repository.remaining.add(([first, second], 0.6));
      await settle();

      final cancelled = session('s');
      expect(cancelled.status, ProcessingStatus.patientExtracted);
      expect(cancelled.resources, isEmpty);
      expect(cancelled.progress, 0.0);
      expect(repository.disposes, 1);
      expect(bloc.state.notification, isNull);
    });

    test(
      'a cancel while the pages are prepared does not start the AI',
      () async {
        ocr.prepareGate = Completer<void>();
        seed(const ProcessingState(sessions: [extracted]));
        bloc.add(const ProcessRemainingResources(sessionId: 's'));
        await settle();
        expect(session('s').status, ProcessingStatus.processing);

        bloc.add(const MappingCancelled(sessionId: 's'));
        await settle();
        ocr.prepareGate!.complete();
        await settle();

        expect(session('s').status, ProcessingStatus.patientExtracted);
        expect(repository.remainingCalls, isEmpty);
      },
    );

    test(
      'a stream that ends after a cancel leaves the session at step one',
      () async {
        seed(withPages(extracted));
        bloc.add(const ProcessRemainingResources(sessionId: 's'));
        await settle();
        repository.remaining.add(([first], 0.3));
        await settle();

        bloc.add(const MappingCancelled(sessionId: 's'));
        await settle();
        // Disposing the model stops the generation, so the stream ends.
        await repository.remaining.close();
        await settle();

        final cancelled = session('s');
        expect(cancelled.status, ProcessingStatus.patientExtracted);
        expect(cancelled.resources, isEmpty);
        expect(cancelled.progress, 0.0);
        expect(
          repository.edited.map((s) => s.status),
          isNot(contains(ProcessingStatus.draft)),
        );
        expect(bloc.state.notification, isNull);
      },
    );

    test('a failure drops the resources read so far and goes back to step '
        'one', () async {
      seed(withPages(extracted));
      bloc.add(const ProcessRemainingResources(sessionId: 's'));
      await settle();
      repository.remaining.add(([first], 0.5));
      await settle();

      repository.remaining.addError(Exception('decode error'));
      await settle();

      final failed = session('s');
      expect(failed.status, ProcessingStatus.patientExtracted);
      expect(failed.resources, [kept]);
      expect(repository.edited.last.status, ProcessingStatus.patientExtracted);
      expect(
        bloc.state.status,
        const PipelineStatus.failure(
          error: 'Exception: decode error',
          reason: PipelineFailureReason.other,
          sessionId: 's',
        ),
      );
      expect(logs, loggedWarning('resource extraction failed'));
    });

    test('running out of memory fails as notEnoughMemory', () async {
      seed(withPages(extracted));
      bloc.add(const ProcessRemainingResources(sessionId: 's'));
      await settle();

      repository.remaining.addError(
        Exception('Not enough memory to load the AI model.'),
      );
      await settle();

      expect(
        (bloc.state.status as Failure).reason,
        PipelineFailureReason.notEnoughMemory,
      );
    });

    test('a tokenization failure is a capacity failure', () async {
      seed(withPages(extracted));
      bloc.add(const ProcessRemainingResources(sessionId: 's'));
      await settle();

      repository.remaining.addError(Exception('Tokenization failed'));
      await settle();

      expect(
        bloc.state.status,
        const PipelineStatus.capacityFailure(sessionId: 's'),
      );
    });

    test('a handover whose records step failed is not continued by the '
        'queue until the user retries it', () async {
      seed(withPages(extracted.copyWith(origin: ProcessingOrigin.handover)));
      bloc.add(const ProcessRemainingResources(sessionId: 's'));
      await settle();
      repository.remaining.addError(Exception('decode error'));
      await settle();
      expect(session('s').status, ProcessingStatus.patientExtracted);

      bloc.add(
        const ProcessRemainingResources(sessionId: 's', automatic: true),
      );
      await settle();

      expect(session('s').status, ProcessingStatus.patientExtracted);
      expect(repository.remainingCalls, hasLength(1));
      expect((bloc.state.status as Failure).sessionId, 's');
    });
  });

  group('cancel', () {
    test('an unknown session is ignored', () async {
      bloc.add(const MappingCancelled(sessionId: 'x'));
      await settle();

      expect(repository.disposes, 0);
    });

    test('cancelling step one with a staged patient keeps the patient '
        'step', () async {
      seed(
        const ProcessingState(
          sessions: [
            ProcessingSession(
              id: 's',
              status: ProcessingStatus.processingPatient,
              progress: 0.4,
              patient: StagedPatient(draft: MappingPatient(id: 'p')),
            ),
          ],
        ),
      );

      bloc.add(const MappingCancelled(sessionId: 's'));
      await settle();

      expect(session('s').status, ProcessingStatus.patientExtracted);
      expect(session('s').progress, 0.0);
      expect(session('s').patient.draft?.id, 'p');
      expect(repository.disposes, 1);
    });

    const running = ProcessingSession(
      id: 's',
      status: ProcessingStatus.processing,
      patient: StagedPatient(draft: MappingPatient(id: 'p')),
    );

    test('a cancelled step is stopping, and is not retried, until the AI '
        'has stopped', () async {
      repository.stopGate = Completer<void>();
      seed(const ProcessingState(sessions: [running]));

      bloc.add(const MappingCancelled(sessionId: 's'));
      await settle();

      expect(session('s').status, ProcessingStatus.patientExtracted);
      expect(bloc.state.isStopping('s'), isTrue);
      expect(bloc.state.canRetrySession('s'), isFalse);
      expect(repository.cancels, 1);
      expect(repository.disposes, 0);

      repository.stopGate!.complete();
      await settle();

      expect(bloc.state.isStopping('s'), isFalse);
      expect(bloc.state.canRetrySession('s'), isTrue);
      expect(repository.disposes, 1);
    });

    test('a cancel of a session the AI is not reading has nothing to '
        'stop', () async {
      seed(
        ProcessingState(
          sessions: [running.copyWith(status: ProcessingStatus.cancelled)],
        ),
      );

      bloc.add(const MappingCancelled(sessionId: 's'));
      await settle();

      expect(repository.cancels, 0);
      expect(repository.disposes, 1);
      expect(
        states.map((s) => s.stoppingSessionIds),
        everyElement(isEmpty),
      );
    });

    test('a stop that fails is logged and the session can be processed '
        'again', () async {
      repository.cancelError = Exception('engine gone');
      seed(const ProcessingState(sessions: [running]));

      bloc.add(const MappingCancelled(sessionId: 's'));
      await settle();

      expect(bloc.state.isStopping('s'), isFalse);
      expect(session('s').status, ProcessingStatus.patientExtracted);
    });
  });

  test('attaching the document of an unknown session saves nothing', () async {
    bloc.add(const DocumentAttached(sessionId: 'x'));
    await settle();

    expect(repository.edited, isEmpty);
  });

  group('save', () {
    const newPatient = StagedPatient(
      draft: MappingPatient(
        id: 'p-new',
        givenName: MappedProperty(value: 'Ana'),
        familyName: MappedProperty(value: 'Pop'),
        gender: MappedProperty(value: 'female'),
      ),
    );
    const observation = MappingObservation(
      id: 'obs',
      observationName: MappedProperty(value: 'Glucose'),
      value: MappedProperty(value: '95'),
      unit: MappedProperty(value: 'mg/dL'),
    );

    Future<void> save(ProcessingSession draft) async {
      seed(ProcessingState(sessions: [draft]));
      bloc.add(ResourceCreationInitiated(sessionId: draft.id));
      await settle();
    }

    test('a new patient and encounter are saved first, then the other '
        'resources tagged with the specialty, then the documents', () async {
      await save(
        ProcessingSession(
          id: 's',
          filePaths: const ['/a.jpg', '/b.jpg'],
          status: ProcessingStatus.draft,
          patient: newPatient,
          encounter: const StagedEncounter(
            draft: MappingEncounter(
              id: 'enc',
              encounterType: MappedProperty(value: 'Checkup'),
              specialty: MappedProperty(value: 'Cardiology'),
            ),
          ),
          resources: [
            newPatient.draft!,
            const MappingEncounter(id: 'stray-enc'),
            const MappingDiagnosticReport(id: 'stray-rep'),
            observation,
          ],
        ),
      );

      expect(
        states.map((s) => s.status),
        containsAllInOrder([
          const PipelineStatus.savingResources(),
          const PipelineStatus.success(sessionId: 's'),
        ]),
      );
      // Someone new gets a wallet of their own and is shown once saved.
      expect(holders.wallets.single, 'p-new');
      expect(selection.selected, ['p-new']);

      final [primaries, others] = sync.saved;
      expect(primaries.map((r) => (r.fhirType, r.id)), [
        (FhirType.Patient, 'p-new'),
        (FhirType.Encounter, 'enc'),
      ]);
      expect(primaries.first.sourceId, 'wallet-p-new');
      expect(primaries.last.subjectId, 'p-new');

      // The staged patient, encounter and report are not saved twice.
      final saved = others.single;
      expect(saved.fhirType, FhirType.Observation);
      expect(saved.id, 'obs');
      expect(saved.sourceId, 'wallet-p-new');
      expect(saved.subjectId, 'p-new');
      expect(saved.encounterId, 'enc');
      final tag = (saved.rawResource['meta']['tag'] as List).single as Map;
      expect(tag['system'], 'http://healthwallet.me/specialty');
      expect(tag['code'], 'cardiology');
      expect(tag['display'], 'Cardiology');

      final docs = documents.calls.single;
      expect(docs.sessionId, 's');
      expect(docs.filePaths, ['/a.jpg', '/b.jpg']);
      expect(docs.patientId, 'p-new');
      expect(docs.sourceId, 'wallet-p-new');
      expect(docs.encounter?.id, 'enc');
      expect(docs.title, 'Checkup');
      // The 200 dpi pages are no longer needed once the records are saved.
      expect(ocr.discarded, ['s']);
    });

    test('a new patient without a gender is saved', () async {
      await save(
        const ProcessingSession(
          id: 's',
          status: ProcessingStatus.draft,
          patient: StagedPatient(draft: MappingPatient(id: 'p-new')),
          encounter: StagedEncounter(draft: MappingEncounter(id: 'enc')),
        ),
      );

      expect(bloc.state.status, const PipelineStatus.success(sessionId: 's'));
      expect(sync.saved.single.first.id, 'p-new');
    });

    test('a specialty the app does not know is tagged as general '
        'care', () async {
      await save(
        const ProcessingSession(
          id: 's',
          status: ProcessingStatus.draft,
          patient: newPatient,
          encounter: StagedEncounter(
            draft: MappingEncounter(
              id: 'enc',
              specialty: MappedProperty(value: 'Space medicine'),
            ),
          ),
          resources: [observation],
        ),
      );

      final tag =
          (sync.saved.last.single.rawResource['meta']['tag'] as List).single
              as Map;
      expect(tag['code'], 'generalCare');
      expect(tag['display'], 'Space medicine');
    });

    test('a linked patient is written through their wallet Patient with the '
        'scanned edits, and the scan is filed under them', () async {
      final existing = _patient('p-old', title: 'Ana Pop');
      await save(
        ProcessingSession(
          id: 's',
          status: ProcessingStatus.draft,
          patient: StagedPatient(
            existing: existing,
            draft: const MappingPatient(
              id: 'p-draft',
              givenName: MappedProperty(value: 'Anna'),
              gender: MappedProperty(value: 'female'),
            ),
            mode: ImportMode.linkExisting,
          ),
          encounter: const StagedEncounter(
            draft: MappingEncounter(id: 'enc'),
          ),
        ),
      );

      final written = holders.linked.single;
      expect(written.patientId, 'p-old');
      expect(written.scanned?.givenName.value, 'Anna');
      // The holder service writes the Patient; only the encounter is saved here.
      final primaries = sync.saved.single;
      expect(primaries.map((r) => r.fhirType), [FhirType.Encounter]);
      expect(primaries.single.subjectId, 'p-old');
      expect(primaries.single.sourceId, 'wallet-p-old');
      expect(selection.selected, ['holder-p-old']);
      expect(bloc.state.status, const PipelineStatus.success(sessionId: 's'));
    });

    test('a linked patient and encounter save no new primary records, and '
        'the resources point at the existing encounter', () async {
      final existing = _patient('p-old');
      const encounter = Encounter(id: 'enc-old', title: 'Old visit');
      await save(
        ProcessingSession(
          id: 's',
          status: ProcessingStatus.draft,
          patient: StagedPatient(
            existing: existing,
            mode: ImportMode.linkExisting,
          ),
          encounter: const StagedEncounter(
            existing: encounter,
            mode: ImportMode.linkExisting,
          ),
          resources: [observation],
        ),
      );

      final saved = sync.saved.single.single;
      expect(saved.id, 'obs');
      expect(saved.encounterId, 'enc-old');
      expect(saved.subjectId, 'p-old');
      expect(saved.rawResource['meta'], isNull);
      final docs = documents.calls.single;
      expect(docs.encounter, encounter);
      expect(docs.title, 'Old visit');
      expect(bloc.state.status, const PipelineStatus.success(sessionId: 's'));
    });

    test('a linked patient and encounter without other resources save only '
        'the documents', () async {
      await save(
        ProcessingSession(
          id: 's',
          status: ProcessingStatus.draft,
          patient: StagedPatient(
            existing: _patient('p-old'),
            mode: ImportMode.linkExisting,
          ),
          encounter: const StagedEncounter(
            existing: Encounter(id: 'enc-old'),
            mode: ImportMode.linkExisting,
          ),
        ),
      );

      expect(sync.saved, isEmpty);
      expect(documents.calls.single.patientId, 'p-old');
      expect(bloc.state.status, const PipelineStatus.success(sessionId: 's'));
    });

    test('a report container is saved as the report and the documents get '
        'no encounter', () async {
      await save(
        const ProcessingSession(
          id: 's',
          status: ProcessingStatus.draft,
          patient: newPatient,
          diagnosticReport: StagedDiagnosticReport(
            draft: MappingDiagnosticReport(
              id: 'rep',
              reportName: MappedProperty(value: 'CBC'),
              issuedDate: MappedProperty(value: '2024-03-01'),
            ),
          ),
        ),
      );

      final primaries = sync.saved.single;
      expect(primaries.map((r) => (r.fhirType, r.id)), [
        (FhirType.Patient, 'p-new'),
        (FhirType.DiagnosticReport, 'rep'),
      ]);
      expect(primaries.last.subjectId, 'p-new');
      final docs = documents.calls.single;
      expect(docs.encounter, isNull);
      expect(docs.title, 'CBC');
    });

    test('a prescription already in the wallet without a visit is completed '
        'with the scanned visit and points at it', () async {
      records.patients = [
        const VisionPrescription(
          id: 'rx-old',
          sourceId: 'src-old',
          subjectId: 'p-old',
          rawResource: {
            'resourceType': 'VisionPrescription',
            'id': 'rx-old',
            'status': 'active',
          },
        ),
      ];
      await save(
        const ProcessingSession(
          id: 's',
          status: ProcessingStatus.draft,
          patient: newPatient,
          encounter: StagedEncounter(draft: MappingEncounter(id: 'enc')),
          resources: [
            MappingVisionPrescription(
              id: 'rx-read',
              existingId: 'rx-old',
              provenance: 'optika@1',
            ),
          ],
        ),
      );

      final [primaries, completions] = sync.saved;
      expect(primaries.map((r) => r.id), ['p-new', 'enc']);
      // The stored row is completed, not saved again as the twin.
      final completed = completions.single;
      expect(completed.id, 'rx-old');
      expect(completed.sourceId, 'src-old');
      expect(completed.encounterId, 'enc');
      expect(
        (completed.rawResource['encounter'] as Map)['reference'],
        'Encounter/enc',
      );
      expect(completed.rawResource['status'], 'active');
      expect(bloc.state.status, const PipelineStatus.success(sessionId: 's'));
    });

    test('a failed document save fails the save with its reason', () async {
      documents.error = Exception('Not enough memory');
      await save(
        const ProcessingSession(
          id: 's',
          status: ProcessingStatus.draft,
          patient: newPatient,
          encounter: StagedEncounter(draft: MappingEncounter(id: 'enc')),
        ),
      );

      expect(
        bloc.state.status,
        const PipelineStatus.failure(
          error: 'Exception: Not enough memory',
          reason: PipelineFailureReason.notEnoughMemory,
          sessionId: 's',
        ),
      );
      expect(logs, loggedWarning('resource creation failed'));
    });

    test('saving a session that is gone leaves the status as it was before '
        'saving', () async {
      const before = PipelineStatus.failure(error: 'Exception: earlier');
      const other = ProcessingSession(
        id: 'other',
        status: ProcessingStatus.draft,
        patient: newPatient,
      );
      seed(const ProcessingState(status: before, sessions: [other]));

      bloc.add(const ResourceCreationInitiated(sessionId: 'gone'));
      await settle();

      expect(bloc.state.status, before);
      expect(bloc.state.sessions, [other]);
      expect(sync.saved, isEmpty);
      expect(documents.calls, isEmpty);
      expect(logs, loggedWarning('session gone no longer exists'));
    });

    test('saving a session that is gone with nothing before goes back to '
        'the initial status, not success', () async {
      bloc.add(const ResourceCreationInitiated(sessionId: 'gone'));
      await settle();

      expect(bloc.state.status, const PipelineStatus.initial());
      expect(
        states.map((s) => s.status),
        isNot(contains(isA<Success>())),
      );
    });
  });
}
