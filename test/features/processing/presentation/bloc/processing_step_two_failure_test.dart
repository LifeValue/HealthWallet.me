import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/processing/domain/entity/extraction_output_mode.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_observation.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
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

const _glucose = MappingObservation(
  id: 'glucose',
  observationName: MappedProperty(value: 'Glucose'),
);
const _sodium = MappingObservation(
  id: 'sodium',
  observationName: MappedProperty(value: 'Sodium'),
);

/// Step two finds both records each time; [failures] makes the next runs
/// fail once they have found the first.
class _FakeProcessingRepository extends Fake implements ProcessingRepository {
  final edited = <ProcessingSession>[];
  var failures = 0;
  Exception failure = Exception('llama.cpp decode failed');

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
  }) async* {
    yield (const [_glucose], 0.5);
    if (failures > 0) {
      failures--;
      throw failure;
    }
    yield (const [_glucose, _sodium], 1.0);
  }
}

class _FakeOcrProcessingHelper extends Fake implements OcrProcessingHelper {
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

class _FakeSyncRepository extends Fake implements SyncRepository {}

class _FakeRecordsRepository extends Fake implements RecordsRepository {}

class _FakeDocumentReferenceService extends Fake
    implements DocumentReferenceService {}

class _FakeHolderSelection extends Fake implements HolderSelection {}

class _FakeHolderService extends Fake implements HolderService {}

const _patient = StagedPatient(
  draft: MappingPatient(id: 'p'),
  mode: ImportMode.createNew,
);
const _encounter = StagedEncounter(draft: MappingEncounter(id: 'e'));
const _report = StagedDiagnosticReport(
  draft: MappingDiagnosticReport(id: 'r'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeProcessingRepository repository;
  late ProcessingBloc bloc;

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
  });

  tearDown(() => bloc.close());

  void seed(ProcessingSession session) {
    // ignore: invalid_use_of_visible_for_testing_member
    bloc.emit(ProcessingState(sessions: [session]));
  }

  ProcessingSession session(String id) =>
      bloc.state.sessions.firstWhere((s) => s.id == id);

  ProcessingSession atStepOne({
    ProcessingOrigin origin = ProcessingOrigin.scan,
    List<MappingObservation> resources = const [],
  }) => ProcessingSession(
    id: 's',
    filePaths: const ['/docs/s.jpg'],
    status: ProcessingStatus.patientExtracted,
    origin: origin,
    patient: _patient,
    encounter: _encounter,
    diagnosticReport: _report,
    resources: resources,
  );

  group('step two failing', () {
    test('goes back to step one without its results, keeps the patient, '
        'visit and report, and is saved so', () async {
      repository.failures = 1;
      seed(atStepOne());

      bloc.add(const ProcessRemainingResources(sessionId: 's'));
      await pumpEventQueue();

      final failed = session('s');
      expect(failed.status, ProcessingStatus.patientExtracted);
      expect(failed.progress, 0.0);
      expect(failed.resources, isEmpty);
      expect(failed.patient, _patient);
      expect(failed.encounter, _encounter);
      expect(failed.diagnosticReport, _report);
      expect(repository.edited.last, failed);
      expect(bloc.state.status, isA<Failure>());
    });

    test('then a retry holds each record once', () async {
      repository.failures = 1;
      seed(atStepOne());
      bloc.add(const ProcessRemainingResources(sessionId: 's'));
      await pumpEventQueue();

      bloc.add(const ProcessRemainingResources(sessionId: 's'));
      await pumpEventQueue();

      expect(session('s').status, ProcessingStatus.draft);
      expect(session('s').resources.map((r) => r.id), ['glucose', 'sodium']);
      expect(repository.edited.last.resources.map((r) => r.id), [
        'glucose',
        'sodium',
      ]);
    });

    test('keeps the records the session had before it', () async {
      const own = MappingObservation(id: 'own');
      repository.failures = 1;
      seed(atStepOne(resources: const [own]));

      bloc.add(const ProcessRemainingResources(sessionId: 's'));
      await pumpEventQueue();
      expect(session('s').resources, [own]);

      bloc.add(const ProcessRemainingResources(sessionId: 's'));
      await pumpEventQueue();
      expect(session('s').resources.map((r) => r.id), [
        'own',
        'glucose',
        'sodium',
      ]);
    });

    test('for lack of room says so, without its results', () async {
      repository
        ..failures = 1
        ..failure = Exception('Input is too long');
      seed(atStepOne());

      bloc.add(const ProcessRemainingResources(sessionId: 's'));
      await pumpEventQueue();

      expect(
        bloc.state.status,
        const PipelineStatus.capacityFailure(sessionId: 's'),
      );
      expect(session('s').resources, isEmpty);
    });

    test('halts a handover, without its results', () async {
      repository.failures = 1;
      seed(atStepOne(origin: ProcessingOrigin.handover));

      bloc.add(const ProcessRemainingResources(sessionId: 's'));
      await pumpEventQueue();
      // The queue does not run it again by itself.
      bloc.add(
        const ProcessRemainingResources(sessionId: 's', automatic: true),
      );
      await pumpEventQueue();

      expect(session('s').status, ProcessingStatus.patientExtracted);
      expect(session('s').resources, isEmpty);
    });
  });
}
