import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/features/processing/data/data_source/local/processing_local_data_source.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_data_source.dart';
import 'package:health_wallet/features/processing/data/model/generation_stats.dart';
import 'package:health_wallet/features/processing/data/repository/processing_repository_impl.dart';
import 'package:health_wallet/features/processing/domain/entity/extraction_output_mode.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_condition.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';

import '../../../../helpers/log_capture.dart';
import '../../../share_records/share_test_helpers.dart';

const _variant = AiModelVariant.qwen;

class _FakeLocalDataSource extends Fake implements ProcessingLocalDataSource {
  final cached = <ProcessingSessionsCompanion>[];
  final updated = <(String, ProcessingSessionsCompanion)>[];
  List<ProcessingSessionDto> stored = [];

  @override
  Future<int> cacheProcessingSession(
    ProcessingSessionsCompanion entity,
  ) async {
    cached.add(entity);
    return 1;
  }

  @override
  Future<List<ProcessingSessionDto>> getProcessingSessions() async => stored;

  @override
  Future<int> updateProcessingSession(
    String id,
    ProcessingSessionsCompanion entity,
  ) async {
    updated.add((id, entity));
    return 7;
  }
}

/// Reports a fixed OCR text; [gate], when set, holds the OCR until it
/// completes, so a test can act while a mapping stream is running.
class _FakeOcr extends Fake implements TextRecognitionService {
  _FakeOcr(this.text);

  final String text;
  Completer<void>? gate;
  var calls = 0;

  @override
  Future<String> recognizeTextFromImage(String imagePath) async {
    calls++;
    await gate?.future;
    return text;
  }
}

/// A download the test drives: [start] records the progress callback and
/// returns a future the test completes or fails.
class _Transfer {
  void Function(int)? onProgress;
  final done = Completer<void>();
  var cancels = 0;

  /// Completes the cancel call; null makes the cancel complete at once.
  Completer<void>? cancelGate;
  Error? cancelError;

  Future<void> start(void Function(int) onProgress) {
    this.onProgress = onProgress;
    return done.future;
  }

  Future<void> cancel() async {
    cancels++;
    await cancelGate?.future;
    if (cancelError != null) throw cancelError!;
    // The real data source fails the interrupted download.
    if (!done.isCompleted) done.completeError(StateError('cancelled'));
  }
}

class _FakeNetwork extends Fake implements AiInferenceDataSource {
  final model = _Transfer();
  final mmproj = _Transfer();
  final modelCancels = <AiModelVariant>[];
  final mmprojCancels = <AiModelVariant>[];
  final deleted = <AiModelVariant>[];
  final initLoads = <({bool withVision, int? ctx, int? gpu, int? threads})>[];
  Error? initError;
  bool modelExists = false;
  bool mmprojExists = false;
  var disposes = 0;
  var textPrompts = 0;
  var visionPrompts = 0;

  @override
  Future<bool> checkModelExistence() async => modelExists;

  @override
  Future<void> downloadModelForVariant(
    AiModelVariant variant, {
    required void Function(int) onProgress,
  }) => model.start(onProgress);

  @override
  Future<void> downloadMmprojForVariant(
    AiModelVariant variant, {
    required void Function(int) onProgress,
  }) => mmproj.start(onProgress);

  @override
  Future<void> cancelModelDownloadForVariant(AiModelVariant variant) {
    modelCancels.add(variant);
    return model.cancel();
  }

  @override
  Future<void> cancelMmprojDownloadForVariant(AiModelVariant variant) {
    mmprojCancels.add(variant);
    return mmproj.cancel();
  }

  @override
  Future<bool> checkModelExistenceForVariant(AiModelVariant variant) async =>
      modelExists;

  @override
  Future<bool> checkMmprojExistenceForVariant(AiModelVariant variant) async =>
      mmprojExists;

  @override
  Future<void> deleteModelForVariant(AiModelVariant variant) async =>
      deleted.add(variant);

  @override
  Future<void> disposeModel() async => disposes++;

  @override
  PromptFamily get promptFamily => PromptFamily.standard;

  @override
  int get visionPagesPerBatch => 2;

  @override
  GenerationStats? get lastGenerationStats => null;

  @override
  Future<void> initModel({
    bool withVision = true,
    int? contextSize,
    int? gpuLayers,
    int? threads,
  }) async {
    initLoads.add((
      withVision: withVision,
      ctx: contextSize,
      gpu: gpuLayers,
      threads: threads,
    ));
    if (initError != null) throw initError!;
  }

  @override
  Future<String?> runVisionPrompt({
    required String prompt,
    required List<String> imagePaths,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
  }) async {
    visionPrompts++;
    return '[]';
  }

  @override
  Future<String?> runTextPrompt({
    required String prompt,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
    Map<String, dynamic>? chatTemplateKwargs,
  }) async {
    textPrompts++;
    return '[{"resourceType":"Condition","conditionName":"Vorhofflimmern",'
        '"onsetDateTime":"2019","clinicalStatus":"active"}]';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final logs = captureLogs();
  late Directory root;
  late String docs;
  late _FakeLocalDataSource local;
  late _FakeNetwork network;
  late _FakeOcr ocr;
  late ProcessingRepositoryImpl repository;

  setUp(() {
    root = mockPathProvider();
    docs = '${root.path}/Documents';
    local = _FakeLocalDataSource();
    network = _FakeNetwork();
    ocr = _FakeOcr('Diagnosen: Vorhofflimmern seit 2019.');
    repository = ProcessingRepositoryImpl(network, local, ocr, PathResolver());
  });

  test('exposes its data source and OCR service to the extraction mixin', () {
    expect(repository.networkDataSource, same(network));
    expect(repository.textRecognitionService, same(ocr));
    expect(repository.shouldCancelGeneration, isFalse);
  });

  group('saveScannedDocument', () {
    test('copies the scan into scanned_documents and returns its relative '
        'path', () async {
      final source = File('${root.path}/tmp/scan.jpg')
        ..writeAsStringSync('jpeg');

      final saved = await repository.saveScannedDocument(source.path);

      expect(saved, matches(RegExp(r'^scanned_documents/document_\d+\.jpg$')));
      expect(File('$docs/$saved').readAsStringSync(), 'jpeg');
      expect(source.existsSync(), isTrue);
    });

    test('a missing source is an error and writes nothing', () async {
      await expectLater(
        repository.saveScannedDocument('${root.path}/tmp/gone.jpg'),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            allOf(
              contains('Failed to save document'),
              contains('Source file does not exist'),
            ),
          ),
        ),
      );
      expect(
        Directory('$docs/scanned_documents').listSync(),
        isEmpty,
        reason: 'the folder is made, but nothing is copied into it',
      );
    });
  });

  group('processing sessions', () {
    const oldContainer =
        '/var/mobile/Containers/Data/Application/OLD-ID/Documents/scans/b.jpg';

    test('a new session is stored with relative paths and returned with '
        'absolute ones', () async {
      final before = DateTime.now();

      final session = await repository.createProcessingSession(
        filePaths: ['$docs/imports/a.pdf', oldContainer],
        origin: ProcessingOrigin.import,
      );

      expect(session.id, isNotEmpty);
      expect(session.origin, ProcessingOrigin.import);
      expect(session.createdAt!.isBefore(before), isFalse);
      expect(session.filePaths, ['$docs/imports/a.pdf', '$docs/scans/b.jpg']);
      final stored = local.cached.single;
      expect(stored.id.value, session.id);
      expect(stored.origin.value, 'Import');
      expect(
        jsonDecode(stored.filePaths.value!),
        ['imports/a.pdf', 'scans/b.jpg'],
      );
    });

    test('two new sessions get different ids', () async {
      final a = await repository.createProcessingSession(
        filePaths: const [],
        origin: ProcessingOrigin.scan,
      );
      final b = await repository.createProcessingSession(
        filePaths: const [],
        origin: ProcessingOrigin.scan,
      );

      expect(a.id, isNot(b.id));
    });

    test('stored sessions are read back with absolute paths', () async {
      final createdAt = DateTime(2026, 1, 2);
      ProcessingSessionDto dto(String id, List<String> paths) {
        final c = ProcessingSession(
          id: id,
          filePaths: paths,
          origin: ProcessingOrigin.handover,
          createdAt: createdAt,
        ).toDbCompanion();
        return ProcessingSessionDto(
          id: c.id.value,
          filePaths: c.filePaths.value,
          resources: c.resources.value,
          status: c.status.value,
          origin: c.origin.value,
          createdAt: c.createdAt.value,
          patient: c.patient.value,
          encounter: c.encounter.value,
          isDocumentAttached: c.isDocumentAttached.value,
        );
      }

      local.stored = [
        dto('one', ['imports/a.pdf', '/elsewhere/b.jpg']),
        dto('two', []),
      ];

      final sessions = await repository.getProcessingSessions();

      expect(sessions.map((s) => s.id), ['one', 'two']);
      expect(sessions.first.filePaths, [
        '$docs/imports/a.pdf',
        '/elsewhere/b.jpg',
      ]);
      expect(sessions.first.origin, ProcessingOrigin.handover);
      expect(sessions.first.createdAt, createdAt);
      expect(sessions.last.filePaths, isEmpty);
    });

    test('an edited session is stored with relative paths', () async {
      final session = ProcessingSession(
        id: 's',
        filePaths: ['$docs/imports/a.pdf', 'imports/b.jpg'],
        status: ProcessingStatus.processing,
        createdAt: DateTime(2026),
      );

      final count = await repository.editProcessingSession(session);

      expect(count, 7);
      final (id, companion) = local.updated.single;
      expect(id, 's');
      expect(
        jsonDecode(companion.filePaths.value!),
        ['imports/a.pdf', 'imports/b.jpg'],
      );
      expect(companion.status.value, ProcessingStatus.processing.toString());
    });
  });

  group('downloadModelForVariant', () {
    test('reports progress and closes when the download ends', () async {
      final stream = repository.downloadModelForVariant(_variant);
      final expectation = expectLater(
        stream,
        emitsInOrder([5.0, 100.0, emitsDone]),
      );

      network.model.onProgress!(5);
      network.model.onProgress!(100);
      network.model.done.complete();
      await expectation;
      // A finished transfer is never cancelled, even though the stream's
      // cancel runs after its done event.
      await pumpEventQueue();
      expect(network.modelCancels, isEmpty);
    });

    test('a failed download is reported with its stack trace', () async {
      final trace = StackTrace.current;
      final errors = <(Object, StackTrace)>[];
      final done = Completer<void>();
      repository
          .downloadModelForVariant(_variant)
          .listen(
            (_) {},
            onError: (Object e, StackTrace s) => errors.add((e, s)),
            onDone: done.complete,
          );

      network.model.done.completeError(StateError('offline'), trace);
      await done.future;

      expect(errors.single.$1, isA<StateError>());
      expect(errors.single.$2, trace);
      expect(network.modelCancels, isEmpty);
    });

    test('cancelling stops the transfer and waits until it has '
        'ended', () async {
      network.model.cancelGate = Completer<void>();
      final sub = repository.downloadModelForVariant(_variant).listen((_) {});
      await pumpEventQueue();

      var cancelled = false;
      final cancel = sub.cancel().then((_) => cancelled = true);
      await pumpEventQueue();
      expect(network.modelCancels, [_variant]);
      expect(cancelled, isFalse);

      network.model.cancelGate!.complete();
      await cancel;
      expect(cancelled, isTrue);
      // Progress after the cancel goes nowhere and does not throw.
      network.model.onProgress!(50);
    });

    test('a cancel that fails is logged and the subscription still '
        'ends', () async {
      network.model.cancelError = StateError('stuck');
      final sub = repository.downloadModelForVariant(_variant).listen((_) {});
      await pumpEventQueue();

      await sub.cancel();

      expect(network.modelCancels, [_variant]);
      expect(logs, loggedWarning('Could not cancel the model download'));
    });
  });

  group('downloadMmprojForVariant', () {
    test('reports progress and closes when the download ends', () async {
      final stream = repository.downloadMmprojForVariant(_variant);
      final expectation = expectLater(
        stream,
        emitsInOrder([42.0, emitsDone]),
      );

      network.mmproj.onProgress!(42);
      network.mmproj.done.complete();
      await expectation;
      await pumpEventQueue();
      expect(network.mmprojCancels, isEmpty);
    });

    test('cancelling stops the vision transfer only', () async {
      final sub = repository.downloadMmprojForVariant(_variant).listen((_) {});
      await pumpEventQueue();

      await sub.cancel();

      expect(network.mmprojCancels, [_variant]);
      expect(network.modelCancels, isEmpty);
    });
  });

  group('model files', () {
    test('existence checks and deletes go to the data source', () async {
      expect(await repository.checkModelExistence(), isFalse);
      expect(await repository.checkModelExistenceForVariant(_variant), isFalse);
      expect(
        await repository.checkMmprojExistenceForVariant(_variant),
        isFalse,
      );

      network
        ..modelExists = true
        ..mmprojExists = true;
      expect(await repository.checkModelExistence(), isTrue);
      expect(await repository.checkModelExistenceForVariant(_variant), isTrue);
      expect(await repository.checkMmprojExistenceForVariant(_variant), isTrue);

      await repository.deleteModelForVariant(AiModelVariant.medGemma);
      expect(network.deleted, [AiModelVariant.medGemma]);

      await repository.disposeModel();
      expect(network.disposes, 1);
    });
  });

  group('mapBasicInfo', () {
    test('passes the model settings to the extraction and surfaces a model '
        'that fails to load', () async {
      // Short OCR text goes straight to the vision model.
      network.initError = StateError('no model');

      await expectLater(
        repository.mapBasicInfo(
          const ['page-1.png'],
          maxTokens: 300,
          gpuLayers: 12,
          threads: 3,
          contextSize: 4096,
          outputMode: ExtractionOutputMode.grammar,
        ),
        throwsA(isA<StateError>()),
      );

      expect(ocr.calls, 1);
      expect(network.initLoads.single, (
        withVision: true,
        ctx: 4096,
        gpu: 12,
        threads: 3,
      ));
    });
  });

  group('mapRemainingResources', () {
    test('streams the extracted resources and unloads the model at the '
        'end', () async {
      final events = await repository
          .mapRemainingResources(
            const ['page-1.png'],
            documentCategory: 'visit',
            outputMode: ExtractionOutputMode.grammar,
          )
          .toList();

      final (resources, progress) = events.last;
      expect(progress, 1.0);
      expect(resources.single, isA<MappingCondition>());
      expect(network.textPrompts, greaterThan(0));
      expect(network.disposes, greaterThan(0));
      expect(repository.shouldCancelGeneration, isFalse);
    });

    test('waitForStreamCompletion returns at once with no stream '
        'running', () async {
      await repository.waitForStreamCompletion().timeout(
        const Duration(seconds: 1),
      );
    });

    test('waitForStreamCompletion waits for the running stream to '
        'end', () async {
      ocr.gate = Completer<void>();
      final events = repository.mapRemainingResources(
        const ['page-1.png'],
        outputMode: ExtractionOutputMode.grammar,
      ).toList();
      await pumpEventQueue();
      expect(ocr.calls, 1);

      var waited = false;
      final wait = repository.waitForStreamCompletion().then(
        (_) => waited = true,
      );
      await pumpEventQueue();
      expect(waited, isFalse);

      ocr.gate!.complete();
      await events;
      await wait;
      expect(waited, isTrue);
      // Done now, so a later wait returns at once.
      await repository.waitForStreamCompletion().timeout(
        const Duration(seconds: 1),
      );
    });

    test('cancelGeneration stops before the next vision batch and is reset '
        'when the stream ends', () async {
      ocr.gate = Completer<void>();
      final events = repository
          .mapRemainingResources(
            const ['page-1.png', 'page-2.png'],
            useVision: true,
            outputMode: ExtractionOutputMode.grammar,
          )
          .toList();
      await pumpEventQueue();

      await repository.cancelGeneration();
      expect(repository.shouldCancelGeneration, isTrue);
      ocr.gate!.complete();

      expect(await events, isEmpty);
      expect(network.initLoads.single.withVision, isTrue);
      expect(network.visionPrompts, 0);
      expect(network.textPrompts, 0);
      expect(network.disposes, 1);
      expect(repository.shouldCancelGeneration, isFalse);
    });

    test('a new stream clears an earlier cancel', () async {
      await repository.cancelGeneration();

      final events = await repository.mapRemainingResources(
        const ['page-1.png'],
        outputMode: ExtractionOutputMode.grammar,
      ).toList();

      expect(events, isNotEmpty);
      expect(events.last.$1.single, isA<MappingCondition>());
    });
  });
}
