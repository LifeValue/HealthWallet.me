import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/widgets/media_fullscreen_viewer.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';
import '../../../share_records/share_test_helpers.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory('${mockPathProvider().path}/tmp');
  });

  List<String> tempFiles() => [
    for (final f in tmp.listSync()) f.uri.pathSegments.last,
  ];

  /// Pumps until [condition] holds. The file I/O is real and takes as long
  /// as the machine needs, so both the real and the test clock move on.
  Future<void> pumpUntil(WidgetTester tester, bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('the decoded PDF is written once and deleted when the viewer '
      'closes', (tester) async {
    final media = entityFromJson({
      'resourceType': 'Media',
      'id': 'm1',
      'status': 'completed',
      'content': {
        'contentType': 'application/pdf',
        // "%PDF-1.4"
        'data': 'JVBERi0xLjQ=',
        'title': 'Lab results 03/2024',
      },
    }) as Media;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaFullscreenViewer(media: media),
      ),
    );
    await pumpUntil(tester, () => tempFiles().isNotEmpty);
    await tester.pump();

    final names = tempFiles();
    expect(names, hasLength(1), reason: 'one file however often it rebuilds');
    expect(names.single, startsWith(TempFileSweeper.recordPreviewPrefix));

    await tester.pumpWidget(const SizedBox());
    await pumpUntil(tester, () => tempFiles().isEmpty);

    expect(tempFiles(), isEmpty);
  });
}
