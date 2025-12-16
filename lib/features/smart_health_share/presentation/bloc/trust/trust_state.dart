part of 'trust_bloc.dart';

@freezed
class TrustState with _$TrustState {
  const factory TrustState({
    @Default(false) bool isLoading,
    String? errorMessage,
    String? successMessage,
    @Default([]) List<TrustedIssuerInfo> issuers,
  }) = _TrustState;
}

