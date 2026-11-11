import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';

void main() {
  // Built at run time (not as constants) so every event's constructor runs,
  // as it does when the UI or the bloc sends it.
  final id = ['s', '1'].join();
  final session = ProcessingSession(id: id);
  final patient = StagedPatient(draft: MappingPatient(id: id));
  final encounter = StagedEncounter(draft: MappingEncounter(id: id));

  test('events with the same values are equal and differ otherwise', () {
    final pairs = <(ProcessingEvent Function(String), String)>[
      ((v) => MappingInitiated(sessionId: v), 'MappingInitiated'),
      ((v) => SessionActivated(sessionId: v), 'SessionActivated'),
      ((v) => PatientReverted(sessionId: v), 'PatientReverted'),
      ((v) => ResourceRemoved(sessionId: v, index: 0), 'ResourceRemoved'),
      (
        (v) => ResourceCreationInitiated(sessionId: v),
        'ResourceCreationInitiated',
      ),
      ((v) => MappingCancelled(sessionId: v), 'MappingCancelled'),
      (
        (v) => ResourcesAdded(sessionId: v, resourceTypes: const ['Condition']),
        'ResourcesAdded',
      ),
      (
        (v) => EncounterAttached(
          sessionId: v,
          patient: patient,
          encounter: encounter,
        ),
        'EncounterAttached',
      ),
      (
        (v) => ProcessRemainingResources(sessionId: v),
        'ProcessRemainingResources',
      ),
      ((v) => DocumentAttached(sessionId: v), 'DocumentAttached'),
      (
        (v) => TokenCapacityUpdated(sessionId: v, newMaxTokens: 2048),
        'TokenCapacityUpdated',
      ),
      (
        (v) => PagesReordered(sessionId: v, reorderedPaths: const ['/1']),
        'PagesReordered',
      ),
      ((v) => PageRotated(sessionId: v, previewPath: '/1'), 'PageRotated'),
      ((v) => OcrPagesReleased(sessionId: v), 'OcrPagesReleased'),
      ((v) => ContainerTypeSwitched(sessionId: v), 'ContainerTypeSwitched'),
      (
        (v) => ResourceChanged(
          sessionId: v,
          index: 1,
          propertyKey: 'givenName',
          newValue: 'Ana',
          isDraftPatient: true,
        ),
        'ResourceChanged',
      ),
      (
        (v) => DocumentImported(filePaths: [v]),
        'DocumentImported',
      ),
    ];

    for (final (make, name) in pairs) {
      final event = make(id);
      expect(event, isA<ProcessingEvent>(), reason: name);
      expect(event, make(id), reason: name);
      expect(event.hashCode, make(id).hashCode, reason: name);
      expect(event, isNot(make('other')), reason: name);
      expect(event.toString(), startsWith(name), reason: name);
    }
  });

  test('events without values are equal to each other', () {
    final ProcessingEvent Function() initialised = ProcessingInitialised.new;
    final ProcessingEvent Function() acknowledged =
        NotificationAcknowledged.new;

    expect(initialised(), initialised());
    expect(acknowledged(), acknowledged());
    expect(initialised(), isNot(acknowledged()));
  });

  test('defaults: an image scan of up to 5 pages, an import, and one '
      'quarter turn', () {
    final CaptureButtonPressed Function() pressCapture =
        CaptureButtonPressed.new;
    final capture = pressCapture();
    expect(capture.mode, CaptureMode.images);
    expect(capture.maxPages, 5);
    expect(capture.copyWith(mode: CaptureMode.pdf).mode, CaptureMode.pdf);

    final imported = DocumentImported(filePaths: [id]);
    expect(imported.origin, ProcessingOrigin.import);
    expect(imported.phase1Patient, isNull);
    expect(imported.phase1Encounter, isNull);
    expect(imported.phase1DiagnosticReport, isNull);

    expect(PageRotated(sessionId: id, previewPath: '/1').quarterTurns, 1);
    expect(TokenCapacityUpdated(sessionId: id).newMaxTokens, isNull);
    expect(VisionToggled(useVision: id.isNotEmpty).useVision, isTrue);
  });

  test('a document from the desktop carries its step-one result', () {
    final imported = DocumentImported(
      filePaths: [id],
      origin: ProcessingOrigin.handover,
      phase1Patient: patient,
      phase1Encounter: encounter,
    );

    expect(imported.origin, ProcessingOrigin.handover);
    expect(imported.phase1Patient, patient);
    expect(imported.phase1Encounter, encounter);
    expect(
      imported.copyWith(origin: ProcessingOrigin.scan).phase1Patient,
      patient,
    );
  });

  test('session events carry the session', () {
    expect(SessionChangedProgress(session: session).session, session);
    expect(SessionCleared(session: session).session, session);
    expect(
      SessionCleared(session: session),
      isNot(SessionCleared(session: session.copyWith(id: 'other'))),
    );
  });
}
