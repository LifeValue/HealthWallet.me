part of 'scan_bloc.dart';

abstract class ScanEvent {
  const ScanEvent();
}

@freezed
class ScanInitialised extends ScanEvent with _$ScanInitialised {
  const factory ScanInitialised() = _ScanInitialised;
}

@freezed
class ScanButtonPressed extends ScanEvent with _$ScanButtonPressed {
  const factory ScanButtonPressed({
    @Default(ScanMode.images) ScanMode mode,
    @Default(5) int maxPages,
  }) = _ScanButtonPressed;
}

@freezed
class DocumentImported extends ScanEvent with _$DocumentImported {
  const factory DocumentImported({
    required String filePath,
  }) = _DocumentImported;
}

@freezed
class ScanSessionChangedProgress extends ScanEvent
    with _$ScanSessionChangedProgress {
  const factory ScanSessionChangedProgress({
    required ProcessingSession session,
  }) = _ScanSessionChangedProgress;
}

@freezed
class ScanSessionCleared extends ScanEvent with _$ScanSessionCleared {
  const factory ScanSessionCleared({
    required ProcessingSession session,
  }) = _ScanSessionCleared;
}

enum ScanMode {
  images,
  pdf,
}

@freezed
class ScanSessionActivated extends ScanEvent with _$ScanSessionActivated {
  const factory ScanSessionActivated({
    required String sessionId,
  }) = _ScanSessionActivated;
}

@freezed
class ScanMappingInitiated extends ScanEvent with _$ScanMappingInitiated {
  const factory ScanMappingInitiated({required String sessionId}) =
      _ScanMappingInitiated;
}

@freezed
class ScanResourceChanged extends ScanEvent with _$ScanResourceChanged {
  const factory ScanResourceChanged({
    required String sessionId,
    required int index,
    required String propertyKey,
    required String newValue,
    bool? isDraftPatient,
    bool? isDraftEncounter,
  }) = _ScanResourceChanged;
}

@freezed
class ScanResourceRemoved extends ScanEvent with _$ScanResourceRemoved {
  const factory ScanResourceRemoved(
      {required String sessionId, required int index}) = _ScanResourceRemoved;
}

@freezed
class ScanResourceCreationInitiated extends ScanEvent
    with _$ScanResourceCreationInitiated {
  const factory ScanResourceCreationInitiated({required String sessionId}) =
      _ScanResourceCreationInitiated;
}

@freezed
class ScanNotificationAcknowledged extends ScanEvent
    with _$ScanNotificationAcknowledged {
  const factory ScanNotificationAcknowledged() = _ScanNotificationAcknowledged;
}

@freezed
class ScanMappingCancelled extends ScanEvent with _$ScanMappingCancelled {
  const factory ScanMappingCancelled({required String sessionId}) =
      _ScanMappingCancelled;
}

@freezed
class ScanResourcesAdded extends ScanEvent with _$ScanResourcesAdded {
  const factory ScanResourcesAdded({
    required String sessionId,
    required List<String> resourceTypes,
  }) = _ScanResourcesAdded;
}

@freezed
class ScanEncounterAttached extends ScanEvent with _$ScanEncounterAttached {
  const factory ScanEncounterAttached({
    required String sessionId,
    required StagedPatient patient,
    required StagedEncounter encounter,
  }) = _ScanEncounterAttached;
}

@freezed
class ScanProcessRemainingResources extends ScanEvent
    with _$ScanProcessRemainingResources {
  const factory ScanProcessRemainingResources({
    required String sessionId,
  }) = _ScanProcessRemainingResources;
}

@freezed
class ScanDocumentAttached extends ScanEvent with _$ScanDocumentAttached {
  const factory ScanDocumentAttached({
    required String sessionId,
  }) = _ScanDocumentAttached;
}
