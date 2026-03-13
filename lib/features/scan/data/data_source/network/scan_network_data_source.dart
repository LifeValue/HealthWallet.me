import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:background_downloader/background_downloader.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:health_wallet/features/scan/domain/services/scan_log_buffer.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/features/scan/domain/services/device_capability_service.dart';
import 'package:health_wallet/core/config/constants/app_constants.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/config/env/env.dart';
import 'package:image/image.dart' as img;
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

  Future<({int availableMB, int requiredMB, bool canProceed})> checkMemoryHealth({
    bool withVision = true,
    int? contextSize,
  });
}

@LazySingleton(as: ScanNetworkDataSource)
class ScanNetworkDataSourceImpl implements ScanNetworkDataSource {
  final SharedPreferences _prefs;

  ScanNetworkDataSourceImpl(this._prefs);

  LlamaEngine? _engine;
  bool _hasVisionProjector = false;
  int? _deviceRamMB;

  String get _ts => DateTime.now().toIso8601String().substring(11, 23);

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
    ScanLogBuffer.instance.log('[$_ts][ScanAI] iOS memory: RSS=${currentRssMB}MB, deviceRAM=${deviceRam}MB, ceiling=${(_iosMemoryCeiling * 100).toInt()}%, safeLimit=${safeLimit}MB, headroom=${available}MB');
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
        } else if (status == TaskStatus.canceled) {
          if (!completer.isCompleted) {
            completer.completeError(
              Exception('Download cancelled for $filename. Check your internet connection.'),
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
    final autoConfig = computeModelConfig(withVision: withVision, ramMB: ramMB);
    final config = (
      gpuLayers: gpuLayers ?? autoConfig.gpuLayers,
      threads: threads ?? autoConfig.threads,
    );
    final ctx = contextSize ?? autoConfig.contextSize;
    final availableMB = Platform.isIOS
        ? await _getAvailableRamMBForIos()
        : await _getAvailableRamMB();
    final requiredMB = estimateRequiredMB(ctx, withVision: withVision);
    ScanLogBuffer.instance.log('[$_ts][ScanAI] --- INIT MODEL ---');
    ScanLogBuffer.instance.log('[$_ts][ScanAI] model: ${_activeConfig.modelId} (${(fileSize / 1024 / 1024).toStringAsFixed(0)}MB)');
    ScanLogBuffer.instance.log('[$_ts][ScanAI] config: ctx=$ctx, gpu_layers=${config.gpuLayers}, threads=${config.threads}, ram=${ramMB}MB, available=${availableMB}MB, rssMB=${ProcessInfo.currentRss ~/ (1024 * 1024)}, required~${requiredMB}MB, platform=${Platform.operatingSystem}');

    if (availableMB >= 0 && availableMB < requiredMB) {
      ScanLogBuffer.instance.log('[$_ts][ScanAI] ABORT: only ${availableMB}MB available, need ~${requiredMB}MB');
      throw Exception('Not enough memory to load the AI model. Available: ${availableMB}MB, required: ~${requiredMB}MB. Close other apps and try again.');
    }

    if (!await _isValidGgufFile(modelPath)) {
      ScanLogBuffer.instance.log('[$_ts][ScanAI] ERROR: corrupt GGUF header, deleting file');
      await modelFile.delete();
      throw Exception('Model file is corrupted. Please re-download the AI model.');
    }

    final backend = Platform.isAndroid ? GpuBackend.cpu : GpuBackend.auto;
    ScanLogBuffer.instance.log('[$_ts][ScanAI] creating engine with backend=$backend');

    _engine = LlamaEngine(LlamaBackend());

    final params = ModelParams(
      contextSize: ctx,
      gpuLayers: config.gpuLayers,
      preferredBackend: backend,
      numberOfThreads: config.threads,
      numberOfThreadsBatch: config.threads,
    );
    ScanLogBuffer.instance.log('[$_ts][ScanAI] loadModel: ctx=${params.contextSize}, gpuLayers=${params.gpuLayers}, backend=${params.preferredBackend}, threads=${params.numberOfThreads}');

    final loadSw = Stopwatch()..start();
    try {
      await _engine!.loadModel(modelPath, modelParams: params);
      loadSw.stop();
      ScanLogBuffer.instance.log('[$_ts][ScanAI] model loaded in ${(loadSw.elapsedMilliseconds / 1000.0).toStringAsFixed(1)}s');
    } catch (e) {
      loadSw.stop();
      ScanLogBuffer.instance.log('[$_ts][ScanAI] model load FAILED after ${loadSw.elapsedMilliseconds}ms: $e');
      await _engine?.dispose();
      _engine = null;
      rethrow;
    }

    if (withVision) {
      final mmprojPath = await _getMmprojFilePath();
      if (File(mmprojPath).existsSync()) {
        if (!await _isValidGgufFile(mmprojPath)) {
          ScanLogBuffer.instance.log('[$_ts][ScanAI] ERROR: corrupt mmproj GGUF, deleting');
          await File(mmprojPath).delete();
          return;
        }
        final mmprojSw = Stopwatch()..start();
        try {
          await _engine!.loadMultimodalProjector(mmprojPath);
          _hasVisionProjector = true;
          mmprojSw.stop();
          ScanLogBuffer.instance.log('[$_ts][ScanAI] vision projector loaded in ${(mmprojSw.elapsedMilliseconds / 1000.0).toStringAsFixed(1)}s');
        } catch (e) {
          mmprojSw.stop();
          ScanLogBuffer.instance.log('[$_ts][ScanAI] vision projector FAILED: $e');
        }
      } else {
        ScanLogBuffer.instance.log('[$_ts][ScanAI] WARNING: mmproj file not found, vision disabled');
      }
    }
  }

  @override
  Future<({int availableMB, int requiredMB, bool canProceed})> checkMemoryHealth({
    bool withVision = true,
    int? contextSize,
  }) async {
    final ramMB = await _getDeviceRamMB();
    final autoConfig = computeModelConfig(withVision: withVision, ramMB: ramMB);
    final ctx = contextSize ?? autoConfig.contextSize;
    final availableMB = Platform.isIOS
        ? await _getAvailableRamMBForIos()
        : await _getAvailableRamMB();
    final requiredMB = estimateRequiredMB(ctx, withVision: withVision);
    final canProceed = (availableMB < 0) || availableMB >= requiredMB;
    ScanLogBuffer.instance.log('[$_ts][ScanAI] health check: available=${availableMB}MB, required~${requiredMB}MB, rssMB=${ProcessInfo.currentRss ~/ (1024 * 1024)}, canProceed=$canProceed');
    return (availableMB: availableMB, requiredMB: requiredMB, canProceed: canProceed);
  }

  static const int _maxImageDimension = 560;

  Future<String> _resizeImageIfNeeded(String imagePath) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return imagePath;

    final w = decoded.width;
    final h = decoded.height;

    if (w <= _maxImageDimension && h <= _maxImageDimension) {
      return imagePath;
    }

    final scale = _maxImageDimension / math.max(w, h);
    final newW = (w * scale).round();
    final newH = (h * scale).round();

    final resized = img.copyResize(decoded, width: newW, height: newH);
    final dir = await getTemporaryDirectory();
    final resizedPath = path.join(dir.path, 'resized_${path.basename(imagePath)}');
    await File(resizedPath).writeAsBytes(img.encodeJpg(resized, quality: 85));

    return resizedPath;
  }

  bool _isGenerating = false;
  bool _pendingDisposal = false;

  @override
  Future<void> disposeModel() async {
    _pendingDisposal = true;

    if (_isGenerating) {
      return;
    }

    await _performActualDisposal();
  }

  Future<void> _performActualDisposal() async {
    await _engine?.dispose();
    _engine = null;
    _hasVisionProjector = false;
    _pendingDisposal = false;
  }

  @override
  Future<String?> runVisionPrompt({
    required String prompt,
    required List<String> imagePaths,
    int? maxTokens,
  }) async {
    if (_engine == null) {
      throw Exception('Model not initialized. Call initModel() first.');
    }

    final effectiveTokens = maxTokens ?? AppConstants.visionMaxTokens;
    ScanLogBuffer.instance.log('[$_ts][ScanAI] --- VISION INFERENCE ---');
    ScanLogBuffer.instance.log('[$_ts][ScanAI] input: ${imagePaths.length} images, prompt ${prompt.length} chars, maxTokens=$effectiveTokens');

    final resizeSw = Stopwatch()..start();
    final resizedPaths = <String>[];
    for (final imgPath in imagePaths) {
      final originalSize = File(imgPath).existsSync() ? File(imgPath).lengthSync() : 0;
      final resized = await _resizeImageIfNeeded(imgPath);
      final resizedSize = File(resized).existsSync() ? File(resized).lengthSync() : 0;
      final wasResized = resized != imgPath;
      ScanLogBuffer.instance.log('[$_ts][ScanAI] image: ${(resizedSize / 1024).toStringAsFixed(0)}KB${wasResized ? ' (resized from ${(originalSize / 1024).toStringAsFixed(0)}KB, max ${_maxImageDimension}px)' : ' (${_maxImageDimension}px limit ok)'}');
      resizedPaths.add(resized);
    }
    resizeSw.stop();
    if (resizeSw.elapsedMilliseconds > 100) {
      ScanLogBuffer.instance.log('[$_ts][ScanAI] image prep: ${(resizeSw.elapsedMilliseconds / 1000.0).toStringAsFixed(1)}s');
    }

    final content = <LlamaContentPart>[
      for (final imgPath in resizedPaths)
        LlamaImageContent(path: imgPath),
      LlamaTextContent(prompt),
    ];

    final messages = [
      LlamaChatMessage.fromText(
        role: LlamaChatRole.system,
        text: 'You are a medical document data extractor. Output only valid JSON.',
      ),
      LlamaChatMessage.withContent(
        role: LlamaChatRole.user,
        content: content,
      ),
    ];

    _isGenerating = true;
    final sw = Stopwatch()..start();
    Timer? heartbeat;
    try {
      final buffer = StringBuffer();
      int tokenCount = 0;
      ScanLogBuffer.instance.log('[$_ts][ScanAI] encoding image + prompt (native, no callbacks available)...');

      heartbeat = Timer.periodic(const Duration(seconds: 10), (_) {
        final elapsed = (sw.elapsedMilliseconds / 1000.0).toStringAsFixed(0);
        if (tokenCount == 0) {
          ScanLogBuffer.instance.log('[$_ts][ScanAI] still encoding... ${elapsed}s elapsed');
        }
      });

      await for (final chunk in _engine!.create(
        messages,
        params: GenerationParams(
          maxTokens: effectiveTokens,
          temp: 0.0,
          topK: 1,
          topP: 1.0,
        ),
        enableThinking: false,
      )) {
        final text = chunk.choices.first.delta.content;
        if (text != null) {
          buffer.write(text);
          tokenCount++;
          if (tokenCount == 1) {
            heartbeat?.cancel();
            final prefillSec = (sw.elapsedMilliseconds / 1000.0).toStringAsFixed(1);
            ScanLogBuffer.instance.log('[$_ts][ScanAI] image encoded + prefill done in ${prefillSec}s, generating JSON...');
            heartbeat = Timer.periodic(const Duration(seconds: 5), (_) {
              final elapsed = (sw.elapsedMilliseconds / 1000.0).toStringAsFixed(0);
              final snippet = buffer.length > 60 ? '...${buffer.toString().substring(buffer.length - 60)}' : buffer.toString();
              ScanLogBuffer.instance.log('[$_ts][ScanAI] generating... $tokenCount tokens, ${elapsed}s | $snippet');
            });
          }
        }
      }

      heartbeat?.cancel();
      sw.stop();
      final totalSec = sw.elapsedMilliseconds / 1000.0;
      final tokPerSec = tokenCount > 0 ? (tokenCount / totalSec).toStringAsFixed(1) : '0';
      ScanLogBuffer.instance.log('[$_ts][ScanAI] done: $tokenCount tokens in ${totalSec.toStringAsFixed(1)}s ($tokPerSec tok/s)');
      if (tokenCount >= effectiveTokens) {
        ScanLogBuffer.instance.log('[$_ts][ScanAI] WARNING: hit maxTokens limit ($effectiveTokens), output may be truncated');
      }
      final preview = buffer.length > 120 ? '${buffer.toString().substring(0, 120)}...' : buffer.toString();
      ScanLogBuffer.instance.log('[$_ts][ScanAI] response: $preview');
      return buffer.toString();
    } catch (e) {
      heartbeat?.cancel();
      sw.stop();
      ScanLogBuffer.instance.log('[$_ts][ScanAI] FAILED after ${(sw.elapsedMilliseconds / 1000.0).toStringAsFixed(1)}s: $e');
      rethrow;
    } finally {
      heartbeat?.cancel();
      _isGenerating = false;
      if (_pendingDisposal) {
        await _performActualDisposal();
      }
    }
  }

  @override
  Future<String?> runTextPrompt({
    required String prompt,
    int? maxTokens,
  }) async {
    if (_engine == null) {
      throw Exception('Model not initialized. Call initModel() first.');
    }

    final effectiveTokens = maxTokens ?? AppConstants.defaultMaxTokens;
    ScanLogBuffer.instance.log('[$_ts][ScanAI] --- TEXT INFERENCE ---');
    ScanLogBuffer.instance.log('[$_ts][ScanAI] prompt ${prompt.length} chars, maxTokens=$effectiveTokens');

    final messages = [
      LlamaChatMessage.fromText(
        role: LlamaChatRole.system,
        text: 'You are a medical document data extractor. Output only valid JSON.',
      ),
      LlamaChatMessage.fromText(
        role: LlamaChatRole.user,
        text: '$prompt\n\nJSON:\n',
      ),
    ];

    _isGenerating = true;
    final sw = Stopwatch()..start();
    Timer? heartbeat;
    try {
      final buffer = StringBuffer();
      int tokenCount = 0;

      heartbeat = Timer.periodic(const Duration(seconds: 5), (_) {
        final elapsed = (sw.elapsedMilliseconds / 1000.0).toStringAsFixed(0);
        if (tokenCount == 0) {
          ScanLogBuffer.instance.log('[$_ts][ScanAI] text: processing prompt (no tokens generated yet)... ${elapsed}s elapsed');
        } else {
          final snippet = buffer.length > 60 ? '...${buffer.toString().substring(buffer.length - 60)}' : buffer.toString();
          ScanLogBuffer.instance.log('[$_ts][ScanAI] text: generating... $tokenCount tokens, ${elapsed}s | $snippet');
        }
      });

      await for (final chunk in _engine!.create(
        messages,
        params: GenerationParams(
          maxTokens: effectiveTokens,
          temp: 0.0,
          topK: 1,
          topP: 1.0,
        ),
        enableThinking: false,
      )) {
        final text = chunk.choices.first.delta.content;
        if (text != null) {
          buffer.write(text);
          tokenCount++;
          if (tokenCount == 1) {
            final prefillMs = sw.elapsedMilliseconds;
            ScanLogBuffer.instance.log('[$_ts][ScanAI] text: prefill done in ${(prefillMs / 1000.0).toStringAsFixed(1)}s, generating JSON...');
          }
        }
      }

      heartbeat.cancel();
      sw.stop();
      final totalSec = sw.elapsedMilliseconds / 1000.0;
      final tokPerSec = tokenCount > 0 ? (tokenCount / totalSec).toStringAsFixed(1) : '0';
      ScanLogBuffer.instance.log('[$_ts][ScanAI] text done: $tokenCount tokens in ${totalSec.toStringAsFixed(1)}s ($tokPerSec tok/s)');
      if (tokenCount >= effectiveTokens) {
        ScanLogBuffer.instance.log('[$_ts][ScanAI] WARNING: hit maxTokens limit ($effectiveTokens), output may be truncated');
      }
      final preview = buffer.length > 120 ? '${buffer.toString().substring(0, 120)}...' : buffer.toString();
      ScanLogBuffer.instance.log('[$_ts][ScanAI] response: $preview');
      return buffer.toString();
    } catch (e) {
      heartbeat?.cancel();
      sw.stop();
      ScanLogBuffer.instance.log('[$_ts][ScanAI] text FAILED after ${(sw.elapsedMilliseconds / 1000.0).toStringAsFixed(1)}s: $e');
      rethrow;
    } finally {
      heartbeat?.cancel();
      _isGenerating = false;
      if (_pendingDisposal) {
        await _performActualDisposal();
      }
    }
  }
}
