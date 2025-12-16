/// Result of sharing a SMART Health Card
class SHCShareResult {
  final String qrCodeData; // QR code string with shc:/ prefix
  final String jwsToken; // Full JWS token (for debugging/testing)

  SHCShareResult({
    required this.qrCodeData,
    required this.jwsToken,
  });
}


