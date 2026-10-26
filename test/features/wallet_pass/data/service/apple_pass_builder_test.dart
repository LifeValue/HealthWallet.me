import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/env/env.dart';
import 'package:health_wallet/core/utils/phone_formatter.dart';
import 'package:health_wallet/features/wallet_pass/data/service/apple_pass_builder.dart';
import 'package:health_wallet/features/wallet_pass/data/service/emergency_qr_encoder.dart';
import 'package:health_wallet/features/wallet_pass/domain/entity/emergency_card_data.dart';
import 'package:intl/intl.dart';
import 'package:passkit/passkit.dart';

import 'signing_test_material.dart';

const _passTypeId = 'pass.me.healthwallet.test';
const _teamId = 'TEAM123456';
const _certPath = 'assets/certs/pass_certificate.pem';
const _keyPath = 'assets/certs/private_key.pem';
const _iconPath = 'assets/icons/app-icon-transparent.png';

const _labels = ApplePassLabels(
  patient: 'L-patient',
  bloodType: 'L-blood',
  allergies: 'L-allergies',
  gender: 'L-gender',
  dateOfBirth: 'L-dob',
  emergencyPhone: 'L-ephone',
  conditions: 'L-conditions',
  medications: 'L-meds',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SigningTestMaterial signing;
  late List<int> iconBytes;
  late String originalPassTypeId;
  late String originalTeamId;

  setUpAll(() {
    signing = SigningTestMaterial.generate();
    iconBytes = File(_iconPath).readAsBytesSync();
    originalPassTypeId = Env.applePassTypeId;
    originalTeamId = Env.appleTeamId;
  });

  setUp(() {
    Env.applePassTypeId = _passTypeId;
    Env.appleTeamId = _teamId;
    serveTestAssets({
      _certPath: utf8.encode(
        signing.certificatePem(passTypeId: _passTypeId, teamId: _teamId),
      ),
      _keyPath: utf8.encode(signing.pkcs8PrivateKeyPem),
      _iconPath: iconBytes,
    });
  });

  tearDown(() {
    clearTestAssets();
    Env.applePassTypeId = originalPassTypeId;
    Env.appleTeamId = originalTeamId;
  });

  Future<PkPass> buildPass(EmergencyCardData card, {String id = 'p-1'}) async {
    final bytes = await ApplePassBuilder().build(
      card,
      patientId: id,
      labels: _labels,
    );
    return PkPass.fromBytes(bytes, skipSignatureVerification: true);
  }

  Map<String, Object?> fieldsOf(List<FieldDict>? fields) => {
    for (final f in fields ?? const <FieldDict>[]) f.key: f.value,
  };

  Map<String, String?> labelsOf(List<FieldDict>? fields) => {
    for (final f in fields ?? const <FieldDict>[]) f.key: f.label,
  };

  group('ApplePassBuilder.build', () {
    test('writes pass metadata and the emergency QR barcode', () async {
      const card = EmergencyCardData(patientName: 'Zoë Doe', bloodType: 'O-');
      final pkPass = await buildPass(card, id: 'patient-42');
      final pass = pkPass.pass;

      expect(pass.formatVersion, 1);
      expect(pass.passTypeIdentifier, _passTypeId);
      expect(pass.teamIdentifier, _teamId);
      expect(pass.serialNumber, 'emergency_patient-42');
      expect(pass.organizationName, 'HealthWallet.me');
      expect(pass.description, 'Emergency Medical ID');
      expect(pass.logoText, 'HealthWallet.me');

      final barcode = pass.barcodes!.single;
      expect(barcode.format, PkPassBarcodeType.qr);
      expect(barcode.message, EmergencyQrEncoder.encode(card));
      expect(barcode.messageEncoding, 'iso-8859-1');
      expect(barcode.altText, 'Zoë Doe');

      final json = pass.toJson();
      expect(json['foregroundColor'], '#ffffff');
      expect(json['backgroundColor'], '#5767ff');
      expect(json['labelColor'], '#c8d2ff');

      expect(pkPass.icon, isNotNull);
      expect(pkPass.logo, isNotNull);
    });

    test('lays out every field with the given labels', () async {
      final dob = DateTime.now().subtract(const Duration(days: 30 * 365 + 180));
      final card = EmergencyCardData(
        patientName: 'Jane Doe',
        bloodType: 'A+',
        dateOfBirth: dob,
        gender: 'female',
        allergies: const ['Penicillin', 'Latex'],
        conditions: const ['Asthma', 'Diabetes'],
        medications: const ['Insulin'],
        emergencyContactName: 'John Doe',
        emergencyContactPhone: '+40712345678',
      );
      final structure = (await buildPass(card)).pass.generic!;
      final age = DateTime.now().difference(dob).inDays ~/ 365;

      expect(fieldsOf(structure.primaryFields), {'patient-name': 'Jane Doe'});
      expect(fieldsOf(structure.headerFields), {'blood-type': 'A+'});
      expect(fieldsOf(structure.secondaryFields), {
        'allergies': 'Penicillin, Latex',
        'gender': 'female',
      });
      expect(fieldsOf(structure.auxiliaryFields), {
        'dob': '${DateFormat('MMM d, yyyy').format(dob)} (Age $age)',
        'emergency-contact': PhoneDisplayFormatter.format('+40712345678'),
      });
      expect(age, 30);
      expect(fieldsOf(structure.backFields), {
        'conditions': 'Asthma, Diabetes',
        'medications': 'Insulin',
      });

      expect(
        {
          ...labelsOf(structure.primaryFields),
          ...labelsOf(structure.headerFields),
          ...labelsOf(structure.secondaryFields),
          ...labelsOf(structure.auxiliaryFields),
          ...labelsOf(structure.backFields),
        },
        {
          'patient-name': 'L-patient',
          'blood-type': 'L-blood',
          'allergies': 'L-allergies',
          'gender': 'L-gender',
          'dob': 'L-dob',
          'emergency-contact': 'L-ephone',
          'conditions': 'L-conditions',
          'medications': 'L-meds',
        },
      );
    });

    test('omits empty sections for a name-only card', () async {
      final structure = (await buildPass(
        const EmergencyCardData(patientName: 'A'),
      )).pass.generic!;
      expect(fieldsOf(structure.primaryFields), {'patient-name': 'A'});
      expect(structure.headerFields, isNull);
      expect(structure.secondaryFields, isNull);
      expect(structure.auxiliaryFields, isNull);
      expect(structure.backFields, isNull);
    });

    test('fills each section from its own field only', () async {
      final structure = (await buildPass(
        const EmergencyCardData(
          patientName: 'A',
          gender: 'other',
          emergencyContactPhone: 'not a phone',
          medications: ['Aspirin'],
        ),
      )).pass.generic!;
      expect(fieldsOf(structure.secondaryFields), {'gender': 'other'});
      expect(fieldsOf(structure.auxiliaryFields), {
        'emergency-contact': 'not a phone',
      });
      expect(fieldsOf(structure.backFields), {'medications': 'Aspirin'});
      expect(structure.headerFields, isNull);
    });

    test(
      'fails with a helpful message when the certificate is missing',
      () async {
        serveTestAssets({
          _keyPath: utf8.encode(signing.pkcs8PrivateKeyPem),
          _iconPath: iconBytes,
        });
        await expectLater(
          ApplePassBuilder().build(
            const EmergencyCardData(patientName: 'A'),
            patientId: 'p',
            labels: _labels,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Certificate not found at $_certPath'),
            ),
          ),
        );
      },
    );

    test(
      'fails with a helpful message when the private key is missing',
      () async {
        serveTestAssets({
          _certPath: utf8.encode(
            signing.certificatePem(passTypeId: _passTypeId, teamId: _teamId),
          ),
          _iconPath: iconBytes,
        });
        await expectLater(
          ApplePassBuilder().build(
            const EmergencyCardData(patientName: 'A'),
            patientId: 'p',
            labels: _labels,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Certificate not found at $_keyPath'),
            ),
          ),
        );
      },
    );

    test(
      'refuses to sign when the certificate does not match the env IDs',
      () async {
        Env.appleTeamId = 'OTHERTEAM1';
        await expectLater(
          ApplePassBuilder().build(
            const EmergencyCardData(patientName: 'A'),
            patientId: 'p',
            labels: _labels,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('teamIdentifier'),
            ),
          ),
        );
      },
    );
  });
}
