import 'dart:io';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/capture/scan/presentation/pages/preview/bloc/preview_bloc.dart';
import 'package:health_wallet/features/capture/scan/presentation/pages/preview/image_preview_page.dart';

import '../../../../../../helpers/log_capture.dart';

class _MockPreviewBloc extends MockBloc<PreviewEvent, PreviewState>
    implements PreviewBloc {
  @override
  void add(PreviewEvent event) {}
}

/// Makes reading the size of [path] fail.
final class _UnstatableFile extends IOOverrides {
  _UnstatableFile(this.path);

  final String path;

  @override
  FileStat statSync(String path) => path == this.path
      ? throw FileSystemException('Cannot stat', path)
      : super.statSync(path);
}

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  final logs = captureLogs();
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('hw_image_preview_'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<void> pumpPage(WidgetTester tester, String path) async {
    final bloc = _MockPreviewBloc();
    whenListen(
      bloc,
      const Stream<PreviewState>.empty(),
      initialState: PreviewState(images: [path]),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<PreviewBloc>.value(
          value: bloc,
          child: ImagePreviewPage(imagePath: path),
        ),
      ),
    );
  }

  testWidgets('an empty file says so', (tester) async {
    final file = File('${dir.path}/empty.png')..createSync();

    await pumpPage(tester, file.path);

    expect(find.text(_en.fileIsEmpty), findsOne);
  });

  testWidgets('a file whose size cannot be read is still shown, and the '
      'failure is logged', (tester) async {
    final file = File('${dir.path}/page.png')..writeAsBytesSync([1, 2, 3]);

    // The page builds during the pump, inside this zone.
    await IOOverrides.runWithIOOverrides(
      () => pumpPage(tester, file.path),
      _UnstatableFile(file.path),
    );

    expect(find.byType(InteractiveViewer), findsOne);
    expect(find.text(_en.fileIsEmpty), findsNothing);
    expect(logs, loggedWarning('Could not read the size of the preview image'));
  });
}
