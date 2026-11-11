import 'dart:convert';

import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_data_source.dart';
import 'package:health_wallet/features/processing/data/model/generation_stats.dart';
import 'package:llamadart/llamadart.dart';

/// One model call made while processing a document.
class GenerationLog {
  GenerationLog({required this.phase, required this.mode});

  /// `basic` (phase 1) or `remaining` (phase 2), set by the runner.
  final String phase;
  final GenerationMode mode;

  /// How the call was constrained: `grammar`, `schema` (a `json_schema`
  /// response format) or `none` (a schemaDraft draft call).
  String constraint = 'none';
  String? rawOutput;
  bool strictJsonValid = false;
  GenerationStats? stats;

  /// Sum of llama.cpp mtmd `image slice encoded in N ms` lines written to
  /// stderr during the call; null when none were seen.
  double? imageEncodeMs;

  /// Sum of mtmd `image decoded (batch i/n) in N ms` lines; null when none.
  double? imageDecodeMs;
  String? error;

  Map<String, dynamic> toJson() => {
    'phase': phase,
    'mode': mode.name,
    'strictJsonValid': strictJsonValid,
    'promptTokens': stats?.promptTokens,
    'completionTokens': stats?.completionTokens,
    'timeToFirstTokenMs': stats?.timeToFirstTokenMs,
    'promptEvalMs': stats?.promptEvalMs,
    'durationMs': stats?.durationMs,
    'finishReason': stats?.finishReason,
    'constraint': constraint,
    'imageEncodeMs': imageEncodeMs,
    'imageDecodeMs': imageDecodeMs,
    'rawOutput': rawOutput,
    if (error != null) 'error': error,
  };
}

/// Wraps the production [AiInferenceDataSource] and records every generation:
/// raw output, whether it is strict JSON as produced, the call's
/// [GenerationStats], and image-encode times from llama.cpp's native log
/// (read through [drainNativeLog] after each call). Behaviour is otherwise
/// passed through unchanged.
class RecordingAiInferenceDataSource implements AiInferenceDataSource {
  RecordingAiInferenceDataSource(
    this._inner, {
    this.gpuLayersOverride,
    this.drainNativeLog,
  });

  final AiInferenceDataSource _inner;

  /// Returns the native log written since the last call
  /// (`NativeLogCapture.drain`); null when stderr is not captured.
  final String Function()? drainNativeLog;

  /// When set, replaces the GPU layers of every model load, text and vision;
  /// the pipeline's text paths otherwise never pass any (auto config).
  final int? gpuLayersOverride;

  /// Label stored on the next generations.
  String phase = '';
  final List<GenerationLog> generations = [];
  GenerationLog? _current;

  static final _sliceEncoded = RegExp(
    r'image slice encoded in (\d+(?:\.\d+)?) ms',
  );
  static final _imageDecoded = RegExp(
    r'image decoded \(batch \d+/\d+\) in (\d+(?:\.\d+)?) ms',
  );

  /// Starts a new document: clears the recorded generations and discards the
  /// native log written before it.
  void beginDocument() {
    drainNativeLog?.call();
    generations.clear();
    _current = null;
    phase = '';
  }

  /// Handler for `LlamaLogging.configure`: Dart-side records. llama.cpp's own
  /// lines go to stderr and arrive through [drainNativeLog] instead.
  void onLog(LlamaLogRecord record) {
    final current = _current;
    if (current != null) _parseNativeLog(current, record.message);
  }

  static void _parseNativeLog(GenerationLog log, String text) {
    for (final line in text.split('\n')) {
      final enc = _sliceEncoded.firstMatch(line);
      if (enc != null) {
        log.imageEncodeMs =
            (log.imageEncodeMs ?? 0) + double.parse(enc.group(1)!);
      }
      final dec = _imageDecoded.firstMatch(line);
      if (dec != null) {
        log.imageDecodeMs =
            (log.imageDecodeMs ?? 0) + double.parse(dec.group(1)!);
      }
    }
  }

  /// True when [output], exactly as produced, decodes to a JSON array or
  /// object (bare `null`, strings and numbers don't count).
  static bool isStrictJson(String? output) {
    if (output == null) return false;
    try {
      final decoded = jsonDecode(output);
      return decoded is List || decoded is Map;
    } on FormatException {
      return false;
    }
  }

  Future<String?> _record(
    GenerationMode mode,
    Future<String?> Function() call, {
    String? grammar,
    Map<String, dynamic>? responseFormat,
  }) async {
    final log = GenerationLog(phase: phase, mode: mode)
      ..constraint = responseFormat != null
          ? 'schema'
          : grammar != null
          ? 'grammar'
          : 'none';
    generations.add(log);
    _current = log;
    try {
      final output = await call();
      log
        ..rawOutput = output
        ..strictJsonValid = isStrictJson(output)
        ..stats = _inner.lastGenerationStats;
      return output;
    } catch (e) {
      log.error = e.toString();
      rethrow;
    } finally {
      // The call's lines, plus any model-load output since the last call.
      final native = drainNativeLog?.call();
      if (native != null) _parseNativeLog(log, native);
      _current = null;
    }
  }

  @override
  Future<String?> runVisionPrompt({
    required String prompt,
    required List<String> imagePaths,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
  }) => _record(
    GenerationMode.vision,
    () => _inner.runVisionPrompt(
      prompt: prompt,
      imagePaths: imagePaths,
      maxTokens: maxTokens,
      grammar: grammar,
      responseFormat: responseFormat,
    ),
    grammar: grammar,
    responseFormat: responseFormat,
  );

  @override
  Future<String?> runTextPrompt({
    required String prompt,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
    Map<String, dynamic>? chatTemplateKwargs,
  }) => _record(
    GenerationMode.text,
    () => _inner.runTextPrompt(
      prompt: prompt,
      maxTokens: maxTokens,
      grammar: grammar,
      responseFormat: responseFormat,
      chatTemplateKwargs: chatTemplateKwargs,
    ),
    grammar: grammar,
    responseFormat: responseFormat,
  );

  @override
  GenerationStats? get lastGenerationStats => _inner.lastGenerationStats;

  @override
  PromptFamily get promptFamily => _inner.promptFamily;

  @override
  int get visionPagesPerBatch => _inner.visionPagesPerBatch;

  @override
  Future<void> initModel({
    bool withVision = true,
    int? contextSize,
    int? gpuLayers,
    int? threads,
  }) => _inner.initModel(
    withVision: withVision,
    contextSize: contextSize,
    gpuLayers: gpuLayersOverride ?? gpuLayers,
    threads: threads,
  );

  @override
  Future<void> disposeModel() => _inner.disposeModel();

  @override
  void cancelGeneration() => _inner.cancelGeneration();

  @override
  Future<({int availableMB, int requiredMB, bool canProceed})>
  checkMemoryHealth({
    bool withVision = true,
    int? contextSize,
  }) => _inner.checkMemoryHealth(
    withVision: withVision,
    contextSize: contextSize,
  );

  @override
  bool isVisionModelAvailable() => _inner.isVisionModelAvailable();

  @override
  Future<bool> checkModelExistence() => _inner.checkModelExistence();

  @override
  Future<bool> checkMmprojExistence() => _inner.checkMmprojExistence();

  @override
  Future<bool> checkModelExistenceForVariant(AiModelVariant variant) =>
      _inner.checkModelExistenceForVariant(variant);

  @override
  Future<bool> checkMmprojExistenceForVariant(AiModelVariant variant) =>
      _inner.checkMmprojExistenceForVariant(variant);

  @override
  Future<void> deleteModelForVariant(AiModelVariant variant) =>
      _inner.deleteModelForVariant(variant);

  @override
  Future<void> cancelModelDownloadForVariant(AiModelVariant variant) =>
      _inner.cancelModelDownloadForVariant(variant);

  @override
  Future<void> cancelMmprojDownloadForVariant(AiModelVariant variant) =>
      _inner.cancelMmprojDownloadForVariant(variant);

  @override
  Future<void> downloadModel({required void Function(int) onProgress}) =>
      _inner.downloadModel(onProgress: onProgress);

  @override
  Future<void> downloadMmproj({required void Function(int) onProgress}) =>
      _inner.downloadMmproj(onProgress: onProgress);

  @override
  Future<void> downloadModelForVariant(
    AiModelVariant variant, {
    required void Function(int) onProgress,
  }) => _inner.downloadModelForVariant(variant, onProgress: onProgress);

  @override
  Future<void> downloadMmprojForVariant(
    AiModelVariant variant, {
    required void Function(int) onProgress,
  }) => _inner.downloadMmprojForVariant(variant, onProgress: onProgress);
}
