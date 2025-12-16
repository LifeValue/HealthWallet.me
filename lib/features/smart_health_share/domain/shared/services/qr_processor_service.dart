/// Service for encoding/decoding SMART Health Cards to/from QR code format
abstract class QRProcessorService {
  /// Maximum QR code capacity (version 40, error correction level M)
  /// This is approximately 23,468 characters
  static const int maxQrCodeCapacity = 23468;

  /// Encode JWS token to SHC QR code format
  /// Returns the QR code string with shc:/ prefix
  /// Throws [QRInputTooLongException] if the encoded data exceeds QR code capacity
  String encodeToShcQr(String jwsToken);

  /// Decode SHC QR code format to JWS token
  /// Throws exception if format is invalid
  String decodeFromShcQr(String qrData);

  /// Check if QR data is a SMART Health Card
  bool isShcQr(String qrData);

  /// Check if QR data is a SMART Health Link
  bool isShLink(String qrData);

  /// Estimate the size of the encoded QR code for a given JWS token
  /// Returns the estimated character count
  int estimateEncodedSize(String jwsToken);
}
