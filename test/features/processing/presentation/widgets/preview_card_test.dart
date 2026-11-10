import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/capture/scan/presentation/pages/preview/bloc/preview_bloc.dart';
import 'package:health_wallet/features/processing/presentation/widgets/preview_card.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('hw_preview_card_'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  String writePage(String name) => (File(
    '${dir.path}/$name.png',
  )..writeAsBytesSync(img.encodePng(img.Image(width: 4, height: 2)))).path;

  PageController newController() {
    final controller = PageController();
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required List<String> imagePaths,
    required PageController controller,
    bool isEditable = false,
    void Function(List<String>)? onPagesChanged,
    PageRotatedCallback? onPageRotated,
    Locale? locale,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PreviewCard(
              imagePaths: imagePaths,
              pageController: controller,
              isEditable: isEditable,
              onPagesChanged: onPagesChanged,
              onPageRotated: onPageRotated,
            ),
          ),
        ),
      ),
    );
    // Whether each page exists is checked on the real file system.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  // A page that has just scrolled in shows a spinner until the real file
  // system says it exists, so pumpAndSettle would never settle: this runs
  // the page animations, lets the file checks finish, then lets the retries
  // the spinners scheduled run out.
  Future<void> settle(WidgetTester tester) async {
    final spinner = find.byType(CircularProgressIndicator);
    for (var i = 0; i < 4 || (i < 50 && spinner.evaluate().isNotEmpty); i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('shows nothing when there are no pages', (tester) async {
    await pumpCard(tester, imagePaths: const [], controller: newController());

    expect(find.byType(PageView), findsNothing);
    expect(find.byType(Card), findsNothing);
    expect(find.text('Preview document'), findsNothing);
  });

  testWidgets('the page counter reads "1 of 2" in English and follows the '
      'chevrons to the next and previous page', (tester) async {
    await pumpCard(
      tester,
      imagePaths: [writePage('a'), writePage('b')],
      controller: newController(),
    );

    expect(find.text('1 of 2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await settle(tester);
    expect(find.text('2 of 2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await settle(tester);
    expect(find.text('1 of 2'), findsOneWidget);
  });

  testWidgets('the page counter reads "1 din 2" in Romanian and changes '
      'when the page controller turns the page', (tester) async {
    final controller = newController();
    await pumpCard(
      tester,
      imagePaths: [writePage('a'), writePage('b')],
      controller: controller,
      locale: const Locale('ro'),
    );

    expect(find.text('1 din 2'), findsOneWidget);

    controller.jumpToPage(1);
    await settle(tester);
    expect(find.text('2 din 2'), findsOneWidget);
  });

  testWidgets('the chevrons do nothing past the first and the last page', (
    tester,
  ) async {
    final controller = newController();
    await pumpCard(
      tester,
      imagePaths: [writePage('a'), writePage('b')],
      controller: controller,
    );

    await tester.tap(find.byIcon(Icons.chevron_left));
    await settle(tester);
    expect(find.text('1 of 2'), findsOneWidget);
    expect(controller.page, 0);

    controller.jumpToPage(1);
    await settle(tester);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await settle(tester);
    expect(find.text('2 of 2'), findsOneWidget);
    expect(controller.page, 1);
  });

  testWidgets('turning a page in the full-screen preview reports its path '
      'and one quarter turn', (tester) async {
    final page = writePage('page');
    final turns = <(String, int)>[];

    await pumpCard(
      tester,
      imagePaths: [page],
      controller: newController(),
      isEditable: true,
      onPageRotated: (path, quarterTurns) => turns.add((path, quarterTurns)),
    );

    await tester.tap(find.byType(InkWell).first);
    await settle(tester);
    await tester.tap(find.byIcon(Icons.rotate_right));
    // The engine decodes and turns the page in real time; pumping lets the
    // bloc see each step.
    for (var i = 0; i < 100 && turns.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }

    expect(turns, [(page, 1)]);
  });

  testWidgets('the preview button opens the full-screen preview, and closing '
      'it unchanged reports no new pages', (tester) async {
    final changes = <List<String>>[];
    await pumpCard(
      tester,
      imagePaths: [writePage('a'), writePage('b')],
      controller: newController(),
      onPagesChanged: changes.add,
    );

    await tester.tap(find.text('Preview document'));
    await settle(tester);
    expect(find.byType(AppBar), findsOneWidget);

    await tester.pageBack();
    await settle(tester);

    expect(find.byType(AppBar), findsNothing);
    expect(changes, isEmpty);
  });

  testWidgets('deleting a page in the full-screen preview hands the pages '
      'left back when it closes', (tester) async {
    final first = writePage('a');
    final second = writePage('b');
    final changes = <List<String>>[];
    await pumpCard(
      tester,
      imagePaths: [first, second],
      controller: newController(),
      isEditable: true,
      onPagesChanged: changes.add,
    );

    await tester.tap(find.text('Preview document'));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await tester.tap(find.text('Delete').last);
    await settle(tester);
    await tester.pageBack();
    await settle(tester);

    expect(changes, [
      [second],
    ]);
  });

  testWidgets('swiping to another page in the full-screen preview turns the '
      'card to that page too', (tester) async {
    final controller = newController();
    await pumpCard(
      tester,
      imagePaths: [writePage('a'), writePage('b')],
      controller: controller,
    );

    await tester.tap(find.text('Preview document'));
    await settle(tester);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await settle(tester);
    expect(find.text('2 of 2'), findsOneWidget);

    await tester.pageBack();
    await settle(tester);

    expect(controller.page, 1);
    expect(find.text('2 of 2'), findsOneWidget);
  });

  testWidgets('a page that is not on disk shows a spinner, and keeps it '
      'once the retries run out', (
    tester,
  ) async {
    await pumpCard(
      tester,
      imagePaths: ['${dir.path}/missing.png'],
      controller: newController(),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
  });

  testWidgets('a page that cannot be decoded shows a spinner while it '
      'retries, then a broken-image icon', (tester) async {
    final broken = File('${dir.path}/broken.png')
      ..writeAsStringSync('not an image');
    await pumpCard(
      tester,
      imagePaths: [broken.path],
      controller: newController(),
    );

    // Reading and decoding the file happen in real time.
    final retrying = find.descendant(
      of: find.byType(Image),
      matching: find.byType(CircularProgressIndicator),
    );
    for (var i = 0; i < 100 && retrying.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(retrying, findsOneWidget);

    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }

    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
