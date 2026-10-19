part of 'load_model_bloc.dart';

@freezed
class LoadModelState with _$LoadModelState {
  const LoadModelState._();

  const factory LoadModelState({
    @Default(LoadModelStatus.loading) LoadModelStatus status,
    double? downloadProgress,
    String? errorMessage,
    @Default(false) bool isBackgroundDownload,
    @Default(DeviceAiCapability.unsupported) DeviceAiCapability deviceCapability,
    AiModelVariant? selectedVariant,
    AiModelVariant? downloadingVariant,
    @Default({}) Map<AiModelVariant, bool> downloadedVariants,
    @Default({}) Map<AiModelVariant, bool> downloadingVariants,
    @Default({}) Map<AiModelVariant, double> variantProgress,
  }) = _LoadModelState;

  bool isVariantDownloaded(AiModelVariant variant) =>
      downloadedVariants[variant] ?? false;

  bool isVariantDownloading(AiModelVariant variant) =>
      downloadingVariants[variant] ?? false;

  double? variantProgressOf(AiModelVariant variant) =>
      variantProgress[variant];

  bool get isAnyDownloading =>
      downloadingVariants.values.any((v) => v);
}

enum LoadModelStatus {
  modelAbsent,
  loading,
  modelLoaded,
  error,
}
