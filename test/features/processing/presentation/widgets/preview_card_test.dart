import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/processing/presentation/widgets/preview_card.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('hw_preview_card_'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  testWidgets('turning a page in the full-screen preview reports its path '
      'and one quarter turn', (tester) async {
    final page = File('${dir.path}/page.png')
      ..writeAsBytesSync(img.encodePng(img.Image(width: 4, height: 2)));
    final turns = <(String, int)>[];
    final controller = PageController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PreviewCard(
              imagePaths: [page.path],
              pageController: controller,
              isEditable: true,
              onPageRotated: (path, quarterTurns) =>
                  turns.add((path, quarterTurns)),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.rotate_right));
    // The engine decodes and turns the page in real time; pumping lets the
    // bloc see each step.
    for (var i = 0; i < 100 && turns.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }

    expect(turns, [(page.path, 1)]);
  });
}
