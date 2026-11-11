import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:background_downloader/background_downloader.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/config/env/env.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_data_source.dart';
import 'package:health_wallet/features/processing/domain/entity/model_download_cancelled_exception.dart';
import 'package:health_wallet/features/processing/domain/services/processing_log_buffer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/log_capture.dart';

const _variant = AiModelVariant.qwen;
final _modelId = AiModelConfig.qwen.modelId;

/// Answers every request at once with a four-byte body.
class _Server implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody(
    Stream.value(Uint8List.fromList('GGUF'.codeUnits)),
    200,
    headers: {
      Headers.contentLengthHeader: ['4'],
    },
  );

  @override
  void close({bool force = false}) {}
}

/// A body that sends one chunk and ends at once, even while its listener
/// has paused it.
class _UnpausableBody extends Stream<Uint8List> {
  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final subscription = const Stream<Uint8List>.empty().listen(null);
    scheduleMicrotask(() {
      onData?.call(Uint8List.fromList('GGUF'.codeUnits));
      onDone?.call();
    });
    return subscription;
  }
}

/// How the partial `.tmp` download file behaves.
class _PartialFileFaults {
  bool writeFails = false;
  bool closeFails = false;
  bool deleteFails = false;

  /// Runs as the finished partial file is closed.
  void Function()? onClose;
}

/// The partial download file: real, with the faults of [faults]. CI runs as
/// root, so a permission can't make these operations fail.
class _PartialFile extends Fake implements File {
  _PartialFile(this._real, this.faults);

  final File _real;
  final _PartialFileFaults faults;

  @override
  String get path => _real.path;

  @override
  Future<bool> exists() => _real.exists();

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async =>
      _PartialRandomAccessFile(await _real.open(mode: mode), faults);

  @override
  Future<File> rename(String newPath) => _real.rename(newPath);

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    if (faults.deleteFails) throw FileSystemException('Cannot delete', path);
    return _real.delete(recursive: recursive);
  }
}

class _PartialRandomAccessFile extends Fake implements RandomAccessFile {
  _PartialRandomAccessFile(this._real, this.faults);

  final RandomAccessFile _real;
  final _PartialFileFaults faults;

  @override
  Future<RandomAccessFile> writeFrom(
    List<int> buffer, [
    int start = 0,
    int? end,
  ]) async {
    if (faults.writeFails) throw const FileSystemException('No space left');
    await _real.writeFrom(buffer, start, end);
    return this;
  }

  @override
  Future<void> close() async {
    faults.onClose?.call();
    await _real.close();
    if (faults.closeFails) throw const FileSystemException('Cannot close');
  }
}

/// Puts [_PartialFile] in place of the partial file of [filename], and runs
/// [onModelFileChecked] when the model file itself is first looked for.
final class _DownloadIo extends IOOverrides {
  _DownloadIo(this.filename, {this.faults, this.onModelFileChecked});

  final String filename;
  final _PartialFileFaults? faults;
  final void Function()? onModelFileChecked;

  @override
  File createFile(String path) {
    final real = super.createFile(path);
    if (path.endsWith('/$filename.tmp') && faults != null) {
      return _PartialFile(real, faults!);
    }
    if (path.endsWith('/$filename') && onModelFileChecked != null) {
      return _CheckedModelFile(real, onModelFileChecked!);
    }
    return real;
  }
}

/// The model file, telling the test when the download looks for it.
class _CheckedModelFile extends Fake implements File {
  _CheckedModelFile(this._real, this.onChecked);

  final File _real;
  final void Function() onChecked;

  @override
  String get path => _real.path;

  @override
  bool existsSync() {
    onChecked();
    return _real.existsSync();
  }
}

/// background_downloader stand-in that records cancels; no task may start.
class _IdleFileDownloader extends Fake implements FileDownloader {
  final cancelledTaskIds = <String>[];

  @override
  Future<bool> cancelTaskWithId(String taskId) async {
    cancelledTaskIds.add(taskId);
    return true;
  }
}

void main() {
  final logs = captureLogs();
  late Directory docs;
  late SharedPreferences prefs;
  late ProcessingLogBuffer log;
  late String originalToken;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      SharedPrefsConstants.aiSelectedModel: _variant.name,
    });
    prefs = await SharedPreferences.getInstance();
    docs = Directory.systemTemp.createTempSync('hw_ai_download_io_');
    log = ProcessingLogBuffer.forTesting(enabled: false, directory: docs);
    ProcessingLogBuffer.debugOverrideInstance(log);
    originalToken = Env.huggingFaceToken;
    Env.huggingFaceToken = '';
  });

  tearDown(() {
    Env.huggingFaceToken = originalToken;
    ProcessingLogBuffer.debugOverrideInstance(null);
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  File modelFile([String suffix = '']) =>
      File('${docs.path}/ai_models/$_modelId$suffix');

  AiInferenceDataSourceImpl dioDataSource({void Function(Dio)? configure}) =>
      AiInferenceDataSourceImpl(
        prefs,
        createDio: () {
          final dio = Dio()..httpClientAdapter = _Server();
          configure?.call(dio);
          return dio;
        },
        useDio: true,
        documentsDirectory: () async => docs,
      );

  /// Downloads the model with the partial file behaving as [faults] says.
  Future<void> download(
    AiInferenceDataSourceImpl dataSource,
    _PartialFileFaults faults,
  ) => IOOverrides.runWithIOOverrides(
    () => dataSource.downloadModelForVariant(_variant, onProgress: (_) {}),
    _DownloadIo(_modelId, faults: faults),
  );

  Matcher downloadFailed(String detail) => throwsA(
    isA<Exception>()
        .having(
          (e) => e,
          'not a cancel',
          isNot(isA<ModelDownloadCancelledException>()),
        )
        .having(
          (e) => '$e',
          'message',
          allOf(contains('Download failed for $_modelId'), contains(detail)),
        ),
  );

  final cancelled = throwsA(
    isA<ModelDownloadCancelledException>().having(
      (e) => e.filename,
      'filename',
      _modelId,
    ),
  );

  group('Dio download (desktop)', () {
    test('a write that fails fails the download and deletes the partial '
        'file', () async {
      final faults = _PartialFileFaults()..writeFails = true;

      await expectLater(
        download(dioDataSource(), faults),
        downloadFailed('No space left'),
      );

      expect(modelFile().existsSync(), isFalse);
      expect(modelFile('.tmp').existsSync(), isFalse);
    });

    test('a write that fails while the body still ends fails the download '
        'once', () async {
      final faults = _PartialFileFaults()..writeFails = true;
      final dataSource = dioDataSource(
        configure: (dio) => dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(
              Response<ResponseBody>(
                requestOptions: options,
                statusCode: 200,
                data: ResponseBody(_UnpausableBody(), 200),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        download(dataSource, faults),
        downloadFailed('No space left'),
      );

      expect(modelFile().existsSync(), isFalse);
      expect(modelFile('.tmp').existsSync(), isFalse);
    });

    test('a partial file that cannot be closed after a failure is logged, '
        'and still deleted', () async {
      final faults = _PartialFileFaults()
        ..writeFails = true
        ..closeFails = true;

      await expectLater(
        download(dioDataSource(), faults),
        downloadFailed('No space left'),
      );

      expect(modelFile('.tmp').existsSync(), isFalse);
      expect(
        logs,
        loggedWarning('Could not close the partial download $_modelId'),
      );
    });

    test('a partial file that cannot be deleted is logged; the download '
        'still fails', () async {
      final faults = _PartialFileFaults()
        ..writeFails = true
        ..deleteFails = true;

      await expectLater(
        download(dioDataSource(), faults),
        downloadFailed('No space left'),
      );

      expect(modelFile().existsSync(), isFalse);
      expect(
        logs,
        loggedWarning('Could not delete the partial download'),
      );
    });

    test('a cancel that lands as the last bytes are written wins: no model '
        'file is left', () async {
      final dataSource = dioDataSource();
      Future<void>? cancel;
      final faults = _PartialFileFaults()
        ..onClose = () =>
            cancel ??= dataSource.cancelModelDownloadForVariant(_variant);

      await expectLater(download(dataSource, faults), cancelled);
      await cancel;

      expect(cancel, isNotNull);
      expect(modelFile().existsSync(), isFalse);
      expect(modelFile('.tmp').existsSync(), isFalse);
    });
  });

  group('background_downloader (mobile)', () {
    test('a cancel that lands while the downloader is being set up starts '
        'no task', () async {
      final downloader = _IdleFileDownloader();
      final dataSource = AiInferenceDataSourceImpl(
        prefs,
        fileDownloader: downloader,
        useDio: false,
        documentsDirectory: () async => docs,
      );
      Future<void>? cancel;

      await expectLater(
        IOOverrides.runWithIOOverrides(
          () =>
              dataSource.downloadModelForVariant(_variant, onProgress: (_) {}),
          _DownloadIo(
            _modelId,
            // Lands after the download's own cancel check, before the task
            // is handed to the downloader.
            onModelFileChecked: () => scheduleMicrotask(
              () => cancel ??= dataSource.cancelModelDownloadForVariant(
                _variant,
              ),
            ),
          ),
        ),
        cancelled,
      );
      await cancel;

      expect(downloader.cancelledTaskIds, hasLength(1));
      expect(modelFile().existsSync(), isFalse);
    });
  });
}
