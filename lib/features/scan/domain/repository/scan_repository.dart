import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';

abstract class ScanRepository {
  // Document management
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

  // Fhir Mapping
  Stream<double> downloadModel();

  Future<bool> checkModelExistence();

  Stream<MappingResourcesWithProgress> mapResources(String medicalText);
}

typedef MappingResourcesWithProgress = (List<MappingResource>, double);
