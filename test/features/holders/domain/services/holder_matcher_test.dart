import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/holders/domain/entity/holder_patient.dart';
import 'package:health_wallet/features/holders/domain/services/holder_matcher.dart';

const _clinicA = 'http://healthwallet.me/clinic/optica-exemplu-1/patient';
const _clinicB = 'http://healthwallet.me/clinic/vizual-optic-centru/patient';

HolderPatient _person(
  String rowId, {
  String system = '',
  String value = 'PA-01234',
  String sourceId = 'wallet-x',
  String given = 'Ioana',
  String family = 'Popescu',
}) => HolderPatient(
  rowId: rowId,
  resourceId: rowId,
  sourceId: sourceId,
  identifiers: [
    HolderIdentifier(
      system: system,
      value: value,
      typeCodes: system.isEmpty ? const {} : const {'MR'},
    ),
  ],
  given: given,
  family: family,
);

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

  group("a clinic's patient number", () {
    const matcher = HolderMatcher();

    test('a scan with a clinic system matches only that clinic\'s number', () {
      final stored = _person('a', system: _clinicA, sourceId: 'wallet-a');
      expect(
        matcher.sameScannedPerson(
          _person('', system: _clinicA, given: 'X', family: 'Y'),
          stored,
        ),
        isTrue,
      );
      expect(
        matcher.sameScannedPerson(
          _person('', system: _clinicB, given: 'X', family: 'Y'),
          stored,
        ),
        isFalse,
      );
    });

    test('a scan without a system still matches other numbers by value', () {
      expect(
        matcher.sameScannedPerson(
          _person('', given: 'X', family: 'Y'),
          _person('a', system: 'http://healthwallet.me/mrn'),
        ),
        isTrue,
      );
    });

    test('a scan without a system never matches a clinic\'s number', () {
      expect(
        matcher.sameScannedPerson(
          _person('', given: 'X', family: 'Y'),
          _person('a', system: _clinicA),
        ),
        isFalse,
      );
    });

    test(
      'two clinics\' same number, both saved in the app, are two people',
      () {
        final a = _person('a', system: _clinicA, sourceId: 'wallet-a');
        final b = _person(
          'b',
          system: _clinicB,
          sourceId: 'wallet-b',
          given: 'Andrei',
          family: 'Ionescu',
        );
        expect(matcher.sameIdentity(a, b), isFalse);
        expect(matcher.samePerson(a, b), isFalse);
        expect(
          matcher.sameIdentity(
            a,
            _person('c', system: _clinicA, sourceId: 'wallet-c'),
          ),
          isTrue,
        );
      },
    );

    test('a number typed in the app still counts by value', () {
      expect(
        matcher.sameIdentity(
          _person('a', system: 'urn:x', sourceId: 'wallet-a'),
          _person('b', system: 'urn:y', sourceId: 'wallet-b'),
        ),
        isTrue,
      );
    });
  });
}
