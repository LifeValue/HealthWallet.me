// Runs the production document→FHIR pipeline over the benchmark dataset in
// the app's documents directory and writes one prediction record per document.
//
//   fvm flutter test integration_test/extraction_bench_test.dart -d macos \
//     [--no-uninstall on a phone, or the results are deleted with the app] \
//     --dart-define=BENCH_MODEL=qwen [--dart-define=BENCH_VISION=false] \
//     [--dart-define=BENCH_RUN_ID=<id>] [--dart-define=BENCH_LIMIT=<n>] \
//     [--dart-define=BENCH_COOLDOWN_S=<seconds>] [--dart-define=BENCH_GPU_LAYERS=<n>] \
//     [--dart-define=BENCH_OUTPUT=grammar|schema|schemaDraft]
//
// Input:  <documents>/extraction_bench/dataset/<split>/<docId>/
//         {document.pdf | page-*.png | page-*.jpg, meta.json}
// Output: <documents>/extraction_bench/results/<runId>/predictions.jsonl
// See tool/extraction_bench/README.md.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/features/processing/data/data_source/local/processing_local_data_source.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_data_source.dart';
import 'package:health_wallet/features/processing/data/repository/processing_repository_impl.dart';
import 'package:health_wallet/features/processing/domain/entity/extraction_output_mode.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';
import 'package:integration_test/integration_test.dart';
import 'package:llamadart/llamadart.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'extraction_bench/document_runner.dart';
import 'extraction_bench/native_log_capture.dart';
import 'extraction_bench/recording_data_source.dart';

const _model = String.fromEnvironment('BENCH_MODEL');
const _useVision = bool.fromEnvironment('BENCH_VISION', defaultValue: true);
const _runIdDefine = String.fromEnvironment('BENCH_RUN_ID');
const _limit = int.fromEnvironment('BENCH_LIMIT');
// Comma-separated document ids, e.g. to re-run the documents that errored.
const _docsDefine = String.fromEnvironment('BENCH_DOCS');
const _cooldownSeconds = int.fromEnvironment('BENCH_COOLDOWN_S');
// A string, so that 0 (CPU only) is distinguishable from unset.
const _gpuLayersDefine = String.fromEnvironment('BENCH_GPU_LAYERS');
// Empty: the app's aiOutputMode pref as it is.
const _outputDefine = String.fromEnvironment('BENCH_OUTPUT');

final _pageImage = RegExp(r'^page-(\d+)\.(png|jpe?g)$', caseSensitive: false);

/// Page images of a document: its rasterized PDF (production rasterizer) or
/// its `page-<n>` images in page-number order (page-2 before page-10).
Future<List<String>> _pages(BenchDoc doc, TextRecognitionService ocr) async {
  final pdf = File(p.join(doc.dir, 'document.pdf'));
  if (pdf.existsSync()) return ocr.convertPdfToImages(pdf.path);
  final numbered = <(int, String)>[
    for (final f in Directory(doc.dir).listSync().whereType<File>())
      if (_pageImage.firstMatch(p.basename(f.path)) case final m?)
        (int.parse(m.group(1)!), f.path),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, path) in numbered) path];
}

String _timestamp() => DateTime.now()
    .toUtc()
    .toIso8601String()
    .replaceAll(RegExp(r'[:.]'), '-')
    .substring(0, 19);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('extraction benchmark', (tester) async {
    final variant = AiModelVariant.values.firstWhereOrNull(
      (v) => v.name == _model,
    );
    if (variant == null) {
      fail(
        'Set --dart-define=BENCH_MODEL=<${AiModelVariant.values.map((v) => v.name).join('|')}> '
        '(got "$_model").',
      );
    }
    final gpuLayers = _gpuLayersDefine.isEmpty
        ? null
        : int.tryParse(_gpuLayersDefine);
    if (_gpuLayersDefine.isNotEmpty && (gpuLayers == null || gpuLayers < 0)) {
      fail(
        'BENCH_GPU_LAYERS must be a non-negative integer (got "$_gpuLayersDefine").',
      );
    }
    if (_outputDefine.isNotEmpty &&
        !ExtractionOutputMode.values.any((m) => m.name == _outputDefine)) {
      fail(
        'BENCH_OUTPUT must be one of ${ExtractionOutputMode.values.map((m) => m.name).join('|')} '
        '(got "$_outputDefine").',
      );
    }

    final documents = await getApplicationDocumentsDirectory();
    debugPrint('[bench] documents: ${documents.path}');
    final config = AiModelConfig.fromVariant(variant);
    final expected = [
      p.join(documents.path, 'ai_models', config.modelId),
      p.join(documents.path, 'ai_models', config.mmprojId),
    ];
    final missingModel = expected.where((f) => !File(f).existsSync()).toList();
    if (missingModel.isNotEmpty) {
      fail(
        'Model files for BENCH_MODEL=$_model not found: ${missingModel.join(', ')}. '
        'Download the model in the app or copy the files there (tool/extraction_bench/README.md).',
      );
    }

    final benchRoot = p.join(documents.path, 'extraction_bench');
    final datasetDir = Directory(p.join(benchRoot, 'dataset'));
    if (!datasetDir.existsSync()) {
      fail('Dataset not found at ${datasetDir.path}');
    }
    var docs = loadBenchDocs(datasetDir);
    if (docs.isEmpty) {
      fail('No documents (*/<docId>/meta.json) under ${datasetDir.path}');
    }
    if (_docsDefine.isNotEmpty) {
      final ids = _docsDefine.split(',').map((id) => id.trim()).toSet();
      docs = docs.where((d) => ids.contains(d.docId)).toList();
      if (docs.isEmpty) {
        fail('None of BENCH_DOCS ($_docsDefine) is in the dataset');
      }
    }
    if (_limit > 0) docs = docs.take(_limit).toList();

    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    if (!getIt.isRegistered<AppPlatform>()) {
      getIt.registerSingleton<AppPlatform>(
        isDesktop ? AppPlatform.desktop : AppPlatform.mobile,
      );
    }
    await configureDependencies();

    final prefs = getIt<SharedPreferences>();
    final previousModel = prefs.getString(SharedPrefsConstants.aiSelectedModel);
    final previousOutput = prefs.getString(SharedPrefsConstants.aiOutputMode);
    NativeLogCapture? nativeLog;
    Directory? workDir;
    // The finally restores both prefs, whatever fails after they are set.
    try {
      await prefs.setString(SharedPrefsConstants.aiSelectedModel, variant.name);
      if (_outputDefine.isNotEmpty) {
        await prefs.setString(SharedPrefsConstants.aiOutputMode, _outputDefine);
      }
      // Read back as ProcessingHandler reads it.
      final outputMode = ExtractionOutputMode.fromPref(
        prefs.getString(SharedPrefsConstants.aiOutputMode),
      );
      debugPrint('[bench] output mode: ${outputMode.name}');

      final runId = _runIdDefine.isNotEmpty
          ? _runIdDefine
          : '${variant.name}-${Platform.operatingSystem}-${_timestamp()}';
      final resultsDir = Directory(p.join(benchRoot, 'results', runId))
        ..createSync(recursive: true);
      // llama.cpp logs image-encode times only to stderr; see NativeLogCapture.
      try {
        nativeLog = NativeLogCapture.start(
          p.join(resultsDir.path, 'native.log'),
        );
      } catch (e) {
        debugPrint(
          '[bench] stderr capture unavailable, image-encode times will be n/a: $e',
        );
      }
      final recorder = RecordingAiInferenceDataSource(
        AiInferenceDataSourceImpl(prefs),
        gpuLayersOverride: gpuLayers,
        drainNativeLog: nativeLog?.drain,
      );
      final ocr = getIt<TextRecognitionService>();
      final repository = ProcessingRepositoryImpl(
        recorder,
        getIt<ProcessingLocalDataSource>(),
        ocr,
        getIt<PathResolver>(),
      );
      await LlamaLogging.configure(
        level: LlamaLogLevel.info,
        handler: recorder.onLog,
      );

      final output = File(p.join(resultsDir.path, 'predictions.jsonl'));
      workDir = Directory(p.join(resultsDir.path, 'pages'))
        ..createSync(recursive: true);

      // ProcessingHandler passes the tuning prefs on mobile and null on desktop.
      int? pref(String key) => isDesktop ? null : prefs.getInt(key);

      for (final (index, doc) in docs.indexed) {
        debugPrint(
          '[bench] ${index + 1}/${docs.length} ${doc.docId} (${doc.degradation})',
        );
        final record = await runBenchDocument(
          doc: doc,
          repository: repository,
          recorder: recorder,
          pages: (d) => _pages(d, ocr),
          workDir: workDir.path,
          runId: runId,
          model: variant.name,
          useVision: _useVision,
          pref: pref,
          outputMode: outputMode,
        );
        await record.appendTo(output);

        if (_cooldownSeconds > 0 && index < docs.length - 1) {
          await Future<void>.delayed(const Duration(seconds: _cooldownSeconds));
        }
      }
      debugPrint('[bench] wrote ${output.path}');
    } finally {
      await LlamaLogging.configure();
      nativeLog?.stop();
      if (previousModel == null) {
        await prefs.remove(SharedPrefsConstants.aiSelectedModel);
      } else {
        await prefs.setString(
          SharedPrefsConstants.aiSelectedModel,
          previousModel,
        );
      }
      if (previousOutput == null) {
        await prefs.remove(SharedPrefsConstants.aiOutputMode);
      } else {
        await prefs.setString(
          SharedPrefsConstants.aiOutputMode,
          previousOutput,
        );
      }
      if (workDir != null && workDir.existsSync()) {
        workDir.deleteSync(recursive: true);
      }
    }
  }, timeout: Timeout.none);
}
