import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/services/qr_processor_service.dart';
import 'package:injectable/injectable.dart';

/// Exception thrown when QR code input exceeds maximum capacity
class QRInputTooLongException implements Exception {
  final int inputLength;
  final int maxCapacity;
  final String message;

  QRInputTooLongException({
    required this.inputLength,
    required this.maxCapacity,
  }) : message =
            'Input too long $inputLength > $maxCapacity. Please select fewer resources or use Bluetooth direct transfer for large data.';

  @override
  String toString() => message;
}

@Injectable(as: QRProcessorService)
class QRProcessorServiceImpl implements QRProcessorService {
  static const String _shcPrefix = 'shc:/';

  @override
  String encodeToShcQr(String jwsToken) {
    // Convert JWS token to bytes
    final jwsBytes = utf8.encode(jwsToken);

    // Compress using DEFLATE (raw DEFLATE, not gzip)
    final compressed = Deflate(jwsBytes).getBytes();

    // Encode to numeric (each byte becomes three digits)
    final numeric = _encodeNumeric(Uint8List.fromList(compressed));

    // Calculate final QR code size (prefix + numeric encoding)
    final qrCodeData = '$_shcPrefix$numeric';
    final qrCodeLength = qrCodeData.length;

    // Check if exceeds maximum QR code capacity
    if (qrCodeLength > QRProcessorService.maxQrCodeCapacity) {
      throw QRInputTooLongException(
        inputLength: qrCodeLength,
        maxCapacity: QRProcessorService.maxQrCodeCapacity,
      );
    }

    return qrCodeData;
  }

  @override
  int estimateEncodedSize(String jwsToken) {
    // Convert JWS token to bytes
    final jwsBytes = utf8.encode(jwsToken);

    // Compress using DEFLATE (raw DEFLATE, not gzip)
    final compressed = Deflate(jwsBytes).getBytes();

    // Encode to numeric (each byte becomes three digits)
    final numericLength = compressed.length * 3;

    // Add shc:/ prefix (5 characters)
    final estimated = _shcPrefix.length + numericLength;
    return estimated;
  }

  @override
  String decodeFromShcQr(String qrData) {
    if (!isShcQr(qrData)) {
      throw Exception('Invalid SHC QR code format');
    }

    // Remove shc:/ prefix
    final numericData = qrData.substring(_shcPrefix.length);

    // Decode from numeric to bytes
    final compressedBytes = _decodeNumeric(numericData);

    // Decompress using DEFLATE (raw DEFLATE, not gzip)
    final decompressed = Inflate(compressedBytes.toList()).getBytes();

    // Convert bytes back to JWS token string
    return utf8.decode(decompressed);
  }

  @override
  bool isShcQr(String qrData) {
    return qrData.startsWith(_shcPrefix);
  }

  @override
  bool isShLink(String qrData) {
    // SMART Health Links start with https:// or shlink:/
    return qrData.startsWith('https://') ||
        qrData.startsWith('shlink:/') ||
        qrData.contains('/shlink/');
  }

  /// Encode bytes to numeric string (SMART Health Cards encoding)
  /// Each byte (0-255) is encoded as its decimal value (3 digits: 000-255)
  String _encodeNumeric(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      // Encode each byte as exactly 3 digits (000-255)
      buffer.write(byte.toString().padLeft(3, '0'));
    }
    return buffer.toString();
  }

  /// Decode numeric string to bytes (SMART Health Cards decoding)
  /// Expects 3-digit encoding (000-255)
  Uint8List _decodeNumeric(String numeric) {
    if (numeric.length % 3 != 0) {
      throw Exception('Invalid numeric encoding: length must be multiple of 3');
    }

    final bytes = <int>[];
    for (int i = 0; i < numeric.length; i += 3) {
      final threeDigits = numeric.substring(i, i + 3);
      final byteValue = int.parse(threeDigits);
      if (byteValue > 255) {
        throw Exception('Invalid byte value: $byteValue');
      }
      bytes.add(byteValue);
    }

    return Uint8List.fromList(bytes);
  }
}

