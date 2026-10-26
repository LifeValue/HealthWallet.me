import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/wallet_pass/data/repository/wallet_pass_repository_impl.dart';
import 'package:health_wallet/features/wallet_pass/data/service/apple_pass_builder.dart';
import 'package:health_wallet/features/wallet_pass/data/service/google_pass_builder.dart';
import 'package:health_wallet/features/wallet_pass/domain/entity/emergency_card_data.dart';

class FakeApplePassBuilder extends Fake implements ApplePassBuilder {
  FakeApplePassBuilder(this.result);

  final Uint8List result;
  final calls = <(EmergencyCardData, String, ApplePassLabels)>[];
  Object? error;

  @override
  Future<Uint8List> build(
    EmergencyCardData cardData, {
    required String patientId,
    required ApplePassLabels labels,
  }) async {
    calls.add((cardData, patientId, labels));
    if (error != null) Error.throwWithStackTrace(error!, StackTrace.current);
    return result;
  }
}

class FakeGooglePassBuilder extends Fake implements GooglePassBuilder {
  FakeGooglePassBuilder(this.result);

  final String result;
  final calls = <(EmergencyCardData, String)>[];
  Object? error;

  @override
  Future<String> build(
    EmergencyCardData cardData, {
    required String patientId,
  }) async {
    calls.add((cardData, patientId));
    if (error != null) Error.throwWithStackTrace(error!, StackTrace.current);
    return result;
  }
}

const _card = EmergencyCardData(patientName: 'Jane', bloodType: 'A+');
const _labels = ApplePassLabels(
  patient: 'Patient',
  bloodType: 'Blood Type',
  allergies: 'Allergies',
  gender: 'Gender',
  dateOfBirth: 'Date of Birth',
  emergencyPhone: 'Emergency Phone',
  conditions: 'Conditions',
  medications: 'Medications',
);

void main() {
  late FakeApplePassBuilder apple;
  late FakeGooglePassBuilder google;
  late WalletPassRepositoryImpl repository;

  setUp(() {
    apple = FakeApplePassBuilder(Uint8List.fromList([1, 2, 3]));
    google = FakeGooglePassBuilder('header.claims.signature');
    repository = WalletPassRepositoryImpl(apple, google);
  });

  group('WalletPassRepositoryImpl', () {
    test('generateApplePass delegates to ApplePassBuilder only', () async {
      final bytes = await repository.generateApplePass(
        cardData: _card,
        patientId: 'p-1',
        labels: _labels,
      );
      expect(bytes, [1, 2, 3]);
      expect(apple.calls, [(_card, 'p-1', _labels)]);
      expect(google.calls, isEmpty);
    });

    test(
      'generateGooglePassJson delegates to GooglePassBuilder only',
      () async {
        final jwt = await repository.generateGooglePassJson(
          cardData: _card,
          patientId: 'p-2',
        );
        expect(jwt, 'header.claims.signature');
        expect(google.calls, [(_card, 'p-2')]);
        expect(apple.calls, isEmpty);
      },
    );

    test('propagates builder failures', () async {
      apple.error = Exception('no cert');
      google.error = StateError('no account');
      await expectLater(
        repository.generateApplePass(
          cardData: _card,
          patientId: 'p',
          labels: _labels,
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        repository.generateGooglePassJson(cardData: _card, patientId: 'p'),
        throwsStateError,
      );
    });
  });
}
