import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/core/widgets/checked_pdf_view.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_attachments/bloc/record_attachments_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_attachments/record_attachments_widget.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:share_plus/share_plus.dart' show XFile;

class _MockRecordAttachmentsBloc
    extends MockBloc<RecordAttachmentsEvent, RecordAttachmentsState>
    implements RecordAttachmentsBloc {
  final events = <RecordAttachmentsEvent>[];

  @override
  void add(RecordAttachmentsEvent event) => events.add(event);
}

/// Answers the native file picker with [picked].
class _FakeFilePicker extends FilePickerPlatform {
  List<PlatformFile> picked = const [];

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
  }) async => picked;
}

/// A picked file at [uri]: a `file:` URI has a path, anything else not.
final class _PickedFile extends PlatformFile {
  _PickedFile(this.name, this.uri);

  @override
  final String name;

  @override
  final Uri uri;

  @override
  XFile get xFile => XFile(uri.toString());

  @override
  int? lengthSync() => null;

  @override
  Future<int?> length() async => null;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);

  @override
  Stream<Uint8List> readAsByteStream() => const Stream.empty();
}

final _l10n = lookupAppLocalizations(const Locale('en'));

// A 1x1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  late _MockRecordAttachmentsBloc bloc;
  late StreamController<RecordAttachmentsState> states;
  late Directory dir;
  late _FakeFilePicker picker;
  final previousPicker = FilePickerPlatform.instance;
  final previousCanOpen = CheckedPdfView.defaultCanOpen;

  const resource = GeneralResource(id: 'obs-1');

  setUp(() async {
    bloc = _MockRecordAttachmentsBloc();
    states = StreamController<RecordAttachmentsState>.broadcast();
    whenListen(
      bloc,
      states.stream,
      initialState: const RecordAttachmentsState(
        status: RecordAttachmentsStatus.success(),
      ),
    );
    getIt.registerFactory<RecordAttachmentsBloc>(() => bloc);
    getIt.registerSingleton<AppPlatform>(AppPlatform.mobile);
    picker = _FakeFilePicker();
    FilePickerPlatform.instance = picker;
    dir = Directory.systemTemp.createTempSync('attachments_viewers');
  });

  tearDown(() async {
    await getIt.unregister<RecordAttachmentsBloc>();
    await getIt.unregister<AppPlatform>();
    FilePickerPlatform.instance = previousPicker;
    CheckedPdfView.defaultCanOpen = previousCanOpen;
    await states.close();
    dir.deleteSync(recursive: true);
  });

  String writeFile(String name, List<int> bytes) {
    final file = File('${dir.path}/$name')..writeAsBytesSync(bytes);
    return file.path;
  }

  /// Opens the widget as a pushed page, so its close button has something to
  /// pop, and lists [attachments].
  Future<void> open(
    WidgetTester tester, {
    List<AttachmentInfo> attachments = const [],
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: RecordAttachmentsWidget(resource: resource),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    states.add(
      RecordAttachmentsState(
        status: const RecordAttachmentsStatus.success(),
        resource: resource,
        attachments: attachments,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
  }

  /// Taps [finder] and lets the real file check behind it finish: until a
  /// message shows or a viewer covers the list, or about 3 s for a file
  /// handed to another app, which changes nothing on screen.
  Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    for (var i = 0; i < 150; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byKey(AppSnackBar.cardKey).evaluate().isNotEmpty ||
          find.byType(RecordAttachmentsWidget).evaluate().isEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();
  }

  Finder messageCard(String text) => find.descendant(
    of: find.byKey(AppSnackBar.cardKey),
    matching: find.text(text),
  );

  testWidgets('the close button closes the attachments', (tester) async {
    await open(tester);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(RecordAttachmentsWidget), findsNothing);
  });

  testWidgets('attaching sends the picked files to the bloc', (tester) async {
    final path = writeFile('scan.pdf', utf8.encode('%PDF-1.7'));
    picker.picked = [
      _PickedFile('scan.pdf', Uri.file(path)),
      _PickedFile('cloud.pdf', Uri.parse('content://provider/cloud.pdf')),
    ];
    await open(tester);

    await tester.tap(find.text(_l10n.attachFile));
    await tester.pumpAndSettle();

    final attached = bloc.events.whereType<RecordAttachmentsFileAttached>();
    expect(attached.single.files.map((f) => f.path), [path]);
  });

  testWidgets('cancelling the picker attaches nothing', (tester) async {
    await open(tester);

    await tester.tap(find.text(_l10n.attachFile));
    await tester.pumpAndSettle();

    expect(bloc.events.whereType<RecordAttachmentsFileAttached>(), isEmpty);
  });

  testWidgets('a file that is gone shows a message instead of opening', (
    tester,
  ) async {
    await open(
      tester,
      attachments: [
        AttachmentInfo(
          documentReference: const GeneralResource(id: 'doc-1'),
          title: 'report.pdf',
          contentType: 'application/pdf',
          filePath: '${dir.path}/missing.pdf',
        ),
      ],
    );

    await tapAndWait(tester, find.byIcon(Icons.remove_red_eye_outlined));

    expect(messageCard(_l10n.fileNotAvailable), findsOne);
  });

  testWidgets('an image opens full screen under the name the user picked', (
    tester,
  ) async {
    final path = writeFile('photo_1a2b3c4d.png', _png);
    await open(
      tester,
      attachments: [
        AttachmentInfo(
          documentReference: const GeneralResource(id: 'doc-1'),
          title: 'photo.png',
          contentType: 'image/png',
          filePath: path,
        ),
      ],
    );

    await tapAndWait(tester, find.text('photo.png'));

    expect(find.byType(InteractiveViewer), findsOne);
    expect(find.widgetWithText(AppBar, 'photo.png'), findsOne);
  });

  group('a PDF on a phone', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      // The PDF view is a native view; answer its creation like iOS would.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform_views, (_) async {
            return null;
          });
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform_views, null);
    });

    Future<void> openPdf(WidgetTester tester) async {
      final path = writeFile('report_1a2b3c4d.pdf', utf8.encode('%PDF-1.7'));
      await open(
        tester,
        attachments: [
          AttachmentInfo(
            documentReference: const GeneralResource(id: 'doc-1'),
            title: 'report.pdf',
            contentType: 'application/pdf',
            filePath: path,
          ),
        ],
      );
      await tapAndWait(tester, find.byIcon(Icons.remove_red_eye_outlined));
    }

    testWidgets('opens in the PDF view under the name the user picked', (
      tester,
    ) async {
      CheckedPdfView.defaultCanOpen = (_) async => true;

      await openPdf(tester);

      expect(find.byType(PDFView), findsOne);
      expect(find.widgetWithText(AppBar, 'report.pdf'), findsOne);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a PDF view error shows the translated message, not its '
        'own text', (tester) async {
      CheckedPdfView.defaultCanOpen = (_) async => true;
      await openPdf(tester);

      final view = tester.widget<PDFView>(find.byType(PDFView));
      view.onError!('PdfiumException: bad xref');
      await tester.pump();
      expect(messageCard(_l10n.failedToLoadPdf), findsOne);

      view.onPageError!(2, 'page render failed');
      await tester.pump();
      expect(find.textContaining('Pdfium'), findsNothing);
      expect(find.textContaining('render failed'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a file that is not a readable PDF shows a message instead '
        'of a blank page', (tester) async {
      CheckedPdfView.defaultCanOpen = (_) async => false;

      await openPdf(tester);

      expect(find.byType(PDFView), findsNothing);
      expect(find.text(_l10n.failedToLoadPdf), findsOne);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  testWidgets('on the desktop a PDF opens in the desktop PDF view', (
    tester,
  ) async {
    await getIt.unregister<AppPlatform>();
    getIt.registerSingleton<AppPlatform>(AppPlatform.desktop);
    CheckedPdfView.defaultCanOpen = (_) async => true;
    final path = writeFile('report_1a2b3c4d.pdf', utf8.encode('%PDF-1.7'));
    await open(
      tester,
      attachments: [
        AttachmentInfo(
          documentReference: const GeneralResource(id: 'doc-1'),
          title: 'report.pdf',
          contentType: 'application/pdf',
          filePath: path,
        ),
      ],
    );

    await tapAndWait(tester, find.byIcon(Icons.remove_red_eye_outlined));

    expect(find.byType(pdfx.PdfView), findsOne);
    expect(find.widgetWithText(AppBar, 'report.pdf'), findsOne);
  });

  group('another file type', () {
    const channel = MethodChannel('open_file');

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    Future<void> openText(WidgetTester tester) async {
      final path = writeFile('notes_1a2b3c4d.txt', utf8.encode('notes'));
      await open(
        tester,
        attachments: [
          AttachmentInfo(
            documentReference: const GeneralResource(id: 'doc-1'),
            title: 'notes.txt',
            contentType: 'text/plain',
            filePath: path,
          ),
        ],
      );
      await tapAndWait(tester, find.byIcon(Icons.remove_red_eye_outlined));
    }

    void answerOpenFile(Future<Object?> Function(MethodCall) answer) =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, answer);

    testWidgets('opens in another app without a message', (tester) async {
      final opened = <Object?>[];
      answerOpenFile((call) async {
        opened.add((call.arguments as Map)['file_path']);
        return jsonEncode({'type': 0, 'message': 'done'});
      });

      await openText(tester);

      expect(opened.single, endsWith('notes_1a2b3c4d.txt'));
      expect(find.byKey(AppSnackBar.cardKey), findsNothing);
    });

    testWidgets('no app to open it shows the translated message, not the '
        'system text', (tester) async {
      answerOpenFile(
        (_) async =>
            jsonEncode({'type': -1, 'message': 'No APP found to open this'}),
      );

      await openText(tester);

      expect(messageCard(_l10n.fileOpenFailed), findsOne);
      expect(find.textContaining('No APP'), findsNothing);
    });

    testWidgets('a failure to open shows the translated message, not the '
        'exception', (tester) async {
      answerOpenFile(
        (_) async => throw PlatformException(code: 'ERR', message: 'boom'),
      );

      await openText(tester);

      expect(messageCard(_l10n.fileOpenFailed), findsOne);
      expect(find.textContaining('boom'), findsNothing);
    });
  });
}
