import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/widgets/resources_form.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';

class _MockUserBloc extends MockBloc<UserEvent, UserState>
    implements UserBloc {}

/// Records the events the form sends instead of running them.
class _MockProcessingBloc extends MockBloc<ProcessingEvent, ProcessingState>
    implements ProcessingBloc {
  final added = <ProcessingEvent>[];

  @override
  void add(ProcessingEvent event) => added.add(event);
}

void main() {
  setUpAll(initializeDateFormatting);
  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<_MockProcessingBloc> pump(
    WidgetTester tester,
    ResourcesForm form,
  ) async {
    final userBloc = _MockUserBloc();
    whenListen(
      userBloc,
      const Stream<UserState>.empty(),
      initialState: const UserState(),
    );
    final processingBloc = _MockProcessingBloc();
    whenListen(
      processingBloc,
      const Stream<ProcessingState>.empty(),
      initialState: const ProcessingState(),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<UserBloc>.value(value: userBloc),
            BlocProvider<ProcessingBloc>.value(value: processingBloc),
          ],
          child: Scaffold(body: SingleChildScrollView(child: form)),
        ),
      ),
    );
    return processingBloc;
  }

  ResourcesForm formWith(StagedPatient patient) => ResourcesForm(
    resources: const [],
    sessionId: 's',
    formKey: GlobalKey<FormState>(),
    patient: patient,
  );

  group('patient note', () {
    testWidgets('a patient the AI did not find says so, with empty fields to '
        'fill in', (tester) async {
      await pump(
        tester,
        formWith(
          StagedPatient(
            draft: MappingPatient.empty(),
            mode: ImportMode.createNew,
          ),
        ),
      );

      expect(find.text(l10n.processingNoPatientFound), findsOne);
      expect(find.textContaining(l10n.newPatient), findsNothing);
      final names = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((f) => f.controller?.text ?? '');
      expect(names, isNotEmpty);
      expect(names.every((text) => text.isEmpty), isTrue);
    });

    testWidgets('a new patient with a name is announced by name', (
      tester,
    ) async {
      await pump(
        tester,
        formWith(
          const StagedPatient(
            draft: MappingPatient(
              id: 'p',
              givenName: MappedProperty(value: 'Ana'),
              familyName: MappedProperty(value: 'Pop'),
            ),
            mode: ImportMode.createNew,
          ),
        ),
      );

      expect(find.text('${l10n.newPatient}: Ana Pop'), findsOne);
      expect(find.text(l10n.processingNoPatientFound), findsNothing);
    });

    testWidgets('a new patient known only by an identifier is not "no '
        'patient found"', (tester) async {
      await pump(
        tester,
        formWith(
          const StagedPatient(
            draft: MappingPatient(
              id: 'p',
              patientIdentifier: MappedProperty(value: '1850101123456'),
            ),
            mode: ImportMode.createNew,
          ),
        ),
      );

      expect(find.text(l10n.newPatient), findsOne);
      expect(find.text(l10n.processingNoPatientFound), findsNothing);
    });
  });
}
