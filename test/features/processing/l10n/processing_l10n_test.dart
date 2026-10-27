import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/utils/validator.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_observation.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/model_not_found_exception.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/widgets/processing_mapping_section.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/widgets/resources_form.dart';

final _en = lookupAppLocalizations(const Locale('en'));
final _de = lookupAppLocalizations(const Locale('de'));
final _ro = lookupAppLocalizations(const Locale('ro'));

Widget _app(Locale locale, Widget child) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('model not found is a typed failure', () {
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
    });

    test('confidence and status names are German', () {
      expect(ConfidenceLevel.low.localizedName(_de), _de.confidenceLow);
      expect(_de.confidenceLow, isNot(_en.confidenceLow));
      expect(ConfidenceLevel.high.localizedName(_de), isEmpty);
    });
  });
}
