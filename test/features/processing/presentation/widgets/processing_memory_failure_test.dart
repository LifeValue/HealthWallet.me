import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/widgets/processing_mapping_section.dart';

void main() {
  tearDown(getIt.reset);

  for (final platform in AppPlatform.values) {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('out of memory on ${platform.name} in '
          '${locale.languageCode} shows the memory message with Retry only', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(locale);
        final calls = <String>[];
        getIt.registerSingleton<AppPlatform>(platform);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProcessingMappingSection(
                  state: const ProcessingState(
                    status: PipelineStatus.failure(
                      error:
                          'Exception: Not enough memory to load the AI '
                          'model. Available: 1MB',
                      reason: PipelineFailureReason.notEnoughMemory,
                    ),
                  ),
                  displayedSession: const ProcessingSession(id: 's'),
                  sessionId: 's',
                  onShowAiSettings: () => calls.add('settings'),
                  onRetryStep1: () => calls.add('retry1'),
                  onRetryStep2: () => calls.add('retry2'),
                  onCancel: () => calls.add('cancel'),
                  checkModelExistence: () async => true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text(l10n.processingFailedMemory), findsOneWidget);
        expect(find.text(l10n.processingFailedCapacity), findsNothing);
        expect(find.text(l10n.increaseAiModelCapacity), findsNothing);
        expect(find.textContaining('Not enough memory'), findsNothing);
        await tester.tap(find.text(l10n.retry));
        expect(calls, ['retry1']);
      });
    }
  }
}
