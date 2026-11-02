import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/holders/domain/services/holder_matcher.dart';

void main() {
  group('an identifier in scanned text', () {
    test('counts on its own, not inside a longer number or word', () {
      expect(HolderMatcher.appearsIn('55501', 'MRN: 55501, Ward 3'), isTrue);
      expect(HolderMatcher.appearsIn('55501', 'Tel. 0721555013'), isFalse);
      expect(HolderMatcher.appearsIn('55501', 'ID A55501B'), isFalse);
    });

    test('a long number counts written with separators, or without its '
        'check digit', () {
      expect(
        HolderMatcher.appearsIn('123456789', 'SSN 123-45-6789 issued'),
        isTrue,
      );
      expect(
        HolderMatcher.appearsIn('1800402123456', 'CNP 180040212345 ...'),
        isTrue,
      );
      expect(
        HolderMatcher.appearsIn('123456789', 'born 12.03.4567 89 years'),
        isFalse,
      );
    });

    test('a short number is only matched whole', () {
      expect(HolderMatcher.appearsIn('20240', 'Date 2024-05-01'), isFalse);
    });
  });

  test('normalizing drops case, spaces, dashes and diacritics', () {
    expect(HolderMatcher.normalize(' Ștefan-Ioan '), 'stefanioan');
    expect(HolderMatcher.normalize('123-45 6789'), '123456789');
  });
}
