import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_identifier.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_vision_prescription.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/widgets/processing_resources_section.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/widgets/resources_form.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';

class _MockUserBloc extends MockBloc<UserEvent, UserState>
    implements UserBloc {}

class _MockProcessingBloc extends MockBloc<ProcessingEvent, ProcessingState>
    implements ProcessingBloc {
  final added = <ProcessingEvent>[];

  @override
  void add(ProcessingEvent event) => added.add(event);
}

const _visitKey = MappingIdentifier(
  system: 'http://healthwallet.me/visit/clearvis.io',
  value: 'optica-exemplu-1|PA-01234|2024-03-14',
);

const _twin = MappingVisionPrescription(
  id: 'vp-1',
  lensType: VisionLensType.reading,
  rightSphere: MappedProperty(value: '+2.50', confidenceLevel: 1),
  existingId: 'vp-row',
);

final _session = ProcessingSession(
  id: 's',
  status: ProcessingStatus.draft,
  patient: const StagedPatient(
    existing: Patient(id: 'p1', title: 'Ioana Maria Popescu'),
    mode: ImportMode.linkExisting,
  ),
  encounter: StagedEncounter(
    draft: const MappingEncounter(id: 'e-draft', identifiers: [_visitKey]),
    existing: Encounter(
      id: 'e1',
      title: 'Rețetă Ochelari multifocali',
      date: DateTime(2024, 3, 14),
      rawResource: {
        'identifier': [_visitKey.toJson()],
      },
    ),
    mode: ImportMode.linkExisting,
  ),
  resources: const [_twin],
);

void main() {
  setUpAll(initializeDateFormatting);
  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<_MockProcessingBloc> pump(WidgetTester tester, Widget child) async {
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
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    return processingBloc;
  }

  testWidgets('a record already in the wallet is noted and locked', (
    tester,
  ) async {
    await pump(
      tester,
      ResourcesForm(
        resources: [
          _twin,
          _twin.copyWith(id: 'vp-2', completesExisting: true),
        ],
        sessionId: 's',
        formKey: GlobalKey<FormState>(),
      ),
    );

    expect(find.text(l10n.stagedAlreadyInWallet), findsOne);
    expect(find.text(l10n.stagedWillBeCompleted), findsOne);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, isNotEmpty);
    expect(fields.every((f) => f.readOnly), isTrue);
  });

  testWidgets('a new record stays editable and has no note', (tester) async {
    await pump(
      tester,
      ResourcesForm(
        resources: [_twin.copyWith(existingId: '')],
        sessionId: 's',
        formKey: GlobalKey<FormState>(),
      ),
    );

    expect(find.text(l10n.stagedAlreadyInWallet), findsNothing);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .any((f) => f.readOnly),
      isFalse,
    );
  });

  testWidgets('a glasses prescription edits its lens values in a per-eye '
      'grid, with plain labels', (tester) async {
    final bloc = await pump(
      tester,
      ResourcesForm(
        resources: [_twin.copyWith(existingId: '')],
        sessionId: 's',
        formKey: GlobalKey<FormState>(),
      ),
    );

    expect(find.text(l10n.visionEyeRight), findsOne);
    expect(find.text(l10n.visionEyeLeft), findsOne);
    expect(find.text(l10n.visionSphere), findsOne);
    expect(find.text(l10n.visionCylinder), findsOne);
    expect(find.text(l10n.visionAxis), findsOne);
    // A reading lens prints no add.
    expect(find.text(l10n.visionAdd), findsNothing);
    expect(find.text(l10n.fieldDateWritten), findsOne);
    expect(find.text(l10n.fieldRecommendedFollowUp), findsOne);
    expect(find.text(l10n.fieldPrescribedBy), findsOne);
    // Three values for two eyes, and the prescriber.
    expect(find.byType(TextField), findsNWidgets(7));

    await tester.enterText(
      find.byKey(const ValueKey('vp-1_leftSphere')),
      '+2.25',
    );
    expect(bloc.added, [
      const ResourceChanged(
        sessionId: 's',
        index: 0,
        propertyKey: 'leftSphere',
        newValue: '+2.25',
      ),
    ]);

    await tester.enterText(
      find.byKey(const ValueKey('vp-1_rightAxis')),
      '200',
    );
    await tester.pump();
    expect(find.text(l10n.visionInvalidAxis), findsOne);
  });

  testWidgets('an empty field shows no low-confidence hint, a doubtful '
      'value does', (tester) async {
    Future<void> show(MappedProperty prescriber) => pump(
      tester,
      ResourcesForm(
        resources: [
          _twin.copyWith(existingId: '', prescriberName: prescriber),
        ],
        sessionId: 's',
        formKey: GlobalKey<FormState>(),
      ),
    );

    await show(const MappedProperty());
    expect(find.textContaining(l10n.confidenceLow), findsNothing);

    await show(
      const MappedProperty(value: 'Dr. Exemplu', confidenceLevel: 0.2),
    );
    expect(find.textContaining(l10n.confidenceLow), findsOne);
  });

  testWidgets('a document already in the wallet says so above Done', (
    tester,
  ) async {
    expect(_session.isAlreadyInWallet, isTrue);
    final formKey = GlobalKey<FormState>();
    await pump(
      tester,
      ProcessingResourcesSection(
        state: ProcessingState(sessions: [_session]),
        displayedSession: _session,
        sessionId: 's',
        formKey: formKey,
        encounterSectionKey: GlobalKey(),
        deviceCapability: DeviceAiCapability.full,
        onScrollToFormErrors: () {},
        onSaveResources: () {},
      ),
    );

    expect(find.text(l10n.documentAlreadyInWallet), findsOne);
    // The visit and the prescription each say they are already there.
    expect(find.text(l10n.stagedAlreadyInWallet), findsNWidgets(2));
    expect(find.byType(ReviewBanner), findsAtLeast(3));
    // The visit in the wallet has no specialty, which a new visit requires:
    // a locked card can't be corrected, so it never blocks saving.
    expect(formKey.currentState!.validate(), isTrue);
  });
}
