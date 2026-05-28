part of 'processing_bloc.dart';

abstract class ProcessingEvent {
  const ProcessingEvent();
}

@freezed
class ProcessingInitialised extends ProcessingEvent with _$ProcessingInitialised {
  const factory ProcessingInitialised() = _ProcessingInitialised;
}

@freezed
class CaptureButtonPressed extends ProcessingEvent with _$CaptureButtonPressed {
  const factory CaptureButtonPressed({
    @Default(CaptureMode.images) CaptureMode mode,
    @Default(5) int maxPages,
  }) = _CaptureButtonPressed;
}

@freezed
class DocumentImported extends ProcessingEvent with _$DocumentImported {
  const factory DocumentImported({
    required List<String> filePaths,
    @Default(ProcessingOrigin.import) ProcessingOrigin origin,
    StagedPatient? phase1Patient,
    StagedEncounter? phase1Encounter,
    StagedDiagnosticReport? phase1DiagnosticReport,
  }) = _DocumentImported;
}

@freezed
class SessionChangedProgress extends ProcessingEvent
    with _$SessionChangedProgress {
  const factory SessionChangedProgress({
    required ProcessingSession session,
  }) = _SessionChangedProgress;
}

@freezed
class SessionCleared extends ProcessingEvent with _$SessionCleared {
  const factory SessionCleared({
    required ProcessingSession session,
  }) = _SessionCleared;
}

enum CaptureMode {
  images,
  pdf,
}

@freezed
class SessionActivated extends ProcessingEvent with _$SessionActivated {
  const factory SessionActivated({
    required String sessionId,
  }) = _SessionActivated;
}

@freezed
class MappingInitiated extends ProcessingEvent with _$MappingInitiated {
  const factory MappingInitiated({required String sessionId}) =
      _MappingInitiated;
}

@freezed
class ResourceChanged extends ProcessingEvent with _$ResourceChanged {
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
class PatientReverted extends ProcessingEvent with _$PatientReverted {
  const factory PatientReverted({required String sessionId}) =
      _PatientReverted;
}

@freezed
class ResourceRemoved extends ProcessingEvent with _$ResourceRemoved {
  const factory ResourceRemoved(
      {required String sessionId, required int index}) = _ResourceRemoved;
}

@freezed
class ResourceCreationInitiated extends ProcessingEvent
    with _$ResourceCreationInitiated {
  const factory ResourceCreationInitiated({required String sessionId}) =
      _ResourceCreationInitiated;
}

@freezed
class NotificationAcknowledged extends ProcessingEvent
    with _$NotificationAcknowledged {
  const factory NotificationAcknowledged() = _NotificationAcknowledged;
}

@freezed
class MappingCancelled extends ProcessingEvent with _$MappingCancelled {
  const factory MappingCancelled({required String sessionId}) =
      _MappingCancelled;
}

@freezed
class ResourcesAdded extends ProcessingEvent with _$ResourcesAdded {
  const factory ResourcesAdded({
    required String sessionId,
    required List<String> resourceTypes,
  }) = _ResourcesAdded;
}

@freezed
class EncounterAttached extends ProcessingEvent with _$EncounterAttached {
  const factory EncounterAttached({
    required String sessionId,
    required StagedPatient patient,
    required StagedEncounter encounter,
  }) = _EncounterAttached;
}

@freezed
class ProcessRemainingResources extends ProcessingEvent
    with _$ProcessRemainingResources {
  const factory ProcessRemainingResources({
    required String sessionId,
  }) = _ProcessRemainingResources;
}

@freezed
class DocumentAttached extends ProcessingEvent with _$DocumentAttached {
  const factory DocumentAttached({
    required String sessionId,
  }) = _DocumentAttached;
}

@freezed
class TokenCapacityUpdated extends ProcessingEvent
    with _$TokenCapacityUpdated {
  const factory TokenCapacityUpdated({
    required int newMaxTokens,
    required String sessionId,
  }) = _TokenCapacityUpdated;
}

@freezed
class VisionToggled extends ProcessingEvent with _$VisionToggled {
  const factory VisionToggled({required bool useVision}) =
      _VisionToggled;
}

@freezed
class PagesReordered extends ProcessingEvent with _$PagesReordered {
  const factory PagesReordered({
    required String sessionId,
    required List<String> reorderedPaths,
  }) = _PagesReordered;
}

@freezed
class ContainerTypeSwitched extends ProcessingEvent
    with _$ContainerTypeSwitched {
  const factory ContainerTypeSwitched({
    required String sessionId,
  }) = _ContainerTypeSwitched;
}
