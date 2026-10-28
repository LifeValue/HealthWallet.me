import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/env/env.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/utils/phone_formatter.dart';
import 'package:health_wallet/features/wallet_pass/data/service/emergency_qr_encoder.dart';
import 'package:health_wallet/features/wallet_pass/data/service/google_pass_builder.dart';
import 'package:health_wallet/features/wallet_pass/domain/entity/emergency_card_data.dart';
import 'package:health_wallet/features/wallet_pass/domain/entity/wallet_pass_labels.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'signing_test_material.dart';

const _issuerId = '3388000000012345678';
const _serviceAccountPath = 'assets/certs/android/service-account.json';
const _clientEmail = 'wallet@health-wallet-test.iam.gserviceaccount.com';

final _base64UrlNoPadding = RegExp(r'^[A-Za-z0-9_-]+$');

Map<String, dynamic> _decodeSegment(String segment) =>
    jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(segment))))
        as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SigningTestMaterial signing;
  late String originalIssuerId;

  setUpAll(() async {
    signing = SigningTestMaterial.generate();
    originalIssuerId = Env.googleWalletIssuerId;
    await initializeDateFormatting();
  });

  setUp(() {
    Env.googleWalletIssuerId = _issuerId;
    serveTestAssets({
      _serviceAccountPath: utf8.encode(
        jsonEncode({
          'type': 'service_account',
          'client_email': _clientEmail,
          'private_key': signing.pkcs8PrivateKeyPem,
        }),
      ),
    });
  });

  tearDown(() {
    clearTestAssets();
    Env.googleWalletIssuerId = originalIssuerId;
  });

  WalletPassLabels labelsFor(String locale) =>
      WalletPassLabels.fromL10n(lookupAppLocalizations(Locale(locale)));

  Future<String> build(
    EmergencyCardData card, {
    String id = 'p-1',
    String locale = 'en',
  }) => GooglePassBuilder().build(
    card,
    patientId: id,
    labels: labelsFor(locale),
  );

  Future<Map<String, dynamic>> genericObjectOf(
    EmergencyCardData card, {
    String locale = 'en',
  }) async {
    final jwt = await build(card, locale: locale);
    final claims = _decodeSegment(jwt.split('.')[1]);
    final payload = claims['payload'] as Map<String, dynamic>;
    return (payload['genericObjects'] as List).single as Map<String, dynamic>;
  }

  String localized(Map<String, dynamic> object, String key) =>
      ((object[key] as Map)['defaultValue'] as Map)['value'] as String;

  group('GooglePassBuilder.build — JWT', () {
    test('is a three-part base64url JWT without padding', () async {
      final jwt = await build(const EmergencyCardData(patientName: 'Zoë'));
      final parts = jwt.split('.');
      expect(parts, hasLength(3));
      for (final part in parts) {
        expect(part, matches(_base64UrlNoPadding));
      }
      expect(_decodeSegment(parts[0]), {'alg': 'RS256', 'typ': 'JWT'});
    });

    test('carries the save-to-wallet claims', () async {
      final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final jwt = await build(const EmergencyCardData(patientName: 'A'));
      final after = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final claims = _decodeSegment(jwt.split('.')[1]);

      expect(claims['iss'], _clientEmail);
      expect(claims['aud'], 'google');
      expect(claims['typ'], 'savetowallet');
      expect(claims['origins'], isEmpty);
      expect(claims['iat'], inInclusiveRange(before, after));
      expect((claims['payload'] as Map)['genericObjects'], hasLength(1));
    });

    test('is signed RS256 with the service-account key', () async {
      final jwt = await build(const EmergencyCardData(patientName: 'A'));
      final parts = jwt.split('.');
      final signature = base64Url.decode(base64Url.normalize(parts[2]));
      expect(signing.verifyRs256('${parts[0]}.${parts[1]}', signature), isTrue);
      expect(signing.verifyRs256('${parts[0]}.e30', signature), isFalse);
    });

    test(
      'fails with a helpful message when the service account is missing',
      () async {
        serveTestAssets({});
        await expectLater(
          build(const EmergencyCardData(patientName: 'A')),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains(
                'Google service account not found at $_serviceAccountPath',
              ),
            ),
          ),
        );
      },
    );

    test('reports malformed service-account JSON the same way', () async {
      serveTestAssets({_serviceAccountPath: utf8.encode('{not json')});
      await expectLater(
        build(const EmergencyCardData(patientName: 'A')),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Google service account not found'),
          ),
        ),
      );
    });
  });

  group('GooglePassBuilder.build — generic object', () {
    test('identifies the object by issuer and patient', () async {
      final jwt = await build(
        const EmergencyCardData(patientName: 'A'),
        id: 'pat-9',
      );
      final payload =
          _decodeSegment(jwt.split('.')[1])['payload'] as Map<String, dynamic>;
      final object = (payload['genericObjects'] as List).single as Map;
      expect(object['id'], '$_issuerId.emergency_pat-9_v2');
      expect(object['classId'], '$_issuerId.healthwallet_emergency_card');
      expect(object['state'], 'ACTIVE');
      expect(object['hexBackgroundColor'], '#5767FF');
    });

    test('carries the emergency QR as its barcode', () async {
      const card = EmergencyCardData(
        patientName: 'Zoë Doe',
        bloodType: 'B+',
        allergies: ['Latex'],
      );
      final object = await genericObjectOf(card);
      expect(object['barcode'], {
        'type': 'QR_CODE',
        'value': EmergencyQrEncoder.encode(card),
        'alternateText': 'Zoë Doe',
      });
    });

    test('titles the card and names the patient', () async {
      final object = await genericObjectOf(
        const EmergencyCardData(patientName: 'Jane'),
      );
      expect(localized(object, 'cardTitle'), 'Emergency Medical ID');
      expect(localized(object, 'header'), 'Jane');
      expect(
        ((object['cardTitle'] as Map)['defaultValue'] as Map)['language'],
        'en-US',
      );
      expect(
        ((object['logo'] as Map)['sourceUri'] as Map)['uri'],
        GooglePassBuilder.logoUrl,
      );
    });

    test('builds subheader and text modules for a full card', () async {
      final dob = DateTime.now().subtract(const Duration(days: 40 * 365 + 180));
      final card = EmergencyCardData(
        patientName: 'Jane',
        bloodType: 'AB-',
        dateOfBirth: dob,
        gender: 'female',
        allergies: const ['Penicillin', 'Latex'],
        conditions: const ['Asthma'],
        medications: const ['Insulin', 'Metformin'],
        emergencyContactPhone: '+40712345678',
      );
      final object = await genericObjectOf(card);

      expect(
        localized(object, 'subheader'),
        'Female  •  AB-  •  Age 40  •  Allergies: Penicillin, Latex',
      );
      expect(object['textModulesData'], [
        {
          'id': 'dob',
          'header': 'Date of Birth',
          'body': DateFormat('MMM d, yyyy').format(dob),
        },
        {'id': 'gender', 'header': 'Gender', 'body': 'Female'},
        {'id': 'allergies', 'header': 'Allergies', 'body': 'Penicillin, Latex'},
        {
          'id': 'emergency_contact',
          'header': 'Emergency Phone',
          'body': PhoneDisplayFormatter.format('+40712345678'),
        },
        {'id': 'conditions', 'header': 'Medical Conditions', 'body': 'Asthma'},
        {
          'id': 'medications',
          'header': 'Medications',
          'body': 'Insulin, Metformin',
        },
      ]);
    });

    test('falls back to "HealthWallet" with no text modules', () async {
      final object = await genericObjectOf(
        const EmergencyCardData(patientName: 'A'),
      );
      expect(localized(object, 'subheader'), 'HealthWallet');
      expect(object['textModulesData'], isEmpty);
    });

    final subheaders = <String, EmergencyCardData>{
      'Male': const EmergencyCardData(gender: 'male'),
      'X': const EmergencyCardData(gender: 'x'),
      'O+': const EmergencyCardData(bloodType: 'O+'),
      'Allergies: Nuts': const EmergencyCardData(allergies: ['Nuts']),
      'Unknown  •  A+': const EmergencyCardData(
        gender: 'unknown',
        bloodType: 'A+',
      ),
    };
    subheaders.forEach((expected, card) {
      test('subheader is "$expected"', () async {
        expect(localized(await genericObjectOf(card), 'subheader'), expected);
      });
    });

    test('keeps the emergency phone raw when it cannot be parsed', () async {
      final object = await genericObjectOf(
        const EmergencyCardData(emergencyContactPhone: 'call reception'),
      );
      expect(object['textModulesData'], [
        {
          'id': 'emergency_contact',
          'header': 'Emergency Phone',
          'body': 'call reception',
        },
      ]);
    });
  });

  group('GooglePassBuilder.build — German labels', () {
    final dob = DateTime(1985, 3, 14);
    final card = EmergencyCardData(
      patientName: 'Jana',
      bloodType: 'AB-',
      dateOfBirth: dob,
      gender: 'female',
      allergies: const ['Penicillin'],
      conditions: const ['Asthma'],
      medications: const ['Insulin'],
      emergencyContactPhone: '+40712345678',
    );

    test('labels every text module in German', () async {
      final object = await genericObjectOf(card, locale: 'de');
      final headers = (object['textModulesData'] as List)
          .map((m) => (m as Map)['header'])
          .toList();
      expect(headers, [
        'Geburtsdatum',
        'Geschlecht',
        'Allergien',
        'Notfalltelefon',
        'Erkrankungen',
        'Medikamente',
      ]);
    });

    test('titles the card, dates and genders in German', () async {
      final object = await genericObjectOf(card, locale: 'de');
      expect(localized(object, 'cardTitle'), 'Medizinischer Notfallausweis');
      expect(
        ((object['cardTitle'] as Map)['defaultValue'] as Map)['language'],
        'de',
      );
      final modules = {
        for (final m in object['textModulesData'] as List)
          (m as Map)['id']: m['body'],
      };
      expect(modules['dob'], DateFormat.yMMMd('de').format(dob));
      expect(modules['gender'], 'Weiblich');
      final age = DateTime.now().difference(dob).inDays ~/ 365;
      expect(
        localized(object, 'subheader'),
        'Weiblich  •  AB-  •  $age Jahre  •  Allergien: Penicillin',
      );
    });

    test('keeps the QR payload independent of the language', () async {
      final de = await genericObjectOf(card, locale: 'de');
      final en = await genericObjectOf(card);
      expect(de['barcode'], en['barcode']);
    });
  });

  test('the logo is served from master, never from a feature branch', () {
    final uri = Uri.parse(GooglePassBuilder.logoUrl);
    expect(uri.scheme, 'https');
    expect(uri.pathSegments, contains('master'));
    expect(uri.path, endsWith('/assets/icons/app-icon.png'));
  });
}
