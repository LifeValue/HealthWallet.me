import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/services/pdf_preview_service.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/core/widgets/checked_pdf_view.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

import '../../features/desktop/lww_sync/lww_sync_test_helpers.dart'
    show TestDirs;

final _l10n = lookupAppLocalizations(const Locale('en'));

// A 1x1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// A path resolver that fails, as an unreadable stored path would.
class _FailingPathResolver extends PathResolver {
  @override
  Future<String> toAbsolute(String path) async =>
      throw StateError('cannot resolve');
}

/// A document whose attachment is stored as [storedName] with [title].
DocumentReference _document({
  String? storedName,
  String? attachmentTitle,
  String title = '',
}) => DocumentReference(
  id: 'doc-1',
  title: title,
  rawResource: {
    'resourceType': 'DocumentReference',
    'content': [
      {
        'attachment': {
          'url': ?(storedName == null ? null : 'file://$storedName'),
          'title': ?attachmentTitle,
        },
      },
    ],
  },
);

void main() {
  late TestDirs dirs;
  late PdfPreviewService service;
  final previousCanOpen = CheckedPdfView.defaultCanOpen;

  setUp(() async {
    dirs = await TestDirs.create();
    service = PdfPreviewService(PathResolver());
    getIt.registerSingleton<AppPlatform>(AppPlatform.mobile);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    // The PDF view is a native view; answer its creation like iOS would.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, (_) async {
          return null;
        });
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
    CheckedPdfView.defaultCanOpen = previousCanOpen;
    await getIt.unregister<AppPlatform>();
    await dirs.dispose();
  });

  void store(String name, List<int> bytes) =>
      dirs.docFile(name).writeAsBytesSync(bytes);

  /// Previews [resource] from a button, as the record page does.
  Future<void> preview(
    WidgetTester tester,
    IFhirResource resource, {
    PdfPreviewService? using,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  (using ?? service).previewPdfFromResource(context, resource),
              child: const Text('view'),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('view'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
  }

  Finder messageCard(String text) => find.descendant(
    of: find.byKey(AppSnackBar.cardKey),
    matching: find.text(text),
  );

  testWidgets('a record that is not a document or media is not viewable', (
    tester,
  ) async {
    await preview(tester, const Observation(id: 'obs-1'));

    expect(messageCard(_l10n.resourceNotViewable), findsOne);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a document without a file says so', (tester) async {
    await preview(tester, _document());

    expect(messageCard(_l10n.noFilePathFound), findsOne);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a file that is gone says so', (tester) async {
    await preview(tester, _document(storedName: 'missing_1a2b3c4d.pdf'));

    expect(messageCard(_l10n.fileNotAvailable), findsOne);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a path that cannot be read shows the translated message, not '
      'the exception', (tester) async {
    await preview(
      tester,
      _document(storedName: 'report_1a2b3c4d.pdf'),
      using: PdfPreviewService(_FailingPathResolver()),
    );

    expect(messageCard(_l10n.fileOpenFailed), findsOne);
    expect(find.textContaining('cannot resolve'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  group('the viewer title', () {
    setUp(() {
      CheckedPdfView.defaultCanOpen = (_) async => true;
      store('report_1a2b3c4d.pdf', utf8.encode('%PDF-1.7'));
    });

    testWidgets('is the name the user picked, not the stored one', (
      tester,
    ) async {
      await preview(
        tester,
        _document(
          storedName: 'report_1a2b3c4d.pdf',
          attachmentTitle: 'report.pdf',
          title: 'Lab report',
        ),
      );

      expect(find.widgetWithText(AppBar, 'report.pdf'), findsOne);
      expect(find.text('report_1a2b3c4d.pdf'), findsNothing);
      expect(find.byType(PDFView), findsOne);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('falls back to the record title', (tester) async {
      await preview(
        tester,
        _document(storedName: 'report_1a2b3c4d.pdf', title: 'Lab report'),
      );

      expect(find.widgetWithText(AppBar, 'Lab report'), findsOne);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  testWidgets('an image opens in the image viewer under its title', (
    tester,
  ) async {
    store('photo_1a2b3c4d.png', _png);

    await preview(
      tester,
      _document(storedName: 'photo_1a2b3c4d.png', attachmentTitle: 'photo.png'),
    );

    expect(find.byType(InteractiveViewer), findsOne);
    expect(find.widgetWithText(AppBar, 'photo.png'), findsOne);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a PDF view error shows the translated message, not its own '
      'text', (tester) async {
    CheckedPdfView.defaultCanOpen = (_) async => true;
    store('report_1a2b3c4d.pdf', utf8.encode('%PDF-1.7'));
    await preview(
      tester,
      _document(storedName: 'report_1a2b3c4d.pdf', attachmentTitle: 'r.pdf'),
    );

    final view = tester.widget<PDFView>(find.byType(PDFView));
    view.onError!('PdfiumException: bad xref');
    await tester.pump();
    view.onPageError!(4, 'page render failed');
    await tester.pump();

    expect(messageCard(_l10n.failedToLoadPdf), findsWidgets);
    expect(find.textContaining('Pdfium'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('media carrying its PDF as data opens from a temporary file', (
    tester,
  ) async {
    CheckedPdfView.defaultCanOpen = (_) async => true;

    await preview(
      tester,
      Media(
        id: 'media-1',
        title: 'Referral',
        rawResource: {
          'resourceType': 'Media',
          'content': {
            'contentType': 'application/pdf',
            'data': base64Encode(utf8.encode('%PDF-1.7')),
          },
        },
      ),
    );

    final view = tester.widget<PDFView>(find.byType(PDFView));
    expect(view.filePath, startsWith(dirs.temp.path));
    expect(find.widgetWithText(AppBar, 'Referral'), findsOne);
    debugDefaultTargetPlatformOverride = null;
  });
}
