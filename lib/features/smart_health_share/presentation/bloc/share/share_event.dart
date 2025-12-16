part of 'share_bloc.dart';

@freezed
class ShareEvent with _$ShareEvent {
  const factory ShareEvent.initialized() = ShareInitialized;
  const factory ShareEvent.loadResources() = ShareLoadResources;
  const factory ShareEvent.resourcesSelected(List<String> resourceIds) =
      ShareResourcesSelected;
  const factory ShareEvent.generateQrCode({
    required List<String> resourceIds,
    required String issuerUrl,
    String? sourceId,
  }) = ShareGenerateQrCode;
  const factory ShareEvent.reset() = ShareReset;
}
