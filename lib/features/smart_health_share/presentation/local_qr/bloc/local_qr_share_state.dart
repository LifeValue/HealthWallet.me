part of 'local_qr_share_bloc.dart';

@freezed
class LocalQRShareState with _$LocalQRShareState {
  const factory LocalQRShareState({
    @Default(false) bool isLoading,
    String? errorMessage,
    @Default([]) List<IFhirResource> availableResources,
    @Default([]) List<String> selectedResourceIds,
    @Default(LocalQRShareConfig.defaultTimeAndLocation) LocalQRShareConfig config,
    LocalQRShareSession? session,
  }) = _LocalQRShareState;
}

