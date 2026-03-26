part of 'load_model_bloc.dart';

abstract class LoadModelEvent {
  const LoadModelEvent();
}

@freezed
class LoadModelInitialized extends LoadModelEvent
    with _$LoadModelInitialized {
  const factory LoadModelInitialized() = _LoadModelInitialized;
}

@freezed
class LoadModelDownloadInitiated extends LoadModelEvent
    with _$LoadModelDownloadInitiated {
  const factory LoadModelDownloadInitiated({AiModelVariant? variant}) =
      _LoadModelDownloadInitiated;
}

@freezed
class LoadModelServiceStateChanged extends LoadModelEvent
    with _$LoadModelServiceStateChanged {
  const factory LoadModelServiceStateChanged({
    required AiModelDownloadState serviceState,
  }) = _LoadModelServiceStateChanged;
}

@freezed
class LoadModelDownloadCancelled extends LoadModelEvent
    with _$LoadModelDownloadCancelled {
  const factory LoadModelDownloadCancelled() = _LoadModelDownloadCancelled;
}

@freezed
class LoadModelVariantSelected extends LoadModelEvent
    with _$LoadModelVariantSelected {
  const factory LoadModelVariantSelected(AiModelVariant variant) =
      _LoadModelVariantSelected;
}

@freezed
class LoadModelDeleteRequested extends LoadModelEvent
    with _$LoadModelDeleteRequested {
  const factory LoadModelDeleteRequested(AiModelVariant variant) =
      _LoadModelDeleteRequested;
}
