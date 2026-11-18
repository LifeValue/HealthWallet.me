import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/external_files_service.dart';
import 'package:health_wallet/features/capture/import/presentation/pages/import_page.dart';
import 'package:health_wallet/features/dashboard/presentation/dashboard_page.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';
import 'package:health_wallet/features/desktop/handover/presentation/bloc/handover_bloc.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';

class _MockProcessingBloc extends MockBloc<ProcessingEvent, ProcessingState>
    implements ProcessingBloc {}

class _MockSyncBloc extends MockBloc<SyncEvent, SyncState>
    implements SyncBloc {}

class _MockHandoverBloc extends MockBloc<HandoverEvent, HandoverState>
    implements HandoverBloc {}

/// Opens the dashboard on [page], so only that page is built.
class _NavigationController extends Fake
    implements PageViewNavigationController {
  _NavigationController(int page)
    : pageController = PageController(initialPage: page),
      currentPageNotifier = ValueNotifier(page);

  @override
  final PageController pageController;

  @override
  final ValueNotifier<int> currentPageNotifier;

  @override
  final ValueNotifier<bool> swipeEnabledNotifier = ValueNotifier(true);

  @override
  int get currentPage => currentPageNotifier.value;
}

void main() {
  late _MockProcessingBloc processingBloc;
  late _MockSyncBloc syncBloc;

  setUp(() {
    processingBloc = _MockProcessingBloc();
    syncBloc = _MockSyncBloc();
    whenListen(
      processingBloc,
      const Stream<ProcessingState>.empty(),
      initialState: const ProcessingState(),
    );
    whenListen(
      syncBloc,
      const Stream<SyncState>.empty(),
      initialState: const SyncState(),
    );
    getIt
      ..registerSingleton<ExternalFilesService>(ExternalFilesService())
      ..registerSingleton<ProcessingBloc>(processingBloc);
  });

  tearDown(getIt.reset);

  Future<void> pumpDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ProcessingBloc>.value(value: processingBloc),
          BlocProvider<SyncBloc>.value(value: syncBloc),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DashboardPage(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('on the phone, the dashboard opens without the desktop\'s '
      'handover', (tester) async {
    getIt
      ..registerSingleton<AppPlatform>(AppPlatform.mobile)
      // The import page is the last of the phone's four pages.
      ..registerSingleton<PageViewNavigationController>(
        _NavigationController(3),
      );

    await pumpDashboard(tester);

    expect(find.byType(ImportPage), findsOne);
  });

  testWidgets('on the desktop, the dashboard opens with the handover bloc', (
    tester,
  ) async {
    final handoverBloc = _MockHandoverBloc();
    whenListen(
      handoverBloc,
      const Stream<HandoverState>.empty(),
      initialState: HandoverState.initial(),
    );
    getIt
      ..registerSingleton<AppPlatform>(AppPlatform.desktop)
      // The import page is the last of the desktop's three pages.
      ..registerSingleton<PageViewNavigationController>(
        _NavigationController(2),
      )
      ..registerSingleton<HandoverBloc>(handoverBloc);

    await pumpDashboard(tester);

    expect(find.byType(ImportPage), findsOne);
  });
}
