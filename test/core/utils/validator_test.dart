import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/utils/validator.dart';

void main() {
  group('dioptreValidator', () {
    test('accepts quarter steps as prescriptions print them', () {
      for (final value in ['', '+0.75', '-1,25', '2', '+10.50', '0.00']) {
        expect(dioptreValidator(value), isNull, reason: value);
      }
    });

    test('rejects other steps, text and impossible powers', () {
      for (final value in ['+0.30', '0.250', 'abc', '+31.00', '1.2.5']) {
        expect(
          dioptreValidator(value),
          FieldValidationError.invalidDioptre,
          reason: value,
        );
      }
    });
  });

  group('axisValidator', () {
    test('accepts whole degrees from 0 to 180', () {
      for (final value in ['', '0', '90', '180']) {
        expect(axisValidator(value), isNull, reason: value);
      }
    });

    test('rejects anything else', () {
      for (final value in ['181', '-5', '45.5', 'x']) {
        expect(
          axisValidator(value),
          FieldValidationError.invalidAxis,
          reason: value,
        );
      }
    });
  });
}
