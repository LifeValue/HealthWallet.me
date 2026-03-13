import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:health_wallet/features/scan/domain/services/scan_log_buffer.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/features/scan/domain/services/device_capability_service.dart';
import 'package:health_wallet/core/config/env/env.dart';
import 'package:health_wallet/features/scan/data/data_source/network/scan_inference_handler.dart';
import 'package:injectable/injectable.dart';
import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

abstract class ScanNetworkDataSource {
  Future<void> downloadModel({
    required void Function(int) onProgress,
  });

  Future<void> downloadMmproj({
    required void Function(int) onProgress,
  });

  Future<bool> checkModelExistence();

  Future<bool> checkMmprojExistence();

  Future<void> downloadModelForVariant(
    AiModelVariant variant, {
    required void Function(int) onProgress,
  });

  Future<void> downloadMmprojForVariant(
    AiModelVariant variant, {
    required void Function(int) onProgress,
  });

  Future<bool> checkModelExistenceForVariant(AiModelVariant variant);

  Future<bool> checkMmprojExistenceForVariant(AiModelVariant variant);

  Future<void> deleteModelForVariant(AiModelVariant variant);

  bool isVisionModelAvailable();

  Future<String?> runVisionPrompt({
    required String prompt,
    required List<String> imagePaths,
    int? maxTokens,
  });

  Future<String?> runTextPrompt({
    required String prompt,
    int? maxTokens,
  });

  Future<void> initModel({
    bool withVision = true,
    int? contextSize,
    int? gpuLayers,
    int? threads,
  });

  Future<void> disposeModel();

  Future<({int availableMB, int requiredMB, bool canProceed})>
      checkMemoryHealth({
    bool withVision = true,
    int? contextSize,
  });
}

@LazySingleton(as: ScanNetworkDataSource)
class ScanNetworkDataSourceImpl
    with ScanInferenceHandler
    implements ScanNetworkDataSource {
  final SharedPreferences _prefs;

  ScanNetworkDataSourceImpl(this._prefs);

  LlamaEngine? _engine;
  bool _hasVisionProjector = false;
  int? _deviceRamMB;

  @override
  LlamaEngine? get engine => _engine;
  @override
  set engine(LlamaEngine? value) => _engine = value;
  @override
  bool get hasVisionProjector => _hasVisionProjector;
  @override
  set hasVisionProjector(bool value) => _hasVisionProjector = value;
  @override
  String get ts => DateTime.now().toIso8601String().substring(11, 23);

  Future<int> _getDeviceRamMB() async {
    if (_deviceRamMB != null) return _deviceRamMB!;
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        _deviceRamMB = estimateIosRam(ios.utsname.machine);
      } else if (Platform.isAndroid) {
        _deviceRamMB = await _readAndroidRamMB();
        if (_deviceRamMB == null) {
          final android = await deviceInfo.androidInfo;
          _deviceRamMB = android.isLowRamDevice ? 2048 : 4096;
        }
      }
    } catch (_) {}
    _deviceRamMB ??= 4096;
    return _deviceRamMB!;
  }

  static Future<int?> _readAndroidRamMB() async {
    try {
      final memInfo = await File('/proc/meminfo').readAsString();
      final match = RegExp(r'MemTotal:\s+(\d+)').firstMatch(memInfo);
      if (match != null) return int.parse(match.group(1)!) ~/ 1024;
    } catch (_) {}
    return null;
  }

  static Future<int> _getAvailableRamMB() async {
    if (Platform.isAndroid) {
      try {
        final memInfo = await File('/proc/meminfo').readAsString();
        final match = RegExp(r'MemAvailable:\s+(\d+)').firstMatch(memInfo);
        if (match != null) return int.parse(match.group(1)!) ~/ 1024;
      } catch (_) {}
    }
    return -1;
  }

  static const double _iosMemoryCeiling = 0.60;

  Future<int> _getAvailableRamMBForIos() async {
    final deviceRam = await _getDeviceRamMB();
    final currentRssMB = ProcessInfo.currentRss ~/ (1024 * 1024);
    final safeLimit = (deviceRam * _iosMemoryCeiling).round();
    final headroom = safeLimit - currentRssMB;
    final available = headroom > 0 ? headroom : 0;
    ScanLogBuffer.instance.log(
        '[$ts][ScanAI] iOS memory: RSS=${currentRssMB}MB, deviceRAM=${deviceRam}MB, ceiling=${(_iosMemoryCeiling * 100).toInt()}%, safeLimit=${safeLimit}MB, headroom=${available}MB');
    return available;
  }

  static int estimateIosRam(String machine) =>
      DeviceCapabilityService.estimateIosRam(machine);

  static const double kvCacheMBPerCtx1024 = 170;

  int estimateRequiredMB(int contextSize, {bool withVision = true}) {
    final modelMB = _activeConfig.modelSizeMB;
    final visionExtra = withVision ? _activeConfig.mmprojSizeMB : 0;
    final overheadMB = modelMB >= 2000 ? 700 : 400;
    return modelMB +
        visionExtra +
        (contextSize * kvCacheMBPerCtx1024 ~/ 1024) +
        overheadMB;
  }

  static ({int gpuLayers, int threads, int contextSize}) computeModelConfig({
    required bool withVision,
    required int ramMB,
  }) =>
      DeviceCapabilityService.computeModelConfig(
        withVision: withVision,
        ramMB: ramMB,
      );

  Future<String> _getModelDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final modelDir = Directory(path.join(directory.path, 'ai_models'));
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir.path;
  }

  AiModelConfig get _activeConfig => AiModelConfig.getActive(_prefs);

  Future<String> _getModelFilePath() async {
    final dir = await _getModelDirectory();
    return path.join(dir, _activeConfig.modelId);
  }

  Future<String> _getMmprojFilePath() async {
    final dir = await _getModelDirectory();
    return path.join(dir, _activeConfig.mmprojId);
  }

  @override
  Future<bool> checkModelExistence() async {
    final modelPath = await _getModelFilePath();
    return File(modelPath).existsSync();
  }

  @override
  Future<bool> checkMmprojExistence() async {
    final mmprojPath = await _getMmprojFilePath();
    return File(mmprojPath).existsSync();
  }

  @override
  bool isVisionModelAvailable() => _engine != null && _hasVisionProjector;

  Future<void> _configureDownloaderForLargeFile() async {
    if (!Platform.isAndroid) return;

    FileDownloader().configureNotificationForGroup(
      'smart_downloads',
      running: const TaskNotification(
        'Downloading AI Model',
        'Progress: {progress}',
      ),
      complete: const TaskNotification(
        'AI Model Downloaded',
        'Ready to use',
      ),
      error: const TaskNotification(
        'Download Failed',
        'Tap to retry',
      ),
      progressBar: true,
    );

    await FileDownloader().configure(
      androidConfig: [
        (Config.runInForeground, Config.always),
      ],
    );
  }

  Future<void> _downloadFile({
    required String url,
    required String filename,
    required void Function(int) onProgress,
  }) async {
    await _configureDownloaderForLargeFile();

    final dir = await _getModelDirectory();
    final filePath = path.join(dir, filename);

    if (File(filePath).existsSync()) {
      onProgress(100);
      return;
    }

    final headers = <String, String>{};
    final token = Env.huggingFaceToken;
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final task = DownloadTask(
      url: url,
      baseDirectory: BaseDirectory.applicationDocuments,
      directory: 'ai_models',
      filename: filename,
      headers: headers,
      updates: Updates.statusAndProgress,
    );

    final completer = Completer<void>();

    FileDownloader().download(
      task,
      onProgress: (progress) {
        final percent = (progress * 100).round();
        onProgress(percent);
      },
      onStatus: (status) {
        if (status == TaskStatus.complete) {
          if (!completer.isCompleted) completer.complete();
        } else if (status == TaskStatus.failed ||
            status == TaskStatus.notFound) {
          if (!completer.isCompleted) {
            completer.completeError(
              Exception('Download failed for $filename: $status'),
            );
          }
        } else if (status == TaskStatus.cancel) {
          if (!completer.isCompleted) {
            completer.completeError(
              Exception(
                  'Download cancelled for $filename. Check your internet connection.'),
            );
          }
        }
      },
    );

    await completer.future;
  }

  @override
  Future<void> downloadModel({
    required void Function(int) onProgress,
  }) async {
    final config = _activeConfig;
    await _downloadFile(
      url: config.modelUrl,
      filename: config.modelId,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> downloadMmproj({
    required void Function(int) onProgress,
  }) async {
    final config = _activeConfig;
    await _downloadFile(
      url: config.mmprojUrl,
      filename: config.mmprojId,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> downloadModelForVariant(
    AiModelVariant variant, {
    required void Function(int) onProgress,
  }) async {
    final config = AiModelConfig.fromVariant(variant);
    await _downloadFile(
      url: config.modelUrl,
      filename: config.modelId,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> downloadMmprojForVariant(
    AiModelVariant variant, {
    required void Function(int) onProgress,
  }) async {
    final config = AiModelConfig.fromVariant(variant);
    await _downloadFile(
      url: config.mmprojUrl,
      filename: config.mmprojId,
      onProgress: onProgress,
    );
  }

  @override
  Future<bool> checkModelExistenceForVariant(AiModelVariant variant) async {
    final config = AiModelConfig.fromVariant(variant);
    final dir = await _getModelDirectory();
    final modelPath = path.join(dir, config.modelId);
    return File(modelPath).existsSync();
  }

  @override
  Future<bool> checkMmprojExistenceForVariant(AiModelVariant variant) async {
    final config = AiModelConfig.fromVariant(variant);
    final dir = await _getModelDirectory();
    return File(path.join(dir, config.mmprojId)).existsSync();
  }

  @override
  Future<void> deleteModelForVariant(AiModelVariant variant) async {
    final config = AiModelConfig.fromVariant(variant);
    final dir = await _getModelDirectory();
    final modelFile = File(path.join(dir, config.modelId));
    final mmprojFile = File(path.join(dir, config.mmprojId));
    if (await modelFile.exists()) await modelFile.delete();
    if (await mmprojFile.exists()) await mmprojFile.delete();
  }

  Future<bool> _isValidGgufFile(String filePath) async {
    try {
      final file = File(filePath);
      final raf = await file.open();
      final header = await raf.read(4);
      await raf.close();
      return header.length == 4 &&
          header[0] == 0x47 &&
          header[1] == 0x47 &&
          header[2] == 0x55 &&
          header[3] == 0x46;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> initModel({
    bool withVision = true,
    int? contextSize,
    int? gpuLayers,
    int? threads,
  }) async {
    if (_engine != null) return;

    final modelPath = await _getModelFilePath();
    if (!File(modelPath).existsSync()) {
      throw Exception('Model file not found at $modelPath');
    }

    final modelFile = File(modelPath);
    final fileSize = await modelFile.length();
    final ramMB = await _getDeviceRamMB();
    final autoConfig =
        computeModelConfig(withVision: withVision, ramMB: ramMB);
    final config = (
      gpuLayers: gpuLayers ?? autoConfig.gpuLayers,
      threads: threads ?? autoConfig.threads,
    );
    final ctx = contextSize ?? autoConfig.contextSize;
    final availableMB = Platform.isIOS
        ? await _getAvailableRamMBForIos()
        : await _getAvailableRamMB();
    final requiredMB = estimateRequiredMB(ctx, withVision: withVision);
    ScanLogBuffer.instance.log('[$ts][ScanAI] --- INIT MODEL ---');
    ScanLogBuffer.instance.log(
        '[$ts][ScanAI] model: ${_activeConfig.modelId} (${(fileSize / 1024 / 1024).toStringAsFixed(0)}MB)');
    ScanLogBuffer.instance.log(
        '[$ts][ScanAI] config: ctx=$ctx, gpu_layers=${config.gpuLayers}, threads=${config.threads}, ram=${ramMB}MB, available=${availableMB}MB, rssMB=${ProcessInfo.currentRss ~/ (1024 * 1024)}, required~${requiredMB}MB, platform=${Platform.operatingSystem}');

    if (availableMB >= 0 && availableMB < requiredMB) {
      ScanLogBuffer.instance.log(
          '[$ts][ScanAI] ABORT: only ${availableMB}MB available, need ~${requiredMB}MB');
      throw Exception(
          'Not enough memory to load the AI model. Available: ${availableMB}MB, required: ~${requiredMB}MB. Close other apps and try again.');
    }

    if (!await _isValidGgufFile(modelPath)) {
      ScanLogBuffer.instance.log(
          '[$ts][ScanAI] ERROR: corrupt GGUF header, deleting file');
      await modelFile.delete();
      throw Exception(
          'Model file is corrupted. Please re-download the AI model.');
    }

    final backend = Platform.isAndroid ? GpuBackend.cpu : GpuBackend.auto;
    ScanLogBuffer.instance
        .log('[$ts][ScanAI] creating engine with backend=$backend');

    _engine = LlamaEngine(LlamaBackend());

    final params = ModelParams(
      contextSize: ctx,
      gpuLayers: config.gpuLayers,
      preferredBackend: backend,
      numberOfThreads: config.threads,
      numberOfThreadsBatch: config.threads,
    );
    ScanLogBuffer.instance.log(
        '[$ts][ScanAI] loadModel: ctx=${params.contextSize}, gpuLayers=${params.gpuLayers}, backend=${params.preferredBackend}, threads=${params.numberOfThreads}');

    final loadSw = Stopwatch()..start();
    try {
      await _engine!.loadModel(modelPath, modelParams: params);
      loadSw.stop();
      ScanLogBuffer.instance.log(
          '[$ts][ScanAI] model loaded in ${(loadSw.elapsedMilliseconds / 1000.0).toStringAsFixed(1)}s');
    } catch (e) {
      loadSw.stop();
      ScanLogBuffer.instance.log(
          '[$ts][ScanAI] model load FAILED after ${loadSw.elapsedMilliseconds}ms: $e');
      await _engine?.dispose();
      _engine = null;
      rethrow;
    }

    if (withVision) {
      final mmprojPath = await _getMmprojFilePath();
      if (File(mmprojPath).existsSync()) {
        if (!await _isValidGgufFile(mmprojPath)) {
          ScanLogBuffer.instance.log(
              '[$ts][ScanAI] ERROR: corrupt mmproj GGUF, deleting');
          await File(mmprojPath).delete();
          return;
        }
        final mmprojSw = Stopwatch()..start();
        try {
          await _engine!.loadMultimodalProjector(mmprojPath);
          _hasVisionProjector = true;
          mmprojSw.stop();
          ScanLogBuffer.instance.log(
              '[$ts][ScanAI] vision projector loaded in ${(mmprojSw.elapsedMilliseconds / 1000.0).toStringAsFixed(1)}s');
        } catch (e) {
          mmprojSw.stop();
          ScanLogBuffer.instance
              .log('[$ts][ScanAI] vision projector FAILED: $e');
        }
      } else {
        ScanLogBuffer.instance.log(
            '[$ts][ScanAI] WARNING: mmproj file not found, vision disabled');
      }
    }
  }

  @override
  Future<({int availableMB, int requiredMB, bool canProceed})>
      checkMemoryHealth({
    bool withVision = true,
    int? contextSize,
  }) async {
    final ramMB = await _getDeviceRamMB();
    final autoConfig =
        computeModelConfig(withVision: withVision, ramMB: ramMB);
    final ctx = contextSize ?? autoConfig.contextSize;
    final availableMB = Platform.isIOS
        ? await _getAvailableRamMBForIos()
        : await _getAvailableRamMB();
    final requiredMB = estimateRequiredMB(ctx, withVision: withVision);
    final canProceed = (availableMB < 0) || availableMB >= requiredMB;
    ScanLogBuffer.instance.log(
        '[$ts][ScanAI] health check: available=${availableMB}MB, required~=${requiredMB}MB, rssMB=${ProcessInfo.currentRss ~/ (1024 * 1024)}, canProceed=$canProceed');
    return (
      availableMB: availableMB,
      requiredMB: requiredMB,
      canProceed: canProceed
    );
  }

  @override
  Future<String?> runVisionPrompt({
    required String prompt,
    required List<String> imagePaths,
    int? maxTokens,
  }) =>
      runVisionPromptImpl(
          prompt: prompt, imagePaths: imagePaths, maxTokens: maxTokens);

  @override
  Future<String?> runTextPrompt({
    required String prompt,
    int? maxTokens,
  }) =>
      runTextPromptImpl(prompt: prompt, maxTokens: maxTokens);
}
