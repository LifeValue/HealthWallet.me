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
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/widgets/media_fullscreen_viewer.dart';

import '../../../desktop/lww_sync/lww_sync_test_helpers.dart' show TestDirs;

final _l10n = lookupAppLocalizations(const Locale('en'));

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
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaFullscreenViewer(media: media),
        ),
      );
      // The PDF is written to a temporary file first.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
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
}
