import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:health_wallet/core/config/constants/country_identifier.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_data_source.dart';
import 'package:health_wallet/features/processing/data/model/prompt_template/basic_info_prompt.dart';
import 'package:health_wallet/features/processing/data/model/prompt_template/basic_info_vision_prompt.dart';
import 'package:health_wallet/features/processing/data/model/prompt_template/draft_prompt.dart';
import 'package:health_wallet/features/processing/data/model/prompt_template/remaining_resources_vision_prompt.dart';
import 'package:health_wallet/features/processing/data/utils/image_preprocessor.dart';
import 'package:health_wallet/features/processing/data/utils/observation_ocr_validator.dart';
import 'package:health_wallet/features/processing/data/utils/patient_post_processor.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/data/model/grammar/gbnf_grammars.dart';
import 'package:health_wallet/features/processing/data/model/structured_output/extraction_schemas.dart';
import 'package:health_wallet/features/processing/domain/services/processing_log_buffer.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';

mixin AiExtractionRepository {
  static final _markdownFenceRegex = RegExp(r'```(?:json)?\s*');

  static const int _minOcrCharsForTextOnly = 200;
  static const int _visionBatchSize = 2;

  /// OCR characters in a phase-2 prompt, vision and text alike.
  static const int _remainingOcrMaxLength = 2000;

  static const _basicInfoTypes = {'Patient', 'Encounter', 'DiagnosticReport'};
  static final _numericValue = RegExp(r'^[\d.,\-+/<>= ]+$');
  static final _sectionHeaders = RegExp(
    r'^(anamnèse|anamn[eè]se|atcd|antécédents|examen|examen clinique|histoire|motif|conclusion|résumé|bilan|remarques?)\b',
    caseSensitive: false,
  );
  static const _booleanValues = {
    'true', 'false', 'yes', 'no', 'oui', 'non', 'vrai', 'faux',
  };

  AiInferenceDataSource get networkDataSource;
  TextRecognitionService get textRecognitionService;
  bool get shouldCancelGeneration;
  Future<void> disposeModel();

  String get _ts => DateTime.now().toIso8601String().substring(11, 23);

  String _stripMarkdownFences(String text) {
    return text.replaceAll(_markdownFenceRegex, '').trim();
  }

  /// Text-only context: at least 2048, or 4096 in schemaDraft mode, whose
  /// prompts also carry the draft.
  static int _textContextSize(int? contextSize, ExtractionOutputMode mode) {
    final minimum = mode == ExtractionOutputMode.schemaDraft ? 4096 : 2048;
    return (contextSize == null || contextSize < minimum) ? minimum : contextSize;
  }

  /// One constrained text generation: the legacy grammar, or [schema] as the
  /// response format in the schema modes.
  Future<String?> _runConstrainedText({
    required String prompt,
    required int? maxTokens,
    required ExtractionOutputMode mode,
    required Map<String, dynamic> schema,
    required String schemaName,
  }) =>
      mode.usesSchema
          ? networkDataSource.runTextPrompt(
              prompt: prompt,
              maxTokens: maxTokens,
              responseFormat: ExtractionSchemas.responseFormat(schema, name: schemaName),
            )
          : networkDataSource.runTextPrompt(
              prompt: prompt,
              maxTokens: maxTokens,
              grammar: GbnfGrammars.jsonArray,
            );

  /// The unconstrained draft call of schemaDraft mode; null when it fails or
  /// returns nothing, so the constrained call runs without a draft.
  Future<String?> _runDraft(Future<String?> Function(int maxTokens) call, int? maxTokens) async {
    final tokens = math.min(DraftPrompt.maxTokens, maxTokens ?? DraftPrompt.maxTokens);
    ProcessingLogBuffer.instance.log('[$_ts][ScanAI] draft pass (unconstrained, maxTokens=$tokens)...');
    try {
      final draft = (await call(tokens))?.trim();
      if (draft == null || draft.isEmpty) {
        ProcessingLogBuffer.instance.log('[$_ts][ScanAI] draft empty, constrained pass without draft');
        return null;
      }
      ProcessingLogBuffer.instance.log('[$_ts][ScanAI] draft: ${draft.length} chars');
      return draft;
    } catch (e) {
      ProcessingLogBuffer.instance.log('[$_ts][ScanAI] draft failed: $e, constrained pass without draft');
      return null;
    }
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
      ProcessingLogBuffer.instance.log('[${DateTime.now().toIso8601String().substring(11, 23)}][ScanAI] repaired truncated JSON array (cut at char $lastCompleteObjectEnd of ${trimmed.length})');
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
    String inputTextForConfidence, [
    ExtractionOutputMode mode = ExtractionOutputMode.grammar,
  ]) {
    final List<dynamic> jsonList;
    if (mode.usesSchema) {
      final object = ExtractionSchemas.decodeObject(response);
      if (object == null) {
        throw const FormatException('basic info: schema output is not a JSON object');
      }
      jsonList = ExtractionSchemas.basicInfoToLegacy(object);
    } else {
      final cleaned = _stripMarkdownFences(response ?? '');
      final repaired = _repairTruncatedJsonArray(cleaned);
      jsonList = jsonDecode(repaired);
    }

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
    ProcessingLogBuffer.instance.log('[${DateTime.now().toIso8601String().substring(11, 23)}][ScanAI] parsed ${jsonList.length} JSON objects -> ${resources.length} valid resources [$resourceTypes], category=${documentCategory.isEmpty ? '(empty)' : documentCategory}');

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
    final preprocessed = await Future.wait(
      imagePaths.map(ImagePreprocessor.preprocessForOcr),
    );
    final results = await Future.wait(
      preprocessed.map((p) => textRecognitionService.recognizeTextFromImage(p)),
    );
    for (var i = 0; i < preprocessed.length; i++) {
      if (preprocessed[i] != imagePaths[i]) {
        try { await File(preprocessed[i]).delete(); } catch (_) {}
      }
    }
    return results.join('\n');
  }

  bool _isUsableResult(MappingPatient patient) {
    return patient.familyName.value.isNotEmpty ||
        patient.givenName.value.isNotEmpty ||
        patient.patientIdentifier.value.isNotEmpty;
  }

  Future<(MappingPatient, MappingResource)> processMapBasicInfo(
    List<String> imagePaths, {
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
    ExtractionOutputMode outputMode = ExtractionOutputMode.defaultMode,
  }) async {
    ProcessingLogBuffer.instance.log('[$_ts][ScanAI] === BASIC INFO EXTRACTION === (output=${outputMode.name})');

    final ocrSw = Stopwatch()..start();
    final ocrText = await _runOcrOnImages(imagePaths);
    ocrSw.stop();
    ProcessingLogBuffer.instance.log('[$_ts][ScanAI] OCR: ${ocrText.length} chars in ${(ocrSw.elapsedMilliseconds / 1000.0).toStringAsFixed(1)}s');

    if (ocrText.trim().length >= _minOcrCharsForTextOnly) {
      ProcessingLogBuffer.instance.log('[$_ts][ScanAI] OCR has enough text, trying text-only (fast path)...');
      try {
        final textResult = await _tryTextOnlyBasicInfo(ocrText, maxTokens, gpuLayers, threads, contextSize, outputMode);
        if (textResult != null) {
          final (patient, container, docCategory) = textResult;
          final postProcessed = PatientPostProcessor.postProcess(
            patient,
            ocrText,
            // The document's country, as the prompt's hints, not the phone's.
            regionDefaultLabel: CountryIdentifier.forDocument(ocrText).identifierLabel,
          );
          if (_isUsableResult(postProcessed)) {
            final containerType = container is MappingDiagnosticReport ? 'DiagnosticReport' : 'Encounter';
            ProcessingLogBuffer.instance.log('[$_ts][ScanAI] text-only succeeded: ${postProcessed.givenName.value} ${postProcessed.familyName.value}, label=${postProcessed.identifierLabel}, container=$containerType, category=$docCategory');
            return (postProcessed, container);
          }
          ProcessingLogBuffer.instance.log('[$_ts][ScanAI] text-only result was empty, falling back to vision...');
        }
      } catch (e) {
        ProcessingLogBuffer.instance.log('[$_ts][ScanAI] text-only failed: $e, falling back to vision...');
      } finally {
        await disposeModel();
      }
    } else {
      ProcessingLogBuffer.instance.log('[$_ts][ScanAI] OCR too short (${ocrText.trim().length} < $_minOcrCharsForTextOnly chars), using vision directly...');
    }

    return _visionBasicInfo(imagePaths, ocrText, maxTokens, gpuLayers, threads, contextSize, outputMode);
  }

  Future<MappingResource> mapContainerOnly(
    String ocrText, {
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
    ExtractionOutputMode outputMode = ExtractionOutputMode.defaultMode,
  }) async {
    ProcessingLogBuffer.instance.log('[$_ts][ScanAI] === CONTAINER-ONLY EXTRACTION (pre-matched patient) === (output=${outputMode.name})');

    final textCtx = _textContextSize(contextSize, outputMode);
    await networkDataSource.initModel(
      withVision: false,
      gpuLayers: gpuLayers,
      threads: threads,
      contextSize: textCtx,
    );

    final truncated = ocrText.length > 1500 ? ocrText.substring(0, 1500) : ocrText;
    final draft = outputMode == ExtractionOutputMode.schemaDraft
        ? await _runDraft(
            (tokens) => networkDataSource.runTextPrompt(prompt: DraftPrompt.basicInfo(ocrText), maxTokens: tokens),
            maxTokens,
          )
        : null;
    final prompt = outputMode.usesSchema
        ? '''What type of medical document is this? Return ONLY one JSON object.
Text:
$truncated
---
${DraftPrompt.section(draft)}${ExtractionSchemas.containerShape}

Rules:
- documentCategory = "lab_report" ONLY for standalone lab test results (blood tests, urine tests, imaging reports). Use "visit" for discharge letters, admission notes, consultation notes, observation sheets, referrals, prescriptions, any hospital/clinic visit document. Most documents are visits.
- documentTitle = the document HEADING at the top (e.g. "Bilet de iesire din spital", "Foaie de observatie", "Scrisoare medicala", "Consult cardiologie"). NOT the diagnosis. NOT "Admission" or "Visit".
- "Diagnostic externare", "Diagnostic", "Epicriza" are SECTIONS inside a discharge letter, not the document type. Use "Bilet de iesire din spital" instead.
- documentDate MUST be full date with year: YYYY-MM-DD (e.g. 2025-09-02). Never omit the year.
- conclusion = the lab report's conclusion, empty for visits.
- Empty string for missing fields.'''
        : '''What type of medical document is this? Return ONLY a single JSON object.
Text:
$truncated
---
Most documents are hospital visits. Use Encounter for: discharge letters, admission notes, consultation notes, observation sheets, referrals, prescriptions, any hospital/clinic visit document.
{"resourceType":"Encounter","encounterType":"<the document heading/title>","periodStart":"YYYY-MM-DD"}

Use DiagnosticReport ONLY for standalone lab test results (blood tests, urine tests, imaging reports):
{"resourceType":"DiagnosticReport","reportName":"<test name>","conclusion":"","issuedDate":"YYYY-MM-DD"}

Rules:
- encounterType = the document HEADING at the top (e.g. "Bilet de iesire din spital", "Foaie de observatie", "Scrisoare medicala", "Consult cardiologie"). NOT the diagnosis. NOT "Admission" or "Visit".
- "Diagnostic externare", "Diagnostic", "Epicriza" are SECTIONS inside a discharge letter, not the document type. Use "Bilet de iesire din spital" instead.
- periodStart/issuedDate MUST be full date with year: YYYY-MM-DD (e.g. 2025-09-02). Never omit the year.
- Empty string for missing fields.''';

    ProcessingLogBuffer.instance.log('[$_ts][ScanAI] running container-only inference, prompt ${prompt.length} chars...');

    final response = await _runConstrainedText(
      prompt: prompt,
      maxTokens: maxTokens ?? 256,
      mode: outputMode,
      schema: ExtractionSchemas.containerSchema(),
      schemaName: 'container',
    );

    await disposeModel();

    if (response == null || response.isEmpty) {
      ProcessingLogBuffer.instance.log('[$_ts][ScanAI] container-only: empty response');
      return MappingEncounter.empty();
    }

    ProcessingLogBuffer.instance.log('[$_ts][ScanAI] container-only response: ${response.length > 200 ? response.substring(0, 200) : response}');

    try {
      final Map<String, dynamic> first;
      if (outputMode.usesSchema) {
        final object = ExtractionSchemas.decodeObject(response);
        if (object == null) throw const FormatException('container: schema output is not a JSON object');
        first = ExtractionSchemas.containerToLegacy(object);
      } else {
        final cleaned = response.replaceAll(_markdownFenceRegex, '').trim();
        final json = jsonDecode(cleaned.startsWith('[') ? cleaned : '[$cleaned]') as List;
        if (json.isEmpty) return MappingEncounter.empty();
        first = json.first as Map<String, dynamic>;
      }
      if (first['resourceType'] == 'DiagnosticReport') {
        return MappingDiagnosticReport.fromJson(first);
      }
      return MappingEncounter.fromJson(first);
    } catch (e) {
      ProcessingLogBuffer.instance.log('[$_ts][ScanAI] container-only parse failed: $e');
      return MappingEncounter.empty();
    }
  }

  Future<(MappingPatient, MappingResource, String)?> _tryTextOnlyBasicInfo(
    String ocrText,
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
    ExtractionOutputMode outputMode,
  ) async {
    final textCtx = _textContextSize(contextSize, outputMode);
    ProcessingLogBuffer.instance.log('[$_ts][ScanAI] loading model (text-only, no vision projector)...');
    await networkDataSource.initModel(
      withVision: false,
      gpuLayers: gpuLayers,
      threads: threads,
      contextSize: textCtx,
    );

    final draft = outputMode == ExtractionOutputMode.schemaDraft
        ? await _runDraft(
            (tokens) => networkDataSource.runTextPrompt(prompt: DraftPrompt.basicInfo(ocrText), maxTokens: tokens),
            maxTokens,
          )
        : null;
    final prompt = BasicInfoPrompt().buildPrompt(ocrText, outputMode: outputMode, draft: draft);
    ProcessingLogBuffer.instance.log('[$_ts][ScanAI] running text inference, prompt ${prompt.length} chars...');

    final response = await _runConstrainedText(
      prompt: prompt,
      maxTokens: maxTokens,
      mode: outputMode,
      schema: ExtractionSchemas.basicInfoSchema(),
      schemaName: 'basic_info',
    );

    ProcessingLogBuffer.instance.log('[$_ts][ScanAI] parsing text-only response...');
    return _parseBasicInfoResponse(response, ocrText, outputMode);
  }

  Future<(MappingPatient, MappingResource)> _visionBasicInfo(
    List<String> imagePaths,
    String ocrText,
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
    ExtractionOutputMode outputMode,
  ) async {
    ProcessingLogBuffer.instance.log('[$_ts][ScanAI] --- VISION FALLBACK ---');
    ProcessingLogBuffer.instance.log('[$_ts][ScanAI] loading model + vision projector...');
    await networkDataSource.initModel(
      gpuLayers: gpuLayers,
      threads: threads,
      contextSize: contextSize,
    );

    try {
      final String? response;
      if (outputMode == ExtractionOutputMode.schemaDraft) {
        // Draft from the image, then the constrained pass text-only on the
        // draft and the OCR text.
        final draft = await _runDraft(
          (tokens) => networkDataSource.runVisionPrompt(
            prompt: DraftPrompt.basicInfo(ocrText, vision: true),
            imagePaths: imagePaths,
            maxTokens: tokens,
          ),
          maxTokens,
        );
        await disposeModel();
        await networkDataSource.initModel(
          withVision: false,
          gpuLayers: gpuLayers,
          threads: threads,
          contextSize: _textContextSize(contextSize, outputMode),
        );
        final prompt = BasicInfoPrompt().buildPrompt(ocrText, outputMode: outputMode, draft: draft);
        ProcessingLogBuffer.instance.log('[$_ts][ScanAI] running constrained text pass on the vision draft...');
        response = await _runConstrainedText(
          prompt: prompt,
          maxTokens: maxTokens,
          mode: outputMode,
          schema: ExtractionSchemas.basicInfoSchema(),
          schemaName: 'basic_info',
        );
      } else {
        final prompt = BasicInfoVisionPrompt(ocrText: ocrText, outputMode: outputMode).buildPrompt();
        ProcessingLogBuffer.instance.log('[$_ts][ScanAI] running vision inference...');

        response = outputMode.usesSchema
            ? await networkDataSource.runVisionPrompt(
                prompt: prompt,
                imagePaths: imagePaths,
                maxTokens: maxTokens,
                responseFormat: ExtractionSchemas.responseFormat(ExtractionSchemas.basicInfoSchema(), name: 'basic_info'),
              )
            : await networkDataSource.runVisionPrompt(
                prompt: prompt,
                imagePaths: imagePaths,
                maxTokens: maxTokens,
                grammar: GbnfGrammars.jsonArray,
              );
      }

      ProcessingLogBuffer.instance.log('[$_ts][ScanAI] parsing vision response...');
      final (patient, container, docCategory) = _parseBasicInfoResponse(response, ocrText, outputMode);

      final postProcessed = PatientPostProcessor.postProcess(
        patient,
        ocrText,
        // The document's country, as the prompt's hints, not the phone's.
        regionDefaultLabel: CountryIdentifier.forDocument(ocrText).identifierLabel,
      );

      final containerType = container is MappingDiagnosticReport ? 'DiagnosticReport' : 'Encounter';
      ProcessingLogBuffer.instance.log('[$_ts][ScanAI] vision result: ${postProcessed.givenName.value} ${postProcessed.familyName.value}, label=${postProcessed.identifierLabel}, container=$containerType, category=$docCategory');

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
    ExtractionOutputMode outputMode = ExtractionOutputMode.defaultMode,
  }) async* {
    final ocrText = await _runOcrOnImages(imagePaths);

    ProcessingLogBuffer.instance.log('[$_ts][ScanAI] === REMAINING RESOURCES EXTRACTION ===');
    ProcessingLogBuffer.instance.log('[$_ts][ScanAI] category=$documentCategory, OCR ${ocrText.length} chars, pages=${imagePaths.length}, maxTokens=${maxTokens ?? 'default'}, useVision=$useVision, output=${outputMode.name}');

    List<MappingResource> allResources = [];
    final confidenceText = ocrText.isNotEmpty ? ocrText : null;
    final drafting = outputMode == ExtractionOutputMode.schemaDraft;
    final remainingSchema = ExtractionSchemas.remainingSchema(documentCategory);
    final remainingFormat = ExtractionSchemas.responseFormat(remainingSchema, name: 'remaining_resources');

    // schemaDraft: the constrained text pass on the drafts and the OCR text.
    Future<List<MappingResource>> constrainedTextPass(String? draft) async {
      final promptBuilder = await RemainingResourcesVisionPrompt.create(
        documentCategory: documentCategory,
        ocrText: ocrText,
        maxOcrLength: _remainingOcrMaxLength,
        includeFewShot: true,
        outputMode: outputMode,
        draft: draft,
      );
      final prompt = promptBuilder.buildPrompt();
      ProcessingLogBuffer.instance.log('[$_ts][ScanAI] running constrained text pass, prompt ${prompt.length} chars...');
      final response = await _runConstrainedText(
        prompt: prompt,
        maxTokens: maxTokens,
        mode: outputMode,
        schema: remainingSchema,
        schemaName: 'remaining_resources',
      );
      return _parseResourcesFromResponse(response, confidenceText, outputMode);
    }

    var visionLoaded = false;
    if (useVision) {
      try {
        await networkDataSource.initModel(
          gpuLayers: gpuLayers,
          threads: threads,
          contextSize: contextSize,
        );
        visionLoaded = true;
      } catch (e) {
        // E.g. model + projector over the memory limit: text-only still fits.
        ProcessingLogBuffer.instance.log('[$_ts][ScanAI] vision model load failed: $e, switching to text fallback');
      }
    }

    // Set once a text pass has run on the OCR text, so the fallback below
    // does not repeat it.
    var textPassRan = false;

    if (visionLoaded) {
      final prompt = drafting
          ? DraftPrompt.remaining(ocrText, documentCategory: documentCategory, vision: true)
          : (await RemainingResourcesVisionPrompt.create(
              documentCategory: documentCategory,
              ocrText: ocrText,
              maxOcrLength: _remainingOcrMaxLength,
              includeFewShot: true,
              outputMode: outputMode,
            )).buildPrompt();

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

      ProcessingLogBuffer.instance.log('[$_ts][ScanAI] vision: ${batches.length} batch(es) of up to $_visionBatchSize images, OCR trimmed to $_remainingOcrMaxLength chars, few-shot${drafting ? ', draft pass' : ''}');

      final drafts = <String>[];
      for (var batchIdx = 0; batchIdx < batches.length; batchIdx++) {
        if (shouldCancelGeneration) return;

        final health = await networkDataSource.checkMemoryHealth(
          withVision: true,
          contextSize: contextSize,
        );
        if (!health.canProceed) {
          ProcessingLogBuffer.instance.log('[$_ts][ScanAI] memory too low (${health.availableMB}MB < ${health.requiredMB}MB), switching to text fallback');
          break;
        }

        final batch = batches[batchIdx];
        final progress = (batchIdx + 1) / (batches.length + 1);
        if (drafting) {
          ProcessingLogBuffer.instance.log('[$_ts][ScanAI] vision draft batch ${batchIdx + 1}/${batches.length} (${batch.length} images)...');
          final draft = await _runDraft(
            (tokens) => networkDataSource.runVisionPrompt(prompt: prompt, imagePaths: batch, maxTokens: tokens),
            maxTokens,
          );
          if (draft != null) drafts.add(draft);
          yield (allResources.toSet().toList(), progress);
          continue;
        }
        try {
          ProcessingLogBuffer.instance.log('[$_ts][ScanAI] vision batch ${batchIdx + 1}/${batches.length} (${batch.length} images)...');

          final response = outputMode.usesSchema
              ? await networkDataSource.runVisionPrompt(
                  prompt: prompt,
                  imagePaths: batch,
                  maxTokens: maxTokens,
                  responseFormat: remainingFormat,
                )
              : await networkDataSource.runVisionPrompt(
                  prompt: prompt,
                  imagePaths: batch,
                  maxTokens: maxTokens,
                  grammar: GbnfGrammars.jsonArray,
                );

          final parsed = _parseResourcesFromResponse(response, confidenceText, outputMode);
          allResources.addAll(parsed);
          ProcessingLogBuffer.instance.log('[$_ts][ScanAI] batch ${batchIdx + 1}: ${parsed.length} resources');

          yield (allResources.toSet().toList(), progress);
        } catch (e) {
          ProcessingLogBuffer.instance.log('[$_ts][ScanAI] vision batch ${batchIdx + 1} failed: $e');
        }
      }

      if (drafting && !shouldCancelGeneration) {
        await disposeModel();
        await networkDataSource.initModel(
          withVision: false,
          gpuLayers: gpuLayers,
          threads: threads,
          contextSize: _textContextSize(contextSize, outputMode),
        );
        textPassRan = true;
        try {
          allResources = await constrainedTextPass(drafts.isEmpty ? null : drafts.join('\n'));
          ProcessingLogBuffer.instance.log('[$_ts][ScanAI] constrained pass on ${drafts.length} vision draft(s): ${allResources.length} resources');
        } catch (e) {
          ProcessingLogBuffer.instance.log('[$_ts][ScanAI] constrained pass failed: $e');
          final msg = e.toString().toLowerCase();
          if (msg.contains('tokenization') || msg.contains('prompt too long')) {
            rethrow;
          }
        }
      }
    } else if (!useVision) {
      ProcessingLogBuffer.instance.log('[$_ts][ScanAI] vision disabled, using text-only');
    }

    if (allResources.isEmpty && ocrText.trim().isNotEmpty && !textPassRan) {
      ProcessingLogBuffer.instance.log('[$_ts][ScanAI] --- TEXT-ONLY FALLBACK ---');
      await disposeModel();

      final fallbackPrompt = drafting
          ? null
          : (await RemainingResourcesVisionPrompt.create(
              documentCategory: documentCategory,
              ocrText: ocrText,
              maxOcrLength: _remainingOcrMaxLength,
              includeFewShot: true,
              outputMode: outputMode,
            )).buildPrompt();

      await networkDataSource.initModel(
        withVision: false,
        gpuLayers: gpuLayers,
        threads: threads,
        contextSize: _textContextSize(contextSize, outputMode),
      );

      try {
        if (fallbackPrompt == null) {
          final draft = await _runDraft(
            (tokens) => networkDataSource.runTextPrompt(
              prompt: DraftPrompt.remaining(ocrText, documentCategory: documentCategory),
              maxTokens: tokens,
            ),
            maxTokens,
          );
          allResources = await constrainedTextPass(draft);
        } else {
          ProcessingLogBuffer.instance.log('[$_ts][ScanAI] running text-only inference, prompt ${fallbackPrompt.length} chars...');
          final response = await _runConstrainedText(
            prompt: fallbackPrompt,
            maxTokens: maxTokens,
            mode: outputMode,
            schema: remainingSchema,
            schemaName: 'remaining_resources',
          );
          allResources = _parseResourcesFromResponse(response, confidenceText, outputMode);
        }
        ProcessingLogBuffer.instance.log('[$_ts][ScanAI] text fallback: ${allResources.length} resources');
      } catch (e) {
        ProcessingLogBuffer.instance.log('[$_ts][ScanAI] text fallback failed: $e');
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

  /// Legacy array output, or (schema modes) the schema object mapped to the
  /// same `resourceType`-tagged maps, then dedupe, skip rules, confidence and
  /// validity. Unusable schema output gives an empty list, not an error.
  List<MappingResource> _parseResourcesFromResponse(
    String? response,
    String? confidenceText, [
    ExtractionOutputMode mode = ExtractionOutputMode.grammar,
  ]) {
    final List<dynamic> jsonList;
    if (mode.usesSchema) {
      final object = ExtractionSchemas.decodeObject(response);
      if (object == null) {
        ProcessingLogBuffer.instance.log('[$_ts][ScanAI] schema output unusable (${response?.length ?? 0} chars), no resources');
        return [];
      }
      jsonList = ExtractionSchemas.remainingToLegacy(object);
    } else {
      final cleaned = _stripMarkdownFences(response ?? '');
      final repaired = _repairTruncatedJsonArray(cleaned);
      jsonList = jsonDecode(repaired);
    }
    final deduplicated = _deduplicateResources(jsonList);

    List<MappingResource> resources = [];
    for (final json in deduplicated) {
      if (_shouldSkipResource(json)) {
        ProcessingLogBuffer.instance.log('[ScanAI] skipped ${json['resourceType']}: ${json['conditionName'] ?? json['observationName'] ?? json['value'] ?? ''}');
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
