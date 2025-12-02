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
    required List<PatientGroup> currentPatients,
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
class ScanPatientSelected extends ScanEvent with _$ScanPatientSelected {
  const factory ScanPatientSelected({
    required String sessionId,
    required PatientGroup patientGroup,
  }) = _ScanPatientSelected;
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
class ScanResourceAdded extends ScanEvent with _$ScanResourceAdded {
  const factory ScanResourceAdded({
    required String sessionId,
    required String resourceType,
  }) = _ScanResourceAdded;
}

@freezed
class ResourcesAdded extends ScanEvent with _$ResourcesAdded {
  const factory ResourcesAdded({
    required String sessionId,
    required List<String> resourceTypes,
  }) = _ResourcesAdded;
}
