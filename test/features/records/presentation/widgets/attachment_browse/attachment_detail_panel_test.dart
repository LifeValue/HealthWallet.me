import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/utils/pdf_pages.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/bloc/attachment_browse_bloc.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/attachment_browse/attachment_detail_panel.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_attachments/bloc/record_attachments_bloc.dart';
// The picker's XFile, which image_picker shares through cross_file.
import 'package:image_picker/image_picker.dart' show XFile;

/// Keeps the events the panel sends to the browse list.
class _MockAttachmentBrowseBloc
    extends MockBloc<AttachmentBrowseEvent, AttachmentBrowseState>
    implements AttachmentBrowseBloc {
  final added = <AttachmentBrowseEvent>[];

  @override
  void add(AttachmentBrowseEvent event) => added.add(event);
}

class _MockRecordsBloc extends MockBloc<RecordsEvent, RecordsState>
    implements RecordsBloc {}

/// Loads the record's attachments, then ends attaching in [attachResult].
class _FakeRecordAttachmentsBloc
    extends Bloc<RecordAttachmentsEvent, RecordAttachmentsState>
    implements RecordAttachmentsBloc {
  _FakeRecordAttachmentsBloc(this.attachResult)
    : super(const RecordAttachmentsState()) {
    on<RecordAttachmentsInitialised>(
      (event, emit) => emit(
        state.copyWith(status: const RecordAttachmentsStatus.success()),
      ),
    );
    on<RecordAttachmentsFileAttached>((event, emit) {
      attached.add(event.files.map((f) => f.path).toList());
      emit(state.copyWith(status: const RecordAttachmentsStatus.loading()));
      emit(state.copyWith(status: attachResult));
    });
  }

  final RecordAttachmentsStatus attachResult;
  final attached = <List<String>>[];
}

/// The file picker, answering with [paths].
class _FakeFilePicker extends FilePickerPlatform {
  _FakeFilePicker(this.paths);

  final List<String> paths;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => [for (final path in paths) _PickedFile(path)];
}

/// A picked file on the local disk, never read by the panel.
final class _PickedFile extends PlatformFile {
  _PickedFile(String path) : uri = Uri.file(path);

  @override
  final Uri uri;

  @override
  String get name => uri.pathSegments.last;

  @override
  XFile get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => 1;

  @override
  Future<int?> length() async => 1;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List(1);

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(Uint8List(1));
}

// pdfx opens files through pigeon on iOS, macOS and Android and through a
// method channel elsewhere: the tests answer both with an error. On Linux
// (CI) pdfx refuses to run at all; either way the file fails to open. The
// tests pin pdfx, which the app uses everywhere but on Linux.
const _pdfPigeonOpenFile = 'dev.flutter.pigeon.PdfxApi.openDocumentFile';
const _pdfMethodChannel = MethodChannel('io.scer.pdf_renderer');

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  late FilePickerPlatform realFilePicker;

  setUp(() {
    realFilePicker = FilePickerPlatform.instance;
    PdfPages.usePdfx = true;
  });

  tearDown(() async {
    FilePickerPlatform.instance = realFilePicker;
    PdfPages.usePdfx = !Platform.isLinux;
    await getIt.reset();
  });

  /// Makes every PDF fail to open.
  void failPdfs(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMessageHandler(_pdfPigeonOpenFile, (_) async {
      return const StandardMessageCodec().encodeMessage(<Object?>[
        'error',
        'not a PDF',
        null,
      ]);
    });
    messenger.setMockMethodCallHandler(_pdfMethodChannel, (call) async {
      throw PlatformException(code: 'error', message: 'not a PDF');
    });
    addTearDown(() {
      messenger.setMockMessageHandler(_pdfPigeonOpenFile, null);
      messenger.setMockMethodCallHandler(_pdfMethodChannel, null);
    });
  }

  Future<_MockAttachmentBrowseBloc> pumpPanel(
    WidgetTester tester,
    AttachmentBrowseDetail detail,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final browseBloc = _MockAttachmentBrowseBloc();
    whenListen(
      browseBloc,
      const Stream<AttachmentBrowseState>.empty(),
      initialState: AttachmentBrowseState(
        status: AttachmentBrowseStatus.success,
        selectedDetail: detail,
      ),
    );
    final recordsBloc = _MockRecordsBloc();
    whenListen(
      recordsBloc,
      const Stream<RecordsState>.empty(),
      initialState: const RecordsState(
        sourceId: 'src-1',
        activeFilters: [FhirType.Encounter],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AttachmentBrowseBloc>.value(value: browseBloc),
            BlocProvider<RecordsBloc>.value(value: recordsBloc),
          ],
          child: Scaffold(
            body: SingleChildScrollView(
              child: AttachmentDetailPanel(detail: detail),
            ),
          ),
        ),
      ),
    );
    return browseBloc;
  }

  /// Lets the snackbar slide in.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
  }

  group('a PDF that cannot be opened', () {
    AttachmentBrowseDetail pdfDetail(String recordId) {
      final record = Encounter(id: recordId, title: 'Visit');
      return AttachmentBrowseDetail(
        record: record,
        attachments: [
          AttachmentBrowseFile(
            id: 'doc-$recordId',
            resource: DocumentReference(id: 'doc-$recordId'),
            title: 'Discharge letter',
            filePath: '/attachments/discharge.pdf',
            contentType: 'application/pdf',
          ),
        ],
      );
    }

    testWidgets('shows the "Failed to load PDF" error and the empty preview', (
      tester,
    ) async {
      failPdfs(tester);
      await pumpPanel(tester, pdfDetail('enc-pdf-1'));
      await settle(tester);

      expect(find.widgetWithText(SnackBar, l10n.failedToLoadPdf), findsOne);
      expect(find.text(l10n.noAttachments), findsOne);
    });

    testWidgets('is not cached: opening the record again tries again and '
        'says so again', (tester) async {
      failPdfs(tester);
      final detail = pdfDetail('enc-pdf-2');
      await pumpPanel(tester, detail);
      await settle(tester);
      ScaffoldMessenger.of(
        tester.element(find.byType(SnackBar)),
      ).removeCurrentSnackBar();
      await tester.pumpWidget(const SizedBox());

      await pumpPanel(tester, detail);
      await settle(tester);

      // A cached result would show the preview without trying, and say
      // nothing; the message proves the PDF was tried again.
      expect(find.widgetWithText(SnackBar, l10n.failedToLoadPdf), findsOne);
    });
  });

  group('Add attachment', () {
    final record = const Encounter(id: 'enc-empty', title: 'Visit');
    final detail = AttachmentBrowseDetail(record: record);

    Future<(_FakeRecordAttachmentsBloc, _MockAttachmentBrowseBloc)> attach(
      WidgetTester tester,
      RecordAttachmentsStatus result,
    ) async {
      FilePickerPlatform.instance = _FakeFilePicker(['/picked/scan.jpg']);
      final attachBloc = _FakeRecordAttachmentsBloc(result);
      // Not awaited: close() would wait on the fake async zone.
      addTearDown(() => unawaited(attachBloc.close()));
      await getIt.reset();
      getIt.registerFactory<RecordAttachmentsBloc>(() => attachBloc);

      final browseBloc = await pumpPanel(tester, detail);
      await tester.pump();
      await tester.tap(find.text(l10n.addAttachment));
      await settle(tester);
      return (attachBloc, browseBloc);
    }

    testWidgets('an attach that fails shows the bloc\'s translated message '
        'and still refreshes the list', (tester) async {
      final (attachBloc, browseBloc) = await attach(
        tester,
        RecordAttachmentsStatus.error(l10n.attachFileFailed),
      );

      expect(attachBloc.attached, [
        ['/picked/scan.jpg'],
      ]);
      expect(find.widgetWithText(SnackBar, l10n.attachFileFailed), findsOne);
      final refresh = browseBloc.added
          .whereType<AttachmentBrowseInitialised>()
          .single;
      expect(refresh.sourceId, 'src-1');
      expect(refresh.resourceTypes, [FhirType.Encounter]);
      expect(find.text(l10n.attachingFiles), findsNothing);
    });

    testWidgets('an error that is not a message shows no snackbar', (
      tester,
    ) async {
      await attach(
        tester,
        RecordAttachmentsStatus.error(Exception('disk full')),
      );

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a successful attach shows no error', (tester) async {
      final (attachBloc, browseBloc) = await attach(
        tester,
        const RecordAttachmentsStatus.success(),
      );

      expect(attachBloc.attached, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
      expect(browseBloc.added.whereType<AttachmentBrowseInitialised>(), [
        isA<AttachmentBrowseInitialised>(),
      ]);
    });
  });
}
