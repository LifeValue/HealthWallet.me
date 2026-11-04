part of 'load_model_bloc.dart';

abstract class LoadModelEvent {
  const LoadModelEvent();
}

@freezed
abstract class LoadModelInitialized extends LoadModelEvent
    with _$LoadModelInitialized {
  const LoadModelInitialized._();

  const factory LoadModelInitialized() = _LoadModelInitialized;
}

@freezed
abstract class LoadModelDownloadInitiated extends LoadModelEvent
    with _$LoadModelDownloadInitiated {
  const LoadModelDownloadInitiated._();

  const factory LoadModelDownloadInitiated({AiModelVariant? variant}) =
      _LoadModelDownloadInitiated;
}

@freezed
abstract class LoadModelServiceStateChanged extends LoadModelEvent
    with _$LoadModelServiceStateChanged {
  const LoadModelServiceStateChanged._();

  const factory LoadModelServiceStateChanged({
    required AiModelDownloadState serviceState,
  }) = _LoadModelServiceStateChanged;
}

@freezed
abstract class LoadModelDownloadCancelled extends LoadModelEvent
    with _$LoadModelDownloadCancelled {
  const LoadModelDownloadCancelled._();

  /// Stops the [variant]'s download, or every model download without one.
  const factory LoadModelDownloadCancelled({AiModelVariant? variant}) =
      _LoadModelDownloadCancelled;
}

@freezed
abstract class LoadModelVariantSelected extends LoadModelEvent
    with _$LoadModelVariantSelected {
  const LoadModelVariantSelected._();

  const factory LoadModelVariantSelected(AiModelVariant variant) =
      _LoadModelVariantSelected;
}

@freezed
abstract class LoadModelDeleteRequested extends LoadModelEvent
    with _$LoadModelDeleteRequested {
  const LoadModelDeleteRequested._();

  const factory LoadModelDeleteRequested(AiModelVariant variant) =
      _LoadModelDeleteRequested;
}
