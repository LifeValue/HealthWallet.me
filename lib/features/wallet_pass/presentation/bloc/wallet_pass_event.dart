part of 'wallet_pass_bloc.dart';

abstract class WalletPassEvent {
  const WalletPassEvent();
}

@freezed
abstract class WalletPassRequested extends WalletPassEvent
    with _$WalletPassRequested {
  const WalletPassRequested._();

  const factory WalletPassRequested({
    required WalletPassType type,
    required String patientId,

    /// The pass texts; the active app language when null.
    WalletPassLabels? labels,
  }) = _WalletPassRequested;
}
