import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/services/pdf_preview_service.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';

import '../../features/share_records/share_test_helpers.dart';
import '../../fixtures/fhir/fhir_fixtures.dart';

/// A 1×1 transparent PNG.
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory('${mockPathProvider().path}/tmp');
  });

  List<String> tempFiles() => [
    for (final f in tmp.listSync()) f.uri.pathSegments.last,
  ];

  testWidgets('an inline Media image is viewed from a temp file that is '
      'deleted when the viewer closes', (tester) async {
    final media = entityFromJson({
      'resourceType': 'Media',
      'id': 'm1',
      'status': 'completed',
      'content': {'contentType': 'image/png', 'data': _png},
    });
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );

    late Future<void> viewing;
    await tester.runAsync(() async {
      viewing = PdfPreviewService(PathResolver()).previewInApp(context, media);
      // The file is written with real I/O, as fast as the machine allows.
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while ((tempFiles().isEmpty || !Navigator.of(context).canPop()) &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();

    final names = tempFiles();
    expect(names, hasLength(1));
    expect(names.single, startsWith(TempFileSweeper.recordPreviewPrefix));
    expect(names.single, endsWith('.png'));

    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await tester.runAsync(() => viewing);

    expect(tempFiles(), isEmpty);
  });
}
