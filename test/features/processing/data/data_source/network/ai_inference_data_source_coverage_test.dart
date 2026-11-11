import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/config/env/env.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_data_source.dart';
import 'package:health_wallet/features/processing/domain/entity/model_download_cancelled_exception.dart';
import 'package:health_wallet/features/processing/domain/entity/model_not_found_exception.dart';
import 'package:health_wallet/features/processing/domain/services/device_capability_service.dart';
import 'package:health_wallet/features/processing/domain/services/processing_log_buffer.dart';
import 'package:llamadart/llamadart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One canned HTTP answer.
class _Reply {
  const _Reply({
    this.chunks = const ['GGUF'],
    this.statusCode = 200,
    this.contentLength,
  });

  final List<String> chunks;
  final int statusCode;

  /// The Content-Length header; null sends none.
  final int? contentLength;
}

/// Answers every request at once with [reply] and records the requests.
class _CannedServer implements HttpClientAdapter {
  _CannedServer([this.reply = const _Reply(contentLength: 4)]);

  final _Reply reply;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody(
      Stream.fromIterable(
        reply.chunks.map((c) => Uint8List.fromList(c.codeUnits)),
      ),
      reply.statusCode,
      headers: {
        if (reply.contentLength != null)
          Headers.contentLengthHeader: ['${reply.contentLength}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// background_downloader stand-in that ends each task as told, after
/// reporting [progressValues]. Any other plugin call (such as the Android
/// notification setup) throws, as [Fake] does.
class _CannedFileDownloader extends Fake implements FileDownloader {
  _CannedFileDownloader(
    this.modelDir, {
    this.status = TaskStatus.complete,
    this.progressValues = const [],
  });

  final Directory modelDir;
  final TaskStatus status;
  final List<double> progressValues;
  final tasks = <DownloadTask>[];

  @override
  Future<TaskStatusUpdate> download(
    DownloadTask task, {
    void Function(TaskStatus)? onStatus,
    void Function(double)? onProgress,
    void Function(Duration)? onElapsedTime,
    Duration? elapsedTimeInterval,
  }) async {
    tasks.add(task);
    progressValues.forEach(onProgress!);
    if (status == TaskStatus.complete) {
      File('${modelDir.path}/${task.filename}')
        ..createSync(recursive: true)
        ..writeAsStringSync('GGUF');
    }
    return TaskStatusUpdate(task, status);
  }
}

/// background_downloader stand-in whose tasks run until the test ends them.
/// A cancel ends the task as cancelled, or throws when [cancelThrows].
class _PendingFileDownloader extends Fake implements FileDownloader {
  _PendingFileDownloader(this.modelDir, {this.cancelThrows = false});

  final Directory modelDir;
  final bool cancelThrows;
  final tasks = <String, DownloadTask>{};
  final _ends = <String, Completer<TaskStatusUpdate>>{};
  final cancelledTaskIds = <String>[];

  @override
  Future<TaskStatusUpdate> download(
    DownloadTask task, {
    void Function(TaskStatus)? onStatus,
    void Function(double)? onProgress,
    void Function(Duration)? onElapsedTime,
    Duration? elapsedTimeInterval,
  }) {
    tasks[task.filename] = task;
    return (_ends[task.filename] = Completer<TaskStatusUpdate>()).future;
  }

  void complete(String filename) {
    File('${modelDir.path}/$filename')
      ..createSync(recursive: true)
      ..writeAsStringSync('GGUF');
    _ends[filename]!.complete(
      TaskStatusUpdate(tasks[filename]!, TaskStatus.complete),
    );
  }

  @override
  Future<bool> cancelTaskWithId(String taskId) async {
    cancelledTaskIds.add(taskId);
    if (cancelThrows) {
      throw PlatformException(code: 'cancel', message: 'plugin unavailable');
    }
    final task = tasks.values.firstWhere((t) => t.taskId == taskId);
    _ends[task.filename]!.complete(TaskStatusUpdate(task, TaskStatus.canceled));
    return true;
  }
}

/// Polls [condition]: the downloads touch real files, which completes outside
/// the microtask queue.
Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

/// Stands in for a loaded llama engine; only [dispose] is expected.
class _FakeEngine extends Fake implements LlamaEngine {
  var disposed = false;

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  late Directory docs;
  late Directory modelDir;
  late SharedPreferences prefs;
  late ProcessingLogBuffer log;
  late String originalToken;

  Future<void> selectModel(AiModelVariant? variant) async {
    SharedPreferences.setMockInitialValues({
      if (variant != null) SharedPrefsConstants.aiSelectedModel: variant.name,
    });
    prefs = await SharedPreferences.getInstance();
  }

  setUp(() async {
    await selectModel(AiModelVariant.qwen);
    docs = Directory.systemTemp.createTempSync('hw_ai_inference_cov_');
    modelDir = Directory('${docs.path}/ai_models');
    log = ProcessingLogBuffer.forTesting(enabled: true, directory: docs);
    ProcessingLogBuffer.debugOverrideInstance(log);
    originalToken = Env.huggingFaceToken;
    Env.huggingFaceToken = '';
  });

  tearDown(() async {
    Env.huggingFaceToken = originalToken;
    ProcessingLogBuffer.debugOverrideInstance(null);
    // Lets the log buffer finish its pending append before the folder goes.
    await log.readPersistedLogs();
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  File fileIn(String name) => File('${modelDir.path}/$name');

  void put(String name, String content) => fileIn(name)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  AiInferenceDataSourceImpl dioDataSource(
    _CannedServer server, {
    void Function(Dio)? configure,
  }) => AiInferenceDataSourceImpl(
    prefs,
    createDio: () {
      final dio = Dio()..httpClientAdapter = server;
      configure?.call(dio);
      return dio;
    },
    useDio: true,
    documentsDirectory: () async => docs,
  );

  AiInferenceDataSourceImpl mobileDataSource(_CannedFileDownloader d) =>
      AiInferenceDataSourceImpl(
        prefs,
        fileDownloader: d,
        useDio: false,
        documentsDirectory: () async => docs,
      );

  AiInferenceDataSourceImpl plainDataSource() => AiInferenceDataSourceImpl(
    prefs,
    useDio: true,
    documentsDirectory: () async => docs,
  );

  Matcher downloadFailed(String filename, [String? detail]) => throwsA(
    isA<Exception>()
        .having(
          (e) => e,
          'not a cancel',
          isNot(isA<ModelDownloadCancelledException>()),
        )
        .having(
          (e) => e.toString(),
          'message',
          allOf(
            contains('Download failed for $filename'),
            contains(detail ?? ''),
          ),
        ),
  );

  final isDesktopHost = Platform.isMacOS || Platform.isLinux;
  final desktopHostOnly = isDesktopHost
      ? null
      : 'RAM and device checks are pinned for macOS and Linux hosts';

  group('model files on disk', () {
    test('existence checks look in ai_models/ under the documents '
        'directory, for the active model', () async {
      await selectModel(AiModelVariant.qwen35x4b);
      final dataSource = plainDataSource();

      expect(await dataSource.checkModelExistence(), isFalse);
      // The check creates the folder for later downloads.
      expect(modelDir.existsSync(), isTrue);

      put(AiModelConfig.qwen35x4b.modelId, 'GGUF');
      expect(await dataSource.checkModelExistence(), isTrue);
    });

    test('a file of another model does not count for the active one', () async {
      final dataSource = plainDataSource();
      put(AiModelConfig.qwen7b.modelId, 'GGUF');
      put(AiModelConfig.qwen7b.mmprojId, 'GGUF');

      expect(await dataSource.checkModelExistence(), isFalse);
      expect(
        await dataSource.checkModelExistenceForVariant(AiModelVariant.qwen7b),
        isTrue,
      );
      expect(
        await dataSource.checkMmprojExistenceForVariant(AiModelVariant.qwen7b),
        isTrue,
      );
      expect(
        await dataSource.checkMmprojExistenceForVariant(AiModelVariant.qwen),
        isFalse,
      );
    });

    test(
      'deleting a variant removes its model and vision files only',
      () async {
        final dataSource = plainDataSource();
        put(AiModelConfig.qwen.modelId, 'GGUF');
        put(AiModelConfig.qwen.mmprojId, 'GGUF');
        put(AiModelConfig.qwen7b.modelId, 'GGUF');

        await dataSource.deleteModelForVariant(AiModelVariant.qwen);

        expect(fileIn(AiModelConfig.qwen.modelId).existsSync(), isFalse);
        expect(fileIn(AiModelConfig.qwen.mmprojId).existsSync(), isFalse);
        expect(fileIn(AiModelConfig.qwen7b.modelId).existsSync(), isTrue);
      },
    );

    test('deleting a variant with only its model file, or none, '
        'succeeds', () async {
      final dataSource = plainDataSource();
      put(AiModelConfig.qwen.modelId, 'GGUF');

      await dataSource.deleteModelForVariant(AiModelVariant.qwen);
      expect(fileIn(AiModelConfig.qwen.modelId).existsSync(), isFalse);

      await dataSource.deleteModelForVariant(AiModelVariant.qwen);
      expect(modelDir.listSync(), isEmpty);
    });
  });

  group('Dio download (desktop)', () {
    test('a variant\'s model and vision files are fetched from its URLs '
        'into its file names', () async {
      final server = _CannedServer();
      final dataSource = dioDataSource(server);

      await dataSource.downloadModelForVariant(
        AiModelVariant.qwen35x4b,
        onProgress: (_) {},
      );
      await dataSource.downloadMmprojForVariant(
        AiModelVariant.qwen35x4b,
        onProgress: (_) {},
      );

      expect(server.requests.map((r) => r.uri.toString()), [
        AiModelConfig.qwen35x4b.modelUrl,
        AiModelConfig.qwen35x4b.mmprojUrl,
      ]);
      expect(
        fileIn(AiModelConfig.qwen35x4b.modelId).readAsStringSync(),
        'GGUF',
      );
      expect(
        fileIn(AiModelConfig.qwen35x4b.mmprojId).readAsStringSync(),
        'GGUF',
      );
      expect(
        await dataSource.checkModelExistenceForVariant(
          AiModelVariant.qwen35x4b,
        ),
        isTrue,
      );
      expect(
        await dataSource.checkMmprojExistenceForVariant(
          AiModelVariant.qwen35x4b,
        ),
        isTrue,
      );
    });

    test('progress is the rounded share of Content-Length', () async {
      final server = _CannedServer(
        const _Reply(chunks: ['G', 'G', 'U'], contentLength: 3),
      );
      final progress = <int>[];

      await dioDataSource(server).downloadModelForVariant(
        AiModelVariant.qwen,
        onProgress: progress.add,
      );

      expect(progress, [33, 67, 100]);
      expect(fileIn(AiModelConfig.qwen.modelId).readAsStringSync(), 'GGU');
      expect(fileIn('${AiModelConfig.qwen.modelId}.tmp').existsSync(), isFalse);
    });

    test('without Content-Length the file is written but no progress is '
        'reported', () async {
      final server = _CannedServer(const _Reply(chunks: ['GG', 'UF']));
      final progress = <int>[];

      await dioDataSource(server).downloadMmprojForVariant(
        AiModelVariant.qwen,
        onProgress: progress.add,
      );

      expect(progress, isEmpty);
      expect(fileIn(AiModelConfig.qwen.mmprojId).readAsStringSync(), 'GGUF');
    });

    test('a file already in place reports 100 without a request', () async {
      put(AiModelConfig.qwen.modelId, 'GGUF-old');
      final server = _CannedServer();
      final progress = <int>[];

      await dioDataSource(server).downloadModelForVariant(
        AiModelVariant.qwen,
        onProgress: progress.add,
      );

      expect(progress, [100]);
      expect(server.requests, isEmpty);
      expect(fileIn(AiModelConfig.qwen.modelId).readAsStringSync(), 'GGUF-old');
    });

    test('sends the Hugging Face token as a bearer header when one is '
        'set', () async {
      Env.huggingFaceToken = 'hf_test';
      final server = _CannedServer();

      await dioDataSource(
        server,
      ).downloadModelForVariant(AiModelVariant.qwen, onProgress: (_) {});

      expect(server.requests.single.headers['Authorization'], 'Bearer hf_test');
    });

    test('sends no Authorization header without a token', () async {
      final server = _CannedServer();

      await dioDataSource(
        server,
      ).downloadModelForVariant(AiModelVariant.qwen, onProgress: (_) {});

      expect(
        server.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test(
      'an HTTP error status fails the download and leaves no file',
      () async {
        final server = _CannedServer(
          const _Reply(chunks: ['nope'], statusCode: 404),
        );

        await expectLater(
          dioDataSource(
            server,
          ).downloadModelForVariant(AiModelVariant.qwen, onProgress: (_) {}),
          downloadFailed(AiModelConfig.qwen.modelId, '404'),
        );

        expect(fileIn(AiModelConfig.qwen.modelId).existsSync(), isFalse);
        expect(
          fileIn('${AiModelConfig.qwen.modelId}.tmp').existsSync(),
          isFalse,
        );
      },
    );

    test('a response without a body fails the download', () async {
      final server = _CannedServer();
      final dataSource = dioDataSource(
        server,
        configure: (dio) => dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(
              Response<ResponseBody>(requestOptions: options, statusCode: 200),
            ),
          ),
        ),
      );

      await expectLater(
        dataSource.downloadModelForVariant(
          AiModelVariant.qwen,
          onProgress: (_) {},
        ),
        downloadFailed(AiModelConfig.qwen.modelId, 'The response has no body'),
      );
      expect(fileIn(AiModelConfig.qwen.modelId).existsSync(), isFalse);
    });

    test('a partial file that cannot be opened fails the download', () async {
      // A folder where the partial file goes makes opening it fail.
      Directory(
        '${modelDir.path}/${AiModelConfig.qwen.modelId}.tmp',
      ).createSync(recursive: true);

      await expectLater(
        dioDataSource(
          _CannedServer(),
        ).downloadModelForVariant(AiModelVariant.qwen, onProgress: (_) {}),
        downloadFailed(AiModelConfig.qwen.modelId),
      );
      expect(fileIn(AiModelConfig.qwen.modelId).existsSync(), isFalse);
    });
  });

  group('background_downloader (mobile)', () {
    test('the task downloads the model into ai_models/ of the documents '
        'directory', () async {
      final downloader = _CannedFileDownloader(modelDir);
      final dataSource = mobileDataSource(downloader);

      await dataSource.downloadModelForVariant(
        AiModelVariant.qwen35x4b,
        onProgress: (_) {},
      );
      await dataSource.downloadMmprojForVariant(
        AiModelVariant.qwen35x4b,
        onProgress: (_) {},
      );

      final model = downloader.tasks.first;
      expect(model.url, AiModelConfig.qwen35x4b.modelUrl);
      expect(model.filename, AiModelConfig.qwen35x4b.modelId);
      expect(model.directory, 'ai_models');
      expect(model.baseDirectory, BaseDirectory.applicationDocuments);
      expect(model.updates, Updates.statusAndProgress);
      expect(model.headers, isEmpty);
      expect(downloader.tasks.last.url, AiModelConfig.qwen35x4b.mmprojUrl);
      expect(downloader.tasks.last.filename, AiModelConfig.qwen35x4b.mmprojId);
      expect(
        await dataSource.checkModelExistenceForVariant(
          AiModelVariant.qwen35x4b,
        ),
        isTrue,
      );
      expect(
        await dataSource.checkMmprojExistenceForVariant(
          AiModelVariant.qwen35x4b,
        ),
        isTrue,
      );
    });

    test('the task carries the Hugging Face token when one is set', () async {
      Env.huggingFaceToken = 'hf_mobile';
      final downloader = _CannedFileDownloader(modelDir);

      await mobileDataSource(
        downloader,
      ).downloadModelForVariant(AiModelVariant.qwen, onProgress: (_) {});

      expect(downloader.tasks.single.headers, {
        'Authorization': 'Bearer hf_mobile',
      });
    });

    test('progress becomes a rounded percentage; negative end-state values '
        'are dropped', () async {
      final downloader = _CannedFileDownloader(
        modelDir,
        progressValues: [0, 0.256, 1, -1, -2],
      );
      final progress = <int>[];

      await mobileDataSource(downloader).downloadModelForVariant(
        AiModelVariant.qwen,
        onProgress: progress.add,
      );

      expect(progress, [0, 26, 100]);
    });

    test('a file already in place reports 100 without a task', () async {
      put(AiModelConfig.qwen.mmprojId, 'GGUF');
      final downloader = _CannedFileDownloader(modelDir);
      final progress = <int>[];

      await mobileDataSource(downloader).downloadMmprojForVariant(
        AiModelVariant.qwen,
        onProgress: progress.add,
      );

      expect(progress, [100]);
      expect(downloader.tasks, isEmpty);
    });

    test('a task the system cancelled ends as a cancel', () async {
      final downloader = _CannedFileDownloader(
        modelDir,
        status: TaskStatus.canceled,
      );

      await expectLater(
        mobileDataSource(
          downloader,
        ).downloadModelForVariant(AiModelVariant.qwen, onProgress: (_) {}),
        throwsA(
          isA<ModelDownloadCancelledException>().having(
            (e) => e.filename,
            'filename',
            AiModelConfig.qwen.modelId,
          ),
        ),
      );
    });

    test('a failed task names the file and the status', () async {
      final downloader = _CannedFileDownloader(
        modelDir,
        status: TaskStatus.failed,
      );

      await expectLater(
        mobileDataSource(
          downloader,
        ).downloadMmprojForVariant(AiModelVariant.qwen, onProgress: (_) {}),
        downloadFailed(AiModelConfig.qwen.mmprojId, 'TaskStatus.failed'),
      );
      expect(fileIn(AiModelConfig.qwen.mmprojId).existsSync(), isFalse);
    });

    test('a download can start again after a failed one', () async {
      final failing = _CannedFileDownloader(
        modelDir,
        status: TaskStatus.failed,
      );
      final dataSource = mobileDataSource(failing);
      await expectLater(
        dataSource.downloadModelForVariant(
          AiModelVariant.qwen,
          onProgress: (_) {},
        ),
        downloadFailed(AiModelConfig.qwen.modelId),
      );

      // The ended transfer is forgotten, so the retry does not wait on it.
      await expectLater(
        dataSource.downloadModelForVariant(
          AiModelVariant.qwen,
          onProgress: (_) {},
        ),
        downloadFailed(AiModelConfig.qwen.modelId),
      );
      expect(failing.tasks, hasLength(2));
    });

    test('cancelling the vision download stops only its task', () async {
      final downloader = _PendingFileDownloader(modelDir);
      final dataSource = AiInferenceDataSourceImpl(
        prefs,
        fileDownloader: downloader,
        useDio: false,
        documentsDirectory: () async => docs,
      );

      final mmproj = expectLater(
        dataSource.downloadMmprojForVariant(
          AiModelVariant.qwen,
          onProgress: (_) {},
        ),
        throwsA(isA<ModelDownloadCancelledException>()),
      );
      final model = dataSource.downloadModelForVariant(
        AiModelVariant.qwen,
        onProgress: (_) {},
      );
      await _until(() => downloader.tasks.length == 2);

      await dataSource.cancelMmprojDownloadForVariant(AiModelVariant.qwen);
      await mmproj;

      expect(downloader.cancelledTaskIds, [
        downloader.tasks[AiModelConfig.qwen.mmprojId]!.taskId,
      ]);
      downloader.complete(AiModelConfig.qwen.modelId);
      await model;
      expect(fileIn(AiModelConfig.qwen.modelId).existsSync(), isTrue);
      expect(fileIn(AiModelConfig.qwen.mmprojId).existsSync(), isFalse);
    });

    test('cancelling the vision download with none running does '
        'nothing', () async {
      final downloader = _PendingFileDownloader(modelDir);
      final dataSource = AiInferenceDataSourceImpl(
        prefs,
        fileDownloader: downloader,
        useDio: false,
        documentsDirectory: () async => docs,
      );

      await dataSource.cancelMmprojDownloadForVariant(AiModelVariant.qwen);

      expect(downloader.cancelledTaskIds, isEmpty);
      expect(modelDir.existsSync(), isFalse);
    });

    test('a plugin error while cancelling is survived, and the task that '
        'then completes still counts as cancelled', () async {
      final downloader = _PendingFileDownloader(modelDir, cancelThrows: true);
      final dataSource = AiInferenceDataSourceImpl(
        prefs,
        fileDownloader: downloader,
        useDio: false,
        documentsDirectory: () async => docs,
        transferEndLimit: const Duration(milliseconds: 50),
      );

      final download = expectLater(
        dataSource.downloadModelForVariant(
          AiModelVariant.qwen,
          onProgress: (_) {},
        ),
        throwsA(isA<ModelDownloadCancelledException>()),
      );
      await _until(() => downloader.tasks.isNotEmpty);

      // The plugin throws and the task never reports its end: the cancel
      // gives up waiting after the limit instead of hanging.
      await dataSource.cancelModelDownloadForVariant(AiModelVariant.qwen);
      expect(downloader.cancelledTaskIds, hasLength(1));

      downloader.complete(AiModelConfig.qwen.modelId);
      await download;
      expect(fileIn(AiModelConfig.qwen.modelId).existsSync(), isFalse);
    });
  });

  group('memory estimate', () {
    test('adds weights, vision projector, KV cache and overhead', () async {
      final dataSource = plainDataSource();

      // Qwen Lite: 1056 MB weights, 445 MB projector, 400 MB overhead.
      expect(dataSource.estimateRequiredMB(2048), 1056 + 445 + 340 + 400);
      expect(
        dataSource.estimateRequiredMB(2048, withVision: false),
        1056 + 340 + 400,
      );
      // 1000 * 170 ~/ 1024 = 166.
      expect(
        dataSource.estimateRequiredMB(1000, withVision: false),
        1056 + 166 + 400,
      );
    });

    test('a model of 2 GB or more gets the larger overhead', () async {
      await selectModel(AiModelVariant.qwen7b);

      // Ultra: 4560 MB weights, 815 MB projector, 700 MB overhead.
      expect(
        plainDataSource().estimateRequiredMB(4096),
        4560 + 815 + 680 + 700,
      );
    });

    test('the KV cache costs 170 MB per 1024 tokens', () {
      expect(AiInferenceDataSourceImpl.kvCacheMBPerCtx1024, 170);
    });

    test('iOS RAM comes from the device model', () {
      expect(AiInferenceDataSourceImpl.estimateIosRam('iPhone17,1'), 8192);
      expect(AiInferenceDataSourceImpl.estimateIosRam('iPhone14,2'), 6144);
      expect(AiInferenceDataSourceImpl.estimateIosRam('iPhone14,5'), 4096);
      expect(AiInferenceDataSourceImpl.estimateIosRam('iPad13,4'), 8192);
      expect(AiInferenceDataSourceImpl.estimateIosRam('x86_64'), 4096);
    });

    test('the model config follows the device profile', () {
      const profile = DeviceProfile(
        ramMB: 16384,
        logicalCores: 8,
        physicalCores: 8,
        gpuType: GpuType.appleSilicon,
        isDesktop: true,
        platform: 'macos',
      );

      for (final withVision in [true, false]) {
        expect(
          AiInferenceDataSourceImpl.computeModelConfigFromProfile(
            withVision: withVision,
            profile: profile,
          ),
          DeviceCapabilityService.computeModelConfig(
            withVision: withVision,
            profile: profile,
          ),
        );
      }
    });
  });

  group('memory health check (desktop host)', skip: desktopHostOnly, () {
    test('with nothing loaded the full estimate is required, and a desktop '
        'always proceeds', () async {
      final dataSource = plainDataSource();

      final health = await dataSource.checkMemoryHealth(contextSize: 2048);

      // macOS and Linux report no free-memory figure.
      expect(health.availableMB, -1);
      expect(health.requiredMB, dataSource.estimateRequiredMB(2048));
      expect(health.canProceed, isTrue);
      expect(
        log.getAll().last,
        contains(
          'health check: available=-1MB, '
          'required~=${dataSource.estimateRequiredMB(2048)}MB',
        ),
      );
    });

    test('without a context size the device decides it', () async {
      final dataSource = plainDataSource();

      final health = await dataSource.checkMemoryHealth(withVision: false);

      expect(
        health.requiredMB,
        isIn([
          for (final ctx in [512, 1024, 2048, 4096])
            dataSource.estimateRequiredMB(ctx, withVision: false),
        ]),
      );
      expect(health.canProceed, isTrue);
    });

    test(
      'weights and projector already loaded are not required again',
      () async {
        final dataSource = plainDataSource()
          ..engine = _FakeEngine()
          ..hasVisionProjector = true;

        final withVision = await dataSource.checkMemoryHealth(
          contextSize: 1024,
        );
        final textOnly = await dataSource.checkMemoryHealth(
          withVision: false,
          contextSize: 1024,
        );

        expect(
          withVision.requiredMB,
          dataSource.estimateRequiredMB(1024) - 1056 - 445,
        );
        expect(
          textOnly.requiredMB,
          dataSource.estimateRequiredMB(1024, withVision: false) - 1056,
        );
      },
    );

    test('a loaded model without a projector still needs the projector '
        'for a vision call', () async {
      final dataSource = plainDataSource()..engine = _FakeEngine();

      final health = await dataSource.checkMemoryHealth(contextSize: 1024);

      expect(health.requiredMB, dataSource.estimateRequiredMB(1024) - 1056);
    });
  });

  group('engine state', () {
    test('the default constructor needs only the preferences and loads '
        'nothing', () {
      final dataSource = AiInferenceDataSourceImpl(prefs);

      expect(dataSource.engine, isNull);
      expect(dataSource.isVisionModelAvailable(), isFalse);
      expect(dataSource.estimateRequiredMB(1024), 1056 + 445 + 170 + 400);
    });

    test('vision is available only with an engine and a projector', () {
      final dataSource = plainDataSource();
      expect(dataSource.isVisionModelAvailable(), isFalse);

      dataSource.engine = _FakeEngine();
      expect(dataSource.isVisionModelAvailable(), isFalse);

      dataSource.hasVisionProjector = true;
      expect(dataSource.isVisionModelAvailable(), isTrue);
      expect(dataSource.hasVisionProjector, isTrue);
    });

    test('disposeModel releases the engine and the projector', () async {
      final engine = _FakeEngine();
      final dataSource = plainDataSource()
        ..engine = engine
        ..hasVisionProjector = true;

      await dataSource.disposeModel();

      expect(engine.disposed, isTrue);
      expect(dataSource.engine, isNull);
      expect(dataSource.isVisionModelAvailable(), isFalse);
    });

    test('prompts without a loaded model fail and leave no stats', () async {
      final dataSource = plainDataSource();
      final notInitialized = throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Model not initialized'),
        ),
      );

      await expectLater(
        dataSource.runTextPrompt(prompt: 'hi'),
        notInitialized,
      );
      await expectLater(
        dataSource.runVisionPrompt(prompt: 'hi', imagePaths: const []),
        notInitialized,
      );
      expect(dataSource.lastGenerationStats, isNull);
    });

    test(
      'prompt family and pages per batch come from the active model',
      () async {
        await selectModel(AiModelVariant.nuExtract3);
        expect(plainDataSource().promptFamily, PromptFamily.nuExtract3);
        expect(plainDataSource().visionPagesPerBatch, 2);

        await selectModel(AiModelVariant.qwen35x4b);
        expect(plainDataSource().promptFamily, PromptFamily.standard);
        expect(plainDataSource().visionPagesPerBatch, 1);
      },
    );

    test('the log timestamp is a time of day with milliseconds', () {
      expect(plainDataSource().ts, matches(RegExp(r'^\d\d:\d\d:\d\d\.\d{3}$')));
    });
  });

  group('initModel', () {
    test('does nothing when an engine is already loaded', () async {
      final engine = _FakeEngine();
      final dataSource = plainDataSource()..engine = engine;

      // No model file: a second load would throw.
      await dataSource.initModel();

      expect(dataSource.engine, same(engine));
      expect(engine.disposed, isFalse);
    });

    test(
      'a missing model file is ModelNotFoundException with its path',
      () async {
        final dataSource = plainDataSource();

        await expectLater(
          dataSource.initModel(),
          throwsA(
            isA<ModelNotFoundException>().having(
              (e) => e.path,
              'path',
              fileIn(AiModelConfig.qwen.modelId).path,
            ),
          ),
        );
        expect(dataSource.engine, isNull);
      },
    );

    for (final (label, content) in [
      ('a wrong header', 'NOTAGGUF'),
      ('fewer than four bytes', 'GG'),
      ('an empty file', ''),
    ]) {
      test(
        'a model file with $label is deleted as corrupt',
        skip: desktopHostOnly,
        () async {
          put(AiModelConfig.qwen.modelId, content);
          final dataSource = plainDataSource();

          await expectLater(
            dataSource.initModel(contextSize: 1234, gpuLayers: 7, threads: 3),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains(
                  'Model file is corrupted. Please re-download the AI model.',
                ),
              ),
            ),
          );

          expect(fileIn(AiModelConfig.qwen.modelId).existsSync(), isFalse);
          expect(dataSource.engine, isNull);
          final lines = log.getAll();
          expect(lines, contains(endsWith('--- INIT MODEL ---')));
          // The caller's context, GPU layers and threads win over the
          // device's.
          expect(
            lines,
            contains(
              contains(
                'config: ctx=1234, gpu_layers=7, threads=3, threadsBatch=3, '
                'available=-1MB',
              ),
            ),
          );
          expect(
            lines,
            contains(
              contains('required~${dataSource.estimateRequiredMB(1234)}MB'),
            ),
          );
          expect(
            lines,
            contains(endsWith('ERROR: corrupt GGUF header, deleting file')),
          );
        },
      );
    }

    test(
      'a model the runtime cannot load fails, keeps the file and leaves no '
      'engine',
      skip: desktopHostOnly,
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // A valid header in front of garbage: the GGUF check passes and the
        // native load fails.
        put(AiModelConfig.qwen.modelId, 'GGUFgarbage');
        final dataSource = plainDataSource();

        await expectLater(
          dataSource.initModel(withVision: false, contextSize: 512),
          throwsA(anything),
        );

        expect(dataSource.engine, isNull);
        expect(dataSource.isVisionModelAvailable(), isFalse);
        expect(
          fileIn(AiModelConfig.qwen.modelId).readAsStringSync(),
          'GGUFgarbage',
        );
        final lines = log.getAll();
        expect(lines, isNot(contains(contains('corrupt GGUF'))));
        expect(lines, contains(contains('creating engine with backend=')));
      },
    );
  });
}
