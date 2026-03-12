import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/features/scan/data/data_source/local/scan_local_data_source.dart';
import 'package:health_wallet/features/scan/data/data_source/network/scan_network_data_source.dart';
import 'package:health_wallet/features/scan/data/model/prompt_template/basic_info_prompt.dart';
import 'package:health_wallet/features/scan/data/model/prompt_template/basic_info_vision_prompt.dart';
import 'package:health_wallet/features/scan/data/utils/scan_log_buffer.dart';
import 'package:health_wallet/features/scan/data/model/prompt_template/remaining_resources_vision_prompt.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/data/utils/observation_ocr_validator.dart';
import 'package:health_wallet/features/scan/data/utils/patient_post_processor.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/domain/services/text_recognition_service.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:health_wallet/features/scan/domain/repository/scan_repository.dart';
import 'package:uuid/uuid.dart';

@LazySingleton(as: ScanRepository)
class ScanRepositoryImpl implements ScanRepository {
  ScanRepositoryImpl(
    this._networkDataSource,
    this._localDataSource,
    this._textRecognitionService,
    this._pathResolver,
  );

  final ScanNetworkDataSource _networkDataSource;
  final ScanLocalDataSource _localDataSource;
  final TextRecognitionService _textRecognitionService;
  final PathResolver _pathResolver;

  static final _markdownFenceRegex = RegExp(r'```(?:json)?\s*');

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

  static const _labKeywords = [
    'laborator', 'analiz', 'biochimi', 'hemato', 'hemogram',
    'test result', 'lab result', 'specimen', 'reference range',
    'val. ref', 'valori de referinta', 'synevo', 'medlife lab',
    'regina maria lab', 'blood test', 'urine test',
  ];

  static const _visitKeywords = [
    'spital', 'hospital', 'consult', 'visit summary',
    'discharge', 'bilet de iesire', 'after visit', 'externare',
    'internare', 'epicriza', 'scrisoare medicala',
  ];

  String _detectDocumentCategory(String medicalText) {
    final lower = medicalText.toLowerCase();
    final labScore = _labKeywords.where((k) => lower.contains(k)).length;
    final visitScore = _visitKeywords.where((k) => lower.contains(k)).length;

    if (labScore > visitScore) return 'lab_report';
    if (visitScore > labScore) return 'visit';
    return '';
  }

  bool _isStreamActive = false;
  Completer<void>? _streamCompleter;
  bool _shouldCancelGeneration = false;

  @override
  Future<List<String>> scanDocuments() async {
    try {
      final scannedResult =
          await FlutterDocScanner().getScannedDocumentAsImages(
        page: 10,
      );

      if (scannedResult == null) {
        return [];
      }

      List<String> imagePaths = [];

      if (scannedResult is List) {
        imagePaths = scannedResult.cast<String>();
      } else if (scannedResult is String) {
        if (scannedResult.contains('Failed') ||
            scannedResult.contains('Unknown') ||
            scannedResult.contains('platform documents')) {
          throw Exception('Scanner error: $scannedResult');
        }
        imagePaths = [scannedResult];
      } else {
        imagePaths = [scannedResult.toString()];
      }

      final validPaths = imagePaths
          .where((path) =>
              path.isNotEmpty &&
              !path.contains('Failed') &&
              !path.contains('Unknown'))
          .toList();

      return validPaths;
    } on PlatformException catch (e) {
      throw Exception('Scanner platform error: ${e.message ?? e.code}');
    } catch (e) {
      throw Exception('Failed to scan: $e');
    }
  }

  @override
  Future<List<String>> scanDocumentsAsPdf({int maxPages = 5}) async {
    try {
      final scannedResult = await FlutterDocScanner().getScannedDocumentAsPdf(
        page: maxPages,
      );

      if (scannedResult == null) {
        return [];
      }

      if (scannedResult is String &&
          (scannedResult.contains('Failed') ||
              scannedResult.contains('Unknown'))) {
        throw Exception('PDF scanner error: $scannedResult');
      }

      final pdfPath = scannedResult.toString();
      return [pdfPath];
    } on PlatformException catch (e) {
      throw Exception('PDF Scanner platform error: ${e.message ?? e.code}');
    } catch (e) {
      throw Exception('Failed to scan PDF documents: $e');
    }
  }

  @override
  Future<List<String>> scanDocumentsDefault({int maxPages = 5}) async {
    try {
      final scannedResult = await FlutterDocScanner().getScanDocuments(
        page: maxPages,
      );

      if (scannedResult == null) {
        return [];
      }

      List<String> documentPaths = [];

      if (scannedResult is List) {
        documentPaths = scannedResult.cast<String>();
      } else if (scannedResult is String) {
        if (scannedResult.contains('Failed') ||
            scannedResult.contains('Unknown')) {
          throw Exception('Default scanner error: $scannedResult');
        }
        documentPaths = [scannedResult];
      } else {
        documentPaths = [scannedResult.toString()];
      }

      final validPaths = documentPaths
          .where((path) =>
              path.isNotEmpty &&
              !path.contains('Failed') &&
              !path.contains('Unknown'))
          .toList();

      return validPaths;
    } on PlatformException catch (e) {
      throw Exception('Default Scanner platform error: ${e.message ?? e.code}');
    } catch (e) {
      throw Exception('Failed to scan in default mode: $e');
    }
  }

  @override
  Future<String> saveScannedDocument(String sourcePath) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final scanDir = Directory(path.join(directory.path, 'scanned_documents'));

      if (!await scanDir.exists()) {
        await scanDir.create(recursive: true);
      }

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source file does not exist: $sourcePath');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(sourcePath);
      final newFileName = 'document_$timestamp$extension';
      final newPath = path.join(scanDir.path, newFileName);

      await sourceFile.copy(newPath);

      return await _pathResolver.toRelative(newPath);
    } catch (e) {
      throw Exception('Failed to save document: $e');
    }
  }

  @override
  Future<List<String>> getSavedDocuments() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final scanDir = Directory(path.join(directory.path, 'scanned_documents'));

      if (!await scanDir.exists()) {
        return [];
      }

      final files = await scanDir
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .toList();

      final documentPaths = files
          .map((file) => file.path)
          .where((path) => _isValidDocumentFile(path))
          .toList();

      documentPaths.sort((a, b) {
        final aFile = File(a);
        final bFile = File(b);
        return bFile.lastModifiedSync().compareTo(aFile.lastModifiedSync());
      });

      return documentPaths;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> deleteDocument(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete document: $e');
    }
  }

  @override
  Future<void> clearAllDocuments({
    List<String>? scannedImagePaths,
    List<String>? importedImagePaths,
    List<String>? importedPdfPaths,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final scanDir = Directory(path.join(directory.path, 'scanned_documents'));

      if (await scanDir.exists()) {
        await scanDir.delete(recursive: true);
      }

      if (importedImagePaths != null) {
        for (var imagePath in importedImagePaths) {
          try {
            final file = File(imagePath);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {}
        }
      }

      if (importedPdfPaths != null) {
        for (var pdfPath in importedPdfPaths) {
          try {
            final file = File(pdfPath);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {}
        }
      }
    } catch (e) {
      throw Exception('Failed to clear all documents: $e');
    }
  }

  bool _isValidDocumentFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return extension == '.jpg' ||
        extension == '.jpeg' ||
        extension == '.png' ||
        extension == '.pdf';
  }

  @override
  Future<ProcessingSession> createProcessingSession({
    required List<String> filePaths,
    required ProcessingOrigin origin,
  }) async {
    final relativePaths =
        await Future.wait(filePaths.map(_pathResolver.toRelative));
    final absolutePaths =
        await _pathResolver.resolveAll(relativePaths);

    final session = ProcessingSession(
      id: const Uuid().v4(),
      filePaths: absolutePaths,
      origin: origin,
      createdAt: DateTime.now(),
    );

    final sessionForDb = session.copyWith(filePaths: relativePaths);
    await _localDataSource.cacheProcessingSession(sessionForDb.toDbCompanion());

    return session;
  }

  @override
  Future<List<ProcessingSession>> getProcessingSessions() async {
    final dtos = await _localDataSource.getProcessingSessions();
    final sessions = dtos.map(ProcessingSession.fromDto).toList();

    return Future.wait(sessions.map((s) async {
      final absolutePaths = await _pathResolver.resolveAll(s.filePaths);
      return s.copyWith(filePaths: absolutePaths);
    }));
  }

  @override
  Future<int> editProcessingSession(ProcessingSession session) async {
    final relativePaths =
        await Future.wait(session.filePaths.map(_pathResolver.toRelative));
    final sessionForDb = session.copyWith(filePaths: relativePaths);
    return _localDataSource.updateProcessingSession(
        session.id, sessionForDb.toDbCompanion());
  }

  @override
  Future<int> deleteProcessingSession(ProcessingSession session) async {
    for (final filePath in session.filePaths) {
      final absolutePath = await _pathResolver.toAbsolute(filePath);
      File(absolutePath).delete().ignore();
    }

    return _localDataSource.deleteProcessingSession(session.id);
  }

  @override
  Stream<double> downloadModel() {
    final controller = StreamController<double>();

    int modelProgress = 0;
    int mmprojProgress = 0;

    void emitCombinedProgress() {
      if (controller.isClosed) return;
      final combined = (modelProgress * 0.7 + mmprojProgress * 0.3);
      controller.add(combined);
    }

    _networkDataSource.downloadModel(onProgress: (progress) {
      modelProgress = progress;
      emitCombinedProgress();
    }).then((_) {
      return _networkDataSource.downloadMmproj(onProgress: (progress) {
        mmprojProgress = progress;
        emitCombinedProgress();
      });
    }).then((_) {
      controller.close();
    }).catchError((error) {
      controller.addError(error);
      controller.close();
    });

    return controller.stream;
  }

  @override
  Future<bool> checkModelExistence() async {
    final modelExists = await _networkDataSource.checkModelExistence();
    final mmprojExists = await _networkDataSource.checkMmprojExistence();
    return modelExists && mmprojExists;
  }

  @override
  Stream<double> downloadModelForVariant(AiModelVariant variant) {
    final controller = StreamController<double>();

    int modelProgress = 0;
    int mmprojProgress = 0;

    void emitCombinedProgress() {
      if (controller.isClosed) return;
      final combined = (modelProgress * 0.7 + mmprojProgress * 0.3);
      controller.add(combined);
    }

    _networkDataSource
        .downloadModelForVariant(variant, onProgress: (progress) {
      modelProgress = progress;
      emitCombinedProgress();
    }).then((_) {
      return _networkDataSource.downloadMmprojForVariant(variant,
          onProgress: (progress) {
        mmprojProgress = progress;
        emitCombinedProgress();
      });
    }).then((_) {
      controller.close();
    }).catchError((error) {
      controller.addError(error);
      controller.close();
    });

    return controller.stream;
  }

  @override
  Future<bool> checkModelExistenceForVariant(AiModelVariant variant) async {
    return _networkDataSource.checkModelExistenceForVariant(variant);
  }

  @override
  Future<void> deleteModelForVariant(AiModelVariant variant) async {
    return _networkDataSource.deleteModelForVariant(variant);
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
      imagePaths.map((p) => _textRecognitionService.recognizeTextFromImage(p)),
    );
    return results.join('\n');
  }

  static const int _minOcrCharsForTextOnly = 200;

  String get _ts => DateTime.now().toIso8601String().substring(11, 23);

  bool _isUsableResult(MappingPatient patient) {
    return patient.familyName.value.isNotEmpty ||
        patient.givenName.value.isNotEmpty ||
        patient.patientMRN.value.isNotEmpty;
  }

  @override
  Future<(MappingPatient, MappingResource)> mapBasicInfo(
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
    ScanLogBuffer.instance.log('[$_ts][ScanAI] loading model (text-only, no vision projector)...');
    await _networkDataSource.initModel(
      withVision: false,
      threads: threads,
      contextSize: contextSize,
    );

    final prompt = BasicInfoPrompt().buildPrompt(ocrText);
    ScanLogBuffer.instance.log('[$_ts][ScanAI] running text inference, prompt ${prompt.length} chars...');

    final response = await _networkDataSource.runTextPrompt(
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
    await _networkDataSource.initModel(
      gpuLayers: gpuLayers,
      threads: threads,
      contextSize: contextSize,
    );

    try {
      final prompt = BasicInfoVisionPrompt(ocrText: ocrText).buildPrompt();
      ScanLogBuffer.instance.log('[$_ts][ScanAI] running vision inference...');

      final response = await _networkDataSource.runVisionPrompt(
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

  static const int _visionBatchSize = 2;
  static const int _visionOcrMaxLength = 800;

  @override
  Stream<MappingResourcesWithProgress> mapRemainingResources(
    List<String> imagePaths, {
    String? documentCategory,
    bool useVision = false,
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
  }) async* {
    try {
      _isStreamActive = true;
      _streamCompleter = Completer<void>();
      _shouldCancelGeneration = false;

      final ocrText = await _runOcrOnImages(imagePaths);

      ScanLogBuffer.instance.log('[$_ts][ScanAI] === REMAINING RESOURCES EXTRACTION ===');
      ScanLogBuffer.instance.log('[$_ts][ScanAI] category=$documentCategory, OCR ${ocrText.length} chars, pages=${imagePaths.length}, maxTokens=${maxTokens ?? 'default'}, useVision=$useVision');

      List<MappingResource> allResources = [];
      final confidenceText = ocrText.isNotEmpty ? ocrText : null;

      if (useVision) {
        await _networkDataSource.initModel(
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
          if (_shouldCancelGeneration) return;

          final health = await _networkDataSource.checkMemoryHealth(
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

            final response = await _networkDataSource.runVisionPrompt(
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

        final textCtx = (contextSize != null && contextSize < 2048) ? 2048 : contextSize;
        await _networkDataSource.initModel(
          withVision: false,
          threads: threads,
          contextSize: textCtx,
        );

        try {
          ScanLogBuffer.instance.log('[$_ts][ScanAI] running text-only inference, prompt ${fallbackPrompt.length} chars...');
          final response = await _networkDataSource.runTextPrompt(
            prompt: fallbackPrompt,
            maxTokens: maxTokens,
          );

          allResources = _parseResourcesFromResponse(response, confidenceText);
          ScanLogBuffer.instance.log('[$_ts][ScanAI] text fallback: ${allResources.length} resources');
        } catch (e) {
          ScanLogBuffer.instance.log('[$_ts][ScanAI] text fallback failed: $e');
        }
      }

      if (ocrText.isNotEmpty) {
        allResources = ObservationOcrValidator.validate(allResources, ocrText);
      }

      yield (allResources.toSet().toList(), 1.0);
    } finally {
      await disposeModel();

      _isStreamActive = false;
      _shouldCancelGeneration = false;
      _streamCompleter?.complete();
    }
  }

  List<MappingResource> _parseResourcesFromResponse(
    String? response,
    String? confidenceText,
  ) {
    final cleaned = _stripMarkdownFences(response ?? '');
    final repaired = _repairTruncatedJsonArray(cleaned);
    List<dynamic> jsonList = jsonDecode(repaired);

    List<MappingResource> resources = [];
    for (Map<String, dynamic> json in jsonList) {
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


  @override
  Future<void> waitForStreamCompletion() async {
    if (_isStreamActive && _streamCompleter != null && !_streamCompleter!.isCompleted) {
      await _streamCompleter!.future;
    }
  }

  @override
  Future<void> cancelGeneration() async {
    _shouldCancelGeneration = true;
  }

  @override
  Future disposeModel() => _networkDataSource.disposeModel();
}
