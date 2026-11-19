import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/external_files_service.dart';
import 'package:health_wallet/features/capture/import/presentation/pages/import_page.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';

import '../../../../../helpers/log_capture.dart';

class _MockProcessingBloc extends MockBloc<ProcessingEvent, ProcessingState>
    implements ProcessingBloc {
  final added = <ProcessingEvent>[];

  @override
  void add(ProcessingEvent event) => added.add(event);
}

void main() {
  final logs = captureLogs();
  final en = lookupAppLocalizations(const Locale('en'));
  late ExternalFilesService externalFiles;
  late _MockProcessingBloc processingBloc;

  setUp(() async {
    await getIt.reset();
    externalFiles = ExternalFilesService();
    getIt
      ..registerSingleton<AppPlatform>(AppPlatform.mobile)
      ..registerSingleton(PageViewNavigationController())
      ..registerSingleton(externalFiles);
    processingBloc = _MockProcessingBloc();
    whenListen(
      processingBloc,
      const Stream<ProcessingState>.empty(),
      initialState: const ProcessingState(),
    );
  });

  tearDown(getIt.reset);

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<ProcessingBloc>.value(
          value: processingBloc,
          child: const ImportView(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the empty state with the import actions', (tester) async {
    await pumpPage(tester);

    expect(find.text(en.noImportsYet), findsOneWidget);
    expect(find.text(en.importDocument), findsOneWidget);
    expect(find.text(en.pickImageFromGallery), findsOneWidget);
    expect(find.text(en.scanDocument), findsOneWidget);
  });

  testWidgets('imports files shared to the app when it opens', (tester) async {
    externalFiles.addFilePaths(['/tmp/shared.pdf']);

    await pumpPage(tester);

    final imported = _imported(processingBloc);
    expect(imported, ['/tmp/shared.pdf']);
    expect(externalFiles.hasPendingFiles, isFalse);
  });

  testWidgets('a failing document picker is logged and shown', (tester) async {
    await pumpPage(tester);

    // No file picker plugin is registered in tests, so picking throws.
    await tester.tap(find.text(en.importDocument));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    expect(find.text(en.importFilesFailed), findsOneWidget);
    expect(logs, loggedWarning('Could not import the picked documents'));
  });

  testWidgets('a failing image picker is logged and shown', (tester) async {
    await pumpPage(tester);

    const channel = MethodChannel('plugins.flutter.io/image_picker');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'photo_access_denied');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.tap(find.text(en.pickImageFromGallery));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    expect(find.text(en.importFilesFailed), findsOneWidget);
    expect(logs, loggedWarning('Could not import the picked images'));
  });
}

List<String>? _imported(_MockProcessingBloc bloc) {
  final imported = bloc.added.whereType<DocumentImported>().toList();
  return imported.isEmpty ? null : imported.single.filePaths;
}
