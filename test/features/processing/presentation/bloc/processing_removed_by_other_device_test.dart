import 'dart:async';

import 'package:flutter/widgets.dart' hide Notification;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/processing/domain/entity/extraction_output_mode.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_observation.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extraction_service.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extractor_registry.dart';
import 'package:health_wallet/features/processing/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fake_device_capability_service.dart';

final _en = lookupAppLocalizations(const Locale('en'));
final _handover = _en.processingOriginHandover;

class _FakeProcessingRepository extends Fake implements ProcessingRepository {
  final edited = <ProcessingSession>[];
  final deleted = <ProcessingSession>[];
  final basicInfoReads = <List<String>>[];

  /// Holds the step-one AI call until completed.
  final basicInfoGate = Completer<void>();

  /// Holds the stop of the AI (the cancelled run ending) until completed.
  final stopGate = Completer<void>();

  /// The step-two stream, fed by each test.
  // ignore: close_sinks, closed in the test or its tearDown.
  final remaining = StreamController<MappingResourcesWithProgress>();

  @override
  bool get shouldCancelGeneration => false;

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
  Future<void> cancelGeneration() async {}

  @override
  Future<void> waitForStreamCompletion() => stopGate.future;

  @override
  Future<void> disposeModel() async {}

  @override
  Future<bool> checkModelExistence() async => true;

  @override
  Future<(MappingPatient, MappingResource)> mapBasicInfo(
    List<String> imagePaths, {
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
    ExtractionOutputMode outputMode = ExtractionOutputMode.defaultMode,
  }) async {
    basicInfoReads.add(imagePaths);
    await basicInfoGate.future;
    return (
      const MappingPatient(id: 'p'),
      const MappingEncounter(id: 'e'),
    );
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
  }) => remaining.stream;
}

class _FakeOcrProcessingHelper extends Fake implements OcrProcessingHelper {
  final discarded = <({String sessionId, List<String> pages})>[];

  @override
  Future<String> processOcrForImages(List<String> imagePaths) async =>
      'Discharge letter';

  @override
  Future<List<String>> prepareAllImages({
    required List<String> filePaths,
    double dpi = 72,
  }) async => filePaths;

  @override
  Future<Map<String, String>> prepareOcrPages({
    required String sessionId,
    required List<String> filePaths,
    required List<String> previewPaths,
  }) async => const {};

  @override
  Future<void> discardSessionPages({
    required String sessionId,
    Iterable<String> pages = const [],
  }) async => discarded.add((sessionId: sessionId, pages: pages.toList()));
}

class _FakeRecordsRepository extends Fake implements RecordsRepository {}

/// Nobody in the wallet yet.
class _FakeHolderService extends Fake implements HolderService {
  @override
  Future<HolderDirectory> load() async => const HolderDirectory();
}

class _FakeHolderSelection extends Fake implements HolderSelection {}

class _FakeSyncRepository extends Fake implements SyncRepository {}

class _FakeDocumentReferenceService extends Fake
    implements DocumentReferenceService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeProcessingRepository repository;
  late _FakeOcrProcessingHelper ocr;
  late ProcessingBloc bloc;
  late List<ProcessingState> states;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repository = _FakeProcessingRepository();
    ocr = _FakeOcrProcessingHelper();
    bloc = ProcessingBloc(
      repository,
      ocr,
      _FakeSyncRepository(),
      _FakeDocumentReferenceService(),
      _FakeHolderService(),
      _FakeHolderSelection(),
      _FakeRecordsRepository(),
      prefs,
      AppStringsProvider.forLocale(const Locale('en')),
      LayoutExtractionService(
        repository,
        ocr,
        LayoutExtractorRegistry(const []),
        _FakeHolderService(),
        _FakeRecordsRepository(),
      ),
      FakeDeviceCapabilityService(),
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

  const patient = StagedPatient(
    draft: MappingPatient(id: 'p'),
    mode: ImportMode.createNew,
  );

  /// The handover `h`, with its preview and 200 dpi OCR page, next to a
  /// document of this device's own.
  ProcessingState withHandover(ProcessingStatus status) => ProcessingState(
    sessions: [
      ProcessingSession(
        id: 'h',
        filePaths: const ['/docs/h.pdf'],
        status: status,
        origin: ProcessingOrigin.handover,
        patient: status == ProcessingStatus.pending
            ? const StagedPatient()
            : patient,
      ),
      const ProcessingSession(
        id: 'own',
        filePaths: ['/docs/own.pdf'],
        status: ProcessingStatus.draft,
      ),
    ],
    sessionImagePaths: const {
      'h': ['/cache/h-preview.png'],
      'own': ['/cache/own-preview.png'],
    },
    ocrPageByPreviewPath: const {
      '/cache/h-preview.png': '/cache/h-ocr.png',
      '/cache/own-preview.png': '/cache/own-ocr.png',
    },
  );

  Iterable<String?> notifications() =>
      states.map((s) => s.notification?.text).nonNulls;

  void expectRemovedWithItsPages() {
    expect(bloc.state.sessions.map((s) => s.id), ['own']);
    expect(repository.deleted.map((s) => s.id), ['h']);
    expect(bloc.state.sessionImagePaths.keys, ['own']);
    expect(bloc.state.ocrPageByPreviewPath, {
      '/cache/own-preview.png': '/cache/own-ocr.png',
    });
    expect(bloc.state.stoppingSessionIds, isEmpty);
    final discarded = ocr.discarded.single;
    expect(discarded.sessionId, 'h');
    expect(
      discarded.pages,
      containsAll([
        '/cache/h-preview.png',
        '/cache/h-ocr.png',
        '/docs/h.pdf',
      ]),
    );
  }

  group('removed by the other device', () {
    test('a handover taken back while its patient is read stages nothing, '
        'announces nothing, and its pages are deleted', () async {
      seed(withHandover(ProcessingStatus.pending));
      bloc.add(const MappingInitiated(sessionId: 'h'));
      await settle();
      expect(repository.basicInfoReads, hasLength(1));

      bloc.add(const SessionTakenBack(sessionId: 'h'));
      await settle();
      // The AI returns while it is being stopped.
      repository.basicInfoGate.complete();
      await settle();
      repository.stopGate.complete();
      await settle();

      expect(
        notifications(),
        isNot(contains(_en.processingPatientInfoExtracted(_handover))),
      );
      expect(notifications().last, _en.handoverTakenBack);
      expect(
        repository.edited.map((s) => s.status),
        isNot(contains(ProcessingStatus.patientExtracted)),
      );
      expectRemovedWithItsPages();
    });

    test('a handover taken back while its records are read saves nothing and '
        'announces nothing', () async {
      seed(withHandover(ProcessingStatus.patientExtracted));
      bloc.add(const ProcessRemainingResources(sessionId: 'h'));
      await settle();

      bloc.add(const SessionTakenBack(sessionId: 'h'));
      await settle();
      // A partial result, then the stopped generation ends the stream.
      repository.remaining.add((
        [
          const MappingObservation(
            id: 'o',
            observationName: MappedProperty(value: 'Glucose'),
          ),
        ],
        0.5,
      ));
      await repository.remaining.close();
      await settle();
      repository.stopGate.complete();
      await settle();

      expect(
        notifications(),
        isNot(contains(_en.processingFinished(_handover))),
      );
      expect(
        repository.edited.map((s) => s.status),
        isNot(contains(ProcessingStatus.draft)),
      );
      expect(
        repository.edited.where((s) => s.resources.isNotEmpty),
        isEmpty,
      );
      expectRemovedWithItsPages();
    });

    test('a handover saved on the phone while its records are read saves '
        'nothing more, and its pages are deleted', () async {
      seed(withHandover(ProcessingStatus.patientExtracted));
      bloc.add(const ProcessRemainingResources(sessionId: 'h'));
      await settle();

      bloc.add(const SessionSavedElsewhere(sessionId: 'h', byDesktop: false));
      await settle();
      await repository.remaining.close();
      await settle();
      repository.stopGate.complete();
      await settle();

      expect(
        notifications(),
        isNot(contains(_en.processingFinished(_handover))),
      );
      expect(notifications().last, _en.handoverSavedOnPhone(_handover));
      expect(
        repository.edited.map((s) => s.status),
        isNot(contains(ProcessingStatus.draft)),
      );
      expectRemovedWithItsPages();
    });

    test('a handover saved elsewhere while it waits has its pages '
        'deleted', () async {
      repository.stopGate.complete();
      seed(withHandover(ProcessingStatus.handedOver));

      bloc.add(const SessionSavedElsewhere(sessionId: 'h', byDesktop: true));
      await settle();

      expectRemovedWithItsPages();
    });

    test('the next waiting document starts once a handover being read is '
        'taken back', () async {
      seed(
        withHandover(ProcessingStatus.pending).copyWith(
          sessions: [
            ...withHandover(ProcessingStatus.pending).sessions,
            const ProcessingSession(id: 'next', filePaths: ['/docs/next.jpg']),
          ],
        ),
      );
      bloc.add(const MappingInitiated(sessionId: 'h'));
      await settle();

      bloc.add(const SessionTakenBack(sessionId: 'h'));
      await settle();
      repository.basicInfoGate.complete();
      repository.stopGate.complete();
      await settle();

      expect(bloc.state.sessionImagePaths['next'], ['/docs/next.jpg']);
    });
  });
}
