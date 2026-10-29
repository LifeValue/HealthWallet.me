import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:health_wallet/core/config/env/env.dart';
import 'package:health_wallet/core/utils/phone_formatter.dart';
import 'package:health_wallet/features/wallet_pass/data/service/emergency_qr_encoder.dart';
import 'package:health_wallet/features/wallet_pass/domain/entity/emergency_card_data.dart';
import 'package:health_wallet/features/wallet_pass/domain/entity/wallet_pass_labels.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

@injectable
class GooglePassBuilder {
  static const _serviceAccountPath =
      'assets/certs/android/service-account.json';

  /// Public URL Google Wallet downloads the pass logo from. It must stay
  /// reachable for as long as passes exist, so it points at `master`, never
  /// at a feature branch (the old branch link returned 404).
  @visibleForTesting
  static const logoUrl =
      'https://raw.githubusercontent.com/LifeValue/HealthWallet.me/master/assets/icons/app-icon.png';

  String get _issuerId => Env.googleWalletIssuerId;

  Future<String> build(
    EmergencyCardData cardData, {
    required String patientId,
    required WalletPassLabels labels,
  }) async {
    final serviceAccount = await _loadServiceAccount();
    final objectSuffix = 'emergency_${patientId}_v2';

    final genericObject = _buildGenericObject(cardData, objectSuffix, labels);

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final claims = {
      'iss': serviceAccount['client_email'],
      'aud': 'google',
      'typ': 'savetowallet',
      'iat': now,
      'origins': <String>[],
      'payload': {
        'genericObjects': [genericObject],
      },
    };

    final privateKeyPem = serviceAccount['private_key'] as String;
    return _signJwt(claims, privateKeyPem);
  }

  Map<String, dynamic> _buildGenericObject(
    EmergencyCardData cardData,
    String objectSuffix,
    WalletPassLabels labels,
  ) {
    final gender = cardData.gender != null
        ? labels.genderName(cardData.gender!)
        : null;
    // English keeps the region the pass was first published with.
    final language = labels.localeName == 'en' ? 'en-US' : labels.localeName;

    final textModules = <Map<String, String>>[];

    if (cardData.dateOfBirth != null) {
      textModules.add({
        'id': 'dob',
        'header': labels.dateOfBirth,
        'body': DateFormat.yMMMd(
          labels.localeName,
        ).format(cardData.dateOfBirth!),
      });
    }
    if (gender != null) {
      textModules.add({
        'id': 'gender',
        'header': labels.gender,
        'body': gender,
      });
    }
    if (cardData.allergies.isNotEmpty) {
      textModules.add({
        'id': 'allergies',
        'header': labels.allergies,
        'body': cardData.allergies.join(', '),
      });
    }
    if (cardData.emergencyContactPhone != null) {
      textModules.add({
        'id': 'emergency_contact',
        'header': labels.emergencyPhone,
        'body': PhoneDisplayFormatter.format(cardData.emergencyContactPhone!),
      });
    }
    if (cardData.conditions.isNotEmpty) {
      textModules.add({
        'id': 'conditions',
        'header': labels.medicalConditions,
        'body': cardData.conditions.join(', '),
      });
    }
    if (cardData.medications.isNotEmpty) {
      textModules.add({
        'id': 'medications',
        'header': labels.medications,
        'body': cardData.medications.join(', '),
      });
    }

    final subheaderParts = <String>[];
    if (gender != null) subheaderParts.add(gender);
    if (cardData.bloodType != null) subheaderParts.add(cardData.bloodType!);
    if (cardData.dateOfBirth != null) {
      final age =
          DateTime.now().difference(cardData.dateOfBirth!).inDays ~/ 365;
      subheaderParts.add(labels.age(age));
    }
    if (cardData.allergies.isNotEmpty) {
      subheaderParts.add(
        '${labels.allergies}: ${cardData.allergies.join(', ')}',
      );
    }

    final qrDeepLink = EmergencyQrEncoder.encode(cardData);

    return {
      'id': '$_issuerId.$objectSuffix',
      'classId': '$_issuerId.healthwallet_emergency_card',
      'state': 'ACTIVE',
      'cardTitle': {
        'defaultValue': {
          'language': language,
          'value': labels.cardTitle,
        },
      },
      'header': {
        'defaultValue': {
          'language': language,
          'value': cardData.patientName,
        },
      },
      'subheader': {
        'defaultValue': {
          'language': language,
          'value': subheaderParts.isNotEmpty
              ? subheaderParts.join('  •  ')
              : 'HealthWallet',
        },
      },
      'hexBackgroundColor': '#5767FF',
      'logo': {
        'sourceUri': {
          'uri': logoUrl,
        },
        'contentDescription': {
          'defaultValue': {
            'language': language,
            'value': 'HealthWallet',
          },
        },
      },
      'barcode': {
        'type': 'QR_CODE',
        'value': qrDeepLink,
        'alternateText': cardData.patientName,
      },
      'textModulesData': textModules,
    };
  }

  Future<Map<String, dynamic>> _loadServiceAccount() async {
    try {
      final jsonStr = await rootBundle.loadString(_serviceAccountPath);
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      throw Exception(
        'Google service account not found at $_serviceAccountPath. '
        'Place your service account JSON in assets/certs/android/',
      );
    }
  }

  String _signJwt(Map<String, dynamic> claims, String privateKeyPem) {
    final header = {'alg': 'RS256', 'typ': 'JWT'};

    final headerB64 = _base64UrlEncode(utf8.encode(jsonEncode(header)));
    final claimsB64 = _base64UrlEncode(utf8.encode(jsonEncode(claims)));
    final signingInput = '$headerB64.$claimsB64';

    final privateKey = _parsePrivateKeyFromPem(privateKeyPem);
    final signer = Signer('SHA-256/RSA');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    final signature = signer.generateSignature(
      Uint8List.fromList(utf8.encode(signingInput)),
    ) as RSASignature;

    final signatureB64 = _base64UrlEncode(signature.bytes);
    return '$signingInput.$signatureB64';
  }

  RSAPrivateKey _parsePrivateKeyFromPem(String pem) {
    final lines = pem
        .split('\n')
        .where((line) => !line.startsWith('-----') && line.trim().isNotEmpty)
        .join();
    final keyBytes = base64.decode(lines);

    final asn1Parser = ASN1Parser(Uint8List.fromList(keyBytes));
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;

    final privateKeyOctetString = topLevelSeq.elements![2] as ASN1OctetString;
    final privateKeyParser = ASN1Parser(privateKeyOctetString.octets!);
    final privateKeySeq = privateKeyParser.nextObject() as ASN1Sequence;

    final modulus = (privateKeySeq.elements![1] as ASN1Integer).integer!;
    final privateExponent =
        (privateKeySeq.elements![3] as ASN1Integer).integer!;
    final p = (privateKeySeq.elements![4] as ASN1Integer).integer!;
    final q = (privateKeySeq.elements![5] as ASN1Integer).integer!;

    return RSAPrivateKey(modulus, privateExponent, p, q);
  }

  String _base64UrlEncode(Uint8List bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
