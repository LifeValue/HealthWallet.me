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
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump();

    final names = tempFiles();
    expect(names, hasLength(1), reason: 'one file however often it rebuilds');
    expect(names.single, startsWith(TempFileSweeper.recordPreviewPrefix));

    await tester.pumpWidget(const SizedBox());
    // The delete starts under the test clock and does real file I/O.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    expect(tempFiles(), isEmpty);
  });
}
