part of 'receive_bloc.dart';

@freezed
class ReceiveState with _$ReceiveState {
  const factory ReceiveState({
    @Default(false) bool isLoading,
    @Default(false) bool isScanning,
    String? errorMessage,
    String? successMessage,
    SHCReceiveResult? receiveResult,
    // LocalQR peer-to-peer resources (in-memory, temporary)
    List<IFhirResource>? receivedResources,
    DateTime? expiresAt,
    int? remainingSeconds,
    @Default(false) bool isPeerToPeer,
  }) = _ReceiveState;
}
