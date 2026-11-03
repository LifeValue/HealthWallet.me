import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:background_downloader/background_downloader.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/features/processing/data/data_source/local/processing_local_data_source.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_data_source.dart';
import 'package:health_wallet/features/processing/data/repository/processing_repository_impl.dart';
import 'package:health_wallet/features/processing/domain/entity/model_download_cancelled_exception.dart';
import 'package:health_wallet/features/processing/domain/services/ai_model_download_service.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _variant = AiModelVariant.qwen;
final _config = AiModelConfig.fromVariant(_variant);

/// One response the fake server is sending; the test feeds its bytes.
class _Response {
  _Response(this.uri, this.events) {
    body = StreamController<Uint8List>(
      onCancel: () => events.add('${uri.pathSegments.last} stopped'),
    );
  }

  final Uri uri;
  final List<String> events;
  late final StreamController<Uint8List> body;

  bool get isRead => body.hasListener;

  void send(String bytes) => body.add(Uint8List.fromList(bytes.codeUnits));

  Future<void> finish() => body.close();
}

/// Serves every request with a 4-byte body the test sends by hand. Like
/// Dio's real adapter, a cancel aborts the response unless [abortOnCancel]
/// is false (a server that has stalled and never answers the abort).
class _FakeServer implements HttpClientAdapter {
  _FakeServer({this.abortOnCancel = true});

  final bool abortOnCancel;
  final responses = <_Response>[];
  final events = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = _Response(options.uri, events);
    responses.add(response);
    events.add('${options.uri.pathSegments.last} requested');
    if (abortOnCancel) {
      unawaited(
        cancelFuture?.whenComplete(() {
          if (response.body.isClosed) return;
          response.body.addError(const SocketException('aborted'));
          unawaited(response.body.close());
        }),
      );
    }
    return ResponseBody(
      response.body.stream,
      200,
      headers: {
        Headers.contentLengthHeader: ['4'],
      },
    );
  }

  _Response responseFor(String filename) =>
      responses.lastWhere((r) => r.uri.pathSegments.last == filename);

  @override
  void close({bool force = false}) {}
}

/// background_downloader stand-in: a task ends when the test completes it or
/// when it is cancelled by id.
class _FakeFileDownloader extends Fake implements FileDownloader {
  _FakeFileDownloader(this.modelDir, {this.cancelEndsTask = true});

  final Directory modelDir;
  final bool cancelEndsTask;
  final tasks = <String, DownloadTask>{};
  final _ends = <String, Completer<TaskStatusUpdate>>{};
  final _progress = <String, void Function(double)?>{};
  final cancelledTaskIds = <String>[];
  var downloadCalls = 0;
  var cancelAllCalls = 0;

  @override
  Future<TaskStatusUpdate> download(
    DownloadTask task, {
    void Function(TaskStatus)? onStatus,
    void Function(double)? onProgress,
    void Function(Duration)? onElapsedTime,
    Duration? elapsedTimeInterval,
  }) {
    downloadCalls++;
    tasks[task.filename] = task;
    _progress[task.filename] = onProgress;
    return (_ends[task.filename] = Completer<TaskStatusUpdate>()).future;
  }

  void progress(String filename, double value) =>
      _progress[filename]?.call(value);

  /// The file moves into place only on completion, like the real plugin.
  void complete(String filename) {
    File('${modelDir.path}/$filename')
      ..createSync(recursive: true)
      ..writeAsStringSync('GGUF');
    _ends[filename]!.complete(
      TaskStatusUpdate(tasks[filename]!, TaskStatus.complete),
    );
  }

  /// Ends the task as the plugin does once a cancel has gone through.
  void endCancelled(String filename) => _ends[filename]!.complete(
    TaskStatusUpdate(tasks[filename]!, TaskStatus.canceled),
  );

  @override
  Future<bool> cancelTaskWithId(String taskId) async {
    cancelledTaskIds.add(taskId);
    if (!cancelEndsTask) return false;
    final task = tasks.values.firstWhere((t) => t.taskId == taskId);
    progress(task.filename, -2);
    _ends[task.filename]!.complete(
      TaskStatusUpdate(task, TaskStatus.canceled),
    );
    return true;
  }

  @override
  Future<bool> cancelAll({Iterable<Task>? tasks, String? group}) async {
    cancelAllCalls++;
    return true;
  }
}

class _FakeLocalDataSource extends Fake implements ProcessingLocalDataSource {}

class _FakeOcr extends Fake implements TextRecognitionService {}

class _FakePathResolver extends Fake implements PathResolver {}

/// Polls [condition]: the transfers write real files, which completes
/// outside the microtask queue.
Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for the download');
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

void main() {
  late Directory docs;
  late Directory modelDir;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    docs = Directory.systemTemp.createTempSync('hw_model_download_test_');
    modelDir = Directory('${docs.path}/ai_models');
  });

  tearDown(() {
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  File modelFile() => File('${modelDir.path}/${_config.modelId}');
  File partialModelFile() => File('${modelFile().path}.tmp');
  File mmprojFile() => File('${modelDir.path}/${_config.mmprojId}');

  AiInferenceDataSourceImpl desktopDataSource(_FakeServer server) =>
      AiInferenceDataSourceImpl(
        prefs,
        createDio: () => Dio()..httpClientAdapter = server,
        useDio: true,
        documentsDirectory: () async => docs,
      );

  AiInferenceDataSourceImpl mobileDataSource(_FakeFileDownloader downloader) =>
      AiInferenceDataSourceImpl(
        prefs,
        fileDownloader: downloader,
        useDio: false,
        documentsDirectory: () async => docs,
      );

  final throwsCancelled = throwsA(isA<ModelDownloadCancelledException>());

  group('desktop (Dio)', () {
    test('a finished download moves the file in place', () async {
      final server = _FakeServer();
      final dataSource = desktopDataSource(server);
      final progress = <int>[];

      final download = dataSource.downloadModelForVariant(
        _variant,
        onProgress: progress.add,
      );
      await _until(() => server.responses.isNotEmpty);
      server.responses.single
        ..send('GG')
        ..send('UF');
      await server.responses.single.finish();
      await download;

      expect(modelFile().readAsStringSync(), 'GGUF');
      expect(partialModelFile().existsSync(), isFalse);
      expect(progress, [50, 100]);
      expect(await dataSource.checkModelExistenceForVariant(_variant), isTrue);
    });

    test('a failed download deletes its partial file', () async {
      final server = _FakeServer();
      final dataSource = desktopDataSource(server);

      final download = expectLater(
        dataSource.downloadModelForVariant(_variant, onProgress: (_) {}),
        throwsA(
          isA<Exception>().having(
            (e) => e,
            'not a cancel',
            isNot(isA<ModelDownloadCancelledException>()),
          ),
        ),
      );
      await _until(() => server.responses.isNotEmpty);
      server.responses.single
        ..send('GG')
        ..body.addError(const SocketException('connection reset'));
      await download;

      expect(partialModelFile().existsSync(), isFalse);
      expect(modelFile().existsSync(), isFalse);
    });

    test('cancel stops the transfer and leaves no model file', () async {
      final server = _FakeServer();
      final dataSource = desktopDataSource(server);
      final progress = <int>[];

      final download = expectLater(
        dataSource.downloadModelForVariant(_variant, onProgress: progress.add),
        throwsCancelled,
      );
      await _until(() => server.responses.isNotEmpty);
      final response = server.responses.single..send('GG');
      await _until(() => progress.isNotEmpty);
      expect(partialModelFile().existsSync(), isTrue);

      await dataSource.cancelModelDownloadForVariant(_variant);

      // By the time cancel returns the transfer has ended and is cleaned up.
      expect(response.isRead, isFalse);
      expect(partialModelFile().existsSync(), isFalse);
      expect(modelFile().existsSync(), isFalse);
      await download;
      expect(await dataSource.checkModelExistenceForVariant(_variant), isFalse);
    });

    test('cancel stops a stalled transfer the server never ends', () async {
      final server = _FakeServer(abortOnCancel: false);
      final dataSource = desktopDataSource(server);
      final progress = <int>[];

      final download = expectLater(
        dataSource.downloadModelForVariant(_variant, onProgress: progress.add),
        throwsCancelled,
      );
      await _until(() => server.responses.isNotEmpty);
      final response = server.responses.single..send('GG');
      await _until(() => progress.isNotEmpty);

      await dataSource.cancelModelDownloadForVariant(_variant);

      expect(response.isRead, isFalse);
      expect(partialModelFile().existsSync(), isFalse);
      await download;
      expect(modelFile().existsSync(), isFalse);
    });

    test('cancel before the server answers leaves no file', () async {
      final server = _FakeServer();
      final dataSource = desktopDataSource(server);

      final download = expectLater(
        dataSource.downloadModelForVariant(_variant, onProgress: (_) {}),
        throwsCancelled,
      );
      await dataSource.cancelModelDownloadForVariant(_variant);
      await download;

      expect(partialModelFile().existsSync(), isFalse);
      expect(modelFile().existsSync(), isFalse);
    });

    test('cancel with nothing running does nothing', () async {
      final dataSource = desktopDataSource(_FakeServer());

      await dataSource.cancelModelDownloadForVariant(_variant);

      expect(modelDir.existsSync(), isFalse);
    });

    test(
      'the vision download keeps running when the model is cancelled',
      () async {
        final server = _FakeServer();
        final dataSource = desktopDataSource(server);

        final model = expectLater(
          dataSource.downloadModelForVariant(_variant, onProgress: (_) {}),
          throwsCancelled,
        );
        final mmproj = dataSource.downloadMmprojForVariant(
          _variant,
          onProgress: (_) {},
        );
        await _until(() => server.responses.length == 2);

        await dataSource.cancelModelDownloadForVariant(_variant);
        await model;

        final vision = server.responseFor(_config.mmprojId);
        expect(vision.isRead, isTrue);
        vision.send('GGUF');
        await vision.finish();
        await mmproj;

        expect(mmprojFile().readAsStringSync(), 'GGUF');
        expect(modelFile().existsSync(), isFalse);
      },
    );

    test(
      'a quick restart waits for the cancelled transfer, then writes alone',
      () async {
        final server = _FakeServer(abortOnCancel: false);
        final dataSource = desktopDataSource(server);
        final firstProgress = <int>[];

        final first = expectLater(
          dataSource.downloadModelForVariant(
            _variant,
            onProgress: firstProgress.add,
          ),
          throwsCancelled,
        );
        await _until(() => server.responses.isNotEmpty);
        server.responses.single.send('xx');
        await _until(() => firstProgress.isNotEmpty);

        // Cancel and restart without waiting in between.
        final cancel = dataSource.cancelModelDownloadForVariant(_variant);
        final second = dataSource.downloadModelForVariant(
          _variant,
          onProgress: (_) {},
        );
        await cancel;
        await first;
        await _until(() => server.responses.length == 2);

        expect(server.events, [
          '${_config.modelId} requested',
          '${_config.modelId} stopped',
          '${_config.modelId} requested',
        ]);
        server.responses.last.send('GGUF');
        await server.responses.last.finish();
        await second;

        expect(modelFile().readAsStringSync(), 'GGUF');
        expect(partialModelFile().existsSync(), isFalse);
      },
    );
  });

  group('mobile (background_downloader)', () {
    test('a finished task leaves the model file', () async {
      final downloader = _FakeFileDownloader(modelDir);
      final dataSource = mobileDataSource(downloader);
      final progress = <int>[];

      final download = dataSource.downloadModelForVariant(
        _variant,
        onProgress: progress.add,
      );
      await _until(() => downloader.tasks.isNotEmpty);
      downloader
        ..progress(_config.modelId, 0.5)
        ..complete(_config.modelId);
      await download;

      expect(progress, [50]);
      expect(await dataSource.checkModelExistenceForVariant(_variant), isTrue);
    });

    test('cancel stops only the model task, never every task', () async {
      final downloader = _FakeFileDownloader(modelDir);
      final dataSource = mobileDataSource(downloader);
      final progress = <int>[];

      final model = expectLater(
        dataSource.downloadModelForVariant(_variant, onProgress: progress.add),
        throwsCancelled,
      );
      final mmproj = dataSource.downloadMmprojForVariant(
        _variant,
        onProgress: (_) {},
      );
      await _until(() => downloader.tasks.length == 2);

      await dataSource.cancelModelDownloadForVariant(_variant);
      await model;

      expect(downloader.cancelledTaskIds, [
        downloader.tasks[_config.modelId]!.taskId,
      ]);
      expect(downloader.cancelAllCalls, 0);
      // The plugin's -2 "canceled" progress is not reported as progress.
      expect(progress, isEmpty);
      expect(modelFile().existsSync(), isFalse);

      downloader.complete(_config.mmprojId);
      await mmproj;
      expect(mmprojFile().existsSync(), isTrue);
    });

    test(
      'a task that completes as it is cancelled leaves no model file',
      () async {
        final downloader = _FakeFileDownloader(modelDir, cancelEndsTask: false);
        final dataSource = mobileDataSource(downloader);

        final download = expectLater(
          dataSource.downloadModelForVariant(_variant, onProgress: (_) {}),
          throwsCancelled,
        );
        await _until(() => downloader.tasks.isNotEmpty);

        final cancel = dataSource.cancelModelDownloadForVariant(_variant);
        await _until(() => downloader.cancelledTaskIds.isNotEmpty);
        downloader.complete(_config.modelId);
        await cancel;
        await download;

        expect(modelFile().existsSync(), isFalse);
      },
    );

    test(
      'a quick restart starts its task only after the cancelled one ended',
      () async {
        final downloader = _FakeFileDownloader(modelDir, cancelEndsTask: false);
        final dataSource = mobileDataSource(downloader);

        final first = expectLater(
          dataSource.downloadModelForVariant(_variant, onProgress: (_) {}),
          throwsCancelled,
        );
        await _until(() => downloader.tasks.isNotEmpty);

        final cancel = dataSource.cancelModelDownloadForVariant(_variant);
        final second = dataSource.downloadModelForVariant(
          _variant,
          onProgress: (_) {},
        );
        await _until(() => downloader.cancelledTaskIds.isNotEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(downloader.downloadCalls, 1);

        downloader.endCancelled(_config.modelId);
        await cancel;
        await first;
        await _until(() => downloader.downloadCalls == 2);
        downloader.complete(_config.modelId);
        await second;

        expect(modelFile().existsSync(), isTrue);
      },
    );
  });

  group('through AiModelDownloadService', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test(
      'cancelling stops the model transfer and keeps the vision one',
      () async {
        final server = _FakeServer();
        final dataSource = desktopDataSource(server);
        final service = AiModelDownloadService(
          ProcessingRepositoryImpl(
            dataSource,
            _FakeLocalDataSource(),
            _FakeOcr(),
            _FakePathResolver(),
          ),
          prefs,
          AppStringsProvider.forLocale(const Locale('en')),
        );
        addTearDown(service.dispose);
        final states = <AiModelDownloadState>[];
        final sub = service.stateStream.listen(states.add);
        addTearDown(sub.cancel);

        await service.startDownloadForVariant(_variant);
        await service.startMmprojDownloadForVariant(_variant);
        await _until(() => server.responses.length == 2);
        server.responseFor(_config.modelId).send('GG');
        await _until(partialModelFile().existsSync);

        await service.cancelDownload();
        // The broadcast state stream delivers asynchronously.
        await Future<void>.delayed(Duration.zero);

        expect(server.responseFor(_config.modelId).isRead, isFalse);
        expect(partialModelFile().existsSync(), isFalse);
        expect(modelFile().existsSync(), isFalse);
        expect(service.isVariantDownloading(_variant), isFalse);
        expect(
          states.last,
          isA<AiModelDownloadState>()
              .having(
                (s) => s.status,
                'status',
                AiModelDownloadStatus.cancelled,
              )
              .having((s) => s.variant, 'variant', _variant)
              .having((s) => s.isMmprojDownload, 'isMmprojDownload', isFalse),
        );

        final vision = server.responseFor(_config.mmprojId);
        expect(vision.isRead, isTrue);
        vision.send('GGUF');
        await vision.finish();
        await _until(mmprojFile().existsSync);
        expect(await service.checkModelExistsForVariant(_variant), isFalse);
      },
    );
  });
}
