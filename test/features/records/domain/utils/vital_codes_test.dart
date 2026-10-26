import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/records/domain/utils/vital_codes.dart';

void main() {
  test('isVitalLoinc', () {
    const vitals = [
      '8867-4',
      '85354-9',
      '55284-4',
      '8310-5',
      '2708-6',
      '29463-7',
      '8302-2',
      '39156-5',
      '8480-6',
      '8462-4',
      '9279-1',
      '2339-0',
    ];
    for (final code in vitals) {
      expect(isVitalLoinc(code), isTrue, reason: code);
    }
    for (final code in ['718-7', '883-9', '34530-6', '']) {
      expect(isVitalLoinc(code), isFalse, reason: code);
    }
  });

  test('isBpPanelCode', () {
    expect(isBpPanelCode('85354-9'), isTrue);
    expect(isBpPanelCode('55284-4'), isTrue);
    expect(isBpPanelCode('8480-6'), isFalse);
  });

  test('isBloodTypeLoinc', () {
    expect(isBloodTypeLoinc('883-9'), isTrue);
    expect(isBloodTypeLoinc('10331-7'), isTrue);
    expect(isBloodTypeLoinc('34530-6'), isTrue);
    expect(isBloodTypeLoinc('8867-4'), isFalse);
  });
}
