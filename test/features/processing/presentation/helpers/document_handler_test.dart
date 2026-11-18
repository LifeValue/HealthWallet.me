import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extraction_service.dart';
import 'package:health_wallet/features/processing/presentation/helpers/document_handler.dart';

/// Says whether a session can be read now, or fails to say.
class _FakeLayoutExtractionService extends Fake
    implements LayoutExtractionService {
  bool canProcessResult = false;
  Exception? error;

  @override
  Future<bool> canProcess(
    String sessionId, {
    required List<String> filePaths,
    List<String>? imagePaths,
  }) async {
    if (error != null) throw error!;
    return canProcessResult;
  }
}

/// Records the routes pushed; the AI model page answers with [modelPage].
class _FakeStackRouter extends Fake implements StackRouter {
  final pushed = <PageRouteInfo>[];
  bool? modelPage;

  @override
  Future<T?> push<T extends Object?>(
    PageRouteInfo route, {
    OnNavigationFailure? onFailure,
  }) async {
    pushed.add(route);
    return route is LoadModelRoute ? modelPage as T? : null;
  }
}

class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with DocumentHandler {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  const session = ProcessingSession(id: 's1', filePaths: ['/doc.pdf']);
  late _FakeLayoutExtractionService layout;
  late _FakeStackRouter router;

  setUp(() {
    layout = _FakeLayoutExtractionService();
    router = _FakeStackRouter();
    getIt.registerSingleton<LayoutExtractionService>(layout);
  });

  tearDown(getIt.reset);

  Future<_HostState> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: const _Host(),
        ),
      ),
    );
    return tester.state<_HostState>(find.byType(_Host));
  }

  ProcessingRouteArgs? processingArgs() =>
      router.pushed.whereType<ProcessingRoute>().singleOrNull?.args;

  group('an imported document', () {
    testWidgets('that can be read now opens the processing screen', (
      tester,
    ) async {
      layout.canProcessResult = true;
      final host = await pumpHost(tester);

      await host.navigateToFhirMapper(host.context, session);
      await tester.pump();

      expect(router.pushed, hasLength(1));
      expect(processingArgs()?.sessionId, 's1');
      expect(processingArgs()?.attachOnly, isFalse);
    });

    testWidgets('without a model asks about the AI first', (tester) async {
      final host = await pumpHost(tester);

      await host.navigateToFhirMapper(host.context, session);
      await tester.pump();

      final modelPage = router.pushed.first as LoadModelRoute;
      expect(modelPage.args?.canAttachToEncounter, isTrue);
      expect(modelPage.args?.sessionId, 's1');
    });

    testWidgets('a failed check says so', (tester) async {
      layout.error = Exception('unreadable');
      final host = await pumpHost(tester);

      await host.navigateToFhirMapper(host.context, session);
      await tester.pumpAndSettle();

      expect(router.pushed, isEmpty);
      expect(find.text(_en.errorTitle), findsOne);
    });
  });

  group('after the AI model page', () {
    Future<void> answer(WidgetTester tester, bool? choice) async {
      router.modelPage = choice;
      final host = await pumpHost(tester);
      await host.navigateToLoadModel(host.context, session);
      await tester.pump();
    }

    testWidgets('a downloaded model reads the document', (tester) async {
      await answer(tester, true);

      expect(processingArgs()?.sessionId, 's1');
      expect(processingArgs()?.attachOnly, isFalse);
    });

    testWidgets('attaching without the AI shows the pages to attach', (
      tester,
    ) async {
      await answer(tester, false);

      expect(processingArgs()?.sessionId, 's1');
      expect(processingArgs()?.attachOnly, isTrue);
    });

    testWidgets('leaving the page opens nothing', (tester) async {
      await answer(tester, null);

      expect(router.pushed.single, isA<LoadModelRoute>());
    });
  });
}
