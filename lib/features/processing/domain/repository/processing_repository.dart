import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/features/processing/domain/entity/extraction_output_mode.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';

abstract class ProcessingRepository {
  Future<List<String>> scanDocuments();

  Future<List<String>> scanDocumentsAsPdf({int maxPages = 5});

  Future<List<String>> scanDocumentsDefault({int maxPages = 5});

  Future<String> saveScannedDocument(String sourcePath);

  Future<List<String>> getSavedDocuments();

  Future<void> deleteDocument(String imagePath);

  Future<void> clearAllDocuments();

  Future<ProcessingSession> createProcessingSession({
    required List<String> filePaths,
    required ProcessingOrigin origin,
    String? id,
  });

  Future<List<ProcessingSession>> getProcessingSessions();

  Future<int> editProcessingSession(ProcessingSession session);

  Future<int> deleteProcessingSession(ProcessingSession session);

  Stream<double> downloadModel();

  Stream<double> downloadModelForVariant(AiModelVariant variant);

  Future<bool> checkModelExistence();

  Future<bool> checkModelExistenceForVariant(AiModelVariant variant);

  Future<void> deleteModelForVariant(AiModelVariant variant);

  Stream<double> downloadMmprojForVariant(AiModelVariant variant);

  Future<bool> checkMmprojExistenceForVariant(AiModelVariant variant);

  Future<MappingResource> mapContainerOnly(
    String ocrText, {
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
    ExtractionOutputMode outputMode = ExtractionOutputMode.defaultMode,
  });

  Future<(MappingPatient, MappingResource)> mapBasicInfo(
    List<String> imagePaths, {
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
    ExtractionOutputMode outputMode = ExtractionOutputMode.defaultMode,
  });

  /// Each event carries every resource extracted so far (a snapshot that
  /// replaces the previous one, not a delta) and the progress.
  Stream<MappingResourcesWithProgress> mapRemainingResources(
    List<String> imagePaths, {
    String? documentCategory,
    bool useVision = false,
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
    ExtractionOutputMode outputMode = ExtractionOutputMode.defaultMode,
  });

  /// Whether the AI run in progress was cancelled; false between runs. The
  /// AI runs ([mapContainerOnly], [mapBasicInfo], [mapRemainingResources])
  /// take turns: each starts once those started before it have ended.
  bool get shouldCancelGeneration;

  /// Cancels the AI runs started so far and stops the running generation; a
  /// run started afterwards is not affected.
  Future<void> cancelGeneration();

  /// Completes once the AI runs started so far have ended.
  Future<void> waitForStreamCompletion();

  Future disposeModel();
}

typedef MappingResourcesWithProgress = (List<MappingResource>, double);
