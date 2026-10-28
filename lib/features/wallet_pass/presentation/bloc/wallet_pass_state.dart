part of 'wallet_pass_bloc.dart';

enum WalletPassStatus {
  initial,
  loading,
  dataReady,
  passGenerated,

  /// The pass was handed to Apple or Google Wallet. Google Wallet does not
  /// report whether the user then saved it.
  passAddedToWallet,
  notAvailable,
  failure,
}

@freezed
abstract class WalletPassState with _$WalletPassState {
  const factory WalletPassState({
    @Default(WalletPassStatus.initial) WalletPassStatus status,
    EmergencyCardData? cardData,
    @Default(null) Uint8List? passBytes,
    @Default(null) String? googlePassJson,

    /// Translated message for [WalletPassStatus.failure]; the cause is
    /// logged, never shown.
    String? errorMessage,
  }) = _WalletPassState;
}
