part of 'processing_bloc.dart';

abstract class ProcessingEvent {
  const ProcessingEvent();
}

@freezed
abstract class ProcessingInitialised extends ProcessingEvent
    with _$ProcessingInitialised {
  const ProcessingInitialised._();

  const factory ProcessingInitialised() = _ProcessingInitialised;
}

@freezed
abstract class CaptureButtonPressed extends ProcessingEvent
    with _$CaptureButtonPressed {
  const CaptureButtonPressed._();

  const factory CaptureButtonPressed({
    @Default(CaptureMode.images) CaptureMode mode,
    @Default(5) int maxPages,
  }) = _CaptureButtonPressed;
}

@freezed
abstract class DocumentImported extends ProcessingEvent
    with _$DocumentImported {
  const DocumentImported._();

  /// [sessionId] names the new session (a handover keeps the phone's id);
  /// otherwise one is made.
  const factory DocumentImported({
    required List<String> filePaths,
    @Default(ProcessingOrigin.import) ProcessingOrigin origin,
    String? sessionId,
    StagedPatient? phase1Patient,
    StagedEncounter? phase1Encounter,
    StagedDiagnosticReport? phase1DiagnosticReport,
  }) = _DocumentImported;
}

@freezed
abstract class SessionChangedProgress extends ProcessingEvent
    with _$SessionChangedProgress {
  const SessionChangedProgress._();

  const factory SessionChangedProgress({
    required ProcessingSession session,
  }) = _SessionChangedProgress;
}

@freezed
abstract class SessionCleared extends ProcessingEvent with _$SessionCleared {
  const SessionCleared._();

  const factory SessionCleared({
    required ProcessingSession session,
  }) = _SessionCleared;
}

enum CaptureMode {
  images,
  pdf,
}

@freezed
abstract class SessionActivated extends ProcessingEvent
    with _$SessionActivated {
  const SessionActivated._();

  const factory SessionActivated({
    required String sessionId,
  }) = _SessionActivated;
}

@freezed
abstract class MappingInitiated extends ProcessingEvent
    with _$MappingInitiated {
  const MappingInitiated._();

  const factory MappingInitiated({required String sessionId}) =
      _MappingInitiated;
}

@freezed
abstract class ResourceChanged extends ProcessingEvent with _$ResourceChanged {
  const ResourceChanged._();

  const factory ResourceChanged({
    required String sessionId,
    required int index,
    required String propertyKey,
    required String newValue,
    bool? isDraftPatient,
    bool? isDraftEncounter,
    bool? isDraftDiagnosticReport,
  }) = _ResourceChanged;
}

@freezed
abstract class PatientReverted extends ProcessingEvent with _$PatientReverted {
  const PatientReverted._();

  const factory PatientReverted({required String sessionId}) = _PatientReverted;
}

@freezed
abstract class ResourceRemoved extends ProcessingEvent with _$ResourceRemoved {
  const ResourceRemoved._();

  const factory ResourceRemoved({
    required String sessionId,
    required int index,
  }) = _ResourceRemoved;
}

@freezed
abstract class ResourceCreationInitiated extends ProcessingEvent
    with _$ResourceCreationInitiated {
  const ResourceCreationInitiated._();

  const factory ResourceCreationInitiated({required String sessionId}) =
      _ResourceCreationInitiated;
}

@freezed
abstract class NotificationAcknowledged extends ProcessingEvent
    with _$NotificationAcknowledged {
  const NotificationAcknowledged._();

  const factory NotificationAcknowledged() = _NotificationAcknowledged;
}

@freezed
abstract class MappingCancelled extends ProcessingEvent
    with _$MappingCancelled {
  const MappingCancelled._();

  const factory MappingCancelled({required String sessionId}) =
      _MappingCancelled;
}

@freezed
abstract class ResourcesAdded extends ProcessingEvent with _$ResourcesAdded {
  const ResourcesAdded._();

  const factory ResourcesAdded({
    required String sessionId,
    required List<String> resourceTypes,
  }) = _ResourcesAdded;
}

@freezed
abstract class EncounterAttached extends ProcessingEvent
    with _$EncounterAttached {
  const EncounterAttached._();

  const factory EncounterAttached({
    required String sessionId,
    required StagedPatient patient,
    required StagedEncounter encounter,
  }) = _EncounterAttached;
}

@freezed
abstract class ProcessRemainingResources extends ProcessingEvent
    with _$ProcessRemainingResources {
  const ProcessRemainingResources._();

  /// [automatic]: started by the queue, not the user; a handover whose
  /// extraction failed is then not tried again until the user retries.
  const factory ProcessRemainingResources({
    required String sessionId,
    @Default(false) bool automatic,
  }) = _ProcessRemainingResources;
}

@freezed
abstract class DocumentAttached extends ProcessingEvent
    with _$DocumentAttached {
  const DocumentAttached._();

  const factory DocumentAttached({
    required String sessionId,
  }) = _DocumentAttached;
}

@freezed
abstract class TokenCapacityUpdated extends ProcessingEvent
    with _$TokenCapacityUpdated {
  const TokenCapacityUpdated._();

  /// Reloads the model and maps [sessionId] again. [newMaxTokens] is saved
  /// when given; leave it out when only another model setting changed.
  const factory TokenCapacityUpdated({
    int? newMaxTokens,
    required String sessionId,
  }) = _TokenCapacityUpdated;
}

@freezed
abstract class VisionToggled extends ProcessingEvent with _$VisionToggled {
  const VisionToggled._();

  const factory VisionToggled({required bool useVision}) = _VisionToggled;
}

@freezed
abstract class PagesReordered extends ProcessingEvent with _$PagesReordered {
  const PagesReordered._();

  const factory PagesReordered({
    required String sessionId,
    required List<String> reorderedPaths,
  }) = _PagesReordered;
}

/// The user turned the preview page [previewPath] of [sessionId] by
/// [quarterTurns] clockwise quarter turns; its OCR page turns too.
@freezed
abstract class PageRotated extends ProcessingEvent with _$PageRotated {
  const PageRotated._();

  const factory PageRotated({
    required String sessionId,
    required String previewPath,
    @Default(1) int quarterTurns,
  }) = _PageRotated;
}

/// Sent by the bloc itself once the records of [sessionId] are saved: its
/// 200 dpi OCR pages are no longer needed.
@freezed
abstract class OcrPagesReleased extends ProcessingEvent
    with _$OcrPagesReleased {
  const OcrPagesReleased._();

  const factory OcrPagesReleased({required String sessionId}) =
      _OcrPagesReleased;
}

@freezed
abstract class ContainerTypeSwitched extends ProcessingEvent
    with _$ContainerTypeSwitched {
  const ContainerTypeSwitched._();

  const factory ContainerTypeSwitched({
    required String sessionId,
  }) = _ContainerTypeSwitched;
}

/// The session's files reached the desktop, which processes it now: local
/// processing stops and the session waits as [ProcessingStatus.handedOver].
@freezed
abstract class SessionHandedOver extends ProcessingEvent
    with _$SessionHandedOver {
  const SessionHandedOver._();

  const factory SessionHandedOver({required String sessionId}) =
      _SessionHandedOver;
}

/// The desktop's draft of a handed-over session, to review on this device.
@freezed
abstract class HandoverDraftReceived extends ProcessingEvent
    with _$HandoverDraftReceived {
  const HandoverDraftReceived._();

  const factory HandoverDraftReceived({
    required String sessionId,
    required StagedPatient patient,
    @Default(StagedEncounter()) StagedEncounter encounter,
    StagedDiagnosticReport? diagnosticReport,
    @Default([]) List<MappingResource> resources,
  }) = _HandoverDraftReceived;
}

/// Why a handed-over session came back to this device.
enum HandoverReturnReason {
  /// The user took it back.
  withdrawn,

  /// The desktop could not process it.
  failedOnDesktop,

  /// The desktop has no AI model.
  noModelOnDesktop,

  /// The desktop's user deleted it there.
  deletedOnDesktop,
}

/// A handed-over session is this device's to process again.
@freezed
abstract class HandoverReturned extends ProcessingEvent
    with _$HandoverReturned {
  const HandoverReturned._();

  const factory HandoverReturned({
    required String sessionId,
    required HandoverReturnReason reason,
  }) = _HandoverReturned;
}

/// The records of a handover were saved on the paired device, so this
/// device's copy of the session is removed.
/// The device that sent this document took it back (deleted it there): it
/// goes from this one, with a notification saying so.
@freezed
abstract class SessionTakenBack extends ProcessingEvent
    with _$SessionTakenBack {
  const SessionTakenBack._();

  const factory SessionTakenBack({required String sessionId}) =
      _SessionTakenBack;
}

@freezed
abstract class SessionSavedElsewhere extends ProcessingEvent
    with _$SessionSavedElsewhere {
  const SessionSavedElsewhere._();

  const factory SessionSavedElsewhere({
    required String sessionId,

    /// Whether the paired device is the desktop (else the phone).
    required bool byDesktop,
  }) = _SessionSavedElsewhere;
}
