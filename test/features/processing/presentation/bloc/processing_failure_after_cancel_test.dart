import 'dart:async';

import 'package:flutter/widgets.dart' hide Notification;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/processing/domain/entity/extraction_output_mode.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
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

/// Step one throws, and step two's stream fails, when each test says so.
class _FakeProcessingRepository extends Fake implements ProcessingRepository {
  final edited = <ProcessingSession>[];
  int basicInfoCalls = 0;

  /// Holds the step-one AI call until completed; it then throws.
  final basicInfoGate = Completer<void>();

  /// The step-two stream, fed by each test.
  // ignore: close_sinks, closed in the test's tearDown.
  final remaining = StreamController<MappingResourcesWithProgress>();

  @override
  bool get shouldCancelGeneration => false;

  @override
  Future<int> editProcessingSession(ProcessingSession session) async {
    edited.add(session);
    return 1;
  }

  @override
  Future<void> cancelGeneration() async {}

  @override
  Future<void> waitForStreamCompletion() async {}

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
    basicInfoCalls++;
    await basicInfoGate.future;
    // Loading the vision model failed after the cancel.
    throw Exception('Not enough memory');
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
  late ProcessingBloc bloc;
  late List<ProcessingState> states;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repository = _FakeProcessingRepository();
    final ocr = _FakeOcrProcessingHelper();
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

  ProcessingSession session(String id) =>
      bloc.state.sessions.firstWhere((s) => s.id == id);

  bool isFailure(PipelineStatus status) =>
      status is Failure || status is CapacityFailure;

  group('a failure after a cancel', () {
    test(
      'in step one keeps the session cancelled and out of the queue',
      () async {
        seed(
          const ProcessingState(
            sessions: [
              ProcessingSession(id: 's', filePaths: ['/s.jpg']),
            ],
            sessionImagePaths: {
              's': ['/s.jpg'],
            },
          ),
        );
        bloc.add(const MappingInitiated(sessionId: 's'));
        await settle();
        expect(session('s').status, ProcessingStatus.processingPatient);

        bloc.add(const MappingCancelled(sessionId: 's'));
        await settle();
        expect(session('s').status, ProcessingStatus.cancelled);
        final savedBeforeFailure = repository.edited.length;

        repository.basicInfoGate.complete();
        await settle();

        expect(session('s').status, ProcessingStatus.cancelled);
        expect(
          repository.edited.skip(savedBeforeFailure).map((s) => s.status),
          isNot(contains(ProcessingStatus.pending)),
        );
        expect(
          states.map((s) => s.status),
          isNot(contains(predicate(isFailure))),
        );
        // Nothing starts the AI on the cancelled document again.
        expect(repository.basicInfoCalls, 1);
      },
    );

    test(
      'in step two shows no failure and does not halt the handover',
      () async {
        seed(
          const ProcessingState(
            sessions: [
              ProcessingSession(
                id: 'h',
                filePaths: ['/h.jpg'],
                status: ProcessingStatus.patientExtracted,
                origin: ProcessingOrigin.handover,
                patient: StagedPatient(
                  draft: MappingPatient(id: 'p'),
                  mode: ImportMode.createNew,
                ),
                encounter: StagedEncounter(draft: MappingEncounter(id: 'e')),
              ),
            ],
            sessionImagePaths: {
              'h': ['/h.jpg'],
            },
          ),
        );
        bloc.add(const ProcessRemainingResources(sessionId: 'h'));
        await settle();
        expect(session('h').status, ProcessingStatus.processing);

        bloc.add(const MappingCancelled(sessionId: 'h'));
        await settle();
        expect(session('h').status, ProcessingStatus.patientExtracted);

        repository.remaining.addError(Exception('Not enough memory'));
        await settle();

        expect(session('h').status, ProcessingStatus.patientExtracted);
        expect(
          states.map((s) => s.status),
          isNot(contains(predicate(isFailure))),
        );
        expect(bloc.haltedHandovers, isNot(contains('h')));
      },
    );
  });
}
