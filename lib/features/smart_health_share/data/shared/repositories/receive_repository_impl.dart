import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/data/datasource/fhir_resource_datasource.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/entities/shc_receive_result.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/repositories/receive_repository.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/services/jws_signing_service.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/services/qr_processor_service.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/services/trust_manager_service.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

@Injectable(as: ReceiveRepository)
class ReceiveRepositoryImpl implements ReceiveRepository {
  final QRProcessorService _qrProcessorService;
  final JWSSigningService _jwsSigningService;
  final TrustManagerService _trustManagerService;
  final AppDatabase _appDatabase;
  final FhirResourceDatasource _fhirResourceDatasource;
  final _uuid = const Uuid();

  ReceiveRepositoryImpl(
    this._qrProcessorService,
    this._jwsSigningService,
    this._trustManagerService,
    this._appDatabase,
    this._fhirResourceDatasource,
  );

  @override
  Future<SHCReceiveResult> importHealthCard(String qrData) async {
    try {
      // Check if it's a SMART Health Card (shc:/ format)
      if (!_qrProcessorService.isShcQr(qrData)) {
        return SHCReceiveResult.failure('Invalid SMART Health Card format');
      }

      // Decode QR to JWS token
      final jwsToken = _qrProcessorService.decodeFromShcQr(qrData);

      // Parse JWT payload to check issuer
      final payload = _jwsSigningService.parseJwtPayload(jwsToken);
      final issuer = payload['iss'] as String?;

      // Check if it's a peer-to-peer SHC (issuer contains /peer)
      final isPeerToPeer = issuer != null && issuer.contains('/peer');

      if (isPeerToPeer) {
        // Peer-to-peer: Skip issuer verification, trust the SHC directly
        // Extract FHIR Bundle
        final vc = payload['vc'] as Map<String, dynamic>?;
        if (vc == null) {
          return SHCReceiveResult.failure(
              'Invalid Verifiable Credential structure');
        }

        final credentialSubject =
            vc['credentialSubject'] as Map<String, dynamic>?;
        if (credentialSubject == null) {
          return SHCReceiveResult.failure('Invalid credential subject');
        }

        final fhirBundle =
            credentialSubject['fhirBundle'] as Map<String, dynamic>?;
        if (fhirBundle == null) {
          return SHCReceiveResult.failure('FHIR Bundle not found');
        }

        // Import resources (use peer source ID)
        const peerSourceId = 'healthwallet.me/peer';
        final importedCount =
            await _importBundleResources(fhirBundle, peerSourceId);

        return SHCReceiveResult.success(
          importedResourceCount: importedCount,
          issuerId: peerSourceId,
        );
      } else {
        // Standard SHC: Verify signature with issuer
        final issuerId = await _trustManagerService.verifySignature(
          compactJws: jwsToken,
        );

        if (issuerId == null) {
          return SHCReceiveResult.failure(
            'Signature verification failed. Issuer not trusted or signature invalid.',
          );
        }

        // Extract FHIR Bundle
        final vc = payload['vc'] as Map<String, dynamic>?;
        if (vc == null) {
          return SHCReceiveResult.failure(
              'Invalid Verifiable Credential structure');
        }

        final credentialSubject =
            vc['credentialSubject'] as Map<String, dynamic>?;
        if (credentialSubject == null) {
          return SHCReceiveResult.failure('Invalid credential subject');
        }

        final fhirBundle =
            credentialSubject['fhirBundle'] as Map<String, dynamic>?;
        if (fhirBundle == null) {
          return SHCReceiveResult.failure('FHIR Bundle not found');
        }

        // Import resources from bundle
        final importedCount =
            await _importBundleResources(fhirBundle, issuerId);

        return SHCReceiveResult.success(
          importedResourceCount: importedCount,
          issuerId: issuerId,
        );
      }
    } catch (e) {
      return SHCReceiveResult.failure('Failed to import health card: $e');
    }
  }

  Future<int> _importBundleResources(
    Map<String, dynamic> bundle,
    String issuerId,
  ) async {
    final entries = bundle['entry'] as List<dynamic>?;
    if (entries == null || entries.isEmpty) {
      return 0;
    }

    // Create or get source for this issuer
    final sourceId = await _getOrCreateSource(issuerId);

    int importedCount = 0;
    for (final entry in entries) {
      final resource = entry['resource'] as Map<String, dynamic>?;
      if (resource == null) continue;

      try {
        // Generate unique ID for imported resource
        final resourceId = resource['id'] as String? ?? _uuid.v4();
        final resourceType = resource['resourceType'] as String?;
        if (resourceType == null) continue;

        // Insert resource
        // Use different prefix based on source type
        final resourcePrefix = sourceId.contains('/peer') ? 'localqr' : 'shc';
        await _fhirResourceDatasource.insertResource(
          FhirResourceLocalDto(
            id: '${resourcePrefix}_${sourceId.replaceAll('/', '_')}_$resourceId',
            sourceId: sourceId,
            resourceType: resourceType,
            resourceId: resourceId,
            title: _extractTitle(resource),
            date: _extractDate(resource),
            resourceRaw: jsonEncode(resource),
            encounterId: _extractEncounterId(resource),
            subjectId: _extractSubjectId(resource),
          ),
        );

        importedCount++;
      } catch (e) {
        // Continue importing other resources even if one fails
        continue;
      }
    }

    return importedCount;
  }

  Future<String> _getOrCreateSource(String issuerId) async {
    // Check if source already exists
    final sources = await _appDatabase.select(_appDatabase.sources).get();
    final existingSource = sources.where((s) => s.id == issuerId).firstOrNull;

    if (existingSource != null) {
      return issuerId;
    }

    // Create new source
    final platformName = issuerId.contains('/peer')
        ? 'LocalQR Peer-to-Peer'
        : 'SMART Health Card';
    final platformType = issuerId.contains('/peer') ? 'localqr' : 'shc';

    await _appDatabase.into(_appDatabase.sources).insert(
          SourcesCompanion.insert(
            id: issuerId,
            platformName: Value(platformName),
            platformType: Value(platformType),
          ),
        );

    return issuerId;
  }

  String? _extractTitle(Map<String, dynamic> resource) {
    // Try common title fields
    return resource['title'] as String? ??
        resource['name'] as String? ??
        resource['display'] as String?;
  }

  DateTime? _extractDate(Map<String, dynamic> resource) {
    // Try common date fields
    final dateStr = resource['date'] as String? ??
        resource['effectiveDateTime'] as String? ??
        resource['period']?['start'] as String?;

    if (dateStr == null) return null;

    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  String? _extractEncounterId(Map<String, dynamic> resource) {
    final encounter = resource['encounter'] as Map<String, dynamic>?;
    if (encounter == null) return null;

    final reference = encounter['reference'] as String?;
    if (reference == null) return null;

    // Extract ID from reference (format: "Encounter/123" or "urn:uuid:...")
    if (reference.startsWith('urn:uuid:')) {
      return reference.substring(9);
    } else if (reference.contains('/')) {
      return reference.split('/').last;
    }

    return null;
  }

  String? _extractSubjectId(Map<String, dynamic> resource) {
    final subject = resource['subject'] as Map<String, dynamic>?;
    if (subject == null) return null;

    final reference = subject['reference'] as String?;
    if (reference == null) return null;

    // Extract ID from reference
    if (reference.startsWith('urn:uuid:')) {
      return reference.substring(9);
    } else if (reference.contains('/')) {
      return reference.split('/').last;
    }

    return null;
  }

  @override
  Future<LocalQRReceiveResult> importHealthCardForLocalQR(
    String qrData,
  ) async {
    try {
      // Check if it's a SMART Health Card (shc:/ format)
      if (!_qrProcessorService.isShcQr(qrData)) {
        return LocalQRReceiveResult.failure('Invalid SMART Health Card format');
      }

      // Decode QR to JWS token
      final jwsToken = _qrProcessorService.decodeFromShcQr(qrData);

      // Parse JWT payload
      final payload = _jwsSigningService.parseJwtPayload(jwsToken);
      final issuer = payload['iss'] as String?;

      // Verify it's a peer-to-peer SHC (issuer contains /peer)
      if (issuer == null || !issuer.contains('/peer')) {
        return LocalQRReceiveResult.failure(
          'Not a LocalQR peer-to-peer health card',
        );
      }

      // Extract FHIR Bundle
      final vc = payload['vc'] as Map<String, dynamic>?;
      if (vc == null) {
        return LocalQRReceiveResult.failure(
          'Invalid Verifiable Credential structure',
        );
      }

      final credentialSubject =
          vc['credentialSubject'] as Map<String, dynamic>?;
      if (credentialSubject == null) {
        return LocalQRReceiveResult.failure('Invalid credential subject');
      }

      final fhirBundle =
          credentialSubject['fhirBundle'] as Map<String, dynamic>?;
      if (fhirBundle == null) {
        return LocalQRReceiveResult.failure('FHIR Bundle not found');
      }

      // Convert bundle entries to IFhirResource entities
      final resources = _convertBundleToResources(fhirBundle);

      // Calculate expiration time
      // Use exp claim if available, otherwise calculate from nbf + 15 minutes
      DateTime expiresAt;
      final exp = payload['exp'] as int?;
      if (exp != null) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      } else {
        final nbf = payload['nbf'] as int?;
        if (nbf != null) {
          expiresAt = DateTime.fromMillisecondsSinceEpoch(nbf * 1000)
              .add(const Duration(minutes: 15));
        } else {
          // Default to 15 minutes from now if no time info
          expiresAt = DateTime.now().add(const Duration(minutes: 15));
        }
      }

      return LocalQRReceiveResult.success(
        resources: resources,
        expiresAt: expiresAt,
      );
    } catch (e) {
      return LocalQRReceiveResult.failure(
        'Failed to import LocalQR health card: $e',
      );
    }
  }

  /// Helper method to convert FHIR bundle entries to IFhirResource entities
  List<IFhirResource> _convertBundleToResources(Map<String, dynamic> bundle) {
    final resources = <IFhirResource>[];
    final entries = bundle['entry'] as List<dynamic>?;
    if (entries != null) {
      for (final entry in entries) {
        final resource = entry['resource'] as Map<String, dynamic>?;
        if (resource == null) continue;

        try {
          final resourceType = resource['resourceType'] as String?;
          final resourceId = resource['id'] as String? ?? _uuid.v4();

          if (resourceType == null) continue;

          // Create DTO for entity creation
          final dto = FhirResourceLocalDto(
            id: 'localqr_temp_$resourceId',
            sourceId: 'healthwallet.me/peer',
            resourceType: resourceType,
            resourceId: resourceId,
            title: _extractTitle(resource),
            date: _extractDate(resource),
            resourceRaw: jsonEncode(resource),
            encounterId: _extractEncounterId(resource),
            subjectId: _extractSubjectId(resource),
          );

          // Create IFhirResource from DTO
          final fhirResource = IFhirResource.fromLocalDto(dto);
          resources.add(fhirResource);
        } catch (e) {
          // Skip resources that fail to parse
          continue;
        }
      }
    }
    return resources;
  }

  @override
  Future<LocalQRReceiveResult> importBundleForLocalQR({
    required Map<String, dynamic> bundle,
    required DateTime expiresAt,
  }) async {
    try {
      // Convert bundle entries to IFhirResource entities
      final resources = _convertBundleToResources(bundle);

      return LocalQRReceiveResult.success(
        resources: resources,
        expiresAt: expiresAt,
      );
    } catch (e) {
      return LocalQRReceiveResult.failure(
        'Failed to import bundle: $e',
      );
    }
  }
}

