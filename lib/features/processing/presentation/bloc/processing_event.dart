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

  const factory DocumentImported({
    required List<String> filePaths,
    @Default(ProcessingOrigin.import) ProcessingOrigin origin,
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

  const factory ProcessRemainingResources({
    required String sessionId,
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

@freezed
abstract class ContainerTypeSwitched extends ProcessingEvent
    with _$ContainerTypeSwitched {
  const ContainerTypeSwitched._();

  const factory ContainerTypeSwitched({
    required String sessionId,
  }) = _ContainerTypeSwitched;
}
