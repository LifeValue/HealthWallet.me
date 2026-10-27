/// Reading datasets (`<dataset>/<split>/<docId>/{gold.json, meta.json}`) and
/// prediction files (`predictions.jsonl`, one record per document).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'generator.dart' show DocMeta;

/// Bad command-line input: missing files, malformed JSON. The CLI prints the
/// message and exits non-zero.
class BenchInputException implements Exception {
  BenchInputException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DatasetDoc {
  DatasetDoc(this.meta, this.goldResources, this.dir);
  final DocMeta meta;
  final List<Map<String, dynamic>> goldResources;
  final String dir;
  String get docId => meta.docId;
}

Object? _readJson(File f) {
  try {
    return jsonDecode(f.readAsStringSync());
  } on FormatException catch (e) {
    throw BenchInputException('${f.path} is not valid JSON: ${e.message}');
  }
}

/// Every `<dir>/*/<docId>/meta.json` with a sibling `gold.json`, sorted by
/// docId.
List<DatasetDoc> loadDataset(String dir) {
  final root = Directory(dir);
  if (!root.existsSync()) {
    throw BenchInputException('Dataset directory not found: $dir');
  }
  final docs = <DatasetDoc>[];
  final seen = <String>{};
  for (final split in root.listSync().whereType<Directory>()) {
    for (final docDir in split.listSync().whereType<Directory>()) {
      final metaFile = File(p.join(docDir.path, 'meta.json'));
      final goldFile = File(p.join(docDir.path, 'gold.json'));
      if (!metaFile.existsSync()) continue;
      if (!goldFile.existsSync()) {
        throw BenchInputException(
          '${docDir.path} has meta.json but no gold.json',
        );
      }
      final metaJson = _readJson(metaFile);
      final gold = _readJson(goldFile);
      if (metaJson is! Map<String, dynamic> || metaJson['docId'] is! String) {
        throw BenchInputException('${metaFile.path} has no docId');
      }
      if (gold is! Map<String, dynamic> || gold['resourceType'] != 'Bundle') {
        throw BenchInputException('${goldFile.path} is not a FHIR Bundle');
      }
      final meta = DocMeta.fromJson(metaJson);
      if (!seen.add(meta.docId)) {
        throw BenchInputException('Duplicate docId ${meta.docId} in $dir');
      }
      final resources = <Map<String, dynamic>>[
        for (final e in (gold['entry'] as List?) ?? const [])
          if (e is Map && e['resource'] is Map<String, dynamic>)
            e['resource'] as Map<String, dynamic>,
      ];
      docs.add(DatasetDoc(meta, resources, docDir.path));
    }
  }
  if (docs.isEmpty) {
    throw BenchInputException('No documents (*/<docId>/meta.json) under $dir');
  }
  docs.sort((a, b) => a.docId.compareTo(b.docId));
  return docs;
}

/// One generation (model call) of a run, as the runner records it.
class GenerationRecord {
  GenerationRecord(this.json);
  final Map<String, dynamic> json;

  double? _num(String key) => (json[key] as num?)?.toDouble();

  /// `vision` or `text`.
  String? get mode => json['mode'] as String?;

  /// `basic` (phase 1) or `remaining` (phase 2).
  String? get phase => json['phase'] as String?;

  bool get strictJsonValid => json['strictJsonValid'] == true;

  /// `stop`, or `length` when the generation hit maxTokens or a full context
  /// (truncated); null in records written before it was recorded.
  String? get finishReason => json['finishReason'] as String?;
  bool get truncated => finishReason == 'length';

  /// False for a schemaDraft draft call, which is free text by design
  /// (`constraint: none`); records without the field were all constrained.
  bool get constrained => json['constraint'] != 'none';
  double? get timeToFirstTokenMs => _num('timeToFirstTokenMs');
  double? get promptEvalMs => _num('promptEvalMs');
  double? get imageEncodeMs => _num('imageEncodeMs');
}

class PredictionRecord {
  PredictionRecord({
    required this.docId,
    required this.runId,
    required this.model,
    required this.platform,
    required this.predictedResources,
    required this.generations,
    this.outputMode,
    this.gpuLayers,
    this.peakRssBytes,
    this.wallMs,
    this.error,
  });

  factory PredictionRecord.fromJson(Map<String, dynamic> json) =>
      PredictionRecord(
        docId: json['docId'] as String,
        runId: json['runId'] as String? ?? '',
        model: json['model'] as String? ?? '',
        platform: json['platform'] as String? ?? '',
        predictedResources: [
          for (final r in (json['predictedResources'] as List?) ?? const [])
            if (r is Map<String, dynamic>) r,
        ],
        generations: [
          for (final g in (json['generations'] as List?) ?? const [])
            if (g is Map<String, dynamic>) GenerationRecord(g),
        ],
        outputMode: json['outputMode'] as String?,
        gpuLayers: (json['gpuLayers'] as num?)?.toInt(),
        peakRssBytes: (json['peakRssBytes'] as num?)?.toInt(),
        wallMs: (json['wallMs'] as num?)?.toDouble(),
        error: json['error'] as String?,
      );

  final String docId;
  final String runId;
  final String model;
  final String platform;
  final List<Map<String, dynamic>> predictedResources;
  final List<GenerationRecord> generations;

  /// `ExtractionOutputMode` name of the run; null in records written before
  /// it was recorded (those runs used `grammar`).
  final String? outputMode;

  /// `BENCH_GPU_LAYERS` of the run; null when the app chose them.
  final int? gpuLayers;
  final int? peakRssBytes;
  final double? wallMs;
  final String? error;

  Map<String, dynamic> toJson() => {
    'docId': docId,
    'runId': runId,
    'model': model,
    'platform': platform,
    if (outputMode != null) 'outputMode': outputMode,
    'predictedResources': predictedResources,
    'generations': [for (final g in generations) g.json],
    'peakRssBytes': peakRssBytes,
    'wallMs': wallMs,
    if (error != null) 'error': error,
  };
}

/// Records of a `predictions.jsonl`, keyed by docId. A later line for the
/// same docId replaces an earlier one (a resumed run).
Map<String, PredictionRecord> loadPredictions(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw BenchInputException('Predictions file not found: $path');
  }
  final out = <String, PredictionRecord>{};
  var lineNo = 0;
  for (final line in file.readAsLinesSync()) {
    lineNo++;
    if (line.trim().isEmpty) continue;
    Object? json;
    try {
      json = jsonDecode(line);
    } on FormatException catch (e) {
      throw BenchInputException(
        '$path:$lineNo is not valid JSON: ${e.message}',
      );
    }
    if (json is! Map<String, dynamic> || json['docId'] is! String) {
      throw BenchInputException('$path:$lineNo has no docId');
    }
    final record = PredictionRecord.fromJson(json);
    out[record.docId] = record;
  }
  return out;
}
