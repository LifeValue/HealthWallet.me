part of 'share_bloc.dart';

@freezed
class ShareState with _$ShareState {
  const factory ShareState({
    @Default(false) bool isLoading,
    String? errorMessage,
    String? qrCodeData,
    SHCShareResult? shareResult,
    @Default([]) List<String> selectedResourceIds,
    @Default([]) List<IFhirResource> availableResources,
  }) = _ShareState;
}
