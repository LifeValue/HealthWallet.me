part of 'trust_bloc.dart';

@freezed
class TrustEvent with _$TrustEvent {
  const factory TrustEvent.initialized() = TrustInitialized;
  const factory TrustEvent.loadIssuers() = TrustLoadIssuers;
  const factory TrustEvent.addIssuer({
    required String issuerId,
    required String name,
    required JsonWebKey publicKey,
    required String source,
  }) = TrustAddIssuer;
  const factory TrustEvent.removeIssuer(String issuerId) = TrustRemoveIssuer;
}
