import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extraction_service.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extractor_registry.dart';
import 'package:health_wallet/features/processing/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/widgets/capture_error_listener.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fake_device_capability_service.dart';

class _FakeProcessingRepository extends Fake implements ProcessingRepository {}

class _FakeOcrProcessingHelper extends Fake implements OcrProcessingHelper {}

class _FakeSyncRepository extends Fake implements SyncRepository {}

class _FakeRecordsRepository extends Fake implements RecordsRepository {}

class _FakeDocumentReferenceService extends Fake
    implements DocumentReferenceService {}

class _FakeHolderSelection extends Fake implements HolderSelection {}

class _FakeHolderService extends Fake implements HolderService {}

void main() {
  final ro = lookupAppLocalizations(const Locale('ro'));
  late ProcessingBloc bloc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final ocr = _FakeOcrProcessingHelper();
    bloc = ProcessingBloc(
      _FakeProcessingRepository(),
      ocr,
      _FakeSyncRepository(),
      _FakeDocumentReferenceService(),
      _FakeHolderService(),
      _FakeHolderSelection(),
      _FakeRecordsRepository(),
      await SharedPreferences.getInstance(),
      AppStringsProvider.forLocale(const Locale('ro')),
      LayoutExtractionService(
        _FakeProcessingRepository(),
        ocr,
        LayoutExtractorRegistry(const []),
        _FakeHolderService(),
        _FakeRecordsRepository(),
      ),
      FakeDeviceCapabilityService(),
    );
  });

  tearDown(() => bloc.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: MaterialApp(
          locale: const Locale('ro'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => CaptureErrorListener(child: child!),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
  }

  // Emitting directly drives the listener without running a scan.
  Future<void> emit(WidgetTester tester, PipelineStatus status) async {
    // ignore: invalid_use_of_visible_for_testing_member
    bloc.emit(bloc.state.copyWith(status: status));
    await tester.pump();
    await tester.pump();
  }

  final shown = {
    PipelineFailureReason.scanFailed: ro.scanFailed,
    PipelineFailureReason.importFailed: ro.importDocumentFailed,
    PipelineFailureReason.noValidFiles: ro.noValidFilesFound,
  };
  shown.forEach((reason, text) {
    testWidgets('${reason.name} is shown translated', (tester) async {
      await pump(tester);

      await emit(
        tester,
        PipelineStatus.failure(error: 'Scan failed: secret', reason: reason),
      );

      expect(find.text(text), findsOneWidget);
      expect(find.textContaining('secret'), findsNothing);
    });
  });

  testWidgets('session failures are left to the processing page', (
    tester,
  ) async {
    await pump(tester);

    for (final reason in [
      PipelineFailureReason.other,
      PipelineFailureReason.modelNotFound,
      PipelineFailureReason.noImagesGenerated,
    ]) {
      await emit(tester, const PipelineStatus.loading());
      await emit(tester, PipelineStatus.failure(error: 'x', reason: reason));
    }

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('other states show nothing', (tester) async {
    await pump(tester);

    await emit(tester, const PipelineStatus.loading());
    await emit(tester, const PipelineStatus.success());

    expect(find.byType(SnackBar), findsNothing);
  });
}
