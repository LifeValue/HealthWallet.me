import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:collection/collection.dart';
import 'package:health_wallet/features/scan/data/data_source/local/scan_local_data_source.dart';
import 'package:health_wallet/features/scan/data/data_source/network/scan_network_data_source.dart';
import 'package:health_wallet/features/scan/data/model/prompt_template/basic_info_prompt.dart';
import 'package:health_wallet/features/scan/data/model/prompt_template/prompt_template.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
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
    final controller = StreamController<double>();

    _networkDataSource.downloadModel(onProgress: (progress) {
      controller.add(progress.toDouble());
    }).then((_) {
      controller.close();
    }).catchError((error) {
      controller.addError(error);
      controller.close();
    });

    yield* controller.stream;
  }

  @override
  Future<bool> checkModelExistence() =>
      _networkDataSource.checkModelExistence();

  @override
  Future<(MappingPatient, MappingEncounter)> mapBasicInfo(
    String medicalText,
  ) async {
    await _networkDataSource.initModel();

    try {
      String prompt = BasicInfoPrompt().buildPrompt(medicalText);

      String? promptResponse =
          await _networkDataSource.runPrompt(prompt: prompt);

      List<dynamic> jsonList = jsonDecode(promptResponse ?? '');

      List<MappingResource> resources = [];
      for (Map<String, dynamic> json in jsonList) {
        MappingResource resource =
            MappingResource.fromJson(json).populateConfidence(medicalText);

        if (resource.isValid) {
          resources.add(resource);
        }
      }
      
      MappingEncounter encounter =
          resources.firstWhereOrNull((resource) => resource is MappingEncounter)
                  as MappingEncounter? ??
              MappingEncounter.empty();

      MappingPatient patient =
          resources.firstWhereOrNull((resource) => resource is MappingPatient)
                  as MappingPatient? ??
              MappingPatient.empty();

      return (patient, encounter);
    } finally {
      await disposeModel();
    }
  }

  @override
  Stream<MappingResourcesWithProgress> mapRemainingResources(
    String medicalText,
  ) async* {
    try {
      // Mark stream as active
      _isStreamActive = true;
      _streamCompleter = Completer<void>();
      _shouldCancelGeneration = false;
      
      debugPrint('mapResources: Stream started');
      
      await _networkDataSource.initModel();

      List<PromptTemplate> supportedPrompts = PromptTemplate.supportedPrompts();
      for (int i = 0; i < supportedPrompts.length; i++) {
        // Check if we should cancel before starting next prompt
        if (_shouldCancelGeneration) {
          debugPrint('mapResources: Generation cancelled, stopping at prompt $i');
          break;
        }
        
        String prompt = supportedPrompts[i].buildPrompt(medicalText);

        debugPrint('mapResources: Running prompt ${i + 1}/${supportedPrompts.length}');
        String? promptResponse = await _networkDataSource.runPrompt(
          prompt: prompt,
        );
        debugPrint('mapResources: Prompt ${i + 1} completed');

        // Check again after prompt completes
        if (_shouldCancelGeneration) {
          debugPrint('mapResources: Generation cancelled after prompt ${i + 1} completion');
          break;
        }

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
          yield ([], (i + 1) / supportedPrompts.length);
          continue;
        }

        yield (resources.toSet().toList(), (i + 1) / supportedPrompts.length);
      }
      
      debugPrint('mapResources: All prompts completed or cancelled');
    } finally {
      debugPrint('mapResources: Disposing model...');
      await disposeModel();
      
      _isStreamActive = false;
      _shouldCancelGeneration = false;
      
      debugPrint('mapResources: Stream ended, completing completer');
      _streamCompleter?.complete();
      
      debugPrint('mapResources: Cleanup complete');
    }
  }

  @override
  Future<void> waitForStreamCompletion() async {
    if (_isStreamActive && _streamCompleter != null && !_streamCompleter!.isCompleted) {
      debugPrint('waitForStreamCompletion: Waiting for active stream to complete...');
      await _streamCompleter!.future;
      debugPrint('waitForStreamCompletion: Stream completed');
    } else {
      debugPrint('waitForStreamCompletion: No active stream');
    }
  }

  @override
  Future<void> cancelGeneration() async {
    debugPrint('cancelGeneration: Requesting cancellation...');
    _shouldCancelGeneration = true;
  }

  @override
  Future disposeModel() => _networkDataSource.disposeModel();
}