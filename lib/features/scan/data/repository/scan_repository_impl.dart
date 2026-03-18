import 'dart:async';
import 'dart:io';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/features/scan/data/data_source/local/scan_local_data_source.dart';
import 'package:health_wallet/features/scan/data/data_source/network/scan_network_data_source.dart';
import 'package:health_wallet/features/scan/data/repository/scan_processing_repository.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/domain/repository/scan_repository.dart';
import 'package:health_wallet/features/scan/domain/services/text_recognition_service.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

@LazySingleton(as: ScanRepository)
class ScanRepositoryImpl extends Object
    with ScanProcessingRepository
    implements ScanRepository {
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

  bool _isStreamActive = false;
  Completer<void>? _streamCompleter;
  bool _shouldCancelGeneration = false;

  @override
  ScanNetworkDataSource get networkDataSource => _networkDataSource;

  @override
  TextRecognitionService get textRecognitionService => _textRecognitionService;

  @override
  bool get shouldCancelGeneration => _shouldCancelGeneration;

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

      final validPaths = scannedResult.images
          .where((path) => path.isNotEmpty)
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

      return [scannedResult.pdfUri];
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

    _networkDataSource.downloadModel(onProgress: (progress) {
      if (!controller.isClosed) {
        controller.add(progress.toDouble());
      }
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
    return _networkDataSource.checkModelExistence();
  }

  @override
  Stream<double> downloadModelForVariant(AiModelVariant variant) {
    final controller = StreamController<double>();

    _networkDataSource
        .downloadModelForVariant(variant, onProgress: (progress) {
      if (!controller.isClosed) {
        controller.add(progress.toDouble());
      }
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

  @override
  Stream<double> downloadMmprojForVariant(AiModelVariant variant) {
    final controller = StreamController<double>();

    _networkDataSource
        .downloadMmprojForVariant(variant, onProgress: (progress) {
      if (!controller.isClosed) {
        controller.add(progress.toDouble());
      }
    }).then((_) {
      controller.close();
    }).catchError((error) {
      controller.addError(error);
      controller.close();
    });

    return controller.stream;
  }

  @override
  Future<bool> checkMmprojExistenceForVariant(AiModelVariant variant) async {
    return _networkDataSource.checkMmprojExistenceForVariant(variant);
  }

  @override
  Future<(MappingPatient, MappingResource)> mapBasicInfo(
    List<String> imagePaths, {
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
  }) async {
    return processMapBasicInfo(
      imagePaths,
      maxTokens: maxTokens,
      gpuLayers: gpuLayers,
      threads: threads,
      contextSize: contextSize,
    );
  }

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

      yield* processMapRemainingResources(
        imagePaths,
        documentCategory: documentCategory,
        useVision: useVision,
        maxTokens: maxTokens,
        gpuLayers: gpuLayers,
        threads: threads,
        contextSize: contextSize,
      );
    } finally {
      await disposeModel();

      _isStreamActive = false;
      _shouldCancelGeneration = false;
      _streamCompleter?.complete();
    }
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
