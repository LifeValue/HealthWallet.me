import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/utils/phone_formatter.dart';

void main() {
  test('a full number shows with its country code and grouped digits', () {
    expect(PhoneDisplayFormatter.format('+447700900123'), '+44 7700 900123');
  });

  test('no number, or only spaces, shows nothing', () {
    expect(PhoneDisplayFormatter.format(null), '');
    expect(PhoneDisplayFormatter.format('  '), '');
  });

  test('a country code without a number shows nothing', () {
    expect(PhoneDisplayFormatter.format('+40'), '');
  });

  test('text that is not a phone number shows as it was saved', () {
    expect(PhoneDisplayFormatter.format('call the clinic'), 'call the clinic');
  });
}
