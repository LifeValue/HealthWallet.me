import 'dart:convert';
import 'dart:io';
import 'package:flutter_gemma/mobile/flutter_gemma_mobile.dart';
import 'package:health_wallet/features/scan/data/data_source/local/scan_local_data_source.dart';
import 'package:health_wallet/features/scan/data/data_source/network/scan_network_data_source.dart';
import 'package:health_wallet/features/scan/data/model/prompt_template/prompt_template.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/domain/entity/slm_model.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:health_wallet/features/scan/domain/repository/scan_repository.dart';
import 'package:uuid/uuid.dart';

@LazySingleton(as: ScanRepository)
class ScanRepositoryImpl implements ScanRepository {
  ScanRepositoryImpl(this._networkDataSource, this._localDataSource);

  final ScanNetworkDataSource _networkDataSource;
  final ScanLocalDataSource _localDataSource;

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

      return newPath;
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
    final session = ProcessingSession(
      id: const Uuid().v4(),
      filePaths: filePaths,
      origin: origin,
      createdAt: DateTime.now(),
    );

    await _localDataSource.cacheProcessingSession(session.toDbCompanion());

    return session;
  }

  @override
  Future<List<ProcessingSession>> getProcessingSessions() async {
    final dtos = await _localDataSource.getProcessingSessions();

    return dtos.map(ProcessingSession.fromDto).toList();
  }

  @override
  Future<int> editProcessingSession(ProcessingSession session) async {
    return _localDataSource.updateProcessingSession(
        session.id, session.toDbCompanion());
  }

  @override
  Future<int> deleteProcessingSession(ProcessingSession session) async {
    for (final path in session.filePaths) {
      File(path).delete().ignore();
    }

    return _localDataSource.deleteProcessingSession(session.id);
  }

  @override
  Stream<double> downloadModel() async* {
    Stream<DownloadProgress> stream = _networkDataSource
        .downloadModel(SlmModel.gemmaModel().toInferenceSpec());

    await for (final progress in stream) {
      yield progress.overallProgress.toDouble();
    }
  }

  @override
  Future<bool> checkModelExistence() => _networkDataSource
      .checkModelExistence(SlmModel.gemmaModel().toInferenceSpec());

  @override
  Stream<MappingResourcesWithProgress> mapResources(String medicalText) async* {
    List<PromptTemplate> supportedPrompts = PromptTemplate.supportedPrompts();
    for (int i = 0; i < supportedPrompts.length; i++) {
      String prompt = supportedPrompts[i].buildPrompt(medicalText);

      String? promptResponse = await _networkDataSource.runPrompt(
        spec: SlmModel.gemmaModel().toInferenceSpec(),
        prompt: prompt,
      );

      List<MappingResource> resources = [];

      try {
        List<dynamic> jsonList = jsonDecode(promptResponse ?? '');

        for (Map<String, dynamic> json in jsonList) {
          MappingResource resource =
              MappingResource.fromJson(json).populateConfidence(medicalText);

          if (resource.isValid) {
            resources.add(resource);
          }
        }
      } catch (_) {
        continue;
      }

      yield (resources.toSet().toList(), (i + 1) / supportedPrompts.length);
    }
  }
}
