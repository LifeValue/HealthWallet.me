import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/core/utils/date_format_utils.dart';
import 'package:health_wallet/core/widgets/app_dropdown_field.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_condition.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_identifier.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/widgets/resources_form.dart';
import 'package:health_wallet/features/processing/presentation/widgets/attach_to_encounter/attach_to_encounter_widget.dart';
import 'package:health_wallet/features/processing/presentation/widgets/attach_to_encounter/bloc/attach_to_encounter_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';

class _MockUserBloc extends MockBloc<UserEvent, UserState>
    implements UserBloc {}

/// Opens with a patient and an encounter already picked, so its confirm
/// button returns them.
class _MockAttachToEncounterBloc
    extends MockBloc<AttachToEncounterEvent, AttachToEncounterState>
    implements AttachToEncounterBloc {
  @override
  void add(AttachToEncounterEvent event) {}
}

const _picked = (
  StagedPatient(draft: MappingPatient(id: 'p-picked')),
  StagedEncounter(draft: MappingEncounter(id: 'e-picked')),
);

const _named = MappingPatient(
  id: 'p1',
  givenName: MappedProperty(value: 'Ana', confidenceLevel: 1),
  familyName: MappedProperty(value: 'Pop', confidenceLevel: 1),
  dateOfBirth: MappedProperty(value: '1980-02-03', confidenceLevel: 1),
  gender: MappedProperty(value: 'female', confidenceLevel: 1),
);

const _visit = MappingEncounter(
  id: 'e1',
  encounterType: MappedProperty(value: 'Checkup', confidenceLevel: 1),
  periodStart: MappedProperty(value: '2024-03-01', confidenceLevel: 1),
  specialty: MappedProperty(value: 'Cardiology', confidenceLevel: 1),
);

const _report = MappingDiagnosticReport(
  id: 'r1',
  reportName: MappedProperty(value: 'Labs', confidenceLevel: 1),
  issuedDate: MappedProperty(value: '2024-03-01', confidenceLevel: 1),
);

const _condition = MappingCondition(
  id: 'c1',
  conditionName: MappedProperty(value: 'Anemia', confidenceLevel: 1),
);

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

  setUp(() {
    final attachBloc = _MockAttachToEncounterBloc();
    whenListen(
      attachBloc,
      const Stream<AttachToEncounterState>.empty(),
      initialState: AttachToEncounterState(
        status: AttachToEncounterStatus.success,
        patient: _picked.$1,
        encounter: _picked.$2,
      ),
    );
    getIt.registerFactory<AttachToEncounterBloc>(() => attachBloc);
  });

  tearDown(getIt.reset);

  Future<_MockProcessingBloc> pump(
    WidgetTester tester,
    ResourcesForm form, {
    ThemeData? theme,
  }) async {
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
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
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

  ResourcesForm form({
    StagedPatient? patient,
    StagedEncounter? encounter,
    StagedDiagnosticReport? report,
    List<MappingResource> resources = const [],
    bool locked = false,
    GlobalKey<FormState>? formKey,
  }) => ResourcesForm(
    resources: resources,
    sessionId: 's',
    formKey: formKey ?? GlobalKey<FormState>(),
    patient: patient,
    encounter: encounter,
    diagnosticReport: report,
    isAttachmentLocked: locked,
  );

  /// The card's icon action: attach for a staged record, delete for another.
  Finder iconButton() => find.byWidgetPredicate(
    (w) => w is GestureDetector && w.child is SvgPicture,
  );

  /// The date field showing [iso].
  Finder dateField(String iso) => find.text(
    DateFormatUtils.formatIsoForDisplay(iso, const UserState().regionPreset),
  );

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('editing', () {
    testWidgets('a patient field change edits the draft patient', (
      tester,
    ) async {
      final bloc = await pump(
        tester,
        form(
          patient: const StagedPatient(
            draft: _named,
            mode: ImportMode.createNew,
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'Ana'), 'Anna');

      expect(bloc.added, [
        const ResourceChanged(
          sessionId: 's',
          index: 0,
          propertyKey: 'givenName',
          newValue: 'Anna',
          isDraftPatient: true,
        ),
      ]);
    });

    testWidgets('a gender picked from the list is saved as its FHIR code', (
      tester,
    ) async {
      final bloc = await pump(
        tester,
        form(
          patient: const StagedPatient(
            draft: _named,
            mode: ImportMode.createNew,
          ),
        ),
      );

      for (final (label, code) in [
        (l10n.male, 'male'),
        (l10n.female, 'female'),
        (l10n.preferNotToSay, 'unknown'),
      ]) {
        await tap(tester, find.byType(AppDropdownField<String>));
        await tap(tester, find.text(label).last);
        expect(
          (bloc.added.last as ResourceChanged).newValue,
          code,
          reason: label,
        );
      }
    });

    testWidgets('a patient without a gender shows prefer not to say', (
      tester,
    ) async {
      await pump(
        tester,
        form(
          patient: StagedPatient(
            draft: _named.copyWith(gender: const MappedProperty()),
            mode: ImportMode.createNew,
          ),
        ),
      );

      expect(find.text(l10n.preferNotToSay), findsOne);
    });

    testWidgets('a date picked in the calendar is saved as an ISO date', (
      tester,
    ) async {
      final bloc = await pump(
        tester,
        form(
          patient: const StagedPatient(
            draft: _named,
            mode: ImportMode.createNew,
          ),
          encounter: const StagedEncounter(draft: _visit),
        ),
      );

      await tap(tester, dateField('1980-02-03'));
      await tap(tester, find.text('15'));
      await tap(tester, find.text('OK'));

      final change = bloc.added.whereType<ResourceChanged>().first;
      expect(change.propertyKey, 'dateOfBirth');
      expect(change.newValue, '1980-02-15');
    });

    testWidgets('saving the form sends a picked date again', (tester) async {
      final formKey = GlobalKey<FormState>();
      final bloc = await pump(
        tester,
        form(
          encounter: const StagedEncounter(draft: _visit),
          formKey: formKey,
        ),
      );
      await tap(tester, dateField('2024-03-01'));
      await tap(tester, find.text('15'));
      await tap(tester, find.text('OK'));

      formKey.currentState!.save();

      final changes = bloc.added.whereType<ResourceChanged>().toList();
      expect(changes, hasLength(2));
      expect(changes.map((c) => c.newValue), everyElement('2024-03-15'));
      expect(changes.last.isDraftEncounter, isTrue);
    });

    testWidgets('a cancelled calendar changes nothing', (tester) async {
      final bloc = await pump(
        tester,
        form(encounter: const StagedEncounter(draft: _visit)),
      );

      await tap(tester, dateField('2024-03-01'));
      await tap(tester, find.text('Cancel'));

      expect(bloc.added, isEmpty);
    });

    testWidgets('an encounter edit changes the draft encounter, and the '
        'container can be switched', (tester) async {
      final bloc = await pump(
        tester,
        form(encounter: const StagedEncounter(draft: _visit)),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Checkup'),
        'Consult',
      );
      await tap(tester, find.byIcon(Icons.swap_horiz));

      expect(bloc.added, [
        const ResourceChanged(
          sessionId: 's',
          index: 0,
          propertyKey: 'encounterType',
          newValue: 'Consult',
          isDraftEncounter: true,
        ),
        const ContainerTypeSwitched(sessionId: 's'),
      ]);
    });

    testWidgets('a specialty is picked from the list', (tester) async {
      final bloc = await pump(
        tester,
        form(
          encounter: StagedEncounter(
            draft: _visit.copyWith(specialty: const MappedProperty()),
          ),
        ),
      );
      expect(find.text(l10n.specialty), findsWidgets);

      await tap(tester, find.byType(AppDropdownField<MedicalSpecialty>));
      await tap(
        tester,
        find.text(MedicalSpecialty.cardiology.localizedName(l10n)).last,
      );

      final change = bloc.added.single as ResourceChanged;
      expect(change.propertyKey, 'specialty');
      expect(change.newValue, MedicalSpecialty.cardiology.displayName);
    });

    testWidgets('a specialty the app does not know is shown as it was '
        'read', (tester) async {
      await pump(
        tester,
        form(
          encounter: StagedEncounter(
            draft: _visit.copyWith(
              specialty: const MappedProperty(value: 'Podology'),
            ),
          ),
        ),
      );

      expect(find.text('Podology'), findsOne);
    });

    testWidgets('the specialty read is marked in the list', (tester) async {
      await pump(tester, form(encounter: const StagedEncounter(draft: _visit)));

      await tap(tester, find.byType(AppDropdownField<MedicalSpecialty>));

      final cardiology = MedicalSpecialty.cardiology.localizedName(l10n);
      expect(find.text(cardiology), findsWidgets);
    });

    testWidgets('icons take the text colour when the theme gives them '
        'none', (tester) async {
      await pump(
        tester,
        form(
          patient: const StagedPatient(
            draft: _named,
            mode: ImportMode.createNew,
          ),
          encounter: const StagedEncounter(draft: _visit),
          resources: const [_condition],
        ),
        theme: ThemeData(iconTheme: const IconThemeData()),
      );

      final swap = tester.widget<Icon>(find.byIcon(Icons.swap_horiz));
      expect(swap.color, isNotNull);
      expect(iconButton(), findsNWidgets(2));
    });

    testWidgets('a visit the document adds an identifier to is to be '
        'completed', (tester) async {
      const visitKey = MappingIdentifier(
        system: 'http://healthwallet.me/visit/clearvis.io',
        value: 'optica-exemplu-1|PA-01234|2024-03-14',
      );
      const serial = MappingIdentifier(
        system: 'http://healthwallet.me/serial',
        value: 'EE-1',
      );
      await pump(
        tester,
        form(
          encounter: StagedEncounter(
            draft: const MappingEncounter(
              id: 'e-draft',
              identifiers: [visitKey, serial],
            ),
            existing: Encounter(
              id: 'e9',
              title: 'Stored visit',
              rawResource: {
                'identifier': [visitKey.toJson()],
              },
            ),
            mode: ImportMode.linkExisting,
          ),
        ),
      );

      expect(find.text(l10n.stagedWillBeCompleted), findsOne);
    });

    testWidgets('a visit already in the wallet is shown as it is stored', (
      tester,
    ) async {
      await pump(
        tester,
        form(
          encounter: const StagedEncounter(
            existing: Encounter(id: 'e9', title: 'Stored visit'),
            mode: ImportMode.linkExisting,
          ),
        ),
      );

      expect(find.widgetWithText(TextFormField, 'Stored visit'), findsOne);
    });

    testWidgets('a report edit changes the draft report', (tester) async {
      final bloc = await pump(
        tester,
        form(report: const StagedDiagnosticReport(draft: _report)),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Labs'),
        'Blood count',
      );

      expect(bloc.added, [
        const ResourceChanged(
          sessionId: 's',
          index: 0,
          propertyKey: 'reportName',
          newValue: 'Blood count',
          isDraftDiagnosticReport: true,
        ),
      ]);
    });

    testWidgets('another record is edited by its index and removed after '
        'confirming', (tester) async {
      final bloc = await pump(tester, form(resources: const [_condition]));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Anemia'),
        'Iron deficiency',
      );
      await tap(tester, iconButton());
      await tap(tester, find.text(l10n.delete));

      expect(bloc.added, [
        const ResourceChanged(
          sessionId: 's',
          index: 0,
          propertyKey: 'conditionName',
          newValue: 'Iron deficiency',
        ),
        const ResourceRemoved(sessionId: 's', index: 0),
      ]);
    });

    testWidgets('the patient is attached elsewhere from its card', (
      tester,
    ) async {
      final bloc = await pump(
        tester,
        form(
          patient: const StagedPatient(
            draft: _named,
            mode: ImportMode.createNew,
          ),
          encounter: const StagedEncounter(draft: _visit),
        ),
      );

      await tap(tester, iconButton());
      expect(find.byType(AttachToEncounterWidget), findsOne);
      await tap(tester, find.text(l10n.save).last);

      expect(bloc.added, [
        EncounterAttached(
          sessionId: 's',
          patient: _picked.$1,
          encounter: _picked.$2,
        ),
      ]);
    });

    testWidgets('closing the attach dialog changes nothing', (tester) async {
      final bloc = await pump(
        tester,
        form(
          patient: const StagedPatient(
            draft: _named,
            mode: ImportMode.createNew,
          ),
        ),
      );

      await tap(tester, iconButton());
      await tap(tester, find.text(l10n.cancel).last);

      expect(bloc.added, isEmpty);
    });

    testWidgets('tapping outside the fields closes the keyboard', (
      tester,
    ) async {
      await pump(tester, form(resources: const [_condition]));

      await tester.tap(find.byType(ResourcesForm), warnIfMissed: false);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('patient banners', () {
    const stored = Patient(id: 'p9', title: 'Maria Ionescu');

    testWidgets('a new patient next to a stored one can be swapped to it', (
      tester,
    ) async {
      final bloc = await pump(
        tester,
        form(
          patient: const StagedPatient(
            draft: _named,
            existing: stored,
            mode: ImportMode.createNew,
          ),
        ),
      );

      expect(find.text('${l10n.newPatient}: Ana Pop'), findsOne);
      await tap(tester, find.byIcon(Icons.swap_horiz));

      expect(bloc.added, [
        const EncounterAttached(
          sessionId: 's',
          patient: StagedPatient(
            draft: _named,
            existing: stored,
            mode: ImportMode.linkExisting,
          ),
          encounter: StagedEncounter(),
        ),
      ]);
    });

    testWidgets('a nameless new patient next to a stored one needs the '
        'details, and can go back to the stored one', (tester) async {
      await pump(
        tester,
        form(
          patient: StagedPatient(
            draft: _named.copyWith(
              givenName: const MappedProperty(),
              familyName: const MappedProperty(),
            ),
            existing: stored,
            mode: ImportMode.createNew,
          ),
        ),
      );

      expect(find.text(l10n.processingNoPatientFound), findsOne);
      expect(find.byIcon(Icons.swap_horiz), findsOne);
    });

    group('the unnamed user', () {
      const unnamed = Patient(
        id: 'p-me',
        title: 'Health Wallet Holder',
        rawResource: {
          'name': [
            {
              'family': 'Holder',
              'given': ['Health Wallet'],
            },
          ],
          'identifier': [
            {'value': 'default_patient'},
          ],
        },
      );

      testWidgets('is shown with the document\'s details, which name them, '
          'and can be swapped for a new person', (tester) async {
        final bloc = await pump(
          tester,
          form(
            patient: const StagedPatient(
              draft: _named,
              existing: unnamed,
              mode: ImportMode.linkExisting,
            ),
          ),
        );

        expect(find.text(l10n.patientIsYou('Ana Pop')), findsOne);
        expect(find.text('Ana'), findsOne);
        expect(find.text('Health Wallet'), findsNothing);
        await tap(tester, find.byIcon(Icons.swap_horiz));

        expect(bloc.added, [
          const EncounterAttached(
            sessionId: 's',
            patient: StagedPatient(
              draft: _named,
              existing: unnamed,
              mode: ImportMode.createNew,
            ),
            encounter: StagedEncounter(),
          ),
        ]);
      });

      testWidgets('without a patient in the document, gets it as they are', (
        tester,
      ) async {
        await pump(
          tester,
          form(
            patient: const StagedPatient(
              existing: unnamed,
              mode: ImportMode.linkExisting,
            ),
          ),
        );

        expect(find.text(l10n.patientSavedAsYou), findsOne);
        expect(find.text('Health Wallet'), findsNothing);
      });
    });

    testWidgets('an edited stored patient can be reverted', (tester) async {
      final bloc = await pump(
        tester,
        form(
          patient: StagedPatient(
            draft: _named.copyWith(id: 'p9'),
            existing: stored,
            mode: ImportMode.linkExisting,
          ),
        ),
      );

      expect(
        find.text(l10n.patientModifiedUpdating('Maria Ionescu')),
        findsOne,
      );
      await tap(tester, find.byIcon(Icons.close));

      expect(bloc.added, [const PatientReverted(sessionId: 's')]);
    });

    testWidgets('an edited stored patient of an attached document is being '
        'saved, and can still be reverted', (tester) async {
      final bloc = await pump(
        tester,
        form(
          patient: StagedPatient(
            draft: _named.copyWith(id: 'p9'),
            existing: stored,
            mode: ImportMode.linkExisting,
          ),
          locked: true,
        ),
      );

      expect(find.text(l10n.patientSavingModified('Maria Ionescu')), findsOne);
      await tap(tester, find.byIcon(Icons.close));

      expect(bloc.added, [const PatientReverted(sessionId: 's')]);
    });

    testWidgets('a scanned patient changed to a stored one can be swapped '
        'back to a new patient', (tester) async {
      final bloc = await pump(
        tester,
        form(
          patient: const StagedPatient(
            draft: _named,
            existing: stored,
            mode: ImportMode.linkExisting,
          ),
        ),
      );

      expect(find.text(l10n.patientChangedTo('Maria Ionescu')), findsOne);
      await tap(tester, find.byIcon(Icons.swap_horiz));

      expect(
        (bloc.added.single as EncounterAttached).patient.mode,
        ImportMode.createNew,
      );
    });

    testWidgets('a matched stored patient is named', (tester) async {
      await pump(
        tester,
        form(
          patient: const StagedPatient(
            existing: stored,
            mode: ImportMode.linkExisting,
          ),
        ),
      );

      expect(find.text(l10n.patientMatchFound('Maria Ionescu')), findsOne);
    });

    testWidgets('dropping the scanned patient for the stored one rebuilds '
        'the card', (tester) async {
      ResourcesForm edited() => form(
        patient: StagedPatient(
          draft: _named.copyWith(id: 'p9'),
          existing: stored,
          mode: ImportMode.linkExisting,
        ),
      );
      await pump(tester, edited());
      await pump(tester, edited());
      expect(find.widgetWithText(TextFormField, 'Ana'), findsOne);

      await pump(
        tester,
        form(
          patient: const StagedPatient(
            existing: stored,
            mode: ImportMode.linkExisting,
          ),
        ),
      );

      expect(find.widgetWithText(TextFormField, 'Ana'), findsNothing);
    });
  });
}
