import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/config/env/env.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_handler.dart';
import 'package:health_wallet/features/processing/data/model/generation_stats.dart';
import 'package:health_wallet/features/processing/domain/entity/model_download_cancelled_exception.dart';
import 'package:health_wallet/features/processing/domain/entity/model_not_found_exception.dart';
import 'package:health_wallet/features/processing/domain/services/device_capability_service.dart';
import 'package:health_wallet/features/processing/domain/services/processing_log_buffer.dart';
import 'package:injectable/injectable.dart';
import 'package:llamadart/llamadart.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AiInferenceDataSource {
  Future<bool> checkModelExistence();

  Future<void> downloadModelForVariant(
    AiModelVariant variant, {
    required void Function(int) onProgress,
  });

  Future<void> downloadMmprojForVariant(
    AiModelVariant variant, {
    required void Function(int) onProgress,
  });

  /// Stops the running download of [variant]'s model file, if there is one.
  /// Completes once the transfer has ended and its partial file is deleted;
  /// the interrupted download then fails with
  /// [ModelDownloadCancelledException]. Other files keep downloading.
  Future<void> cancelModelDownloadForVariant(AiModelVariant variant);

  /// [cancelModelDownloadForVariant] for [variant]'s vision (mmproj) file.
  Future<void> cancelMmprojDownloadForVariant(AiModelVariant variant);

  Future<bool> checkModelExistenceForVariant(AiModelVariant variant);

  Future<bool> checkMmprojExistenceForVariant(AiModelVariant variant);

  Future<void> deleteModelForVariant(AiModelVariant variant);

  bool isVisionModelAvailable();

  /// [grammar] (GBNF) or [responseFormat] (llamadart `json_schema` response
  /// format) constrain the output; pass at most one.
  Future<String?> runVisionPrompt({
    required String prompt,
    required List<String> imagePaths,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
  });

  /// With [chatTemplateKwargs] (NuExtract's `template`/`instructions`),
  /// [prompt] is sent alone as the user message: the chat template adds the
  /// rest.
  Future<String?> runTextPrompt({
    required String prompt,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
    Map<String, dynamic>? chatTemplateKwargs,
  });

  /// The [PromptFamily] of the active model.
  PromptFamily get promptFamily;

  /// [AiModelConfig.visionPagesPerBatch] of the active model.
  int get visionPagesPerBatch;

  /// Token counts and timings of the last [runVisionPrompt] or
  /// [runTextPrompt] call. Reset when a call starts; null when the call
  /// failed or none has run.
  GenerationStats? get lastGenerationStats;

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

/// One running model file download. A restart of the same file waits for
/// [ended], so only one writer ever touches its partial file.
class _ModelTransfer {
  _ModelTransfer(this.previous);

  /// The earlier transfer of the same file this one waits for; cleared once
  /// that has ended.
  _ModelTransfer? previous;

  final cancelToken = CancelToken();

  /// The background_downloader task, on mobile.
  String? taskId;

  final _ended = Completer<void>();

  bool get isCancelled => cancelToken.isCancelled;

  /// Completes once the transfer has stopped writing and its partial file is
  /// gone or in place.
  Future<void> get ended => _ended.future;

  bool get hasEnded => _ended.isCompleted;

  void end() {
    if (!_ended.isCompleted) _ended.complete();
  }

  /// This transfer and the earlier ones of its file that are still running.
  Iterable<_ModelTransfer> get unfinishedChain sync* {
    for (_ModelTransfer? t = this; t != null; t = t.previous) {
      if (!t.hasEnded) yield t;
    }
  }
}

@LazySingleton(as: AiInferenceDataSource)
class AiInferenceDataSourceImpl
    with AiInferenceHandler
    implements AiInferenceDataSource {
  final SharedPreferences _prefs;
  final Dio Function() _createDio;
  final FileDownloader? _fileDownloaderOverride;
  final bool _useDio;
  final Future<Directory> Function() _documentsDirectory;

  /// [createDio], [fileDownloader], [useDio], [documentsDirectory] and
  /// [transferEndLimit] are for tests. Desktop downloads with Dio, mobile
  /// with background_downloader.
  AiInferenceDataSourceImpl(
    this._prefs, {
    @ignoreParam Dio Function()? createDio,
    @ignoreParam FileDownloader? fileDownloader,
    @ignoreParam bool? useDio,
    @ignoreParam Future<Directory> Function()? documentsDirectory,
    @ignoreParam Duration? transferEndLimit,
  }) : _transferEndLimit = transferEndLimit ?? const Duration(seconds: 15),
       _createDio = createDio ?? Dio.new,
       _fileDownloaderOverride = fileDownloader,
       _useDio =
           useDio ??
           (Platform.isMacOS || Platform.isWindows || Platform.isLinux),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  /// How long a cancel, or a restart of the same file, waits for a transfer
  /// to report its end. A restart that runs out of time fails rather than
  /// write next to a transfer that may still be running.
  final Duration _transferEndLimit;

  final Map<String, _ModelTransfer> _transfers = {};

  FileDownloader get _fileDownloader =>
      _fileDownloaderOverride ?? FileDownloader();

  LlamaEngine? _engine;
  bool _hasVisionProjector = false;
  int? _deviceRamMB;
  DeviceProfile? _deviceProfile;

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
      if (Platform.isIOS) {
        final deviceInfo = DeviceInfoPlugin();
        final ios = await deviceInfo.iosInfo;
        _deviceRamMB = estimateIosRam(ios.utsname.machine);
      } else if (Platform.isAndroid) {
        _deviceRamMB = await _readAndroidRamMB();
        if (_deviceRamMB == null) {
          final deviceInfo = DeviceInfoPlugin();
          final android = await deviceInfo.androidInfo;
          _deviceRamMB = android.isLowRamDevice ? 2048 : 4096;
        }
      } else if (Platform.isMacOS) {
        _deviceRamMB = await _readMacOsRamMB();
      } else if (Platform.isWindows) {
        _deviceRamMB = await _readWindowsRamMB();
      } else if (Platform.isLinux) {
        _deviceRamMB = await _readLinuxRamMB();
      }
    } catch (e) {
      logger.w('Could not read the device RAM; assuming 4096 MB', e);
    }
    _deviceRamMB ??= 4096;
    return _deviceRamMB!;
  }

  Future<DeviceProfile> _getDeviceProfile() async {
    if (_deviceProfile != null) return _deviceProfile!;
    final ramMB = await _getDeviceRamMB();
    _deviceProfile = await DeviceCapabilityService.buildProfile(ramMB: ramMB);
    return _deviceProfile!;
  }

  static Future<int?> _readAndroidRamMB() async {
    try {
      final memInfo = await File('/proc/meminfo').readAsString();
      final match = RegExp(r'MemTotal:\s+(\d+)').firstMatch(memInfo);
      if (match != null) return int.parse(match.group(1)!) ~/ 1024;
    } catch (_) {
      // A failed RAM probe returns null; the caller falls back to an estimate.
    }
    return null;
  }

  static Future<int?> _readMacOsRamMB() async {
    try {
      final result = await Process.run('sysctl', ['-n', 'hw.memsize']);
      if (result.exitCode == 0) {
        final bytes = int.tryParse(result.stdout.toString().trim());
        if (bytes != null) return bytes ~/ (1024 * 1024);
      }
    } catch (_) {
      // A failed RAM probe returns null; the caller falls back to an estimate.
    }
    return null;
  }

  static Future<int?> _readWindowsRamMB() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        '(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory',
      ]);
      if (result.exitCode == 0) {
        final bytes = int.tryParse(result.stdout.toString().trim());
        if (bytes != null) return bytes ~/ (1024 * 1024);
      }
    } catch (_) {
      // A failed RAM probe returns null; the caller falls back to an estimate.
    }
    return null;
  }

  static Future<int?> _readLinuxRamMB() async {
    try {
      final memInfo = await File('/proc/meminfo').readAsString();
      final match = RegExp(r'MemTotal:\s+(\d+)').firstMatch(memInfo);
      if (match != null) return int.parse(match.group(1)!) ~/ 1024;
    } catch (_) {
      // A failed RAM probe returns null; the caller falls back to an estimate.
    }
    return null;
  }

  static Future<int> _getAvailableRamMB() async {
    if (Platform.isWindows) {
      try {
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          '(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory',
        ]);
        if (result.exitCode == 0) {
          final kb = int.tryParse(result.stdout.toString().trim());
          if (kb != null) return kb ~/ 1024;
        }
      } catch (_) {
        // A failed probe returns -1, which callers read as "unknown".
      }
      return -1;
    }
    if (Platform.isMacOS || Platform.isLinux) {
      return -1;
    }
    if (Platform.isAndroid) {
      try {
        final memInfo = await File('/proc/meminfo').readAsString();
        final match = RegExp(r'MemAvailable:\s+(\d+)').firstMatch(memInfo);
        if (match != null) return int.parse(match.group(1)!) ~/ 1024;
      } catch (_) {
        // A failed probe returns -1, which callers read as "unknown".
      }
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
    ProcessingLogBuffer.instance.log(
      '[$ts][ScanAI] iOS memory: RSS=${currentRssMB}MB, deviceRAM=${deviceRam}MB, ceiling=${(_iosMemoryCeiling * 100).toInt()}%, safeLimit=${safeLimit}MB, headroom=${available}MB',
    );
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

  static ({
    int gpuLayers,
    int threads,
    int threadsBatch,
    int contextSize,
  })
  computeModelConfigFromProfile({
    required bool withVision,
    required DeviceProfile profile,
  }) => DeviceCapabilityService.computeModelConfig(
    withVision: withVision,
    profile: profile,
  );

  Future<String> _getModelDirectory() async {
    final directory = await _documentsDirectory();
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
  bool isVisionModelAvailable() => _engine != null && _hasVisionProjector;

  Future<void> _configureDownloaderForLargeFile() async {
    if (!Platform.isAndroid) return;

    _fileDownloader.configureNotificationForGroup(
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

    await _fileDownloader.configure(
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
    // Registered before any await, so a cancel always finds it and a later
    // caller waits for it.
    final transfer = _ModelTransfer(_transfers[filename]);
    _transfers[filename] = transfer;

    try {
      // A quick restart waits for the earlier transfers of the same file to
      // stop writing and delete their partial file.
      final earlier = transfer.unfinishedChain.skip(1).toList();
      if (earlier.isNotEmpty) {
        try {
          await Future.wait(
            earlier.map((t) => t.ended),
          ).timeout(_transferEndLimit);
        } on TimeoutException {
          logger.e(
            'The previous download of $filename has not ended after '
            '${_transferEndLimit.inSeconds}s; not starting another',
          );
          throw Exception(
            'Download failed for $filename: the previous download has not '
            'ended',
          );
        }
      }
      transfer.previous = null;

      final dir = await _getModelDirectory();
      final filePath = path.join(dir, filename);

      if (File(filePath).existsSync()) {
        onProgress(100);
        return;
      }
      if (transfer.isCancelled) {
        throw ModelDownloadCancelledException(filename);
      }

      if (_useDio) {
        await _downloadWithDio(
          url: url,
          filePath: filePath,
          onProgress: onProgress,
          transfer: transfer,
        );
      } else {
        await _downloadWithBackgroundDownloader(
          url: url,
          filename: filename,
          filePath: filePath,
          onProgress: onProgress,
          transfer: transfer,
        );
      }
    } finally {
      if (identical(_transfers[filename], transfer)) {
        // An earlier transfer that outlived the wait stays the one to wait for.
        final stillRunning = transfer.unfinishedChain.skip(1).firstOrNull;
        if (stillRunning != null) {
          _transfers[filename] = stillRunning;
        } else {
          _transfers.remove(filename);
        }
      }
      transfer.end();
    }
  }

  Future<void> _cancelDownload(String filename) async {
    final latest = _transfers[filename];
    if (latest == null) return;

    // Also reaches a restart still waiting for the transfer it replaces.
    for (final transfer in latest.unfinishedChain.toList()) {
      if (transfer.isCancelled) continue;
      logger.i('Cancelling the download of $filename');
      transfer.cancelToken.cancel('Download cancelled for $filename');
      final taskId = transfer.taskId;
      if (taskId != null) {
        try {
          await _fileDownloader.cancelTaskWithId(taskId);
        } catch (e, s) {
          logger.e('Could not cancel the download task of $filename', e, s);
        }
      }
    }

    await latest.ended.timeout(
      _transferEndLimit,
      onTimeout: () => logger.w(
        'The cancelled download of $filename has not ended after '
        '${_transferEndLimit.inSeconds}s',
      ),
    );
  }

  Future<void> _downloadWithDio({
    required String url,
    required String filePath,
    required void Function(int) onProgress,
    required _ModelTransfer transfer,
  }) async {
    final dio = _createDio();
    final token = Env.huggingFaceToken;
    if (token.isNotEmpty) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }

    debugPrint('[AI_DOWNLOAD] Dio download: $url -> $filePath');

    final filename = path.basename(filePath);
    final tempFile = File('$filePath.tmp');
    RandomAccessFile? raf;
    try {
      // Streamed by hand rather than with dio.download: that returns as soon
      // as it is cancelled, while it is still writing and deleting the
      // partial file, so a restart could open the same file under it.
      final response = await dio.get<ResponseBody>(
        url,
        options: Options(responseType: ResponseType.stream),
        cancelToken: transfer.cancelToken,
      );
      final body = response.data;
      if (body == null) {
        throw StateError('The response has no body');
      }
      final total =
          int.tryParse(
            response.headers.value(Headers.contentLengthHeader) ?? '',
          ) ??
          -1;

      raf = await tempFile.open(mode: FileMode.write);
      await _writeBody(
        body.stream,
        raf,
        cancelToken: transfer.cancelToken,
        total: total,
        onProgress: onProgress,
      );
      final written = raf;
      raf = null;
      await written.close();

      // A cancel that lands as the last bytes arrive still wins.
      if (transfer.isCancelled) {
        throw ModelDownloadCancelledException(filename);
      }
      await tempFile.rename(filePath);
      debugPrint('[AI_DOWNLOAD] Dio download complete: $filePath');
    } catch (e, s) {
      if (raf != null) {
        try {
          await raf.close();
        } catch (closeError, closeStack) {
          logger.e(
            'Could not close the partial download $filename',
            closeError,
            closeStack,
          );
        }
      }
      await _deletePartialFile(tempFile);
      if (transfer.isCancelled) {
        logger.i('Download of $filename cancelled');
        throw ModelDownloadCancelledException(filename);
      }
      logger.e('Dio download of $filename failed', e, s);
      throw Exception('Download failed for $filename: $e');
    } finally {
      dio.close(force: true);
    }
  }

  /// Writes [body] to [raf] one chunk at a time. Completes, or fails, only
  /// after the last write has finished, so [raf] can be closed right after.
  /// A cancel stops reading at once, even when the server sends nothing.
  static Future<void> _writeBody(
    Stream<Uint8List> body,
    RandomAccessFile raf, {
    required CancelToken cancelToken,
    required int total,
    required void Function(int) onProgress,
  }) {
    final done = Completer<void>();
    var received = 0;
    Future<void> pendingWrite = Future.value();

    void fail(Object error, [StackTrace? stackTrace]) {
      if (!done.isCompleted) done.completeError(error, stackTrace);
    }

    late final StreamSubscription<Uint8List> subscription;
    subscription = body.listen(
      (chunk) {
        subscription.pause();
        final write = raf.writeFrom(chunk).then((_) {
          received += chunk.length;
          if (total > 0) onProgress(((received / total) * 100).round());
          if (!cancelToken.isCancelled) subscription.resume();
        });
        pendingWrite = write;
        write.catchError((Object e, StackTrace s) {
          unawaited(subscription.cancel());
          fail(e, s);
        });
      },
      onError: fail,
      onDone: () {
        pendingWrite.then(
          (_) {
            if (!done.isCompleted) done.complete();
          },
          onError: (Object _) {
            // A failed write has already failed `done`.
          },
        );
      },
      cancelOnError: true,
    );

    unawaited(
      cancelToken.whenCancel.then((error) async {
        await subscription.cancel();
        fail(error);
      }),
    );

    // Even after a cancel, the write in flight finishes before this returns.
    return done.future.whenComplete(
      () => pendingWrite.catchError((Object _) {
        // A failed write has already failed `done`.
      }),
    );
  }

  Future<void> _deletePartialFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (e, s) {
      logger.e('Could not delete the partial download ${file.path}', e, s);
    }
  }

  Future<void> _downloadWithBackgroundDownloader({
    required String url,
    required String filename,
    required String filePath,
    required void Function(int) onProgress,
    required _ModelTransfer transfer,
  }) async {
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
    // Known before the first await, so a cancel can always reach the task.
    transfer.taskId = task.taskId;

    await _configureDownloaderForLargeFile();
    if (transfer.isCancelled) {
      throw ModelDownloadCancelledException(filename);
    }

    // The file moves into ai_models/ only once the task completes, so a
    // cancelled task leaves nothing there.
    final update = await _fileDownloader.download(
      task,
      onProgress: (progress) {
        // Negative values mark the end states (failed, canceled, ...).
        if (progress >= 0) onProgress((progress * 100).round());
      },
    );

    switch (update.status) {
      case TaskStatus.complete:
        if (transfer.isCancelled) {
          // The cancel arrived as the task finished: honour it.
          await _deletePartialFile(File(filePath));
          throw ModelDownloadCancelledException(filename);
        }
      case TaskStatus.canceled:
        logger.i('Download of $filename cancelled');
        throw ModelDownloadCancelledException(filename);
      default:
        logger.e(
          'Download of $filename failed: ${update.status}',
          update.exception,
        );
        throw Exception('Download failed for $filename: ${update.status}');
    }
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
  Future<void> cancelModelDownloadForVariant(AiModelVariant variant) =>
      _cancelDownload(AiModelConfig.fromVariant(variant).modelId);

  @override
  Future<void> cancelMmprojDownloadForVariant(AiModelVariant variant) =>
      _cancelDownload(AiModelConfig.fromVariant(variant).mmprojId);

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
      throw ModelNotFoundException(modelPath);
    }

    final modelFile = File(modelPath);
    final fileSize = await modelFile.length();
    final profile = await _getDeviceProfile();
    final autoConfig = computeModelConfigFromProfile(
      withVision: withVision,
      profile: profile,
    );
    final effectiveGpuLayers = gpuLayers ?? autoConfig.gpuLayers;
    final effectiveThreads = threads ?? autoConfig.threads;
    final effectiveThreadsBatch = threads ?? autoConfig.threadsBatch;
    final ctx = contextSize ?? autoConfig.contextSize;
    final availableMB = Platform.isIOS
        ? await _getAvailableRamMBForIos()
        : await _getAvailableRamMB();
    final requiredMB = estimateRequiredMB(ctx, withVision: withVision);
    ProcessingLogBuffer.instance.log('[$ts][ScanAI] --- INIT MODEL ---');
    ProcessingLogBuffer.instance.log(
      '[$ts][ScanAI] model loaded (${(fileSize / 1024 / 1024).toStringAsFixed(0)}MB)',
    );
    ProcessingLogBuffer.instance.log(
      '[$ts][ScanAI] device: ${profile.platform}, ram=${profile.ramMB}MB, '
      'cores=${profile.physicalCores}p/${profile.logicalCores}l, '
      'gpu=${profile.gpuType.name}',
    );
    ProcessingLogBuffer.instance.log(
      '[$ts][ScanAI] config: ctx=$ctx, gpu_layers=$effectiveGpuLayers, '
      'threads=$effectiveThreads, threadsBatch=$effectiveThreadsBatch, '
      'available=${availableMB}MB, rssMB=${ProcessInfo.currentRss ~/ (1024 * 1024)}, '
      'required~${requiredMB}MB',
    );

    if (availableMB >= 0 && availableMB < requiredMB && !profile.isDesktop) {
      ProcessingLogBuffer.instance.log(
        '[$ts][ScanAI] ABORT: only ${availableMB}MB available, need ~${requiredMB}MB',
      );
      throw Exception(
        'Not enough memory to load the AI model. Available: ${availableMB}MB, required: ~${requiredMB}MB. Close other apps and try again.',
      );
    }

    if (!await _isValidGgufFile(modelPath)) {
      ProcessingLogBuffer.instance.log(
        '[$ts][ScanAI] ERROR: corrupt GGUF header, deleting file',
      );
      await modelFile.delete();
      throw Exception(
        'Model file is corrupted. Please re-download the AI model.',
      );
    }

    final GpuBackend backend;
    if (Platform.isAndroid) {
      backend = GpuBackend.cpu;
    } else if (!profile.hasUsableGpu) {
      backend = GpuBackend.cpu;
    } else {
      backend = GpuBackend.auto;
    }
    ProcessingLogBuffer.instance.log(
      '[$ts][ScanAI] creating engine with backend=$backend',
    );

    _engine = LlamaEngine(LlamaBackend());

    final params = ModelParams(
      contextSize: ctx,
      gpuLayers: effectiveGpuLayers,
      preferredBackend: backend,
      numberOfThreads: effectiveThreads,
      numberOfThreadsBatch: effectiveThreadsBatch,
    );
    ProcessingLogBuffer.instance.log(
      '[$ts][ScanAI] loadModel: ctx=${params.contextSize}, gpuLayers=${params.gpuLayers}, backend=${params.preferredBackend}, threads=${params.numberOfThreads}, threadsBatch=${params.numberOfThreadsBatch}',
    );

    final loadSw = Stopwatch()..start();
    try {
      await _engine!.setModel(
        LlamaModel(ModelSource.path(modelPath)),
        params: params,
      );
      loadSw.stop();
      ProcessingLogBuffer.instance.log(
        '[$ts][ScanAI] model loaded in ${(loadSw.elapsedMilliseconds / 1000.0).toStringAsFixed(1)}s',
      );
    } catch (e) {
      loadSw.stop();
      ProcessingLogBuffer.instance.log(
        '[$ts][ScanAI] model load FAILED after ${loadSw.elapsedMilliseconds}ms: $e',
      );
      await _engine?.dispose();
      _engine = null;
      rethrow;
    }

    if (withVision) {
      final mmprojPath = await _getMmprojFilePath();
      if (File(mmprojPath).existsSync()) {
        if (!await _isValidGgufFile(mmprojPath)) {
          ProcessingLogBuffer.instance.log(
            '[$ts][ScanAI] ERROR: corrupt mmproj GGUF, deleting',
          );
          await File(mmprojPath).delete();
          return;
        }
        final mmprojSw = Stopwatch()..start();
        try {
          await _engine!.loadMultimodalProjectorSource(
            ModelSource.path(mmprojPath),
          );
          _hasVisionProjector = true;
          mmprojSw.stop();
          ProcessingLogBuffer.instance.log(
            '[$ts][ScanAI] vision projector loaded in ${(mmprojSw.elapsedMilliseconds / 1000.0).toStringAsFixed(1)}s',
          );
        } catch (e) {
          mmprojSw.stop();
          ProcessingLogBuffer.instance.log(
            '[$ts][ScanAI] vision projector FAILED: $e',
          );
        }
      } else {
        ProcessingLogBuffer.instance.log(
          '[$ts][ScanAI] WARNING: mmproj file not found, vision disabled',
        );
      }
    }
  }

  @override
  Future<({int availableMB, int requiredMB, bool canProceed})>
  checkMemoryHealth({
    bool withVision = true,
    int? contextSize,
  }) async {
    final profile = await _getDeviceProfile();
    final autoConfig = computeModelConfigFromProfile(
      withVision: withVision,
      profile: profile,
    );
    final ctx = contextSize ?? autoConfig.contextSize;
    final availableMB = Platform.isIOS
        ? await _getAvailableRamMBForIos()
        : await _getAvailableRamMB();
    // The pipeline checks after initModel: weights already loaded are in RSS
    // (iOS) or gone from MemAvailable (Android), so only what is not loaded
    // yet, the context and the working memory still have to fit.
    final loadedMB = _engine == null
        ? 0
        : _activeConfig.modelSizeMB +
              (withVision && _hasVisionProjector
                  ? _activeConfig.mmprojSizeMB
                  : 0);
    final requiredMB =
        estimateRequiredMB(ctx, withVision: withVision) - loadedMB;
    final canProceed =
        (availableMB < 0) || availableMB >= requiredMB || profile.isDesktop;
    ProcessingLogBuffer.instance.log(
      '[$ts][ScanAI] health check: available=${availableMB}MB, required~=${requiredMB}MB, rssMB=${ProcessInfo.currentRss ~/ (1024 * 1024)}, canProceed=$canProceed',
    );
    return (
      availableMB: availableMB,
      requiredMB: requiredMB,
      canProceed: canProceed,
    );
  }

  @override
  Future<String?> runVisionPrompt({
    required String prompt,
    required List<String> imagePaths,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
  }) => runVisionPromptImpl(
    prompt: prompt,
    imagePaths: imagePaths,
    maxTokens: maxTokens,
    grammar: grammar,
    responseFormat: responseFormat,
  );

  @override
  Future<String?> runTextPrompt({
    required String prompt,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
    Map<String, dynamic>? chatTemplateKwargs,
  }) => runTextPromptImpl(
    prompt: prompt,
    maxTokens: maxTokens,
    grammar: grammar,
    responseFormat: responseFormat,
    chatTemplateKwargs: chatTemplateKwargs,
  );

  @override
  PromptFamily get promptFamily => _activeConfig.promptFamily;

  @override
  int get visionPagesPerBatch => _activeConfig.visionPagesPerBatch;
}
