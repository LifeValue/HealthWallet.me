import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/processing/data/services/pdf_conversion_mixin.dart';
import 'package:health_wallet/features/processing/domain/entity/extraction_output_mode.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extraction_service.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extractor_registry.dart';
import 'package:health_wallet/features/processing/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';
// The plugin exports no other way to replace its platform, which the
// rasterizer needs to run without a native PDF engine.
// ignore: implementation_imports
import 'package:printing/src/interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fake_device_capability_service.dart';
import '../../../../helpers/log_capture.dart';
import '../../../share_records/share_test_helpers.dart';

/// Width of a rendered page at [dpi]: 9 px at 72 dpi, 25 px at 200 dpi.
int _widthAt(double dpi) => (dpi / 8).round();
int _heightAt(double dpi) => (dpi / 6).round();

/// A rendered page as a PNG of the size [dpi] gives.
class _Page extends PdfRaster {
  _Page(this.dpi) : super(_widthAt(dpi), _heightAt(dpi), Uint8List(0));

  final double dpi;

  @override
  Future<Uint8List> toPng() async => img.encodePng(
    img.Image(width: _widthAt(dpi), height: _heightAt(dpi)),
  );
}

/// Renders [pageCount] pages at the requested dpi instead of a native engine.
class _FakePrinting extends PrintingPlatform {
  int pageCount = 3;

  /// Pages rendered above 72 dpi, when fewer than [pageCount].
  int? ocrPageCount;
  final rendered = <double>[];

  /// Rendering at a dpi in here waits for its completer.
  final gates = <double, Completer<void>>{};

  @override
  Stream<PdfRaster> raster(
    Uint8List document,
    List<int>? pages,
    double dpi,
  ) async* {
    rendered.add(dpi);
    await gates[dpi]?.future;
    final count = dpi > 72 ? ocrPageCount ?? pageCount : pageCount;
    yield* Stream.fromIterable([for (var i = 0; i < count; i++) _Page(dpi)]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The app's PDF conversion, with OCR that records the pages it reads.
class _Recognizer extends Fake
    with PdfConversionMixin
    implements TextRecognitionService {
  final read = <String>[];

  @override
  Future<String> recognizeTextFromImage(String imagePath) async {
    read.add(imagePath);
    return 'Lab report';
  }
}

class _FakeProcessingRepository extends Fake implements ProcessingRepository {
  bool modelExists = true;
  List<String>? basicInfoImages;
  List<String>? remainingImages;
  final deleted = <ProcessingSession>[];

  @override
  Future<bool> checkModelExistence() async => modelExists;

  @override
  Future<int> editProcessingSession(ProcessingSession session) async => 1;

  @override
  Future<int> deleteProcessingSession(ProcessingSession session) async {
    deleted.add(session);
    return 1;
  }

  @override
  bool get shouldCancelGeneration => false;

  @override
  Future<(MappingPatient, MappingResource)> mapBasicInfo(
    List<String> imagePaths, {
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
    ExtractionOutputMode outputMode = ExtractionOutputMode.defaultMode,
  }) async {
    basicInfoImages = imagePaths;
    throw Exception('stop after recording the pages');
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
    ExtractionOutputMode outputMode = ExtractionOutputMode.defaultMode,
  }) {
    remainingImages = imagePaths;
    return const Stream.empty();
  }
}

class _FakeSyncRepository extends Fake implements SyncRepository {
  @override
  Future<List<Source>> getSources() async => [];

  @override
  Future saveResources(List<IFhirResource> resources) async {}
}

class _FakeHolderSelection extends Fake implements HolderSelection {
  @override
  Future<void> select(String holderId) async {}
}

class _FakeDocumentReferenceService extends Fake
    implements DocumentReferenceService {
  @override
  Future<List<String>> replaceSessionDocuments({
    required String sessionId,
    required List<String> filePaths,
    required String patientId,
    Encounter? encounter,
    required String sourceId,
    String? title,
  }) async => [];
}

class _FakeRecordsRepository extends Fake implements RecordsRepository {}

class _FakeHolderService extends Fake implements HolderService {
  @override
  Future<Source> walletSourceOf(String holderId) async =>
      Source(id: 'wallet-$holderId', holderId: holderId);
}

const _sessionId = '3f2b8c1e-9a4d-4e6f-8b7a-1c2d3e4f5a6b';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final logs = captureLogs();

  late Directory root;
  late _FakePrinting printing;
  late _Recognizer recognizer;
  late _FakeProcessingRepository repository;
  late SharedPreferences prefs;
  late ProcessingBloc bloc;
  late File pdf;

  /// A bloc as the app builds one at start.
  ProcessingBloc newBloc() => ProcessingBloc(
    repository,
    OcrProcessingHelper(recognizer, PathResolver()),
    _FakeSyncRepository(),
    _FakeDocumentReferenceService(),
    _FakeHolderService(),
    _FakeHolderSelection(),
    _FakeRecordsRepository(),
    prefs,
    AppStringsProvider.forLocale(const Locale('en')),
    LayoutExtractionService(
      repository,
      OcrProcessingHelper(recognizer, PathResolver()),
      LayoutExtractorRegistry(const []),
      _FakeHolderService(),
      _FakeRecordsRepository(),
    ),
    FakeDeviceCapabilityService(),
  );

  setUp(() async {
    root = mockPathProvider();
    final realPrinting = PrintingPlatform.instance;
    printing = _FakePrinting();
    PrintingPlatform.instance = printing;
    addTearDown(() => PrintingPlatform.instance = realPrinting);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    recognizer = _Recognizer();
    repository = _FakeProcessingRepository();
    pdf = File('${root.path}/Documents/imports/report_1.pdf')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    bloc = newBloc();
  });

  tearDown(() => bloc.close());

  Directory cacheDir() =>
      Directory('${root.path}/Documents/${TempFileSweeper.ocrCacheDirName}');
  File pageMap() => File(
    '${cacheDir().path}/${TempFileSweeper.sessionPageMapName(_sessionId)}',
  );

  img.Image decode(String path) => img.decodeJpg(File(path).readAsBytesSync())!;

  /// Waits until [check] holds: the page work runs in isolates and on real
  /// files, which an event-queue pump doesn't wait for.
  Future<void> eventually(bool Function() check) async {
    for (var i = 0; i < 200 && !check(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(check(), isTrue, reason: 'condition never held');
  }

  Map<String, dynamic> readPageMap() =>
      jsonDecode(pageMap().readAsStringSync()) as Map<String, dynamic>;

  /// Whether the page map has exactly [names], with [turns] on [turned].
  bool pageMapHas(Iterable<String> names, {String? turned, int turns = 0}) {
    if (!pageMap().existsSync()) return false;
    final pages = readPageMap()['pages'] as Map;
    return pages.keys.toSet().containsAll(names) &&
        pages.length == names.length &&
        (turned == null || pages[turned]['quarterTurns'] == turns);
  }

  String name(String path) => path.split('/').last;

  // Seeding the state directly starts a step without the steps before it.
  void seed(ProcessingSession session) {
    // ignore: invalid_use_of_visible_for_testing_member
    bloc.emit(ProcessingState(sessions: [session]));
  }

  ProcessingSession session({
    ProcessingStatus status = ProcessingStatus.patientExtracted,
    List<String>? filePaths,
  }) => ProcessingSession(
    id: _sessionId,
    status: status,
    filePaths: filePaths ?? [pdf.path],
  );

  /// Opens the session and waits until its 200 dpi pages are known.
  Future<List<String>> open(ProcessingSession seeded) async {
    seed(seeded);
    bloc.add(SessionActivated(sessionId: seeded.id));
    await bloc.stream.firstWhere((s) => s.ocrPageByPreviewPath.isNotEmpty);
    return bloc.state.sessionImagePaths[seeded.id]!;
  }

  /// Runs step two and returns the pages it gave the AI.
  Future<List<String>> runStepTwo() async {
    bloc.add(const ProcessRemainingResources(sessionId: _sessionId));
    await bloc.stream.firstWhere(
      (s) => s.sessions.single.status == ProcessingStatus.draft,
    );
    return repository.remainingImages!;
  }

  bool isOcrPage(String path) => decode(path).width == _widthAt(200);
  bool isPreviewPage(String path) => decode(path).width == _widthAt(72);

  test('OCR and the AI read 200 dpi pages; the preview stays at 72', () async {
    seed(session(status: ProcessingStatus.pending));
    bloc.add(const SessionActivated(sessionId: _sessionId));
    await bloc.stream.firstWhere((s) => s.status is Failure);

    final previews = bloc.state.sessionImagePaths[_sessionId]!;
    expect(previews, hasLength(3));
    expect(previews.every(isPreviewPage), isTrue);
    // The preview is rendered first; the OCR pages after it.
    expect(printing.rendered, [72, 200]);

    expect(recognizer.read, hasLength(3));
    expect(recognizer.read.every(isOcrPage), isTrue);
    expect(repository.basicInfoImages, recognizer.read);
    expect(recognizer.read, [
      for (final preview in previews) bloc.state.ocrPageByPreviewPath[preview],
    ]);
  });

  test('step two gives the AI the 200 dpi pages in page order', () async {
    final previews = await open(session());

    final pages = await runStepTwo();

    expect(pages.every(isOcrPage), isTrue);
    expect(pages, [
      for (final preview in previews) bloc.state.ocrPageByPreviewPath[preview],
    ]);
    expect(pages.map((p) => p.split('_page_').last), [
      '1.jpg',
      '2.jpg',
      '3.jpg',
    ]);
  });

  test('a draft is not read again, so it renders no 200 dpi pages', () async {
    seed(session(status: ProcessingStatus.draft));
    bloc.add(const SessionActivated(sessionId: _sessionId));
    await bloc.stream.firstWhere((s) => s.displayedSessionId == _sessionId);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(printing.rendered, [72]);
    expect(bloc.state.ocrPageByPreviewPath, isEmpty);
  });

  test('photos are read as they are', () async {
    final photo = File('${root.path}/Documents/imports/photo.jpg')
      ..writeAsBytesSync(img.encodeJpg(img.Image(width: 3, height: 3)));
    seed(session(filePaths: [photo.path, pdf.path]));
    bloc.add(const SessionActivated(sessionId: _sessionId));
    await bloc.stream.firstWhere((s) => s.ocrPageByPreviewPath.isNotEmpty);

    final pages = await runStepTwo();

    expect(pages.first, photo.path);
    expect(pages.skip(1).every(isOcrPage), isTrue);
    expect(bloc.state.ocrPageByPreviewPath.containsKey(photo.path), isFalse);
  });

  test('the page map records where each preview page came from', () async {
    final previews = await open(session());

    final map = readPageMap();
    final pages = map['pages'] as Map;
    expect(pages.keys, previews.map((p) => p.split('/').last));
    expect(pages.values.map((v) => v['page']), [1, 2, 3]);
    // Stored like the session's paths: relative to Documents.
    expect(pages.values.map((v) => v['file']).toSet(), {
      'imports/report_1.pdf',
    });
    expect(map['previewKeys'], hasLength(1));
    expect(map['ocrKeys'], hasLength(1));
  });

  test('reorder, delete and rotate keep the 200 dpi pages matched', () async {
    final previews = await open(session());

    bloc.add(PageRotated(sessionId: _sessionId, previewPath: previews[1]));
    bloc.add(
      PagesReordered(
        sessionId: _sessionId,
        reorderedPaths: [previews[2], previews[1]],
      ),
    );
    await eventually(
      () =>
          bloc.state.sessionImagePaths[_sessionId]!.length == 2 &&
          bloc.state.ocrPageByPreviewPath[previews[1]]!.endsWith('_r1.jpg') &&
          pageMapHas(
            [
              name(previews[1]),
              name(previews[2]),
            ],
            turned: name(previews[1]),
            turns: 1,
          ),
    );

    final pages = await runStepTwo();

    expect(pages, hasLength(2));
    expect(pages[0], endsWith('_page_3.jpg'));
    expect(pages[1], endsWith('_page_2_r1.jpg'));
    final turned = decode(pages[1]);
    expect((turned.width, turned.height), (_heightAt(200), _widthAt(200)));
    // The rendered page stays as rendered.
    expect(
      isOcrPage(bloc.state.ocrPageByPreviewPath[previews[2]]!),
      isTrue,
    );
  });

  test('four quarter turns read the page as rendered', () async {
    final previews = await open(session());

    for (var i = 0; i < 4; i++) {
      bloc.add(PageRotated(sessionId: _sessionId, previewPath: previews[0]));
    }
    await bloc.stream.firstWhere(
      (s) => s.ocrPageByPreviewPath[previews[0]]!.endsWith('_page_1.jpg'),
    );

    expect(
      bloc.state.ocrPageByPreviewPath[previews[0]],
      endsWith('_page_1.jpg'),
    );
  });

  test('turning a photo leaves OCR on the photo itself', () async {
    final photo = File('${root.path}/Documents/imports/photo.jpg')
      ..writeAsBytesSync(img.encodeJpg(img.Image(width: 3, height: 3)));
    seed(session(filePaths: [photo.path]));

    bloc.add(PageRotated(sessionId: _sessionId, previewPath: photo.path));
    // Nothing changes, so no state comes to wait for.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(bloc.state.ocrPageByPreviewPath, isEmpty);
    expect(pageMap().existsSync(), isFalse);
  });

  group('an edited session reopened after a restart', () {
    /// Edits the pages, then starts a new bloc as after a restart, with the
    /// session as the database keeps it: only its preview pages.
    Future<List<String>> editAndRestart({bool keepOcrPages = false}) async {
      final previews = await open(session());
      bloc.add(PageRotated(sessionId: _sessionId, previewPath: previews[1]));
      final edited = [previews[2], previews[1]];
      bloc.add(PagesReordered(sessionId: _sessionId, reorderedPaths: edited));
      await eventually(
        () => pageMapHas(
          edited.map(name),
          turned: name(previews[1]),
          turns: 1,
        ),
      );
      await bloc.close();

      if (!keepOcrPages) {
        for (final file in cacheDir().listSync().whereType<File>()) {
          final name = file.path.split('/').last;
          final key = name.split('_page_').first;
          if (bloc.state.ocrPageByPreviewPath.values.any(
            (p) => p.contains(key),
          )) {
            file.deleteSync();
          }
        }
      }
      printing.rendered.clear();
      bloc = newBloc();
      seed(session(filePaths: edited));
      return edited;
    }

    test('renders its 200 dpi pages again from the page map', () async {
      final edited = await editAndRestart();

      bloc.add(const SessionActivated(sessionId: _sessionId));
      await bloc.stream.firstWhere((s) => s.ocrPageByPreviewPath.isNotEmpty);
      final pages = await runStepTwo();

      expect(printing.rendered, [200]);
      expect(bloc.state.sessionImagePaths[_sessionId], edited);
      expect(pages[0], endsWith('_page_3.jpg'));
      expect(isOcrPage(pages[0]), isTrue);
      expect(pages[1], endsWith('_page_2_r1.jpg'));
      expect(decode(pages[1]).width, _heightAt(200));
    });

    test('reuses the 200 dpi pages still on disk', () async {
      await editAndRestart(keepOcrPages: true);

      bloc.add(const SessionActivated(sessionId: _sessionId));
      await bloc.stream.firstWhere((s) => s.ocrPageByPreviewPath.isNotEmpty);
      final pages = await runStepTwo();

      // The cache serves them: nothing is rendered.
      expect(printing.rendered, isEmpty);
      expect(pages[1], endsWith('_page_2_r1.jpg'));
    });

    test('falls back to the 72 dpi pages when the original is gone, '
        'and logs it', () async {
      final edited = await editAndRestart();
      pdf.deleteSync();

      bloc.add(const SessionActivated(sessionId: _sessionId));
      await eventually(
        () => logs.any((e) => '${e.message}'.contains('is gone')),
      );
      final pages = await runStepTwo();

      expect(pages, edited);
      expect(logs, loggedWarning('is gone'));
    });

    test('falls back to the 72 dpi pages without a page map, and logs '
        'it', () async {
      final edited = await editAndRestart();
      pageMap().deleteSync();

      bloc.add(const SessionActivated(sessionId: _sessionId));
      await eventually(
        () =>
            logs.where((e) => '${e.message}'.contains('no source')).length == 2,
      );
      final pages = await runStepTwo();

      expect(pages, edited);
      expect(logs, loggedWarning('no source for'));
    });
  });

  test('a page that fails to render at 200 dpi is read at 72, and '
      'logged', () async {
    // The 72 dpi render has three pages, the 200 dpi one only two.
    printing.ocrPageCount = 2;
    await open(session());

    final pages = await runStepTwo();

    expect(isOcrPage(pages[0]), isTrue);
    expect(isOcrPage(pages[1]), isTrue);
    expect(isPreviewPage(pages[2]), isTrue);
    expect(logs, loggedWarning('page 3 of imports/report_1.pdf'));
  });

  test('saving the records deletes the 200 dpi pages and the page map, '
      'not the preview', () async {
    final previews = await open(session());
    final ocrPages = bloc.state.ocrPageByPreviewPath.values.toList();
    seed(
      session().copyWith(
        patient: const StagedPatient(
          draft: MappingPatient(
            id: 'p',
            gender: MappedProperty(value: 'female'),
          ),
          mode: ImportMode.createNew,
        ),
        encounter: const StagedEncounter(draft: MappingEncounter(id: 'e')),
        status: ProcessingStatus.draft,
      ),
    );
    // ignore: invalid_use_of_visible_for_testing_member
    bloc.emit(
      bloc.state.copyWith(
        sessionImagePaths: {_sessionId: previews},
        ocrPageByPreviewPath: {
          for (var i = 0; i < 3; i++) previews[i]: ocrPages[i],
        },
      ),
    );

    bloc.add(const ResourceCreationInitiated(sessionId: _sessionId));
    await bloc.stream.firstWhere(
      (s) => s.status is Success || s.status is Failure,
    );
    expect(bloc.state.status, isA<Success>());
    await eventually(
      () => !pageMap().existsSync() && bloc.state.ocrPageByPreviewPath.isEmpty,
    );

    expect(ocrPages.any((p) => File(p).existsSync()), isFalse);
    expect(pageMap().existsSync(), isFalse);
    expect(previews.every((p) => File(p).existsSync()), isTrue);
    final ocrKey = ocrPages.first.split('/').last.split('_page_').first;
    expect(File('${cacheDir().path}/$ocrKey.json').existsSync(), isFalse);
  });

  for (final dpi in [72.0, 200.0]) {
    test('a session deleted while its ${dpi.round()} dpi pages render leaves '
        'no pages behind', () async {
      seed(session());
      printing.gates[dpi] = Completer<void>();
      bloc.add(const SessionActivated(sessionId: _sessionId));
      await eventually(() => printing.rendered.contains(dpi));

      bloc.add(SessionCleared(session: session()));
      await bloc.stream.firstWhere((s) => s.sessions.isEmpty);
      printing.gates[dpi]!.complete();
      await eventually(
        () =>
            !pageMap().existsSync() &&
            (!cacheDir().existsSync() || cacheDir().listSync().isEmpty),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(printing.rendered, dpi == 72 ? [72] : [72, 200]);
      expect(
        cacheDir().existsSync() && cacheDir().listSync().isNotEmpty,
        false,
      );
      expect(bloc.state.sessionImagePaths, isEmpty);
      expect(bloc.state.ocrPageByPreviewPath, isEmpty);
    });
  }

  test('a session opened while another is processing gets its 200 dpi '
      'pages when its step starts, with the turns made meanwhile', () async {
    const busy = ProcessingSession(
      id: 'busy',
      status: ProcessingStatus.processing,
    );
    // ignore: invalid_use_of_visible_for_testing_member
    bloc.emit(ProcessingState(sessions: [session(), busy]));
    bloc.add(const SessionActivated(sessionId: _sessionId));
    await bloc.stream.firstWhere((s) => s.sessionImagePaths.isNotEmpty);
    final previews = bloc.state.sessionImagePaths[_sessionId]!;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(printing.rendered, [72]);

    bloc.add(PageRotated(sessionId: _sessionId, previewPath: previews[1]));
    await eventually(
      () => pageMapHas(
        previews.map(name),
        turned: name(previews[1]),
        turns: 1,
      ),
    );
    expect(printing.rendered, [72]);

    // The other session finishes.
    // ignore: invalid_use_of_visible_for_testing_member
    bloc.emit(
      bloc.state.copyWith(
        sessions: [
          session(),
          busy.copyWith(status: ProcessingStatus.draft),
        ],
      ),
    );
    bloc.add(const ProcessRemainingResources(sessionId: _sessionId));
    await bloc.stream.firstWhere(
      (s) => s.sessions.first.status == ProcessingStatus.draft,
    );
    final pages = repository.remainingImages!;

    expect(printing.rendered, [72, 200]);
    expect(isOcrPage(pages[0]), isTrue);
    expect(pages[1], endsWith('_page_2_r1.jpg'));
    expect(decode(pages[1]).width, _heightAt(200));
    expect(isOcrPage(pages[2]), isTrue);
  });

  test('a session deleted while its pages render leaves no pages '
      'behind', () async {
    seed(session());
    bloc.add(const SessionActivated(sessionId: _sessionId));
    await bloc.stream.firstWhere((s) => s.sessionImagePaths.isNotEmpty);

    bloc.add(SessionCleared(session: session()));
    await bloc.stream.firstWhere((s) => s.sessions.isEmpty);
    await eventually(
      () =>
          printing.rendered.length == 2 &&
          !pageMap().existsSync() &&
          cacheDir().listSync().isEmpty,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.ocrPageByPreviewPath, isEmpty);
    expect(cacheDir().listSync(), isEmpty);
  });

  test('deleting the session deletes its 72 and 200 dpi pages and its '
      'page map, and no one else\'s', () async {
    final previews = await open(session());
    final ocrPages = bloc.state.ocrPageByPreviewPath.values.toList();
    final otherPage = File(
      '${cacheDir().path}/${'e' * 64}_page_1.jpg',
    )..writeAsStringSync('other session');
    final otherMetadata = File('${cacheDir().path}/${'e' * 64}.json')
      ..writeAsStringSync('{}');

    bloc.add(SessionCleared(session: session()));
    await bloc.stream.firstWhere((s) => s.sessions.isEmpty);
    await eventually(() => !pageMap().existsSync());

    expect(repository.deleted.single.id, _sessionId);
    expect([...previews, ...ocrPages].any((p) => File(p).existsSync()), false);
    expect(pageMap().existsSync(), isFalse);
    expect(
      cacheDir().listSync().map((e) => e.path.split('/').last),
      unorderedEquals([
        otherPage.path.split('/').last,
        otherMetadata.path.split('/').last,
      ]),
    );
    expect(bloc.state.ocrPageByPreviewPath, isEmpty);
  });
}
