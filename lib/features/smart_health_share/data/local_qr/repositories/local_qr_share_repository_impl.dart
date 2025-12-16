import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/smart_health_share/domain/local_qr/entities/local_qr_share_config.dart';
import 'package:health_wallet/features/smart_health_share/domain/local_qr/entities/local_qr_share_session.dart';
import 'package:health_wallet/features/smart_health_share/domain/local_qr/repositories/local_qr_share_repository.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/services/fhir_bundle_builder.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/services/jws_signing_service.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/services/key_management_service.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/services/qr_processor_service.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

@Injectable(as: LocalQRShareRepository)
class LocalQRShareRepositoryImpl implements LocalQRShareRepository {
  final FHIRBundleBuilder _fhirBundleBuilder;
  final JWSSigningService _jwsSigningService;
  final KeyManagementService _keyManagementService;
  final QRProcessorService _qrProcessorService;
  final Uuid _uuid = const Uuid();
  LocalQRShareSession? _activeSession;
  final Map<String, Map<String, dynamic>> _bleDataCache = {}; // sessionId -> fhirBundle

  // HealthWallet.me app identifier for peer verification
  static const String _healthWalletAppIdentifier = 'healthwallet.me';
  // Use healthwallet.me/peer as issuer for peer-to-peer SHC
  static const String _peerIssuerUrl = 'https://healthwallet.me/peer';
  // HealthWallet.me BLE Service UUID for peer-to-peer detection
  static const String _healthWalletServiceUuid =
      '0000FE95-0000-1000-8000-00805F9B34FB';
  static const String _deviceName = 'HealthWallet.me';

  LocalQRShareRepositoryImpl(
    this._fhirBundleBuilder,
    this._jwsSigningService,
    this._keyManagementService,
    this._qrProcessorService,
  );

  @override
  Future<LocalQRShareSession> generateLocalQRCode({
    required List<String> resourceIds,
    required LocalQRShareConfig config,
    String? sourceId,
  }) async {
    // Stop any existing session
    if (_activeSession != null) {
      await stopSession(_activeSession!);
    }

    // Generate SHC format QR code (same foundation as standard SHC)
    // But use peer issuer URL to indicate it's peer-to-peer
    final publicKey = await _keyManagementService.getOrGenerateKeyPair();
    final kid = await _keyManagementService.generateKid(publicKey);

    // Build FHIR Bundle (Patient is optional for LocalQR peer-to-peer)
    logger.d('Building FHIR bundle for ${resourceIds.length} resources');
    final bundle = await _fhirBundleBuilder.buildBundle(
      resourceIds: resourceIds,
      sourceId: sourceId,
      requirePatient: false, // Patient optional for LocalQR
    );
    logger.d('FHIR bundle created with ${bundle.length} entries');

    final now = DateTime.now();
    final expiresAt = config.timeBasedExpiration
        ? now.add(Duration(minutes: config.expirationMinutes))
        : null;

    // Always use BLE mode - generate session ID and store bundle in cache
    final sessionId = _uuid.v4();
    _bleDataCache[sessionId] = bundle;

    // Generate short device identifier (8-character hex string from sessionId hash)
    final deviceIdentifierBytes = sha256.convert(utf8.encode(sessionId)).bytes;
    final deviceIdentifier = deviceIdentifierBytes
        .take(4)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    // Generate minimal QR code with session metadata (SMART Health Cards compliant)
    final metadataPayload = {
      'sessionId': sessionId,
      'transferMode': 'ble',
      'expiresAt': expiresAt?.toIso8601String(),
      'resourceCount': resourceIds.length,
      'serviceUuid': _healthWalletServiceUuid,
      'deviceIdentifier': deviceIdentifier,
      'deviceName': _deviceName,
    };

    // Create minimal JWT with metadata only (still SMART Health Cards compliant)
    // JWT will have proper header (alg: ES256, typ: JWT, zip: DEF, kid)
    final metadataJwsToken = await _jwsSigningService.signJwt(
      payload: {'metadata': metadataPayload},
      issuer: _peerIssuerUrl,
      nbf: now.millisecondsSinceEpoch ~/ 1000,
      kid: kid,
    );

    // Encode minimal QR code (shc:/ prefix with numeric encoding)
    final qrCodeData = _qrProcessorService.encodeToShcQr(metadataJwsToken);

    // Get device ID for BLE connection
    String? deviceId;
    try {
      if (await FlutterBluePlus.isSupported) {
        final adapterState = await FlutterBluePlus.adapterState.first;
        if (adapterState == BluetoothAdapterState.on) {
          deviceId = sessionId; // Use sessionId as device identifier for now
        }
      }
    } catch (e) {
      logger.w('Could not get device ID: $e');
    }

    logger.d('LocalQR BLE Mode - Session ID: $sessionId');
    logger.d('LocalQR BLE Mode - QR Code (metadata only): $qrCodeData');

    // Create session (always BLE mode)
    final session = LocalQRShareSession(
      qrCodeData: qrCodeData,
      fhirBundle: bundle,
      config: config,
      createdAt: now,
      expiresAt: expiresAt,
      isActive: true,
      isBluetoothConnected: false,
      remainingSeconds: config.timeBasedExpiration
          ? config.expirationMinutes * 60
          : null,
      bleTransferProgress: 0.0,
      deviceId: deviceId,
      sessionId: sessionId,
    );

    _activeSession = session;
    return session;
  }

  @override
  Future<void> stopSession(LocalQRShareSession session) async {
    if (_activeSession?.createdAt == session.createdAt) {
      _activeSession = null;
      // Clear BLE data cache if it exists
      // Note: We'd need to extract sessionId from session, but for now just clear all
      _bleDataCache.clear();
    }
  }

  /// Get FHIR bundle for BLE transfer by session ID
  @override
  Map<String, dynamic>? getBleDataForSession(String sessionId) {
    return _bleDataCache[sessionId];
  }

  @override
  LocalQRShareSession? getActiveSession() {
    return _activeSession;
  }

  @override
  Future<bool> verifyPeerDevice(String deviceIdentifier) async {
    // Verify that the peer device is a HealthWallet.me app
    // This can be done via Bluetooth service UUID or app identifier
    // For now, check if identifier contains HealthWallet.me marker
    return deviceIdentifier.toLowerCase().contains(_healthWalletAppIdentifier);
  }
}

