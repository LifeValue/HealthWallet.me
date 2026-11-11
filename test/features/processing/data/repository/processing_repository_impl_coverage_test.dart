import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/features/processing/data/data_source/local/processing_local_data_source.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_data_source.dart';
import 'package:health_wallet/features/processing/data/model/generation_stats.dart';
import 'package:health_wallet/features/processing/data/repository/processing_repository_impl.dart';
import 'package:health_wallet/features/processing/domain/entity/extraction_output_mode.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_condition.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';

import '../../../../helpers/log_capture.dart';
import '../../../share_records/share_test_helpers.dart';

const _scannerChannel = MethodChannel('flutter_doc_scanner');
const _variant = AiModelVariant.qwen;

class _FakeLocalDataSource extends Fake implements ProcessingLocalDataSource {
  final cached = <ProcessingSessionsCompanion>[];
  final updated = <(String, ProcessingSessionsCompanion)>[];
  List<ProcessingSessionDto> stored = [];

  @override
  Future<int> cacheProcessingSession(
    ProcessingSessionsCompanion entity,
  ) async {
    cached.add(entity);
    return 1;
  }

  @override
  Future<List<ProcessingSessionDto>> getProcessingSessions() async => stored;

  @override
  Future<int> updateProcessingSession(
    String id,
    ProcessingSessionsCompanion entity,
  ) async {
    updated.add((id, entity));
    return 7;
  }
}

/// Reports a fixed OCR text; [gate], when set, holds the OCR until it
/// completes, so a test can act while a mapping stream is running.
class _FakeOcr extends Fake implements TextRecognitionService {
  _FakeOcr(this.text);

  final String text;
  Completer<void>? gate;
  var calls = 0;

  @override
  Future<String> recognizeTextFromImage(String imagePath) async {
    calls++;
    await gate?.future;
    return text;
  }
}

/// A download the test drives: [start] records the progress callback and
/// returns a future the test completes or fails.
class _Transfer {
  void Function(int)? onProgress;
  final done = Completer<void>();
  var cancels = 0;

  /// Completes the cancel call; null makes the cancel complete at once.
  Completer<void>? cancelGate;
  Error? cancelError;

  Future<void> start(void Function(int) onProgress) {
    this.onProgress = onProgress;
    return done.future;
  }

  Future<void> cancel() async {
    cancels++;
    await cancelGate?.future;
    if (cancelError != null) throw cancelError!;
    // The real data source fails the interrupted download.
    if (!done.isCompleted) done.completeError(StateError('cancelled'));
  }
}

class _FakeNetwork extends Fake implements AiInferenceDataSource {
  final legacy = _Transfer();
  final model = _Transfer();
  final mmproj = _Transfer();
  final modelCancels = <AiModelVariant>[];
  final mmprojCancels = <AiModelVariant>[];
  final deleted = <AiModelVariant>[];
  final initLoads = <({bool withVision, int? ctx, int? gpu, int? threads})>[];
  Error? initError;
  bool modelExists = false;
  bool mmprojExists = false;
  var disposes = 0;
  var textPrompts = 0;
  var visionPrompts = 0;

  @override
  Future<void> downloadModel({required void Function(int) onProgress}) =>
      legacy.start(onProgress);

  @override
  Future<bool> checkModelExistence() async => modelExists;

  @override
  Future<void> downloadModelForVariant(
    AiModelVariant variant, {
    required void Function(int) onProgress,
  }) => model.start(onProgress);

  @override
  Future<void> downloadMmprojForVariant(
    AiModelVariant variant, {
    required void Function(int) onProgress,
  }) => mmproj.start(onProgress);

  @override
  Future<void> cancelModelDownloadForVariant(AiModelVariant variant) {
    modelCancels.add(variant);
    return model.cancel();
  }

  @override
  Future<void> cancelMmprojDownloadForVariant(AiModelVariant variant) {
    mmprojCancels.add(variant);
    return mmproj.cancel();
  }

  @override
  Future<bool> checkModelExistenceForVariant(AiModelVariant variant) async =>
      modelExists;

  @override
  Future<bool> checkMmprojExistenceForVariant(AiModelVariant variant) async =>
      mmprojExists;

  @override
  Future<void> deleteModelForVariant(AiModelVariant variant) async =>
      deleted.add(variant);

  @override
  Future<void> disposeModel() async => disposes++;

  var engineCancels = 0;

  /// The active model's vision projector: on the device, and loaded with
  /// the model.
  bool projectorOnDisk = true;
  bool projectorLoaded = true;

  @override
  Future<bool> checkMmprojExistence() async => projectorOnDisk;

  @override
  bool isVisionModelAvailable() => projectorLoaded;

  @override
  void cancelGeneration() => engineCancels++;

  @override
  PromptFamily get promptFamily => PromptFamily.standard;

  @override
  int get visionPagesPerBatch => 2;

  @override
  GenerationStats? get lastGenerationStats => null;

  @override
  Future<void> initModel({
    bool withVision = true,
    int? contextSize,
    int? gpuLayers,
    int? threads,
  }) async {
    initLoads.add((
      withVision: withVision,
      ctx: contextSize,
      gpu: gpuLayers,
      threads: threads,
    ));
    if (initError != null) throw initError!;
  }

  @override
  Future<String?> runVisionPrompt({
    required String prompt,
    required List<String> imagePaths,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
  }) async {
    visionPrompts++;
    return '[]';
  }

  /// Holds each text prompt until completed, when set.
  Completer<void>? textGate;

  @override
  Future<String?> runTextPrompt({
    required String prompt,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
    Map<String, dynamic>? chatTemplateKwargs,
  }) async {
    textPrompts++;
    await textGate?.future;
    return '[{"resourceType":"Condition","conditionName":"Vorhofflimmern",'
        '"onsetDateTime":"2019","clinicalStatus":"active"}]';
  }
}

/// A file that exists but cannot be deleted. CI runs as root, so a
/// permission can't make the delete fail.
class _UndeletableFile extends Fake implements File {
  _UndeletableFile(this.path);

  @override
  final String path;

  @override
  Future<bool> exists() async => true;

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async =>
      throw FileSystemException('Cannot delete', path);
}

/// A directory that exists but whose listing and deletion fail.
class _BrokenDirectory extends Fake implements Directory {
  _BrokenDirectory(this.path);

  @override
  final String path;

  @override
  Future<bool> exists() async => true;

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) => Stream.error(FileSystemException('Cannot list', path));

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async =>
      throw FileSystemException('Cannot delete', path);
}

/// Swaps the file or directory at the given paths for a broken one; every
/// other path is real.
final class _BrokenAt extends IOOverrides {
  _BrokenAt({this.file, this.directory});

  final String? file;
  final String? directory;

  @override
  File createFile(String path) =>
      path == file ? _UndeletableFile(path) : super.createFile(path);

  @override
  Directory createDirectory(String path) =>
      path == directory ? _BrokenDirectory(path) : super.createDirectory(path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final logs = captureLogs();
  late Directory root;
  late String docs;
  late _FakeLocalDataSource local;
  late _FakeNetwork network;
  late _FakeOcr ocr;
  late ProcessingRepositoryImpl repository;
  late List<MethodCall> scannerCalls;

  void scannerReturns(Object? Function(MethodCall call) answer) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_scannerChannel, (call) async {
          scannerCalls.add(call);
          return answer(call);
        });
  }

  setUp(() {
    root = mockPathProvider();
    docs = '${root.path}/Documents';
    local = _FakeLocalDataSource();
    network = _FakeNetwork();
    ocr = _FakeOcr('Diagnosen: Vorhofflimmern seit 2019.');
    scannerCalls = [];
    repository = ProcessingRepositoryImpl(network, local, ocr, PathResolver());
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_scannerChannel, null),
    );
  });

  test('exposes its data source and OCR service to the extraction mixin', () {
    expect(repository.networkDataSource, same(network));
    expect(repository.textRecognitionService, same(ocr));
    expect(repository.shouldCancelGeneration, isFalse);
  });

  group('scanDocuments', () {
    test('asks for up to 10 pages and drops empty paths', () async {
      scannerReturns(
        (_) => {
          'images': ['/scan/a.jpg', '', '/scan/b.jpg'],
        },
      );

      expect(await repository.scanDocuments(), ['/scan/a.jpg', '/scan/b.jpg']);
      expect(scannerCalls.single.method, 'getScannedDocumentAsImages');
      expect((scannerCalls.single.arguments as Map)['page'], 10);
    });

    test('a cancelled scan returns no paths', () async {
      scannerReturns((_) => null);

      expect(await repository.scanDocuments(), isEmpty);
    });

    test('a native failure surfaces as a scan error naming its code', () async {
      scannerReturns(
        (_) => throw PlatformException(code: 'SCAN_FAILED', message: 'boom'),
      );

      // The plugin turns the PlatformException into a DocScanException, so
      // the generic branch reports it.
      await expectLater(
        repository.scanDocuments(),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            allOf(contains('Failed to scan:'), contains('SCAN_FAILED')),
          ),
        ),
      );
    });
  });

  group('scanDocumentsAsPdf', () {
    test('returns the PDF the scanner made, with the page limit', () async {
      scannerReturns((_) => {'pdfUri': '/scan/doc.pdf', 'pageCount': 2});

      expect(await repository.scanDocumentsAsPdf(maxPages: 3), [
        '/scan/doc.pdf',
      ]);
      expect(scannerCalls.single.method, 'getScannedDocumentAsPdf');
      expect((scannerCalls.single.arguments as Map)['page'], 3);
    });

    test('defaults to 5 pages and a cancel returns nothing', () async {
      scannerReturns((_) => null);

      expect(await repository.scanDocumentsAsPdf(), isEmpty);
      expect((scannerCalls.single.arguments as Map)['page'], 5);
    });

    test('an unreadable result surfaces as a PDF scan error', () async {
      scannerReturns((_) => {'pageCount': 1});

      await expectLater(
        repository.scanDocumentsAsPdf(),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            contains('Failed to scan PDF documents'),
          ),
        ),
      );
    });

    test('a native failure surfaces as a PDF scan error', () async {
      scannerReturns((_) => throw PlatformException(code: 'NO_ACTIVITY'));

      await expectLater(
        repository.scanDocumentsAsPdf(),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            allOf(
              contains('Failed to scan PDF documents'),
              contains('NO_ACTIVITY'),
            ),
          ),
        ),
      );
    });
  });

  group('scanDocumentsDefault', () {
    test('keeps the listed paths that are not failures', () async {
      scannerReturns(
        (_) => ['/scan/a.jpg', '', 'Failed to save', 'Unknown', '/scan/b.png'],
      );

      expect(await repository.scanDocumentsDefault(maxPages: 2), [
        '/scan/a.jpg',
        '/scan/b.png',
      ]);
      expect(scannerCalls.single.method, 'getScanDocuments');
      expect((scannerCalls.single.arguments as Map)['page'], 2);
    });

    test('a single path is returned as a list', () async {
      scannerReturns((_) => '/scan/doc.pdf');

      expect(await repository.scanDocumentsDefault(), ['/scan/doc.pdf']);
      expect((scannerCalls.single.arguments as Map)['page'], 5);
    });

    test('any other result is kept as its text', () async {
      scannerReturns((_) => 42);

      expect(await repository.scanDocumentsDefault(), ['42']);
    });

    test('a cancel returns nothing', () async {
      scannerReturns((_) => null);

      expect(await repository.scanDocumentsDefault(), isEmpty);
    });

    for (final message in ['Failed to scan', 'Unknown error']) {
      test('a "$message" answer is an error, not a path', () async {
        scannerReturns((_) => message);

        await expectLater(
          repository.scanDocumentsDefault(),
          throwsA(
            isA<Exception>().having(
              (e) => '$e',
              'message',
              allOf(
                contains('Failed to scan in default mode'),
                contains('Default scanner error: $message'),
              ),
            ),
          ),
        );
      });
    }

    test('a native failure surfaces as a default-mode error', () async {
      scannerReturns((_) => throw PlatformException(code: 'SCAN_IN_PROGRESS'));

      await expectLater(
        repository.scanDocumentsDefault(),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            allOf(
              contains('Failed to scan in default mode'),
              contains('SCAN_IN_PROGRESS'),
            ),
          ),
        ),
      );
    });
  });

  group('saveScannedDocument', () {
    test('copies the scan into scanned_documents and returns its relative '
        'path', () async {
      final source = File('${root.path}/tmp/scan.jpg')
        ..writeAsStringSync('jpeg');

      final saved = await repository.saveScannedDocument(source.path);

      expect(saved, matches(RegExp(r'^scanned_documents/document_\d+\.jpg$')));
      expect(File('$docs/$saved').readAsStringSync(), 'jpeg');
      expect(source.existsSync(), isTrue);
    });

    test('a missing source is an error and writes nothing', () async {
      await expectLater(
        repository.saveScannedDocument('${root.path}/tmp/gone.jpg'),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            allOf(
              contains('Failed to save document'),
              contains('Source file does not exist'),
            ),
          ),
        ),
      );
      expect(
        Directory('$docs/scanned_documents').listSync(),
        isEmpty,
        reason: 'the folder is made, but nothing is copied into it',
      );
    });
  });

  group('getSavedDocuments', () {
    test('no scanned_documents folder means no documents', () async {
      expect(await repository.getSavedDocuments(), isEmpty);
    });

    test('lists the images and PDFs, newest first', () async {
      final dir = Directory('$docs/scanned_documents')..createSync();
      File make(String name, DateTime modified) => File('${dir.path}/$name')
        ..writeAsStringSync(name)
        ..setLastModifiedSync(modified);
      make('old.jpg', DateTime(2024));
      make('new.PNG', DateTime(2026));
      make('mid.pdf', DateTime(2025));
      make('b.jpeg', DateTime(2023));
      make('notes.txt', DateTime(2027));
      Directory('${dir.path}/nested.jpg').createSync();

      final paths = await repository.getSavedDocuments();

      expect(paths.map((p) => p.split('/').last), [
        'new.PNG',
        'mid.pdf',
        'old.jpg',
        'b.jpeg',
      ]);
    });

    test('an unreadable folder means no documents', () async {
      final dir = '$docs/scanned_documents';

      final paths = await IOOverrides.runWithIOOverrides(
        repository.getSavedDocuments,
        _BrokenAt(directory: dir),
      );

      expect(paths, isEmpty);
    });
  });

  group('deleteDocument', () {
    test('deletes the file and ignores one already gone', () async {
      final file = File('$docs/scan.jpg')..writeAsStringSync('x');

      await repository.deleteDocument(file.path);
      await repository.deleteDocument('$docs/gone.jpg');

      expect(file.existsSync(), isFalse);
    });

    test('a file that cannot be deleted is an error', () async {
      final path = '$docs/kept.jpg';

      await expectLater(
        IOOverrides.runWithIOOverrides(
          () => repository.deleteDocument(path),
          _BrokenAt(file: path),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            contains('Failed to delete document'),
          ),
        ),
      );
    });
  });

  group('clearAllDocuments', () {
    test('removes the scans folder and the imported images and PDFs', () async {
      final scans = Directory('$docs/scanned_documents')..createSync();
      File('${scans.path}/a.jpg').writeAsStringSync('a');
      final image = File('${root.path}/tmp/import.png')..writeAsStringSync('');
      final pdf = File('${root.path}/tmp/import.pdf')..writeAsStringSync('');
      final unrelated = File('$docs/keep.pdf')..writeAsStringSync('');

      await repository.clearAllDocuments(
        importedImagePaths: [image.path, '${root.path}/tmp/gone.png'],
        importedPdfPaths: [pdf.path, '${root.path}/tmp/gone.pdf'],
      );

      expect(scans.existsSync(), isFalse);
      expect(image.existsSync(), isFalse);
      expect(pdf.existsSync(), isFalse);
      expect(unrelated.existsSync(), isTrue);
    });

    test('with nothing to clear it does nothing', () async {
      await repository.clearAllDocuments();

      expect(Directory('$docs/scanned_documents').existsSync(), isFalse);
    });

    test('an imported file that cannot be deleted does not stop the '
        'others', () async {
      final stuckImage = '${root.path}/tmp/stuck.png';
      final stuckPdf = '${root.path}/tmp/stuck.pdf';
      final image = File('${root.path}/tmp/other.png')..writeAsStringSync('');
      final pdf = File('${root.path}/tmp/other.pdf')..writeAsStringSync('');

      await IOOverrides.runWithIOOverrides(
        () => repository.clearAllDocuments(
          importedImagePaths: [stuckImage, image.path],
        ),
        _BrokenAt(file: stuckImage),
      );
      await IOOverrides.runWithIOOverrides(
        () => repository.clearAllDocuments(
          importedPdfPaths: [stuckPdf, pdf.path],
        ),
        _BrokenAt(file: stuckPdf),
      );

      expect(image.existsSync(), isFalse);
      expect(pdf.existsSync(), isFalse);
    });

    test('a scans folder that cannot be deleted is an error', () async {
      await expectLater(
        IOOverrides.runWithIOOverrides(
          repository.clearAllDocuments,
          _BrokenAt(directory: '$docs/scanned_documents'),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            contains('Failed to clear all documents'),
          ),
        ),
      );
    });
  });

  group('processing sessions', () {
    const oldContainer =
        '/var/mobile/Containers/Data/Application/OLD-ID/Documents/scans/b.jpg';

    test('a new session is stored with relative paths and returned with '
        'absolute ones', () async {
      final before = DateTime.now();

      final session = await repository.createProcessingSession(
        filePaths: ['$docs/imports/a.pdf', oldContainer],
        origin: ProcessingOrigin.import,
      );

      expect(session.id, isNotEmpty);
      expect(session.origin, ProcessingOrigin.import);
      expect(session.createdAt!.isBefore(before), isFalse);
      expect(session.filePaths, ['$docs/imports/a.pdf', '$docs/scans/b.jpg']);
      final stored = local.cached.single;
      expect(stored.id.value, session.id);
      expect(stored.origin.value, 'Import');
      expect(
        jsonDecode(stored.filePaths.value!),
        ['imports/a.pdf', 'scans/b.jpg'],
      );
    });

    test('two new sessions get different ids', () async {
      final a = await repository.createProcessingSession(
        filePaths: const [],
        origin: ProcessingOrigin.scan,
      );
      final b = await repository.createProcessingSession(
        filePaths: const [],
        origin: ProcessingOrigin.scan,
      );

      expect(a.id, isNot(b.id));
    });

    test('stored sessions are read back with absolute paths', () async {
      final createdAt = DateTime(2026, 1, 2);
      ProcessingSessionDto dto(String id, List<String> paths) {
        final c = ProcessingSession(
          id: id,
          filePaths: paths,
          origin: ProcessingOrigin.handover,
          createdAt: createdAt,
        ).toDbCompanion();
        return ProcessingSessionDto(
          id: c.id.value,
          filePaths: c.filePaths.value,
          resources: c.resources.value,
          status: c.status.value,
          origin: c.origin.value,
          createdAt: c.createdAt.value,
          patient: c.patient.value,
          encounter: c.encounter.value,
          isDocumentAttached: c.isDocumentAttached.value,
        );
      }

      local.stored = [
        dto('one', ['imports/a.pdf', '/elsewhere/b.jpg']),
        dto('two', []),
      ];

      final sessions = await repository.getProcessingSessions();

      expect(sessions.map((s) => s.id), ['one', 'two']);
      expect(sessions.first.filePaths, [
        '$docs/imports/a.pdf',
        '/elsewhere/b.jpg',
      ]);
      expect(sessions.first.origin, ProcessingOrigin.handover);
      expect(sessions.first.createdAt, createdAt);
      expect(sessions.last.filePaths, isEmpty);
    });

    test('an edited session is stored with relative paths', () async {
      final session = ProcessingSession(
        id: 's',
        filePaths: ['$docs/imports/a.pdf', 'imports/b.jpg'],
        status: ProcessingStatus.processing,
        createdAt: DateTime(2026),
      );

      final count = await repository.editProcessingSession(session);

      expect(count, 7);
      final (id, companion) = local.updated.single;
      expect(id, 's');
      expect(
        jsonDecode(companion.filePaths.value!),
        ['imports/a.pdf', 'imports/b.jpg'],
      );
      expect(companion.status.value, ProcessingStatus.processing.toString());
    });
  });

  group('downloadModel', () {
    test('reports progress as doubles and closes when the download '
        'ends', () async {
      final events = <double>[];
      final done = Completer<void>();
      repository.downloadModel().listen(events.add, onDone: done.complete);

      network.legacy.onProgress!(10);
      network.legacy.onProgress!(55);
      network.legacy.done.complete();
      await done.future;

      expect(events, [10.0, 55.0]);
    });

    test('a failed download is reported as an error, then the stream '
        'closes', () async {
      final stream = repository.downloadModel();
      final expectation = expectLater(
        stream,
        emitsInOrder([
          1.0,
          emitsError(isA<StateError>()),
          emitsDone,
        ]),
      );

      network.legacy.onProgress!(1);
      network.legacy.done.completeError(StateError('offline'));
      await expectation;
    });
  });

  group('downloadModelForVariant', () {
    test('reports progress and closes when the download ends', () async {
      final stream = repository.downloadModelForVariant(_variant);
      final expectation = expectLater(
        stream,
        emitsInOrder([5.0, 100.0, emitsDone]),
      );

      network.model.onProgress!(5);
      network.model.onProgress!(100);
      network.model.done.complete();
      await expectation;
      // A finished transfer is never cancelled, even though the stream's
      // cancel runs after its done event.
      await pumpEventQueue();
      expect(network.modelCancels, isEmpty);
    });

    test('a failed download is reported with its stack trace', () async {
      final trace = StackTrace.current;
      final errors = <(Object, StackTrace)>[];
      final done = Completer<void>();
      repository
          .downloadModelForVariant(_variant)
          .listen(
            (_) {},
            onError: (Object e, StackTrace s) => errors.add((e, s)),
            onDone: done.complete,
          );

      network.model.done.completeError(StateError('offline'), trace);
      await done.future;

      expect(errors.single.$1, isA<StateError>());
      expect(errors.single.$2, trace);
      expect(network.modelCancels, isEmpty);
    });

    test('cancelling stops the transfer and waits until it has '
        'ended', () async {
      network.model.cancelGate = Completer<void>();
      final sub = repository.downloadModelForVariant(_variant).listen((_) {});
      await pumpEventQueue();

      var cancelled = false;
      final cancel = sub.cancel().then((_) => cancelled = true);
      await pumpEventQueue();
      expect(network.modelCancels, [_variant]);
      expect(cancelled, isFalse);

      network.model.cancelGate!.complete();
      await cancel;
      expect(cancelled, isTrue);
      // Progress after the cancel goes nowhere and does not throw.
      network.model.onProgress!(50);
    });

    test('a cancel that fails is logged and the subscription still '
        'ends', () async {
      network.model.cancelError = StateError('stuck');
      final sub = repository.downloadModelForVariant(_variant).listen((_) {});
      await pumpEventQueue();

      await sub.cancel();

      expect(network.modelCancels, [_variant]);
      expect(logs, loggedWarning('Could not cancel the model download'));
    });
  });

  group('downloadMmprojForVariant', () {
    test('reports progress and closes when the download ends', () async {
      final stream = repository.downloadMmprojForVariant(_variant);
      final expectation = expectLater(
        stream,
        emitsInOrder([42.0, emitsDone]),
      );

      network.mmproj.onProgress!(42);
      network.mmproj.done.complete();
      await expectation;
      await pumpEventQueue();
      expect(network.mmprojCancels, isEmpty);
    });

    test('cancelling stops the vision transfer only', () async {
      final sub = repository.downloadMmprojForVariant(_variant).listen((_) {});
      await pumpEventQueue();

      await sub.cancel();

      expect(network.mmprojCancels, [_variant]);
      expect(network.modelCancels, isEmpty);
    });
  });

  group('model files', () {
    test('existence checks and deletes go to the data source', () async {
      expect(await repository.checkModelExistence(), isFalse);
      expect(await repository.checkModelExistenceForVariant(_variant), isFalse);
      expect(
        await repository.checkMmprojExistenceForVariant(_variant),
        isFalse,
      );

      network
        ..modelExists = true
        ..mmprojExists = true;
      expect(await repository.checkModelExistence(), isTrue);
      expect(await repository.checkModelExistenceForVariant(_variant), isTrue);
      expect(await repository.checkMmprojExistenceForVariant(_variant), isTrue);

      await repository.deleteModelForVariant(AiModelVariant.medGemma);
      expect(network.deleted, [AiModelVariant.medGemma]);

      await repository.disposeModel();
      expect(network.disposes, 1);
    });
  });

  group('mapBasicInfo', () {
    test('passes the model settings to the extraction and surfaces a model '
        'that fails to load', () async {
      // Short OCR text goes straight to the vision model.
      network.initError = StateError('no model');

      await expectLater(
        repository.mapBasicInfo(
          const ['page-1.png'],
          maxTokens: 300,
          gpuLayers: 12,
          threads: 3,
          contextSize: 4096,
          outputMode: ExtractionOutputMode.grammar,
        ),
        throwsA(isA<StateError>()),
      );

      expect(ocr.calls, 1);
      expect(network.initLoads.single, (
        withVision: true,
        ctx: 4096,
        gpu: 12,
        threads: 3,
      ));
    });
  });

  group('mapRemainingResources', () {
    test('streams the extracted resources and unloads the model at the '
        'end', () async {
      final events = await repository
          .mapRemainingResources(
            const ['page-1.png'],
            documentCategory: 'visit',
            outputMode: ExtractionOutputMode.grammar,
          )
          .toList();

      final (resources, progress) = events.last;
      expect(progress, 1.0);
      expect(resources.single, isA<MappingCondition>());
      expect(network.textPrompts, greaterThan(0));
      expect(network.disposes, greaterThan(0));
      expect(repository.shouldCancelGeneration, isFalse);
    });

    test('waitForStreamCompletion returns at once with no stream '
        'running', () async {
      await repository.waitForStreamCompletion().timeout(
        const Duration(seconds: 1),
      );
    });

    test('waitForStreamCompletion waits for the running stream to '
        'end', () async {
      ocr.gate = Completer<void>();
      final events = repository.mapRemainingResources(
        const ['page-1.png'],
        outputMode: ExtractionOutputMode.grammar,
      ).toList();
      await pumpEventQueue();
      expect(ocr.calls, 1);

      var waited = false;
      final wait = repository.waitForStreamCompletion().then(
        (_) => waited = true,
      );
      await pumpEventQueue();
      expect(waited, isFalse);

      ocr.gate!.complete();
      await events;
      await wait;
      expect(waited, isTrue);
      // Done now, so a later wait returns at once.
      await repository.waitForStreamCompletion().timeout(
        const Duration(seconds: 1),
      );
    });

    test('cancelGeneration stops the stream before the model loads and is '
        'reset when the stream ends', () async {
      ocr.gate = Completer<void>();
      final events = repository
          .mapRemainingResources(
            const ['page-1.png', 'page-2.png'],
            useVision: true,
            outputMode: ExtractionOutputMode.grammar,
          )
          .toList();
      await pumpEventQueue();

      await repository.cancelGeneration();
      expect(repository.shouldCancelGeneration, isTrue);
      ocr.gate!.complete();

      expect(await events, isEmpty);
      expect(network.engineCancels, 1);
      expect(network.initLoads, isEmpty);
      expect(network.visionPrompts, 0);
      expect(network.textPrompts, 0);
      expect(network.disposes, 1);
      expect(repository.shouldCancelGeneration, isFalse);
    });

    test('a new stream clears an earlier cancel', () async {
      await repository.cancelGeneration();
      // Nothing was running: the engine is not asked to stop.
      expect(network.engineCancels, 0);

      final events = await repository.mapRemainingResources(
        const ['page-1.png'],
        outputMode: ExtractionOutputMode.grammar,
      ).toList();

      expect(events, isNotEmpty);
      expect(events.last.$1.single, isA<MappingCondition>());
    });
  });

  group('AI runs take turns', () {
    test('a records stream started while another runs waits for it to '
        'end', () async {
      ocr.gate = Completer<void>();
      final first = repository.mapRemainingResources(
        const ['page-1.png'],
        outputMode: ExtractionOutputMode.grammar,
      ).toList();
      await pumpEventQueue();
      final second = repository.mapRemainingResources(
        const ['page-2.png'],
        outputMode: ExtractionOutputMode.grammar,
      ).toList();
      await pumpEventQueue();

      // The second has not started reading its page.
      expect(ocr.calls, 1);

      ocr.gate!.complete();
      expect((await first).last.$1.single, isA<MappingCondition>());
      expect((await second).last.$1.single, isA<MappingCondition>());
      expect(ocr.calls, 2);
      expect(network.disposes, greaterThanOrEqualTo(2));
    });

    test('a cancel stops the running stream and the generation, not a patient '
        'step started after it', () async {
      ocr.gate = Completer<void>();
      final records = repository.mapRemainingResources(
        const ['page-1.png'],
        outputMode: ExtractionOutputMode.grammar,
      ).toList();
      await pumpEventQueue();

      await repository.cancelGeneration();
      expect(network.engineCancels, 1);
      final patient = repository.mapBasicInfo(
        const ['page-1.png'],
        outputMode: ExtractionOutputMode.grammar,
      );
      await pumpEventQueue();
      expect(ocr.calls, 1);

      ocr.gate!.complete();
      expect(await records, isEmpty);
      await patient;
      // The patient step ran its AI call: the cancel was not for it.
      expect(network.initLoads, isNotEmpty);
      expect(repository.shouldCancelGeneration, isFalse);
    });

    test('a patient step cancelled during its text pass returns no patient '
        'and skips the vision pass', () async {
      repository = ProcessingRepositoryImpl(
        network,
        local,
        _FakeOcr('Diagnosen: Vorhofflimmern seit 2019. ' * 10),
        PathResolver(),
      );
      network.textGate = Completer<void>();
      final step = repository.mapBasicInfo(
        const ['page-1.png'],
        outputMode: ExtractionOutputMode.grammar,
      );
      await pumpEventQueue();
      expect(network.textPrompts, 1);

      await repository.cancelGeneration();
      expect(repository.shouldCancelGeneration, isTrue);
      network.textGate!.complete();
      final (patient, container) = await step;

      expect(patient.givenName.value, isEmpty);
      expect(patient.familyName.value, isEmpty);
      expect((container as MappingEncounter).encounterType.value, isEmpty);
      expect(network.visionPrompts, 0);
      expect(network.initLoads.map((l) => l.withVision), [false]);
      expect(repository.shouldCancelGeneration, isFalse);
    });

    test('a container-only step cancelled while it waits for its turn loads '
        'no model', () async {
      ocr.gate = Completer<void>();
      final records = repository.mapRemainingResources(
        const ['page-1.png'],
        outputMode: ExtractionOutputMode.grammar,
      ).toList();
      await pumpEventQueue();
      final container = repository.mapContainerOnly(
        'Discharge letter',
        outputMode: ExtractionOutputMode.grammar,
      );

      await repository.cancelGeneration();
      var stopped = false;
      final wait = repository.waitForStreamCompletion().then(
        (_) => stopped = true,
      );
      await pumpEventQueue();
      // Both runs are cancelled, and the wait covers the one waiting too.
      expect(stopped, isFalse);

      ocr.gate!.complete();
      expect(await records, isEmpty);
      expect(
        ((await container) as MappingEncounter).encounterType.value,
        isEmpty,
      );
      await wait;
      expect(stopped, isTrue);
      expect(network.initLoads, isEmpty);
      expect(network.textPrompts, 0);
    });
  });
}
