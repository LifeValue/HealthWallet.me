import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:health_wallet/features/scan/data/data_source/network/scan_network_data_source.dart';
import 'package:health_wallet/features/scan/data/model/prompt_template/basic_info_prompt.dart';
import 'package:health_wallet/features/scan/data/model/prompt_template/basic_info_vision_prompt.dart';
import 'package:health_wallet/features/scan/data/model/prompt_template/remaining_resources_vision_prompt.dart';
import 'package:health_wallet/features/scan/data/utils/observation_ocr_validator.dart';
import 'package:health_wallet/features/scan/data/utils/patient_post_processor.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/repository/scan_repository.dart';
import 'package:health_wallet/features/scan/domain/services/scan_log_buffer.dart';
import 'package:health_wallet/features/scan/domain/services/text_recognition_service.dart';

mixin ScanProcessingRepository {
  static final _markdownFenceRegex = RegExp(r'```(?:json)?\s*');

  static const int _minOcrCharsForTextOnly = 200;
  static const int _visionBatchSize = 2;
  static const int _visionOcrMaxLength = 800;

  static const _basicInfoTypes = {'Patient', 'Encounter', 'DiagnosticReport'};
  static final _numericValue = RegExp(r'^[\d.,\-+/<>= ]+$');
  static final _sectionHeaders = RegExp(
    r'^(anamnèse|anamn[eè]se|atcd|antécédents|examen|examen clinique|histoire|motif|conclusion|résumé|bilan|remarques?)\b',
    caseSensitive: false,
  );
  static const _booleanValues = {
    'true', 'false', 'yes', 'no', 'oui', 'non', 'vrai', 'faux',
  };

  ScanNetworkDataSource get networkDataSource;
  TextRecognitionService get textRecognitionService;
  bool get shouldCancelGeneration;
  Future<void> disposeModel();

  String get _ts => DateTime.now().toIso8601String().substring(11, 23);

  String _stripMarkdownFences(String text) {
    return text.replaceAll(_markdownFenceRegex, '').trim();
  }

  String _repairTruncatedJsonArray(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('[')) return trimmed;

    try {
      jsonDecode(trimmed);
      return trimmed;
    } catch (_) {}

    int depth = 0;
    int lastCompleteObjectEnd = -1;
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < trimmed.length; i++) {
      final c = trimmed[i];

      if (escaped) {
        escaped = false;
        continue;
      }
      if (c == '\\' && inString) {
        escaped = true;
        continue;
      }
      if (c == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;

      if (c == '{' || c == '[') {
        depth++;
      } else if (c == '}' || c == ']') {
        depth--;
        if (depth == 1 && c == '}') {
          lastCompleteObjectEnd = i;
        }
      }
    }

    if (lastCompleteObjectEnd > 0) {
      final repaired = '${trimmed.substring(0, lastCompleteObjectEnd + 1)}]';
      ScanLogBuffer.instance.log('[${DateTime.now().toIso8601String().substring(11, 23)}][ScanAI] repaired truncated JSON array (cut at char $lastCompleteObjectEnd of ${trimmed.length})');
      return repaired;
    }

    return trimmed;
  }

  MappingResource _selectContainer({
    required List<MappingResource> resources,
    required String documentCategory,
  }) {
    final diagnosticReport = resources
        .whereType<MappingDiagnosticReport>()
        .firstOrNull;
    final encounter = resources
        .whereType<MappingEncounter>()
        .firstOrNull;

    if (documentCategory == 'lab_report' &&
        diagnosticReport != null &&
        diagnosticReport.isValid) {
      return diagnosticReport;
    } else if (documentCategory == 'visit' &&
        encounter != null &&
        encounter.isValid) {
      return encounter;
    } else if (encounter != null && encounter.isValid) {
      return encounter;
    } else if (diagnosticReport != null && diagnosticReport.isValid) {
      return diagnosticReport;
    } else {
      return MappingEncounter.empty();
    }
  }

  (MappingPatient, MappingResource, String) _parseBasicInfoResponse(
    String? response,
    String inputTextForConfidence,
  ) {
    final cleaned = _stripMarkdownFences(response ?? '');
    final repaired = _repairTruncatedJsonArray(cleaned);
    List<dynamic> jsonList = jsonDecode(repaired);

    String? aiCategory;
    for (final json in jsonList) {
      if (json is Map<String, dynamic> && json['resourceType'] == 'Patient') {
        aiCategory = (json['documentCategory'] as String?)?.toLowerCase();
        break;
      }
    }

    List<MappingResource> resources = [];
    for (Map<String, dynamic> json in jsonList) {
      MappingResource resource = MappingResource.fromJson(json);
      if (inputTextForConfidence.isNotEmpty) {
        resource = resource.populateConfidence(inputTextForConfidence);
      } else {
        resource = resource.populateConfidence(
          json.values.whereType<String>().where((v) => v.isNotEmpty).join(' '),
        );
      }

      if (resource.isValid) {
        resources.add(resource);
      }
    }

    final documentCategory = aiCategory ?? '';
    final resourceTypes = resources.map((r) => r.runtimeType.toString().replaceAll(r'_$', '').replaceAll('Impl', '')).join(', ');
    ScanLogBuffer.instance.log('[${DateTime.now().toIso8601String().substring(11, 23)}][ScanAI] parsed ${jsonList.length} JSON objects -> ${resources.length} valid resources [$resourceTypes], category=${documentCategory.isEmpty ? '(empty)' : documentCategory}');

    final container = _selectContainer(
      resources: resources,
      documentCategory: documentCategory,
    );

    MappingPatient patient =
        resources.firstWhereOrNull((resource) => resource is MappingPatient)
                as MappingPatient? ??
            MappingPatient.empty();

    return (patient, container, documentCategory);
  }

  Future<String> _runOcrOnImages(List<String> imagePaths) async {
    final results = await Future.wait(
      imagePaths.map((p) => textRecognitionService.recognizeTextFromImage(p)),
    );
    return results.join('\n');
  }

  bool _isUsableResult(MappingPatient patient) {
    return patient.familyName.value.isNotEmpty ||
        patient.givenName.value.isNotEmpty ||
        patient.patientMRN.value.isNotEmpty;
  }

  Future<(MappingPatient, MappingResource)> processMapBasicInfo(
    List<String> imagePaths, {
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
  }) async {
    ScanLogBuffer.instance.log('[$_ts][ScanAI] === BASIC INFO EXTRACTION ===');

    final ocrSw = Stopwatch()..start();
    final ocrText = await _runOcrOnImages(imagePaths);
    ocrSw.stop();
    ScanLogBuffer.instance.log('[$_ts][ScanAI] OCR: ${ocrText.length} chars in ${(ocrSw.elapsedMilliseconds / 1000.0).toStringAsFixed(1)}s');

    if (ocrText.trim().length >= _minOcrCharsForTextOnly) {
      ScanLogBuffer.instance.log('[$_ts][ScanAI] OCR has enough text, trying text-only (fast path)...');
      try {
        final textResult = await _tryTextOnlyBasicInfo(ocrText, maxTokens, threads, contextSize);
        if (textResult != null) {
          final (patient, container, docCategory) = textResult;
          final postProcessed = PatientPostProcessor.postProcess(patient, ocrText);
          if (_isUsableResult(postProcessed)) {
            final containerType = container is MappingDiagnosticReport ? 'DiagnosticReport' : 'Encounter';
            ScanLogBuffer.instance.log('[$_ts][ScanAI] text-only succeeded: ${postProcessed.givenName.value} ${postProcessed.familyName.value}, label=${postProcessed.identifierLabel}, container=$containerType, category=$docCategory');
            return (postProcessed, container);
          }
          ScanLogBuffer.instance.log('[$_ts][ScanAI] text-only result was empty, falling back to vision...');
        }
      } catch (e) {
        ScanLogBuffer.instance.log('[$_ts][ScanAI] text-only failed: $e, falling back to vision...');
      } finally {
        await disposeModel();
      }
    } else {
      ScanLogBuffer.instance.log('[$_ts][ScanAI] OCR too short (${ocrText.trim().length} < $_minOcrCharsForTextOnly chars), using vision directly...');
    }

    return _visionBasicInfo(imagePaths, ocrText, maxTokens, gpuLayers, threads, contextSize);
  }

  Future<(MappingPatient, MappingResource, String)?> _tryTextOnlyBasicInfo(
    String ocrText,
    int? maxTokens,
    int? threads,
    int? contextSize,
  ) async {
    final textCtx = (contextSize == null || contextSize < 2048) ? 2048 : contextSize;
    ScanLogBuffer.instance.log('[$_ts][ScanAI] loading model (text-only, no vision projector)...');
    await networkDataSource.initModel(
      withVision: false,
      threads: threads,
      contextSize: textCtx,
    );

    final prompt = BasicInfoPrompt().buildPrompt(ocrText);
    ScanLogBuffer.instance.log('[$_ts][ScanAI] running text inference, prompt ${prompt.length} chars...');

    final response = await networkDataSource.runTextPrompt(
      prompt: prompt,
      maxTokens: maxTokens,
    );

    ScanLogBuffer.instance.log('[$_ts][ScanAI] parsing text-only response...');
    return _parseBasicInfoResponse(response, ocrText);
  }

  Future<(MappingPatient, MappingResource)> _visionBasicInfo(
    List<String> imagePaths,
    String ocrText,
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
  ) async {
    ScanLogBuffer.instance.log('[$_ts][ScanAI] --- VISION FALLBACK ---');
    ScanLogBuffer.instance.log('[$_ts][ScanAI] loading model + vision projector...');
    await networkDataSource.initModel(
      gpuLayers: gpuLayers,
      threads: threads,
      contextSize: contextSize,
    );

    try {
      final prompt = BasicInfoVisionPrompt(ocrText: ocrText).buildPrompt();
      ScanLogBuffer.instance.log('[$_ts][ScanAI] running vision inference...');

      final response = await networkDataSource.runVisionPrompt(
        prompt: prompt,
        imagePaths: imagePaths,
        maxTokens: maxTokens,
      );

      ScanLogBuffer.instance.log('[$_ts][ScanAI] parsing vision response...');
      final (patient, container, docCategory) = _parseBasicInfoResponse(response, ocrText);

      final postProcessed = PatientPostProcessor.postProcess(patient, ocrText);

      final containerType = container is MappingDiagnosticReport ? 'DiagnosticReport' : 'Encounter';
      ScanLogBuffer.instance.log('[$_ts][ScanAI] vision result: ${postProcessed.givenName.value} ${postProcessed.familyName.value}, label=${postProcessed.identifierLabel}, container=$containerType, category=$docCategory');

      return (postProcessed, container);
    } finally {
      await disposeModel();
    }
  }

  Stream<MappingResourcesWithProgress> processMapRemainingResources(
    List<String> imagePaths, {
    String? documentCategory,
    bool useVision = false,
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
  }) async* {
    final ocrText = await _runOcrOnImages(imagePaths);

    ScanLogBuffer.instance.log('[$_ts][ScanAI] === REMAINING RESOURCES EXTRACTION ===');
    ScanLogBuffer.instance.log('[$_ts][ScanAI] category=$documentCategory, OCR ${ocrText.length} chars, pages=${imagePaths.length}, maxTokens=${maxTokens ?? 'default'}, useVision=$useVision');

    List<MappingResource> allResources = [];
    final confidenceText = ocrText.isNotEmpty ? ocrText : null;

    if (useVision) {
      await networkDataSource.initModel(
        gpuLayers: gpuLayers,
        threads: threads,
        contextSize: contextSize,
      );

      final promptBuilder = await RemainingResourcesVisionPrompt.create(
        documentCategory: documentCategory,
        ocrText: ocrText,
        maxOcrLength: _visionOcrMaxLength,
        includeFewShot: false,
      );
      final prompt = promptBuilder.buildPrompt();

      final batches = <List<String>>[];
      for (var i = 0; i < imagePaths.length; i += _visionBatchSize) {
        batches.add(
          imagePaths.sublist(
            i,
            i + _visionBatchSize > imagePaths.length
                ? imagePaths.length
                : i + _visionBatchSize,
          ),
        );
      }

      ScanLogBuffer.instance.log('[$_ts][ScanAI] vision: ${batches.length} batch(es) of up to $_visionBatchSize images, OCR trimmed to $_visionOcrMaxLength chars, no few-shot');

      for (var batchIdx = 0; batchIdx < batches.length; batchIdx++) {
        if (shouldCancelGeneration) return;

        final health = await networkDataSource.checkMemoryHealth(
          withVision: true,
          contextSize: contextSize,
        );
        if (!health.canProceed) {
          ScanLogBuffer.instance.log('[$_ts][ScanAI] memory too low (${health.availableMB}MB < ${health.requiredMB}MB), switching to text fallback');
          break;
        }

        final batch = batches[batchIdx];
        try {
          ScanLogBuffer.instance.log('[$_ts][ScanAI] vision batch ${batchIdx + 1}/${batches.length} (${batch.length} images)...');

          final response = await networkDataSource.runVisionPrompt(
            prompt: prompt,
            imagePaths: batch,
            maxTokens: maxTokens,
          );

          final parsed = _parseResourcesFromResponse(response, confidenceText);
          allResources.addAll(parsed);
          ScanLogBuffer.instance.log('[$_ts][ScanAI] batch ${batchIdx + 1}: ${parsed.length} resources');

          final progress = (batchIdx + 1) / (batches.length + 1);
          yield (allResources.toSet().toList(), progress);
        } catch (e) {
          ScanLogBuffer.instance.log('[$_ts][ScanAI] vision batch ${batchIdx + 1} failed: $e');
        }
      }
    } else {
      ScanLogBuffer.instance.log('[$_ts][ScanAI] vision disabled by user, using text-only');
    }

    if (allResources.isEmpty && ocrText.trim().isNotEmpty) {
      ScanLogBuffer.instance.log('[$_ts][ScanAI] --- TEXT-ONLY FALLBACK ---');
      await disposeModel();

      final fallbackPromptBuilder = await RemainingResourcesVisionPrompt.create(
        documentCategory: documentCategory,
        ocrText: ocrText,
        maxOcrLength: 2000,
        includeFewShot: true,
      );
      final fallbackPrompt = fallbackPromptBuilder.buildPrompt();

      final textCtx = (contextSize == null || contextSize < 2048) ? 2048 : contextSize;
      await networkDataSource.initModel(
        withVision: false,
        threads: threads,
        contextSize: textCtx,
      );

      try {
        ScanLogBuffer.instance.log('[$_ts][ScanAI] running text-only inference, prompt ${fallbackPrompt.length} chars...');
        final response = await networkDataSource.runTextPrompt(
          prompt: fallbackPrompt,
          maxTokens: maxTokens,
        );

        allResources = _parseResourcesFromResponse(response, confidenceText);
        ScanLogBuffer.instance.log('[$_ts][ScanAI] text fallback: ${allResources.length} resources');
      } catch (e) {
        ScanLogBuffer.instance.log('[$_ts][ScanAI] text fallback failed: $e');
        final msg = e.toString().toLowerCase();
        if (msg.contains('tokenization') || msg.contains('prompt too long')) {
          rethrow;
        }
      }
    }

    if (ocrText.isNotEmpty) {
      allResources = ObservationOcrValidator.validate(allResources, ocrText);
    }

    yield (allResources.toSet().toList(), 1.0);
  }

  static bool _shouldSkipResource(Map<String, dynamic> json) {
    final type = json['resourceType'] as String?;
    if (type == null) return true;
    if (_basicInfoTypes.contains(type)) return true;

    if (type == 'Observation') {
      final value = (json['value'] as String?)?.trim() ?? '';
      if (value.isEmpty) return false;
      if (_booleanValues.contains(value.toLowerCase())) return true;
      if (!_numericValue.hasMatch(value) && value.split(RegExp(r'\s+')).length > 2) return true;
    }

    if (type == 'Condition') {
      final name = (json['conditionName'] as String?)?.trim() ?? '';
      if (_sectionHeaders.hasMatch(name)) return true;
      if (name.split(RegExp(r'\s+')).length > 10) return true;
    }

    return false;
  }

  static List<Map<String, dynamic>> _deduplicateResources(List<dynamic> jsonList) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final item in jsonList) {
      if (item is! Map<String, dynamic>) continue;
      final type = item['resourceType'] as String? ?? '';
      final nameKey = item['conditionName'] ?? item['observationName'] ??
          item['medicationName'] ?? item['procedureName'] ??
          item['practitionerName'] ?? item['organizationName'] ??
          item['substance'] ?? '';
      final key = '$type:${(nameKey as String).toLowerCase().trim()}';
      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(item);
    }
    return result;
  }

  List<MappingResource> _parseResourcesFromResponse(
    String? response,
    String? confidenceText,
  ) {
    final cleaned = _stripMarkdownFences(response ?? '');
    final repaired = _repairTruncatedJsonArray(cleaned);
    List<dynamic> jsonList = jsonDecode(repaired);
    final deduplicated = _deduplicateResources(jsonList);

    List<MappingResource> resources = [];
    for (final json in deduplicated) {
      if (_shouldSkipResource(json)) {
        ScanLogBuffer.instance.log('[ScanAI] skipped ${json['resourceType']}: ${json['conditionName'] ?? json['observationName'] ?? json['value'] ?? ''}');
        continue;
      }

      MappingResource resource = MappingResource.fromJson(json);
      resource = resource.populateConfidence(
        confidenceText ??
            json.values
                .whereType<String>()
                .where((v) => v.isNotEmpty)
                .join(' '),
      );

      if (resource.isValid) {
        resources.add(resource);
      }
    }
    return resources;
  }
}
