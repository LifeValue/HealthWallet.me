import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart' hide Source;
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/processing/data/services/pdf_generation_service.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fake_device_capability_service.dart';
import '../../../records/records_test_helpers.dart';
import '../../../share_records/share_test_helpers.dart';

/// Writes `<key>_page_<n>.jpg` pages into the page cache, a key per file and
/// dpi, like the app's PDF conversion (without its isolates).
class _FakeRecognition extends Fake implements TextRecognitionService {
  _FakeRecognition(this.cacheDir);

  final Directory cacheDir;

  @override
  bool isPDF(String filePath) => filePath.endsWith('.pdf');

  @override
  bool isImage(String filePath) => filePath.endsWith('.jpg');

  @override
  Future<List<String>> convertPdfToImagesForPreview(
    String pdfPath, {
    double dpi = 72,
  }) async {
    final key = (pdfPath.hashCode.toRadixString(16) + dpi.toString())
        .replaceAll(RegExp('[^0-9a-f]'), '')
        .padRight(64, 'a')
        .substring(0, 64);
    cacheDir.createSync(recursive: true);
    return [
      for (var n = 1; n <= 2; n++)
        (File('${cacheDir.path}/${key}_page_$n.jpg')..writeAsBytesSync(
              img.encodeJpg(img.Image(width: 4, height: 2)),
            ))
            .path,
    ];
  }
}

/// The app's page set, telling the test when each step of it has ended.
class _ObservedPageSet extends OcrProcessingHelper {
  _ObservedPageSet(super.recognition, super.pathResolver);

  final pagesKept = Completer<void>();
  final ocrPagesDiscarded = Completer<void>();
  final sessionPagesDiscarded = Completer<void>();

  @override
  Future<void> keepOcrPages({
    required String sessionId,
    required List<String> filePaths,
    required List<String> previewPaths,
  }) async {
    await super.keepOcrPages(
      sessionId: sessionId,
      filePaths: filePaths,
      previewPaths: previewPaths,
    );
    pagesKept.complete();
  }

  @override
  Future<void> discardOcrPages({
    required String sessionId,
    Iterable<String> ocrPages = const [],
  }) async {
    await super.discardOcrPages(sessionId: sessionId, ocrPages: ocrPages);
    ocrPagesDiscarded.complete();
  }

  @override
  Future<void> discardSessionPages({
    required String sessionId,
    Iterable<String> pages = const [],
  }) async {
    await super.discardSessionPages(sessionId: sessionId, pages: pages);
    sessionPagesDiscarded.complete();
  }
}

class _FakeProcessingRepository extends Fake implements ProcessingRepository {
  @override
  Future<int> editProcessingSession(ProcessingSession session) async => 1;

  @override
  Future<int> deleteProcessingSession(ProcessingSession session) async => 1;
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

class _FakeRecordsRepository extends Fake implements RecordsRepository {}

class _FakeHolderService extends Fake implements HolderService {
  @override
  Future<Source> walletSourceOf(String holderId) async =>
      Source(id: 'wallet-$holderId', holderId: holderId);
}

const _sessionId = '7c1d2e3f-4a5b-4c6d-8e9f-0a1b2c3d4e5f';

/// The Documents-relative path in a DocumentReference's `file://` url.
String _attachmentPath(String raw) {
  final content = (jsonDecode(raw) as Map<String, dynamic>)['content'] as List;
  final url = content.single['attachment']['url'] as String;
  return url.substring('file://'.length);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;
  late Directory cacheDir;
  late AppDatabase db;
  late _ObservedPageSet pageSet;
  late ProcessingBloc bloc;
  late File original;

  setUp(() async {
    final root = mockPathProvider();
    docs = Directory('${root.path}/Documents');
    cacheDir = Directory('${docs.path}/${TempFileSweeper.ocrCacheDirName}');
    db = openTestDatabase();
    SharedPreferences.setMockInitialValues({});
    final paths = PathResolver();
    final recognition = _FakeRecognition(cacheDir);
    final repository = _FakeProcessingRepository();
    pageSet = _ObservedPageSet(recognition, paths);
    bloc = ProcessingBloc(
      repository,
      pageSet,
      _FakeSyncRepository(),
      DocumentReferenceService(db, PdfGenerationService(paths), paths),
      _FakeHolderService(),
      _FakeHolderSelection(),
      _FakeRecordsRepository(),
      await SharedPreferences.getInstance(),
      AppStringsProvider.forLocale(const Locale('en')),
      LayoutExtractionService(
        repository,
        pageSet,
        LayoutExtractorRegistry(const []),
        _FakeHolderService(),
        _FakeRecordsRepository(),
      ),
      FakeDeviceCapabilityService(),
    );
    // The PDF as an import stores it.
    original = File('${docs.path}/imports/report_1.pdf')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
  });

  tearDown(() async {
    await bloc.close();
    await db.close();
  });

  File pageMap() => File(
    '${cacheDir.path}/${TempFileSweeper.sessionPageMapName(_sessionId)}',
  );

  /// The file each saved document's attachment points at.
  Future<List<File>> attachments() async => [
    for (final row in await db.select(db.fhirResource).get())
      if (row.resourceType == 'DocumentReference')
        File('${docs.path}/${_attachmentPath(row.resourceRaw)}'),
  ];

  group('an imported PDF whose pages were edited, then saved', () {
    test('has its imported original deleted when the session is cleared, '
        'and the saved document keeps its file', () async {
      // Imported, its patient step done: the review opens it.
      // ignore: invalid_use_of_visible_for_testing_member
      bloc.emit(
        ProcessingState(
          sessions: [
            ProcessingSession(
              id: _sessionId,
              status: ProcessingStatus.patientExtracted,
              filePaths: [original.path],
            ),
          ],
        ),
      );
      bloc.add(const SessionActivated(sessionId: _sessionId));
      await bloc.stream.firstWhere((s) => s.ocrPageByPreviewPath.isNotEmpty);
      final previews = bloc.state.sessionImagePaths[_sessionId]!;
      final ocrPages = bloc.state.ocrPageByPreviewPath.values.toList();

      // The user deletes the first page: the session now stores only its
      // preview pages, and the original is known only to the page map.
      bloc.add(
        PagesReordered(sessionId: _sessionId, reorderedPaths: [previews[1]]),
      );
      await pageSet.pagesKept.future;
      expect(bloc.state.sessions.single.filePaths, [previews[1]]);

      // Its records are staged and it is saved.
      // ignore: invalid_use_of_visible_for_testing_member
      bloc.emit(
        bloc.state.copyWith(
          sessions: [
            bloc.state.sessions.single.copyWith(
              patient: const StagedPatient(
                draft: MappingPatient(
                  id: 'p',
                  gender: MappedProperty(value: 'female'),
                ),
                mode: ImportMode.createNew,
              ),
              encounter: const StagedEncounter(
                draft: MappingEncounter(id: 'e'),
              ),
              status: ProcessingStatus.draft,
            ),
          ],
        ),
      );
      bloc.add(const ResourceCreationInitiated(sessionId: _sessionId));
      await bloc.stream.firstWhere(
        (s) => s.status is Success || s.status is Failure,
      );
      expect(bloc.state.status, isA<Success>());

      // Saving sends OcrPagesReleased: the 200 dpi pages go.
      await pageSet.ocrPagesDiscarded.future;
      expect(ocrPages.any((page) => File(page).existsSync()), isFalse);
      expect(original.existsSync(), isTrue);

      // The saved session is then cleared.
      bloc.add(SessionCleared(session: bloc.state.sessions.single));
      await pageSet.sessionPagesDiscarded.future;

      expect(original.existsSync(), isFalse);
      expect(pageMap().existsSync(), isFalse);
      expect(cacheDir.listSync(), isEmpty);
      final saved = await attachments();
      expect(saved, hasLength(1));
      expect(saved.single.existsSync(), isTrue);
      expect(saved.single.path, isNot(contains('/imports/')));
    });
  });
}
