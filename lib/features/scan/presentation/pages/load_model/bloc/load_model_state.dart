part of 'load_model_bloc.dart';

@freezed
class LoadModelState with _$LoadModelState {
  const factory LoadModelState({
    @Default(LoadModelStatus.loading) LoadModelStatus status,
    double? downloadProgress,
    String? errorMessage,
    @Default(false) bool isBackgroundDownload,
    @Default(DeviceAiCapability.full) DeviceAiCapability deviceCapability,
    AiModelVariant? selectedVariant,
    @Default(false) bool medGemmaDownloaded,
    @Default(false) bool qwenDownloaded,
    AiModelVariant? downloadingVariant,
    @Default(false) bool medGemmaDownloading,
    @Default(false) bool qwenDownloading,
    double? medGemmaProgress,
    double? qwenProgress,
  }) = _LoadModelState;
}

enum LoadModelStatus {
  modelAbsent,
  loading,
  modelLoaded,
  error,
}
