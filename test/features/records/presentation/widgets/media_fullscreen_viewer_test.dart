import 'dart:convert';

import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
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
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/widgets/media_fullscreen_viewer.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

import '../../../desktop/lww_sync/lww_sync_test_helpers.dart' show TestDirs;

final _l10n = lookupAppLocalizations(const Locale('en'));

/// Records links instead of writing them; throws [error] when set.
class _FakeDocumentReferenceService extends Fake
    implements DocumentReferenceService {
  Error? error;
  final links = <(String, String, String?)>[];

  @override
  Future<void> linkDocumentReferenceToEncounter({
    required String documentReferenceResourceId,
    required String encounterId,
    String? sourceId,
  }) async {
    if (error != null) throw error!;
    links.add((documentReferenceResourceId, encounterId, sourceId));
  }
}

Media _media({String? contentType, String? data}) => Media(
  id: 'media-1',
  title: 'Scan of the referral',
  content: fhir_r4.Attachment.fromJson({
    'contentType': ?contentType,
    'data': ?data,
  }),
);

void main() {
  late TestDirs dirs;
  final previousCanOpen = CheckedPdfView.defaultCanOpen;

  setUp(() async {
    dirs = await TestDirs.create();
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

  Future<void> open(WidgetTester tester, Media media) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaFullscreenViewer(media: media),
      ),
    );
    // The PDF is written to a temporary file first, with real file I/O:
    // let it run until the loading spinner is gone, however long the machine
    // takes (a fixed wait failed on a slower Linux host).
    for (var i = 0; i < 150; i++) {
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  final pdf = base64Encode(utf8.encode('%PDF-1.7 referral'));

  testWidgets('without PDF data it says so', (tester) async {
    await open(tester, _media(contentType: 'image/png', data: pdf));

    expect(find.text('Scan of the referral'), findsOne);
    expect(find.text(_l10n.noPdfDataAvailable), findsOne);
    expect(find.byType(PDFView), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a PDF opens in the PDF view from a temporary file', (
    tester,
  ) async {
    CheckedPdfView.defaultCanOpen = (_) async => true;

    await open(tester, _media(contentType: 'application/pdf', data: pdf));

    final view = tester.widget<PDFView>(find.byType(PDFView));
    expect(view.filePath, startsWith(dirs.temp.path));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a PDF view error shows the translated message, not its own '
      'text', (tester) async {
    CheckedPdfView.defaultCanOpen = (_) async => true;
    await open(tester, _media(contentType: 'application/pdf', data: pdf));

    final view = tester.widget<PDFView>(find.byType(PDFView));
    view.onError!('PdfiumException: bad xref');
    await tester.pump();
    view.onPageError!(1, 'page render failed');
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(AppSnackBar.cardKey),
        matching: find.text(_l10n.failedToLoadPdf),
      ),
      findsWidgets,
    );
    expect(find.textContaining('Pdfium'), findsNothing);
    expect(find.textContaining('render failed'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a PDF that cannot be read shows a message, not a blank page', (
    tester,
  ) async {
    CheckedPdfView.defaultCanOpen = (_) async => false;

    await open(tester, _media(contentType: 'application/pdf', data: pdf));

    expect(find.byType(PDFView), findsNothing);
    expect(find.text(_l10n.failedToLoadPdf), findsOne);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('on the desktop a PDF opens in the desktop PDF view', (
    tester,
  ) async {
    await getIt.unregister<AppPlatform>();
    getIt.registerSingleton<AppPlatform>(AppPlatform.desktop);
    CheckedPdfView.defaultCanOpen = (_) async => true;

    await open(tester, _media(contentType: 'application/pdf', data: pdf));

    expect(find.byType(pdfx.PdfView), findsOne);
    expect(find.byType(PDFView), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  group('linking to an encounter', () {
    late _FakeDocumentReferenceService documents;

    setUp(() {
      documents = _FakeDocumentReferenceService();
      getIt.registerSingleton<DocumentReferenceService>(documents);
    });

    tearDown(() => getIt.unregister<DocumentReferenceService>());

    Future<void> link(WidgetTester tester, String encounterId) async {
      await open(
        tester,
        Media(
          id: 'media-1',
          resourceId: 'media-res-1',
          sourceId: 'clinic',
          title: 'Scan of the referral',
          content: fhir_r4.Attachment.fromJson({'contentType': 'image/png'}),
        ),
      );
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.linkToEncounter).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), encounterId);
      await tester.tap(find.text(_l10n.link));
      await tester.pumpAndSettle();
    }

    testWidgets('links the media and confirms it', (tester) async {
      await link(tester, ' enc-7 ');

      expect(documents.links, [('media-res-1', 'enc-7', 'clinic')]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(AppSnackBar.cardKey),
          matching: find.text(_l10n.mediaLinkedSuccess),
        ),
        findsOne,
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a failed link shows the translated message, not the '
        'exception', (tester) async {
      documents.error = StateError('no such encounter enc-404');

      await link(tester, 'enc-404');

      expect(
        find.descendant(
          of: find.byKey(AppSnackBar.cardKey),
          matching: find.text(_l10n.linkMediaFailed),
        ),
        findsOne,
      );
      expect(find.textContaining('no such encounter'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('an empty encounter id links nothing', (tester) async {
      await link(tester, '   ');

      expect(documents.links, isEmpty);
      expect(find.byType(AlertDialog), findsOne);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
