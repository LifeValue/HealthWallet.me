import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/features/processing/data/data_source/local/processing_local_data_source.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_data_source.dart';
import 'package:health_wallet/features/processing/data/model/generation_stats.dart';
import 'package:health_wallet/features/processing/data/repository/processing_repository_impl.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_observation.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';

import '../../../share_records/share_test_helpers.dart';

/// Page n of the document reads `TEST-n`.
class _PageOcr extends Fake implements TextRecognitionService {
  @override
  Future<String> recognizeTextFromImage(String imagePath) async {
    final n = RegExp(r'page-(\d+)').firstMatch(imagePath)!.group(1);
    return 'TEST-$n\n1\nmUI/mL';
  }
}

class _FakeLocalDataSource extends Fake implements ProcessingLocalDataSource {}

/// An engine like llama.cpp's: a prompt on an unloaded model fails with
/// "Model not initialized". The first vision prompt completes
/// [firstBatchStarted] and waits for [firstBatch], so a test can act while a
/// batch is generating. [log] lists what reached the engine, in order.
class _Engine extends Fake implements AiInferenceDataSource {
  final log = <String>[];
  final firstBatchStarted = Completer<void>();
  final firstBatch = Completer<void>();
  var _loaded = false;
  var _batches = 0;

  @override
  PromptFamily get promptFamily => PromptFamily.standard;

  @override
  int get visionPagesPerBatch => 2;

  @override
  GenerationStats? get lastGenerationStats => null;

  @override
  bool isVisionModelAvailable() => _loaded;

  @override
  Future<void> initModel({
    bool withVision = true,
    int? contextSize,
    int? gpuLayers,
    int? threads,
  }) async {
    _loaded = true;
    log.add('load');
  }

  @override
  Future<void> disposeModel() async {
    _loaded = false;
    log.add('dispose');
  }

  @override
  void cancelGeneration() => log.add('cancel');

  @override
  Future<({int availableMB, int requiredMB, bool canProceed})>
  checkMemoryHealth({
    bool withVision = true,
    int? contextSize,
  }) async => (availableMB: -1, requiredMB: 0, canProceed: true);

  String _answer(String prompt) => jsonEncode({
    'observations': [
      for (final name in RegExp(
        r'TEST-\d+',
      ).allMatches(prompt).map((m) => m.group(0)!).toSet())
        {
          'observationName': name,
          'value': '1',
          'unit': 'mUI/mL',
          'referenceRange': '',
        },
    ],
    'practitioners': [],
    'organizations': [],
  });

  @override
  Future<String?> runVisionPrompt({
    required String prompt,
    required List<String> imagePaths,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
  }) async {
    final batch = ++_batches;
    if (!_loaded) {
      log.add('batch $batch failed');
      throw StateError('Model not initialized');
    }
    log.add('batch $batch');
    if (batch == 1) {
      firstBatchStarted.complete();
      await firstBatch.future;
    }
    return _answer(prompt);
  }

  @override
  Future<String?> runTextPrompt({
    required String prompt,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
    Map<String, dynamic>? chatTemplateKwargs,
  }) async {
    log.add('text');
    return _answer(prompt);
  }
}

List<String> _names(List<MappingResource> resources) =>
    resources.whereType<MappingObservation>().map((o) {
      return o.observationName.value;
    }).toList()..sort();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Engine engine;
  late ProcessingRepositoryImpl repository;

  const pages = [
    'page-1.png',
    'page-2.png',
    'page-3.png',
    'page-4.png',
    'page-5.png',
    'page-6.png',
  ];

  setUp(() {
    // The processing log is written to Documents.
    mockPathProvider();
    engine = _Engine();
    repository = ProcessingRepositoryImpl(
      engine,
      _FakeLocalDataSource(),
      _PageOcr(),
      PathResolver(),
    );
  });

  /// Starts a records stream with three vision batches; its first batch
  /// generates until the test completes [_Engine.firstBatch].
  Future<List<MappingResourcesWithProgress>> startThreeBatches() =>
      repository.mapRemainingResources(pages, useVision: true).toList();

  group('disposeModel takes its turn', () {
    test('asked for during another session\'s records step, it waits for '
        'that step to end, so every batch runs', () async {
      final events = startThreeBatches();
      await engine.firstBatchStarted.future;

      // Another session's AI settings changed (TokenCapacityUpdated).
      var disposed = false;
      final dispose = repository.disposeModel().then((_) => disposed = true);
      await pumpEventQueue();
      expect(disposed, isFalse);
      expect(engine.log, ['load', 'batch 1']);

      engine.firstBatch.complete();
      final records = (await events).last.$1;
      await dispose;

      expect(_names(records), [
        'TEST-1',
        'TEST-2',
        'TEST-3',
        'TEST-4',
        'TEST-5',
        'TEST-6',
      ]);
      expect(engine.log, [
        'load',
        'batch 1',
        'batch 2',
        'batch 3',
        // The stream's own unload, then the one asked for.
        'dispose',
        'dispose',
      ]);
    });

    test('a step started after it waits for the unload', () async {
      final events = startThreeBatches();
      await engine.firstBatchStarted.future;
      final dispose = repository.disposeModel();
      final next = repository.mapRemainingResources(const [
        'page-1.png',
      ], useVision: true).toList();

      engine.firstBatch.complete();
      await events;
      await dispose;
      await next;

      expect(engine.log, [
        'load',
        'batch 1',
        'batch 2',
        'batch 3',
        'dispose',
        'dispose',
        'load',
        'batch 4',
        'dispose',
      ]);
    });

    test('a stop (cancel, wait, unload) ends the running step and then '
        'unloads', () async {
      final events = startThreeBatches();
      await engine.firstBatchStarted.future;

      await repository.cancelGeneration();
      engine.firstBatch.complete();
      await repository.waitForStreamCompletion();
      await repository.disposeModel();

      // Batch 1 had finished generating; the cancel stops the rest.
      expect(_names((await events).last.$1), ['TEST-1', 'TEST-2']);
      expect(engine.log, ['load', 'batch 1', 'cancel', 'dispose', 'dispose']);
      expect(repository.shouldCancelGeneration, isFalse);
    });

    test('with nothing running it unloads at once', () async {
      await repository.disposeModel();

      expect(engine.log, ['dispose']);
    });
  });
}
