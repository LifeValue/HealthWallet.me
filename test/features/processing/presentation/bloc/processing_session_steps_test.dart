import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Notification;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_observation.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/processing/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../share_records/share_test_helpers.dart';

const _docScanner = MethodChannel('flutter_doc_scanner');

class _FakeProcessingRepository extends Fake implements ProcessingRepository {
  final created = <List<String>>[];
  final edited = <ProcessingSession>[];
  final deleted = <ProcessingSession>[];
  int cancels = 0;
  int disposes = 0;

  @override
  Future<ProcessingSession> createProcessingSession({
    required List<String> filePaths,
    required ProcessingOrigin origin,
  }) async {
    created.add(filePaths);
    return ProcessingSession(id: 'new', filePaths: filePaths, origin: origin);
  }

  @override
  Future<int> editProcessingSession(ProcessingSession session) async {
    edited.add(session);
    return 1;
  }

  @override
  Future<int> deleteProcessingSession(ProcessingSession session) async {
    deleted.add(session);
    return 1;
  }

  @override
  Future<void> cancelGeneration() async => cancels++;

  @override
  Future<void> waitForStreamCompletion() async {}

  @override
  Future<void> disposeModel() async => disposes++;

  @override
  Future<bool> checkModelExistence() async => false;
}

/// Reads "page N of M" from the OCR text of each path.
class _FakeOcrProcessingHelper extends Fake implements OcrProcessingHelper {
  Map<String, String> textByPath = {};

  @override
  Future<String> processOcrForImages(List<String> imagePaths) async =>
      textByPath.entries
          .firstWhere(
            (e) => imagePaths.single.contains(e.key),
            orElse: () => const MapEntry('', ''),
          )
          .value;

  @override
  Future<List<String>> prepareAllImages({
    required List<String> filePaths,
  }) async => filePaths;
}

class _FakeSyncRepository extends Fake implements SyncRepository {}

class _FakeRecordsRepository extends Fake implements RecordsRepository {}

class _FakeDocumentReferenceService extends Fake
    implements DocumentReferenceService {}

class _FakePatientDeduplicationService extends Fake
    implements PatientDeduplicationService {}

class _FakeSourceTypeService extends Fake implements SourceTypeService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory root;
  late _FakeProcessingRepository repository;
  late _FakeOcrProcessingHelper ocr;
  late SharedPreferences prefs;
  late ProcessingBloc bloc;

  setUp(() async {
    root = mockPathProvider();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = _FakeProcessingRepository();
    ocr = _FakeOcrProcessingHelper();
    bloc = ProcessingBloc(
      repository,
      ocr,
      _FakeSyncRepository(),
      _FakeDocumentReferenceService(),
      _FakePatientDeduplicationService(),
      _FakeSourceTypeService(),
      _FakeRecordsRepository(),
      prefs,
      AppStringsProvider.forLocale(const Locale('en')),
    );
  });

  tearDown(() async {
    await bloc.close();
    messenger.setMockMethodCallHandler(_docScanner, null);
  });

  // Seeding the state directly starts a step without running the steps
  // before it.
  void seed(ProcessingState state) {
    // ignore: invalid_use_of_visible_for_testing_member
    bloc.emit(state);
  }

  Future<void> settle() => pumpEventQueue();

  File file(String name) =>
      File('${root.path}/$name')..writeAsBytesSync([1, 2, 3]);

  ProcessingSession session(String id) =>
      bloc.state.sessions.firstWhere((s) => s.id == id);

  group('state', () {
    test('a session can be retried when not processed or after a failure', () {
      ProcessingState with_(ProcessingStatus status, [PipelineStatus? p]) =>
          ProcessingState(
            status: p ?? const PipelineStatus.initial(),
            sessions: [ProcessingSession(id: 's', status: status)],
          );

      expect(with_(ProcessingStatus.draft).canRetrySession('s'), isTrue);
      expect(
        with_(ProcessingStatus.patientExtracted).canRetrySession('s'),
        isTrue,
      );
      expect(with_(ProcessingStatus.cancelled).canRetrySession('s'), isTrue);
      expect(with_(ProcessingStatus.processing).canRetrySession('s'), isFalse);
      expect(
        with_(
          ProcessingStatus.processing,
          const PipelineStatus.failure(error: 'x'),
        ).canRetrySession('s'),
        isTrue,
      );
      expect(
        with_(
          ProcessingStatus.processing,
          const PipelineStatus.capacityFailure(sessionId: 's'),
        ).canRetrySession('s'),
        isTrue,
      );
      expect(with_(ProcessingStatus.draft).canRetrySession('other'), isFalse);
    });

    test('step two can be retried from a draft or a failed patient step', () {
      ProcessingState with_(ProcessingStatus status, [PipelineStatus? p]) =>
          ProcessingState(
            status: p ?? const PipelineStatus.initial(),
            sessions: [ProcessingSession(id: 's', status: status)],
          );

      expect(with_(ProcessingStatus.draft).canRetryStep2('s'), isTrue);
      expect(
        with_(ProcessingStatus.patientExtracted).canRetryStep2('s'),
        isFalse,
      );
      expect(
        with_(
          ProcessingStatus.patientExtracted,
          const PipelineStatus.failure(error: 'x'),
        ).canRetryStep2('s'),
        isTrue,
      );
      expect(with_(ProcessingStatus.draft).canRetryStep2('other'), isFalse);
    });
  });

  group('scan', () {
    test('scanned pages are kept and become a scan session', () async {
      final page = file('page1.jpg');
      messenger.setMockMethodCallHandler(
        _docScanner,
        (call) async => {
          'images': ['file://${page.path}', ''],
          'count': 1,
        },
      );

      bloc.add(const CaptureButtonPressed());
      final status = await bloc.stream
          .map((s) => s.status)
          .firstWhere((s) => s is SessionCreated || s is Failure);

      expect(status, isA<SessionCreated>());
      final paths = repository.created.single;
      expect(
        paths.single,
        matches(RegExp(r'/Documents/imports/page1_[0-9a-f]{8}\.jpg$')),
      );
      expect(File(paths.single).existsSync(), isTrue);
      expect(session('new').origin, ProcessingOrigin.scan);
    });

    test('a scan without pages goes back to initial', () async {
      messenger.setMockMethodCallHandler(
        _docScanner,
        (call) async => {'images': <String>[], 'count': 0},
      );

      bloc.add(const CaptureButtonPressed());
      final status = await bloc.stream
          .map((s) => s.status)
          .firstWhere((s) => s is! Loading);

      expect(status, const PipelineStatus.initial());
      expect(repository.created, isEmpty);
    });
  });

  group('import', () {
    test('pages labelled "page N of M" are put in order', () async {
      final second = file('b.jpg');
      final first = file('a.jpg');
      ocr.textByPath = {'b_': 'Page 2 of 2', 'a_': 'Page 1 of 2'};

      bloc.add(DocumentImported(filePaths: [second.path, first.path]));
      await bloc.stream.firstWhere((s) => s.status is SessionCreated);

      final paths = repository.created.single;
      expect(paths[0], contains('/a_'));
      expect(paths[1], contains('/b_'));
    });

    test('unlabelled pages keep their order', () async {
      final second = file('b.jpg');
      final first = file('a.jpg');

      bloc.add(DocumentImported(filePaths: [second.path, first.path]));
      await bloc.stream.firstWhere((s) => s.status is SessionCreated);

      final paths = repository.created.single;
      expect(paths[0], contains('/b_'));
      expect(paths[1], contains('/a_'));
    });

    test('files with the same name are kept apart under unique names, as new '
        'files', () async {
      final first = File('${root.path}/one/scan.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1]);
      final second = File('${root.path}/two/scan.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync([2]);
      for (final f in [first, second]) {
        f.setLastModifiedSync(DateTime(2020));
      }
      final before = DateTime.now().subtract(const Duration(seconds: 5));

      bloc.add(DocumentImported(filePaths: [first.path, second.path]));
      await bloc.stream.firstWhere((s) => s.status is SessionCreated);

      final paths = repository.created.single;
      expect(paths.toSet(), hasLength(2));
      for (final path in paths) {
        expect(
          path,
          matches(RegExp(r'/Documents/imports/scan_[0-9a-f]{8}\.jpg$')),
        );
        expect(File(path).lastModifiedSync().isAfter(before), isTrue);
      }
      expect(paths.map((path) => File(path).readAsBytesSync()), [
        [1],
        [2],
      ]);
    });

    test('a patient found on the desktop starts the session at step two', () {
      final doc = file('doc.pdf');
      const patient = StagedPatient(draft: MappingPatient(id: 'p1'));

      bloc.add(
        DocumentImported(filePaths: [doc.path], phase1Patient: patient),
      );

      return expectLater(
        bloc.stream.map((s) => s.sessions.firstOrNull?.status),
        emitsThrough(ProcessingStatus.patientExtracted),
      );
    });
  });

  group('session list', () {
    test('a draft progress update is saved, others are not', () async {
      bloc.add(
        const SessionChangedProgress(
          session: ProcessingSession(id: 's', progress: 0.5),
        ),
      );
      await settle();
      expect(session('s').progress, 0.5);
      expect(repository.edited, isEmpty);

      bloc.add(
        const SessionChangedProgress(
          session: ProcessingSession(id: 's', status: ProcessingStatus.draft),
        ),
      );
      await settle();
      expect(bloc.state.sessions, hasLength(1));
      expect(repository.edited.single.status, ProcessingStatus.draft);
    });

    test('clearing a running session stops the AI and starts the next', () {
      const running = ProcessingSession(
        id: 'run',
        status: ProcessingStatus.processing,
      );
      const queued = ProcessingSession(id: 'next', filePaths: ['/n.jpg']);
      seed(const ProcessingState(sessions: [running, queued]));

      bloc.add(const SessionCleared(session: running));

      return expectLater(
        bloc.stream.map((s) => s.status),
        emitsThrough(isA<Failure>()),
      ).then((_) {
        expect(repository.cancels, 1);
        expect(repository.deleted.single.id, 'run');
        expect(bloc.state.sessions.single.id, 'next');
        // The next session is activated; with no model it fails as such.
        expect(
          (bloc.state.status as Failure).reason,
          PipelineFailureReason.modelNotFound,
        );
      });
    });

    test('reordered pages are saved and used for OCR', () async {
      seed(const ProcessingState(sessions: [ProcessingSession(id: 's')]));

      bloc.add(
        const PagesReordered(sessionId: 's', reorderedPaths: ['/2', '/1']),
      );
      await settle();

      expect(session('s').filePaths, ['/2', '/1']);
      expect(bloc.state.sessionImagePaths['s'], ['/2', '/1']);
      expect(repository.edited.single.filePaths, ['/2', '/1']);
    });

    test('reordering an unknown session does nothing', () async {
      bloc.add(const PagesReordered(sessionId: 'x', reorderedPaths: ['/1']));
      await settle();

      expect(repository.edited, isEmpty);
    });
  });

  group('review edits', () {
    ProcessingSession draft() => ProcessingSession(
      id: 's',
      status: ProcessingStatus.draft,
      resources: [MappingObservation.empty()],
    );

    test('a resource field change is saved', () async {
      seed(ProcessingState(sessions: [draft()]));

      bloc.add(
        const ResourceChanged(
          sessionId: 's',
          index: 0,
          propertyKey: 'observationName',
          newValue: 'Glucose',
        ),
      );
      await settle();

      final changed = session('s').resources.single as MappingObservation;
      expect(changed.observationName.value, 'Glucose');
      expect(repository.edited, hasLength(1));
    });

    test('a patient field change edits the draft patient', () async {
      seed(ProcessingState(sessions: [draft()]));

      bloc.add(
        const ResourceChanged(
          sessionId: 's',
          index: -1,
          propertyKey: 'givenName',
          newValue: 'Ana',
          isDraftPatient: true,
        ),
      );
      await settle();

      expect(session('s').patient.draft?.givenName.value, 'Ana');
      expect(session('s').patient.mode, ImportMode.createNew);
    });

    test('an encounter field change edits the draft encounter', () async {
      seed(ProcessingState(sessions: [draft()]));

      bloc.add(
        const ResourceChanged(
          sessionId: 's',
          index: -1,
          propertyKey: 'encounterType',
          newValue: 'Checkup',
          isDraftEncounter: true,
        ),
      );
      await settle();

      expect(session('s').encounter.draft?.encounterType.value, 'Checkup');
    });

    test('a report field change edits the draft report', () async {
      seed(ProcessingState(sessions: [draft()]));

      bloc.add(
        const ResourceChanged(
          sessionId: 's',
          index: -1,
          propertyKey: 'reportName',
          newValue: 'CBC',
          isDraftDiagnosticReport: true,
        ),
      );
      await settle();

      expect(session('s').diagnosticReport?.draft?.reportName.value, 'CBC');
    });

    test('resources are added and removed', () async {
      seed(ProcessingState(sessions: [draft()]));

      bloc.add(
        const ResourcesAdded(
          sessionId: 's',
          resourceTypes: ['Condition', 'Procedure'],
        ),
      );
      await settle();
      expect(session('s').resources, hasLength(3));

      bloc.add(const ResourceRemoved(sessionId: 's', index: 0));
      await settle();
      expect(session('s').resources, hasLength(2));
      expect(session('s').resources.first, isNot(isA<MappingObservation>()));
    });

    test('reverting without an existing patient does nothing', () async {
      seed(ProcessingState(sessions: [draft()]));

      bloc.add(const PatientReverted(sessionId: 's'));
      await settle();

      expect(repository.edited, isEmpty);
    });

    test('an attached encounter replaces patient and encounter', () async {
      seed(ProcessingState(sessions: [draft()]));
      const patient = StagedPatient(draft: MappingPatient(id: 'p'));
      const encounter = StagedEncounter(draft: MappingEncounter(id: 'e'));

      bloc.add(
        const EncounterAttached(
          sessionId: 's',
          patient: patient,
          encounter: encounter,
        ),
      );
      await settle();

      expect(session('s').patient, patient);
      expect(session('s').encounter, encounter);
      expect(repository.edited, hasLength(1));
    });
  });

  group('mapping steps', () {
    test('a document without text becomes a draft to fill by hand', () async {
      seed(
        const ProcessingState(
          sessions: [
            ProcessingSession(id: 's', filePaths: ['/p.jpg']),
          ],
          sessionImagePaths: {
            's': ['/p.jpg'],
          },
        ),
      );

      bloc.add(const MappingInitiated(sessionId: 's'));
      await bloc.stream.firstWhere(
        (st) => st.sessions.single.status == ProcessingStatus.draft,
      );
    });

    test('a session already processing is not started again', () async {
      seed(
        const ProcessingState(
          sessions: [
            ProcessingSession(id: 's', status: ProcessingStatus.processing),
          ],
        ),
      );

      bloc.add(const MappingInitiated(sessionId: 's'));
      await settle();

      expect(bloc.state.status, const PipelineStatus.initial());
    });

    test('cancelling before a patient is found cancels the session', () async {
      seed(
        const ProcessingState(
          sessions: [
            ProcessingSession(
              id: 's',
              status: ProcessingStatus.processingPatient,
            ),
          ],
        ),
      );

      bloc.add(const MappingCancelled(sessionId: 's'));
      await settle();

      expect(session('s').status, ProcessingStatus.cancelled);
      expect(repository.disposes, 1);
    });

    test('cancelling step two keeps the patient step', () async {
      seed(
        ProcessingState(
          sessions: [
            ProcessingSession(
              id: 's',
              status: ProcessingStatus.processing,
              resources: [MappingObservation.empty()],
            ),
          ],
        ),
      );

      bloc.add(const MappingCancelled(sessionId: 's'));
      await settle();

      expect(session('s').status, ProcessingStatus.patientExtracted);
      expect(session('s').resources, isEmpty);
    });

    test('attaching the document is saved on the session', () async {
      seed(const ProcessingState(sessions: [ProcessingSession(id: 's')]));

      bloc.add(const DocumentAttached(sessionId: 's'));
      await settle();

      expect(session('s').isDocumentAttached, isTrue);
      expect(repository.edited.single.isDocumentAttached, isTrue);
    });
  });

  group('container type', () {
    test('a report becomes an encounter with its name and date', () async {
      seed(
        const ProcessingState(
          sessions: [
            ProcessingSession(
              id: 's',
              diagnosticReport: StagedDiagnosticReport(
                draft: MappingDiagnosticReport(
                  id: 'r',
                  reportName: MappedProperty(value: 'CBC'),
                  issuedDate: MappedProperty(value: '2024-03-01'),
                ),
              ),
            ),
          ],
        ),
      );

      bloc.add(const ContainerTypeSwitched(sessionId: 's'));
      await settle();

      expect(session('s').encounter.draft?.encounterType.value, 'CBC');
      expect(session('s').encounter.draft?.periodStart.value, '2024-03-01');
      expect(session('s').diagnosticReport?.draft, isNull);
    });

    test('an encounter becomes a report with its name and date', () async {
      seed(
        const ProcessingState(
          sessions: [
            ProcessingSession(
              id: 's',
              encounter: StagedEncounter(
                draft: MappingEncounter(
                  id: 'e',
                  encounterType: MappedProperty(value: 'Checkup'),
                  periodStart: MappedProperty(value: '2024-03-01'),
                ),
              ),
            ),
          ],
        ),
      );

      bloc.add(const ContainerTypeSwitched(sessionId: 's'));
      await settle();

      expect(session('s').diagnosticReport?.draft?.reportName.value, 'Checkup');
      expect(session('s').encounter.draft, isNull);
    });

    test('an unknown session is ignored', () async {
      bloc.add(const ContainerTypeSwitched(sessionId: 'x'));
      await settle();

      expect(bloc.state.sessions, isEmpty);
    });
  });

  group('settings', () {
    test('turning vision on is saved', () async {
      bloc.add(const VisionToggled(useVision: true));
      await settle();

      expect(bloc.state.useVision, isTrue);
      expect(prefs.getBool(SharedPrefsConstants.aiUseVision), isTrue);
    });

    test('a new token limit is saved and the model reloaded', () async {
      bloc.add(const TokenCapacityUpdated(newMaxTokens: 2048, sessionId: 'x'));
      await settle();

      expect(prefs.getInt(SharedPrefsConstants.aiMaxTokens), 2048);
      expect(repository.disposes, 1);
    });

    test('an acknowledged notification is cleared', () async {
      seed(
        ProcessingState(
          notification: Notification(text: 'done', time: DateTime(2026)),
        ),
      );

      bloc.add(const NotificationAcknowledged());
      await settle();

      expect(bloc.state.notification, isNull);
    });

    test('capacity errors are read from the engine text', () {
      for (final text in [
        'maxTokens reached',
        'Input is too long',
        'bad input_size',
        'tokenization failed',
        'Prompt too long',
      ]) {
        expect(bloc.isCapacityError(text), isTrue, reason: text);
      }
      expect(bloc.isCapacityError('Not enough memory'), isFalse);
    });
  });
}
