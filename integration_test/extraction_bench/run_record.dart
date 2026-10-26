import 'dart:convert';
import 'dart:io';

import 'recording_data_source.dart';

/// One line of `predictions.jsonl`; the format `bench.dart score` reads.
class RunRecord {
  RunRecord({
    required this.docId,
    required this.runId,
    required this.model,
    required this.platform,
    required this.useVision,
    required this.predictedResources,
    required this.generations,
    required this.peakRssBytes,
    required this.wallMs,
    this.gpuLayers,
    this.pipelineLog = const [],
    this.mappingErrors = const [],
    this.error,
  });

  final String docId;
  final String runId;

  /// `AiModelVariant` name.
  final String model;

  /// `Platform.operatingSystem`.
  final String platform;
  final bool useVision;

  /// `BENCH_GPU_LAYERS`; null when the app's own config chose them.
  final int? gpuLayers;

  /// FHIR R4 JSON of the patient, the container and every phase-2 resource.
  final List<Map<String, dynamic>> predictedResources;
  final List<GenerationLog> generations;
  final int peakRssBytes;
  final int wallMs;

  /// The pipeline's `ProcessingLogBuffer` lines for this document (OCR size,
  /// memory checks, vision batches, text fallback).
  final List<String> pipelineLog;

  /// Resources the pipeline extracted but `toFhirResource` could not map;
  /// they are left out of [predictedResources].
  final List<String> mappingErrors;

  /// Set when the pipeline threw; [predictedResources] is then empty.
  final String? error;

  Map<String, dynamic> toJson() => {
        'docId': docId,
        'runId': runId,
        'model': model,
        'platform': platform,
        'useVision': useVision,
        if (gpuLayers != null) 'gpuLayers': gpuLayers,
        'predictedResources': predictedResources,
        'generations': [for (final g in generations) g.toJson()],
        'peakRssBytes': peakRssBytes,
        'wallMs': wallMs,
        if (pipelineLog.isNotEmpty) 'pipelineLog': pipelineLog,
        if (mappingErrors.isNotEmpty) 'mappingErrors': mappingErrors,
        if (error != null) 'error': error,
      };

  Future<void> appendTo(File file) =>
      file.writeAsString('${jsonEncode(toJson())}\n', mode: FileMode.append, flush: true);
}
