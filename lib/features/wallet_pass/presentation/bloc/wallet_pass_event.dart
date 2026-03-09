part of 'wallet_pass_bloc.dart';

abstract class WalletPassEvent {}

@freezed
class WalletPassRequested extends WalletPassEvent
    with _$WalletPassRequested {
  const factory WalletPassRequested({
    required WalletPassType type,
    required String patientId,
  }) = _WalletPassRequested;
}
