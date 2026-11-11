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
import '../../../share_records/share_test_helpers.dart';

/// Holds the sessions saved before the app was killed; step two finds one
/// record.
class _FakeProcessingRepository extends Fake implements ProcessingRepository {
  List<ProcessingSession> saved = const [];
  final edited = <ProcessingSession>[];
  Exception? editError;

  @override
  Future<List<ProcessingSession>> getProcessingSessions() async => saved;

  @override
  Future<int> editProcessingSession(ProcessingSession session) async {
    if (editError != null) throw editError!;
    edited.add(session);
    return 1;
  }

  @override
  Future<bool> checkModelExistence() async => true;

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
  }) => Stream.value((
    [
      const MappingObservation(
        id: 'found-again',
        observationName: MappedProperty(value: 'Glucose'),
      ),
    ],
    1.0,
  ));
}

class _FakeOcrProcessingHelper extends Fake implements OcrProcessingHelper {
  @override
  Future<List<String>> prepareAllImages({
    required List<String> filePaths,
    double dpi = 72,
  }) async => filePaths;
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
    mockPathProvider();
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

  ProcessingSession session(String id) =>
      bloc.state.sessions.firstWhere((s) => s.id == id);

  group('a session the app was killed in, on the next start', () {
    test('in step two goes back to step one without step two\'s results, '
        'keeps the patient, visit and report, and is saved so', () async {
      repository.saved = [
        const ProcessingSession(
          id: 's',
          filePaths: ['s.jpg'],
          status: ProcessingStatus.processing,
          progress: 0.6,
          patient: _patient,
          encounter: _encounter,
          diagnosticReport: _report,
          resources: [MappingObservation(id: 'partial')],
        ),
      ];

      bloc.add(const ProcessingInitialised());
      await pumpEventQueue();

      final restored = session('s');
      expect(restored.status, ProcessingStatus.patientExtracted);
      expect(restored.progress, 0.0);
      expect(restored.resources, isEmpty);
      expect(restored.patient, _patient);
      expect(restored.encounter, _encounter);
      expect(restored.diagnosticReport, _report);
      // Saved, so the partial results don't come back with a later start.
      expect(repository.edited, [restored]);
    });

    test('in step two still loads at step one when saving it fails', () async {
      repository
        ..editError = Exception('db locked')
        ..saved = [
          const ProcessingSession(
            id: 's',
            status: ProcessingStatus.processing,
            patient: _patient,
            resources: [MappingObservation(id: 'partial')],
          ),
        ];

      bloc.add(const ProcessingInitialised());
      await pumpEventQueue();

      expect(bloc.state.status, const PipelineStatus.initial());
      expect(session('s').status, ProcessingStatus.patientExtracted);
      expect(session('s').resources, isEmpty);
    });

    test('in step one waits to start again, and finished sessions are left '
        'as they are', () async {
      repository.saved = [
        const ProcessingSession(
          id: 'patient-step',
          status: ProcessingStatus.processingPatient,
          progress: 0.4,
        ),
        const ProcessingSession(
          id: 'draft',
          status: ProcessingStatus.draft,
          progress: 1,
          patient: _patient,
          resources: [MappingObservation(id: 'kept')],
        ),
      ];

      bloc.add(const ProcessingInitialised());
      await pumpEventQueue();

      expect(session('patient-step').status, ProcessingStatus.pending);
      expect(session('patient-step').progress, 0.0);
      expect(session('draft'), repository.saved.last);
      expect(repository.edited.map((s) => s.id), isNot(contains('draft')));
    });

    test(
      'a handover in step two on the desktop reads its records again '
      'from none, so the draft the phone gets holds each record once',
      () async {
        repository.saved = [
          const ProcessingSession(
            id: 'h',
            filePaths: ['h.jpg'],
            status: ProcessingStatus.processing,
            progress: 0.5,
            origin: ProcessingOrigin.handover,
            patient: _patient,
            resources: [MappingObservation(id: 'partial')],
          ),
        ];

        bloc.add(const ProcessingInitialised());
        await pumpEventQueue();

        expect(session('h').status, ProcessingStatus.draft);
        expect(session('h').resources.map((r) => r.id), ['found-again']);
        expect(session('h').patient, _patient);
      },
    );
  });
}
