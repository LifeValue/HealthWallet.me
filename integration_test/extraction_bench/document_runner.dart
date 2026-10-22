import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:path/path.dart' as p;

import 'degradation.dart';
import 'recording_data_source.dart';
import 'run_record.dart';

const benchSubjectId = 'bench-patient';
const benchContainerId = 'bench-container';

class BenchDoc {
  BenchDoc(this.docId, this.dir, this.meta);
  final String docId;
  final String dir;
  final Map<String, dynamic> meta;
  String get degradation => meta['degradation'] as String? ?? 'clean';
  int get seed => (meta['seed'] as num?)?.toInt() ?? 0;
}

/// Every `<dataset>/<split>/<docId>/meta.json`, sorted by docId.
List<BenchDoc> loadBenchDocs(Directory dataset) {
  final docs = <BenchDoc>[];
  for (final split in dataset.listSync().whereType<Directory>()) {
    for (final dir in split.listSync().whereType<Directory>()) {
      final metaFile = File(p.join(dir.path, 'meta.json'));
      if (!metaFile.existsSync()) continue;
      final meta = jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
      docs.add(BenchDoc(meta['docId'] as String, dir.path, meta));
    }
  }
  docs.sort((a, b) => a.docId.compareTo(b.docId));
  return docs;
}

/// Runs one document through the production pipeline and returns its record.
/// A pipeline failure is caught and recorded with empty predictions, so the
/// caller can go on with the next document.
///
/// Mirrors `ProcessingHandler`: phase 1, `docCategory` from the container,
/// then phase 2 with every yielded batch appended. [pref] returns the tuning
/// pref for a `SharedPrefsConstants` key (null on desktop, as in the app).
Future<RunRecord> runBenchDocument({
  required BenchDoc doc,
  required ProcessingRepository repository,
  required RecordingAiInferenceDataSource recorder,
  required Future<List<String>> Function(BenchDoc doc) pages,
  required String workDir,
  required String runId,
  required String model,
  required bool useVision,
  required int? Function(String key) pref,
}) async {
  recorder.beginDocument();
  var peakRss = ProcessInfo.currentRss;
  final rssTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
    final rss = ProcessInfo.currentRss;
    if (rss > peakRss) peakRss = rss;
  });
  final wall = Stopwatch()..start();
  final predicted = <Map<String, dynamic>>[];
  final mappingErrors = <String>[];
  String? error;
  var pageImages = <String>[];
  try {
    pageImages = await pages(doc);
    if (pageImages.isEmpty) throw StateError('No page images for ${doc.docId}');
    final degraded = <String>[
      for (final (i, page) in pageImages.indexed)
        await degradePage(page, mode: doc.degradation, seed: doc.seed, pageIndex: i, outDir: workDir),
    ];

    recorder.phase = 'basic';
    final (patient, container) = await repository.mapBasicInfo(
      degraded,
      maxTokens: pref(SharedPrefsConstants.aiMaxTokens),
      gpuLayers: pref(SharedPrefsConstants.aiGpuLayers),
      threads: pref(SharedPrefsConstants.aiThreads),
      contextSize: pref(SharedPrefsConstants.aiContextSize),
    );
    final docCategory = container is MappingDiagnosticReport ? 'lab_report' : 'visit';

    recorder.phase = 'remaining';
    // ProcessingHandler appends every yielded batch to the session.
    final remaining = <MappingResource>[];
    await for (final (resources, _) in repository.mapRemainingResources(
      degraded,
      documentCategory: docCategory,
      useVision: useVision,
      maxTokens: pref(SharedPrefsConstants.aiMaxTokens),
      gpuLayers: pref(SharedPrefsConstants.aiGpuLayers),
      threads: pref(SharedPrefsConstants.aiThreads),
      contextSize: pref(SharedPrefsConstants.aiContextSize),
    )) {
      remaining.addAll(resources);
    }

    for (final resource in <MappingResource>[patient, container, ...remaining]) {
      try {
        final raw = Map<String, dynamic>.of(resource
            .toFhirResource(subjectId: benchSubjectId, encounterId: benchContainerId)
            .rawResource);
        // toFhirResource fills a missing report date with DateTime.now(); an
        // omitted date must score as omitted, not as a wrong date.
        if (resource is MappingDiagnosticReport && DateTime.tryParse(resource.issuedDate.value) == null) {
          raw.remove('issued');
        }
        predicted.add(raw);
      } catch (e) {
        mappingErrors.add('${resource.runtimeType}: $e');
      }
    }
  } catch (e, st) {
    error = '$e';
    predicted.clear();
    debugPrint('[bench] ${doc.docId} failed: $e\n$st');
    try {
      await recorder.disposeModel();
    } catch (_) {}
  }
  wall.stop();
  rssTimer.cancel();
  // Rasterized PDF pages are temporary files; dataset images are kept.
  for (final page in pageImages) {
    if (!p.isWithin(doc.dir, page)) {
      try {
        File(page).deleteSync();
      } catch (_) {}
    }
  }
  final rss = ProcessInfo.currentRss;
  if (rss > peakRss) peakRss = rss;

  return RunRecord(
    docId: doc.docId,
    runId: runId,
    model: model,
    platform: Platform.operatingSystem,
    useVision: useVision,
    predictedResources: predicted,
    generations: List.of(recorder.generations),
    peakRssBytes: peakRss,
    wallMs: wall.elapsedMilliseconds,
    mappingErrors: mappingErrors,
    error: error,
  );
}
