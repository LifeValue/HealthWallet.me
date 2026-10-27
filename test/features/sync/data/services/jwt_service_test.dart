import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/sync/data/services/jwt_service.dart';

String _segment(Object json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

String _token(Object payload) =>
    '${_segment({'alg': 'HS256', 'typ': 'JWT'})}.${_segment(payload)}.sig';

int _epochSeconds(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

String _expiringIn(Duration d) =>
    _token({'exp': _epochSeconds(DateTime.now().add(d))});

void main() {
  group('JwtService.decodeJWT', () {
    test('returns the payload claims', () {
      expect(
        JwtService.decodeJWT(_token({'sub': 'user-1', 'exp': 1, 'n': 'Zoë'})),
        {'sub': 'user-1', 'exp': 1, 'n': 'Zoë'},
      );
    });

    test('accepts padded payload segments', () {
      final payload = base64Url.encode(utf8.encode(jsonEncode({'a': 1})));
      expect(payload, endsWith('='));
      expect(JwtService.decodeJWT('h.$payload.s'), {'a': 1});
    });

    final invalid = <String, String>{
      'empty string': '',
      'two parts': 'a.b',
      'four parts': 'a.b.c.d',
      'payload not base64': 'a.***.c',
      'payload not JSON': 'a.${base64Url.encode(utf8.encode('nope'))}.c',
      'payload not an object': 'a.${_segment([1, 2])}.c',
    };
    invalid.forEach((name, token) {
      test('returns null for $name', () {
        expect(JwtService.decodeJWT(token), isNull);
      });
    });
  });

  group('JwtService.getExpirationTime', () {
    test('reads exp as seconds since epoch', () {
      expect(
        JwtService.getExpirationTime(_token({'exp': 1700000000})),
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
    });

    final invalid = <String, String>{
      'no exp': _token({'sub': 'x'}),
      'string exp': _token({'exp': '1700000000'}),
      'fractional exp': _token({'exp': 1700000000.5}),
      'malformed token': 'garbage',
    };
    invalid.forEach((name, token) {
      test('returns null for $name', () {
        expect(JwtService.getExpirationTime(token), isNull);
      });
    });
  });

  group('JwtService expiry checks', () {
    test('a future exp is valid', () {
      final token = _expiringIn(const Duration(hours: 1));
      expect(JwtService.isExpired(token), isFalse);
      expect(JwtService.isValid(token), isTrue);
    });

    test('a past exp is expired', () {
      final token = _expiringIn(const Duration(hours: -1));
      expect(JwtService.isExpired(token), isTrue);
      expect(JwtService.isValid(token), isFalse);
    });

    test('a token without exp counts as expired', () {
      final token = _token({'sub': 'x'});
      expect(JwtService.isExpired(token), isTrue);
      expect(JwtService.isValid(token), isFalse);
    });
  });

  group('JwtService.getTimeUntilExpiration', () {
    test('is null without exp', () {
      expect(JwtService.getTimeUntilExpiration('garbage'), isNull);
    });

    test('is zero once expired', () {
      expect(
        JwtService.getTimeUntilExpiration(
          _expiringIn(const Duration(days: -3)),
        ),
        Duration.zero,
      );
    });

    test('is the remaining time before expiry', () {
      final remaining = JwtService.getTimeUntilExpiration(
        _expiringIn(const Duration(hours: 2)),
      )!;
      expect(remaining, lessThanOrEqualTo(const Duration(hours: 2)));
      expect(remaining, greaterThan(const Duration(hours: 1, minutes: 59)));
    });
  });

  group('JwtService.getExpirationDescription', () {
    final cases = <Duration, String>{
      const Duration(days: 1, hours: 1): 'Expires in 1 day',
      const Duration(days: 3, hours: 1): 'Expires in 3 days',
      const Duration(hours: 1, minutes: 5): 'Expires in 1 hour',
      const Duration(hours: 5, minutes: 5): 'Expires in 5 hours',
      const Duration(minutes: 1, seconds: 30): 'Expires in 1 minute',
      const Duration(minutes: 10, seconds: 30): 'Expires in 10 minutes',
      const Duration(seconds: 30): 'Expires in 0 minutes',
    };
    cases.forEach((remaining, expected) {
      test('"$expected" for $remaining left', () {
        expect(
          JwtService.getExpirationDescription(_expiringIn(remaining)),
          expected,
        );
      });
    });

    test('"Invalid token" without exp', () {
      expect(JwtService.getExpirationDescription('a.b'), 'Invalid token');
    });

    // getTimeUntilExpiration clamps to zero, so the "Expired … ago" branch is
    // unreachable and an expired token reads as expiring in 0 minutes.
    test(
      'describes an expired token as "Expires in 0 minutes" (known gap)',
      () {
        expect(
          JwtService.getExpirationDescription(
            _expiringIn(const Duration(days: -2)),
          ),
          'Expires in 0 minutes',
        );
      },
    );
  });
}
