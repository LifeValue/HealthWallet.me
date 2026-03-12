import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';

abstract class ScanRepository {
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
  });

  Future<List<ProcessingSession>> getProcessingSessions();

  Future<int> editProcessingSession(ProcessingSession session);

  Future<int> deleteProcessingSession(ProcessingSession session);

  Stream<double> downloadModel();

  Stream<double> downloadModelForVariant(AiModelVariant variant);

  Future<bool> checkModelExistence();

  Future<bool> checkModelExistenceForVariant(AiModelVariant variant);

  Future<void> deleteModelForVariant(AiModelVariant variant);

  Future<(MappingPatient, MappingResource)> mapBasicInfo(
    List<String> imagePaths, {
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
  });

  Stream<MappingResourcesWithProgress> mapRemainingResources(
    List<String> imagePaths, {
    String? documentCategory,
    bool useVision = false,
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
  });

  Future<void> cancelGeneration();

  Future<void> waitForStreamCompletion();

  Future disposeModel();
}

typedef MappingResourcesWithProgress = (List<MappingResource>, double);
