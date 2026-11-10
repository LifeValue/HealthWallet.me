import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/utils/validator.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_observation.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/model_not_found_exception.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extraction_service.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extractor_registry.dart';
import 'package:health_wallet/features/processing/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/widgets/processing_mapping_section.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/widgets/resources_form.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _en = lookupAppLocalizations(const Locale('en'));
final _de = lookupAppLocalizations(const Locale('de'));
final _ro = lookupAppLocalizations(const Locale('ro'));

Widget _app(Locale locale, Widget child) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// Answers only `checkModelExistence`; the activation path reads nothing else.
class _FakeProcessingRepository extends Fake implements ProcessingRepository {
  _FakeProcessingRepository({required this.modelExists});

  final bool modelExists;

  @override
  Future<bool> checkModelExistence() async => modelExists;
}

/// Prepares the page images of a session, or throws [error].
class _FakeOcrProcessingHelper extends Fake implements OcrProcessingHelper {
  _FakeOcrProcessingHelper({this.error});

  final Exception? error;

  @override
  Future<List<String>> prepareAllImages({
    required List<String> filePaths,
    double dpi = 72,
  }) async {
    if (error != null) throw error!;
    return filePaths;
  }
}

class _FakeSyncRepository extends Fake implements SyncRepository {}

class _FakeRecordsRepository extends Fake implements RecordsRepository {}

class _FakeDocumentReferenceService extends Fake
    implements DocumentReferenceService {}

class _FakeHolderSelection extends Fake implements HolderSelection {}

class _FakeHolderService extends Fake implements HolderService {}

Future<ProcessingBloc> _bloc({
  required bool modelExists,
  Exception? prepareError,
}) async {
  SharedPreferences.setMockInitialValues({});
  final ocr = _FakeOcrProcessingHelper(error: prepareError);
  return ProcessingBloc(
    _FakeProcessingRepository(modelExists: modelExists),
    ocr,
    _FakeSyncRepository(),
    _FakeDocumentReferenceService(),
    _FakeHolderService(),
    _FakeHolderSelection(),
    _FakeRecordsRepository(),
    await SharedPreferences.getInstance(),
    AppStringsProvider(),
    LayoutExtractionService(
      _FakeProcessingRepository(modelExists: modelExists),
      ocr,
      LayoutExtractorRegistry(const []),
      _FakeHolderService(),
      _FakeRecordsRepository(),
    ),
  );
}

/// Activates one pending session and returns the failure it ends in.
Future<Failure> _activatePendingSession(ProcessingBloc bloc) async {
  const session = ProcessingSession(
    id: 's1',
    filePaths: ['/tmp/page-1.jpg'],
  );
  // ignore: invalid_use_of_visible_for_testing_member
  bloc.emit(const ProcessingState(sessions: [session]));
  final failure = bloc.stream
      .map((state) => state.status)
      .firstWhere((status) => status is Failure)
      .then((status) => status as Failure);
  bloc.add(const SessionActivated(sessionId: 's1'));
  return failure;
}

void main() {
  group('model not found is a typed failure', () {
    test(
      'a missing model fails the activated session as modelNotFound',
      () async {
        final bloc = await _bloc(modelExists: false);
        addTearDown(bloc.close);

        final status = await _activatePendingSession(bloc);

        expect(status.reason, PipelineFailureReason.modelNotFound);
      },
    );

    test(
      'a step throwing ModelNotFoundException fails as modelNotFound',
      () async {
        final bloc = await _bloc(
          modelExists: true,
          prepareError: const ModelNotFoundException('/m.gguf'),
        );
        addTearDown(bloc.close);

        final status = await _activatePendingSession(bloc);

        expect(status.reason, PipelineFailureReason.modelNotFound);
      },
    );

    test('the English text keeps "Model file not found" for the desktop', () {
      expect(
        const ModelNotFoundException().toString(),
        contains('Model file not found'),
      );
      expect(
        const ModelNotFoundException('/p').toString(),
        allOf(contains('Model file not found'), contains('/p')),
      );
    });

    test('a ModelNotFoundException maps to modelNotFound', () {
      expect(
        PipelineFailureReason.of(const ModelNotFoundException('/m.gguf')),
        PipelineFailureReason.modelNotFound,
      );
      expect(
        PipelineFailureReason.of(Exception('Model file not found')),
        PipelineFailureReason.other,
      );
    });

    testWidgets('shows the localized no-model failure in ro', (tester) async {
      getIt.registerSingleton<AppPlatform>(AppPlatform.mobile);
      addTearDown(() => getIt.unregister<AppPlatform>());

      await tester.pumpWidget(
        _app(
          const Locale('ro'),
          ProcessingMappingSection(
            state: const ProcessingState(
              status: PipelineStatus.failure(
                error: 'any text',
                reason: PipelineFailureReason.modelNotFound,
              ),
            ),
            displayedSession: const ProcessingSession(id: 's'),
            sessionId: 's',
            onShowAiSettings: () {},
            onRetryStep1: () {},
            onRetryStep2: () {},
            onCancel: () {},
            checkModelExistence: () async => false,
            onAttachWithoutProcessing: () {},
          ),
        ),
      );

      expect(_ro.noAiModel, isNot(_en.noAiModel));
      expect(find.text(_ro.noAiModel), findsOneWidget);
      expect(find.text(_ro.modelNotFoundError), findsOneWidget);
      expect(find.text(_ro.attachWithoutProcessing), findsOneWidget);
      expect(find.text(_ro.retry), findsNothing);
    });
  });

  group('empty field is a typed validation error', () {
    test('validators return typed errors with localized messages', () {
      expect(nonEmptyValidator(''), FieldValidationError.empty);
      expect(nonEmptyValidator(null), FieldValidationError.empty);
      expect(nonEmptyValidator('x'), isNull);
      expect(dateValidator('not a date'), FieldValidationError.invalidDate);
      expect(dateValidator('2024-01-02'), isNull);
      expect(
        FieldValidationError.empty.message(_ro),
        _ro.fieldCannotBeEmpty,
      );
      expect(_ro.fieldCannotBeEmpty, isNot(_en.fieldCannotBeEmpty));
    });

    testWidgets('the review form shows ro errors and labels', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _app(
          const Locale('ro'),
          ResourcesForm(
            resources: const [],
            sessionId: 's',
            formKey: formKey,
            encounter: StagedEncounter(
              draft: MappingEncounter.empty(),
              mode: ImportMode.createNew,
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pump();

      // Encounter name (text), start date (date) and specialty (dropdown).
      expect(find.text(_ro.fieldCannotBeEmpty), findsNWidgets(3));
      expect(find.text(_en.fieldCannotBeEmpty), findsNothing);
      expect(find.text(_ro.encounterLabel), findsOneWidget);
      expect(find.text(_ro.labelEncounterName), findsOneWidget);
      expect(find.text(_ro.labelStartDate), findsOneWidget);
    });
  });

  group('processing labels in de', () {
    test('field descriptors and resource labels are German', () {
      final encounter = MappingEncounter.empty();
      final fields = encounter.getFieldDescriptors(_de);
      expect(fields['encounterType']!.label, _de.labelEncounterName);
      expect(fields['periodStart']!.label, _de.labelStartDate);
      expect(_de.labelEncounterName, isNot(_en.labelEncounterName));
      expect(encounter.localizedLabel(_de), _de.encounterLabel);

      final observation = MappingObservation.empty();
      expect(observation.localizedLabel(_de), _de.observation);
      expect(
        observation.getFieldDescriptors(_de)['referenceRange']!.label,
        _de.labelReferenceRange,
      );
    });

    test('generic identifier label is localized, national ones are not', () {
      const generic = MappingPatient(identifierLabel: 'Identifier');
      const cnp = MappingPatient(identifierLabel: 'CNP');
      expect(
        generic.getFieldDescriptors(_de)['patientIdentifier']!.label,
        _de.labelIdentifier,
      );
      expect(cnp.getFieldDescriptors(_de)['patientIdentifier']!.label, 'CNP');
      const passport = MappingPatient(identifierLabel: 'Passport');
      expect(
        passport.getFieldDescriptors(_de)['patientIdentifier']!.label,
        _de.identifierPassport,
      );
      expect(_de.identifierPassport, isNot('Passport'));
    });

    test('confidence and status names are German', () {
      expect(ConfidenceLevel.low.localizedName(_de), _de.confidenceLow);
      expect(_de.confidenceLow, isNot(_en.confidenceLow));
      expect(ConfidenceLevel.high.localizedName(_de), isEmpty);
    });
  });
}
