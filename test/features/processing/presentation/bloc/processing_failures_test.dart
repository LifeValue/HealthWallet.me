import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/processing/domain/entity/extraction_output_mode.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/entity/model_not_found_exception.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/processing/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../share_records/share_test_helpers.dart';

final _en = lookupAppLocalizations(const Locale('en'));
final _ro = lookupAppLocalizations(const Locale('ro'));

const _docScanner = MethodChannel('flutter_doc_scanner');

class _FakeProcessingRepository extends Fake implements ProcessingRepository {
  Exception? createError;
  Exception? loadError;
  Exception? deleteError;
  Exception? remainingError;
  final created = <List<String>>[];
  final edited = <ProcessingSession>[];

  @override
  Future<ProcessingSession> createProcessingSession({
    required List<String> filePaths,
    required ProcessingOrigin origin,
  }) async {
    if (createError != null) throw createError!;
    created.add(filePaths);
    return ProcessingSession(id: 'new', filePaths: filePaths, origin: origin);
  }

  @override
  Future<List<ProcessingSession>> getProcessingSessions() async {
    if (loadError != null) throw loadError!;
    return const [ProcessingSession(id: 'saved')];
  }

  @override
  Future<int> deleteProcessingSession(ProcessingSession session) async {
    if (deleteError != null) throw deleteError!;
    return 1;
  }

  @override
  Future<int> editProcessingSession(ProcessingSession session) async {
    edited.add(session);
    return 1;
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
  }) => Stream.error(remainingError!);
}

class _FakeOcrProcessingHelper extends Fake implements OcrProcessingHelper {
  Exception? ocrError;

  @override
  Future<String> processOcrForImages(List<String> imagePaths) async {
    throw ocrError!;
  }
}

class _FakeSyncRepository extends Fake implements SyncRepository {
  @override
  Future<List<Source>> getSources() async => throw Exception('db closed');
}

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

  late _FakeProcessingRepository repository;
  late _FakeOcrProcessingHelper ocr;
  late ProcessingBloc bloc;

  setUp(() async {
    mockPathProvider();
    SharedPreferences.setMockInitialValues({});
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
      await SharedPreferences.getInstance(),
      AppStringsProvider.forLocale(const Locale('ro')),
    );
  });

  tearDown(() async {
    await bloc.close();
    messenger.setMockMethodCallHandler(_docScanner, null);
  });

  Future<PipelineStatus> endStatus(ProcessingEvent event) {
    final done = bloc.stream
        .map((s) => s.status)
        .firstWhere(
          (s) =>
              s is Failure ||
              s is CapacityFailure ||
              s is SessionCreated ||
              s is Initial,
        )
        .timeout(const Duration(seconds: 5));
    bloc.add(event);
    return done;
  }

  // Seeding the state directly starts a step without running the steps
  // before it.
  void seed(ProcessingState state) {
    // ignore: invalid_use_of_visible_for_testing_member
    bloc.emit(state);
  }

  group('PipelineFailureReason.of', () {
    test('reads the type, then the AI engine text, then other', () {
      expect(
        PipelineFailureReason.of(const ModelNotFoundException()),
        PipelineFailureReason.modelNotFound,
      );
      expect(
        PipelineFailureReason.of(
          Exception('Not enough memory to load the AI model. Available: 1MB'),
        ),
        PipelineFailureReason.notEnoughMemory,
      );
      expect(
        PipelineFailureReason.of(
          Exception('Model file is corrupted. Please re-download.'),
        ),
        PipelineFailureReason.modelCorrupted,
      );
      expect(
        PipelineFailureReason.of(Exception('boom')),
        PipelineFailureReason.other,
      );
    });
  });

  group('localized messages', () {
    test('every reason has its own translated text', () {
      final expected = {
        PipelineFailureReason.modelNotFound: _ro.modelNotFoundError,
        PipelineFailureReason.modelCorrupted: _ro.modelCorruptedError,
        PipelineFailureReason.notEnoughMemory: _ro.processingFailedCapacity,
        PipelineFailureReason.scanFailed: _ro.scanFailed,
        PipelineFailureReason.importFailed: _ro.importDocumentFailed,
        PipelineFailureReason.noValidFiles: _ro.noValidFilesFound,
        PipelineFailureReason.noImagesGenerated:
            _ro.processingNoImagesGenerated,
        PipelineFailureReason.other: _ro.processingFailedGeneric,
      };
      expect(expected.keys, containsAll(PipelineFailureReason.values));
      expected.forEach((reason, text) {
        expect(reason.localizedMessage(_ro), text);
      });
      expect(_ro.scanFailed, isNot(_en.scanFailed));
      expect(_ro.importDocumentFailed, isNot(_en.importDocumentFailed));
      expect(_ro.processingFailedGeneric, isNot(_en.processingFailedGeneric));
    });

    test(
      'a memory failure tells the user to free memory',
      () {
        expect(
          PipelineFailureReason.notEnoughMemory.localizedMessage(_en),
          isNot(_en.processingFailedCapacity),
        );
      },
      skip:
          'BUG: a memory failure shows the context-size message, which '
          'tells the user to raise the Context Size instead of closing apps',
    );
  });

  group('scan', () {
    test('a scanner error fails as scanFailed with English text', () async {
      messenger.setMockMethodCallHandler(_docScanner, (call) async {
        throw PlatformException(code: 'SCAN_FAILED', message: 'camera busy');
      });

      final status = await endStatus(const CaptureButtonPressed());

      expect(status, isA<Failure>());
      final failure = status as Failure;
      expect(failure.reason, PipelineFailureReason.scanFailed);
      expect(failure.error, startsWith('Scan failed: '));
      expect(failure.error, contains('SCAN_FAILED'));
    });

    test('a cancelled scan goes back to initial', () async {
      messenger.setMockMethodCallHandler(_docScanner, (call) async => null);

      final status = await endStatus(const CaptureButtonPressed());

      expect(status, const PipelineStatus.initial());
    });
  });

  group('import', () {
    test('no existing file fails as noValidFiles', () async {
      final status = await endStatus(
        const DocumentImported(filePaths: ['/does/not/exist.pdf']),
      );

      expect(
        status,
        const PipelineStatus.failure(
          error: 'No valid files found',
          reason: PipelineFailureReason.noValidFiles,
        ),
      );
      expect(repository.created, isEmpty);
    });

    test('a failed session fails as importFailed with English text', () async {
      final file = File('${Directory.systemTemp.path}/hw_import_test.pdf')
        ..writeAsBytesSync([1, 2, 3]);
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });
      repository.createError = Exception('disk full');

      final status = await endStatus(
        DocumentImported(filePaths: [file.path]),
      );

      final failure = status as Failure;
      expect(failure.reason, PipelineFailureReason.importFailed);
      expect(failure.error, 'Failed to import document: Exception: disk full');
    });

    test('an existing file becomes a session', () async {
      final file = File('${Directory.systemTemp.path}/hw_import_ok.pdf')
        ..writeAsBytesSync([1, 2, 3]);
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });

      final status = await endStatus(
        DocumentImported(filePaths: [file.path]),
      );

      expect(status, isA<SessionCreated>());
      expect(repository.created.single.single, contains('hw_import_ok_'));
    });
  });

  group('sessions', () {
    test('a failed load fails with the exception reason', () async {
      repository.loadError = Exception('db locked');

      final status = await endStatus(const ProcessingInitialised());

      final failure = status as Failure;
      expect(failure.reason, PipelineFailureReason.other);
      expect(failure.error, 'Exception: db locked');
    });

    test('a load lists the saved sessions', () async {
      final status = await endStatus(const ProcessingInitialised());

      expect(status, const PipelineStatus.initial());
      expect(bloc.state.sessions.single.id, 'saved');
    });

    test('a failed delete fails and clears the deleting marker', () async {
      repository.deleteError = Exception('db locked');
      const session = ProcessingSession(id: 's1');
      seed(const ProcessingState(sessions: [session]));

      // The session leaves the list (status initial) before the delete runs.
      final failure = bloc.stream
          .map((s) => s.status)
          .firstWhere((s) => s is Failure)
          .timeout(const Duration(seconds: 5));
      bloc.add(const SessionCleared(session: session));

      expect(((await failure) as Failure).reason, PipelineFailureReason.other);
      expect(bloc.state.deletingSessionId, isNull);
      expect(bloc.state.sessions, isEmpty);
    });
  });

  group('patient extraction', () {
    const pending = ProcessingSession(id: 's1', filePaths: ['/p.jpg']);

    test('no page images fails as noImagesGenerated', () async {
      seed(const ProcessingState(sessions: [pending]));

      final status = await endStatus(const MappingInitiated(sessionId: 's1'));

      expect(
        status,
        const PipelineStatus.failure(
          error: 'No images were generated from the document',
          reason: PipelineFailureReason.noImagesGenerated,
        ),
      );
      expect(bloc.state.sessions.single.status, ProcessingStatus.pending);
    });

    test('an engine failure keeps its reason and requeues', () async {
      ocr.ocrError = Exception('Not enough memory to load the AI model.');
      seed(
        const ProcessingState(
          sessions: [pending],
          sessionImagePaths: {
            's1': ['/p.jpg'],
          },
        ),
      );

      final status = await endStatus(const MappingInitiated(sessionId: 's1'));

      expect((status as Failure).reason, PipelineFailureReason.notEnoughMemory);
      expect(status.error, contains('Not enough memory'));
      expect(bloc.state.sessions.single.status, ProcessingStatus.pending);
      expect(repository.edited.last.status, ProcessingStatus.pending);
    });

    test('a too-long input is a capacity failure', () async {
      ocr.ocrError = Exception('maxTokens exceeded');
      seed(
        const ProcessingState(
          sessions: [pending],
          sessionImagePaths: {
            's1': ['/p.jpg'],
          },
        ),
      );

      final status = await endStatus(const MappingInitiated(sessionId: 's1'));

      expect(status, const PipelineStatus.capacityFailure(sessionId: 's1'));
    });
  });

  group('remaining resources', () {
    const extracted = ProcessingSession(
      id: 's1',
      filePaths: ['/p.jpg'],
      status: ProcessingStatus.patientExtracted,
    );

    test('an engine failure fails and goes back to the patient step', () async {
      repository.remainingError = Exception('boom');
      seed(const ProcessingState(sessions: [extracted]));

      final status = await endStatus(
        const ProcessRemainingResources(sessionId: 's1'),
      );

      expect(
        status,
        const PipelineStatus.failure(
          error: 'Exception: boom',
          reason: PipelineFailureReason.other,
        ),
      );
      expect(
        bloc.state.sessions.single.status,
        ProcessingStatus.patientExtracted,
      );
    });

    test('a too-long input is a capacity failure', () async {
      repository.remainingError = Exception('input is too long');
      seed(const ProcessingState(sessions: [extracted]));

      final status = await endStatus(
        const ProcessRemainingResources(sessionId: 's1'),
      );

      expect(status, const PipelineStatus.capacityFailure(sessionId: 's1'));
    });
  });

  test('a failed save fails with the exception reason', () async {
    const draft = ProcessingSession(
      id: 's1',
      status: ProcessingStatus.draft,
      resources: <MappingResource>[],
    );
    seed(const ProcessingState(sessions: [draft]));

    final status = await endStatus(
      const ResourceCreationInitiated(sessionId: 's1'),
    );

    final failure = status as Failure;
    expect(failure.reason, PipelineFailureReason.other);
    expect(failure.error, 'Exception: db closed');
  });
}
