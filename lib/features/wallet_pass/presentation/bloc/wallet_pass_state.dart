part of 'wallet_pass_bloc.dart';

enum WalletPassStatus {
  initial,
  loading,
  dataReady,
  passGenerated,
  passAddedToWallet,
  notAvailable,
  failure,
}

@freezed
class WalletPassState with _$WalletPassState {
  const factory WalletPassState({
    @Default(WalletPassStatus.initial) WalletPassStatus status,
    EmergencyCardData? cardData,
    @Default(null) Uint8List? passBytes,
    @Default(null) String? googlePassJson,
    String? errorMessage,
  }) = _WalletPassState;
}
