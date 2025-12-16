import 'dart:convert';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/entities/shc_share_result.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/repositories/share_repository.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/services/fhir_bundle_builder.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/services/jws_signing_service.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/services/key_management_service.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/services/qr_processor_service.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: ShareRepository)
class ShareRepositoryImpl implements ShareRepository {
  final FHIRBundleBuilder _fhirBundleBuilder;
  final JWSSigningService _jwsSigningService;
  final KeyManagementService _keyManagementService;
  final QRProcessorService _qrProcessorService;

  ShareRepositoryImpl(
    this._fhirBundleBuilder,
    this._jwsSigningService,
    this._keyManagementService,
    this._qrProcessorService,
  );

  @override
  Future<SHCShareResult> generateHealthCard({
    required List<String> resourceIds,
    required String issuerUrl,
    String? sourceId,
  }) async {
    // Ensure key pair exists
    final publicKey = await _keyManagementService.getOrGenerateKeyPair();
    final kid = await _keyManagementService.generateKid(publicKey);

    // Build FHIR Bundle (Patient required for standard SHC - backward compatibility)
    final bundle = await _fhirBundleBuilder.buildBundle(
      resourceIds: resourceIds,
      sourceId: sourceId,
      requirePatient: true, // Patient required for standard SHC
    );

    // Create Verifiable Credential payload
    final payload = {
      'vc': {
        'type': [
          'https://smarthealth.cards#health-card',
          'VerifiableCredential',
        ],
        'credentialSubject': {
          'fhirVersion': '4.0.1',
          'fhirBundle': bundle,
        },
      },
    };

    // Sign JWT
    final nbf = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final jwsToken = await _jwsSigningService.signJwt(
      payload: payload,
      issuer: issuerUrl,
      nbf: nbf,
      kid: kid,
    );

    // Encode to QR format
    final qrCodeData = _qrProcessorService.encodeToShcQr(jwsToken);

    // Log QR code content
    logger.d('QR Code Content: $qrCodeData');
    logger.d('JWS Token: $jwsToken');
    logger.d('Payload: ${jsonEncode(payload)}');

    return SHCShareResult(
      qrCodeData: qrCodeData,
      jwsToken: jwsToken,
    );
  }
}

