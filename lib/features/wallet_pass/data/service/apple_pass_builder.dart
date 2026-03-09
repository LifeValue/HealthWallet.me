import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:csslib/parser.dart' as css;
import 'package:passkit/passkit.dart';
import 'package:health_wallet/core/config/env/env.dart';
import 'package:health_wallet/features/wallet_pass/data/service/emergency_qr_encoder.dart';
import 'package:health_wallet/features/wallet_pass/domain/entity/emergency_card_data.dart';

@injectable
class ApplePassBuilder {
  static const _certPath = 'assets/certs/pass_certificate.pem';
  static const _keyPath = 'assets/certs/private_key.pem';

  Future<Uint8List> build(EmergencyCardData cardData, {required String patientId}) async {
    final certificatePem = await _loadAssetString(_certPath);
    final privateKeyPem = await _loadAssetString(_keyPath);

    final iconBytes = await _loadAssetBytes('assets/icons/app-icon-transparent.png');
    final icon = PkImage(image1: iconBytes);

    final emergencyDeepLink = EmergencyQrEncoder.encode(cardData);

    final passData = PassData(
      formatVersion: 1,
      passTypeIdentifier: Env.applePassTypeId,
      serialNumber: 'emergency_$patientId',
      teamIdentifier: Env.appleTeamId,
      organizationName: 'HealthWallet.me',
      description: 'Emergency Medical ID',
      foregroundColor: css.Color.createRgba(255, 255, 255),
      backgroundColor: css.Color.createRgba(87, 103, 255),
      labelColor: css.Color.createRgba(200, 210, 255),
      logoText: 'HealthWallet.me',
      generic: _buildPassStructure(cardData),
      barcodes: [
        Barcode(
          format: PkPassBarcodeType.qr,
          message: emergencyDeepLink,
          messageEncoding: 'iso-8859-1',
          altText: cardData.patientName,
        ),
      ],
    );
    final pkPass = PkPass(
      pass: passData,
      icon: icon,
      logo: icon,
    );

    final bytes = pkPass.write(
      certificatePem: certificatePem,
      privateKeyPem: privateKeyPem,
    );

    if (bytes == null) {
      throw Exception('Failed to generate signed .pkpass file');
    }

    return bytes;
  }

  PassStructure _buildPassStructure(EmergencyCardData cardData) {
    final primaryFields = <FieldDict>[
      FieldDict(key: 'patient-name', label: 'Patient', value: cardData.patientName),
    ];

    final headerFields = <FieldDict>[];
    if (cardData.bloodType != null) {
      headerFields.add(
        FieldDict(key: 'blood-type', label: 'Blood Type', value: cardData.bloodType!),
      );
    }

    final secondaryFields = <FieldDict>[];
    if (cardData.dateOfBirth != null) {
      final age = DateTime.now().difference(cardData.dateOfBirth!).inDays ~/ 365;
      secondaryFields.add(
        FieldDict(
          key: 'dob',
          label: 'Date of Birth',
          value: '${DateFormat('MMM d, yyyy').format(cardData.dateOfBirth!)} (Age $age)',
        ),
      );
    }
    if (cardData.gender != null) {
      secondaryFields.add(
        FieldDict(key: 'gender', label: 'Gender', value: cardData.gender!),
      );
    }

    final auxiliaryFields = <FieldDict>[];
    if (cardData.allergies.isNotEmpty) {
      auxiliaryFields.add(
        FieldDict(key: 'allergies', label: 'Allergies', value: cardData.allergies.join(', ')),
      );
    }
    if (cardData.patientPhone != null) {
      auxiliaryFields.add(
        FieldDict(key: 'phone', label: 'Phone', value: cardData.patientPhone!),
      );
    }
    if (cardData.emergencyContactName != null) {
      final contactValue = cardData.emergencyContactPhone != null
          ? '${cardData.emergencyContactName!} (${cardData.emergencyContactPhone!})'
          : cardData.emergencyContactName!;
      auxiliaryFields.add(
        FieldDict(key: 'emergency-contact', label: 'Emergency Contact', value: contactValue),
      );
    }

    final backFields = <FieldDict>[];
    if (cardData.conditions.isNotEmpty) {
      backFields.add(
        FieldDict(key: 'conditions', label: 'Conditions', value: cardData.conditions.join(', ')),
      );
    }
    if (cardData.medications.isNotEmpty) {
      backFields.add(
        FieldDict(key: 'medications', label: 'Medications', value: cardData.medications.join(', ')),
      );
    }

    return PassStructure(
      primaryFields: primaryFields,
      headerFields: headerFields.isEmpty ? null : headerFields,
      secondaryFields: secondaryFields.isEmpty ? null : secondaryFields,
      auxiliaryFields: auxiliaryFields.isEmpty ? null : auxiliaryFields,
      backFields: backFields.isEmpty ? null : backFields,
    );
  }

  Future<String> _loadAssetString(String path) async {
    try {
      return await rootBundle.loadString(path);
    } catch (_) {
      throw Exception(
        'Certificate not found at $path. '
        'Place your Apple Developer signing files in assets/certs/',
      );
    }
  }

  Future<Uint8List> _loadAssetBytes(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }
}
