import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/services/pdf_preview_service.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';

import '../../features/share_records/share_test_helpers.dart';
import '../../fixtures/fhir/fhir_fixtures.dart';
import '../../helpers/log_capture.dart';

/// A 1×1 transparent PNG.
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

/// A record preview that is written like any file but cannot be
/// deleted, as when the system holds it open.
class _UndeletableFile extends Fake implements File {
  _UndeletableFile(this._file);

  final File _file;

  @override
  String get path => _file.path;

  @override
  Future<bool> exists() => _file.exists();

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) => _file.writeAsBytes(bytes, mode: mode, flush: flush);

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async =>
      throw FileSystemException('Operation not permitted', path);
}

/// Makes every record preview undeletable.
final class _UndeletablePreviews extends IOOverrides {
  @override
  File createFile(String path) {
    final file = super.createFile(path);
    final name = path.split('/').last;
    return name.startsWith(TempFileSweeper.recordPreviewPrefix)
        ? _UndeletableFile(file)
        : file;
  }
}

void main() {
  final logs = captureLogs();
  late Directory tmp;

  setUp(() {
    tmp = Directory('${mockPathProvider().path}/tmp');
  });

  List<String> tempFiles() => [
    for (final f in tmp.listSync()) f.uri.pathSegments.last,
  ];

  /// Shows a page and returns its context, for the service to push onto.
  Future<BuildContext> showPage(WidgetTester tester) async {
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
    return context;
  }

  /// Runs [start] with real I/O and waits until the viewer is open with
  /// its temp file written.
  Future<void> openViewer(
    WidgetTester tester,
    BuildContext context,
    void Function() start,
  ) async {
    await tester.runAsync(() async {
      start();
      // The file is written with real I/O, as fast as the machine allows.
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while ((tempFiles().isEmpty || !Navigator.of(context).canPop()) &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
  }

  testWidgets('an inline Media image is viewed from a temp file that is '
      'deleted when the viewer closes', (tester) async {
    final media = entityFromJson({
      'resourceType': 'Media',
      'id': 'm1',
      'status': 'completed',
      'content': {'contentType': 'image/png', 'data': _png},
    });
    final context = await showPage(tester);

    late Future<void> viewing;
    await openViewer(
      tester,
      context,
      () => viewing = PdfPreviewService(
        PathResolver(),
      ).previewInApp(context, media),
    );

    final names = tempFiles();
    expect(names, hasLength(1));
    expect(names.single, startsWith(TempFileSweeper.recordPreviewPrefix));
    expect(names.single, endsWith('.png'));

    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await tester.runAsync(() => viewing);

    expect(tempFiles(), isEmpty);
  });

  testWidgets('a preview that cannot be deleted when the viewer closes is '
      'logged and left for the startup sweep', (tester) async {
    final media = entityFromJson({
      'resourceType': 'Media',
      'id': 'm1',
      'status': 'completed',
      'content': {'contentType': 'image/png', 'data': _png},
    });
    final context = await showPage(tester);

    late Future<void> viewing;
    await openViewer(
      tester,
      context,
      () => viewing = IOOverrides.runWithIOOverrides(
        () => PdfPreviewService(PathResolver()).previewInApp(context, media),
        _UndeletablePreviews(),
      ),
    );
    expect(tempFiles(), hasLength(1));

    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await tester.runAsync(() => viewing);

    expect(tempFiles(), hasLength(1));
    expect(logs, loggedWarning('Deleting a record preview failed'));
  });
}
