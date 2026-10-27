import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/wallet_pass/data/service/emergency_qr_encoder.dart';
import 'package:health_wallet/features/wallet_pass/domain/entity/emergency_card_data.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

// Contract tests for the emergency QR payload.
//
// The QR on every Apple/Google wallet pass encodes the URL built by
// EmergencyQrEncoder.encode. It is opened by the live page docs/index.html
// (emergency.healthwallet.me), whose <script> is mirrored by [PageDecoder]
// below, and forwarded to the app as healthwallet://emergency?<same query>,
// which EmergencyQrEncoder.decode reads. Passes already in users' wallets keep
// their QR, so a change that breaks these tests breaks printed passes.

/// Dart port of the <script> in docs/index.html.
///
/// Query parsing follows URLSearchParams (application/x-www-form-urlencoded:
/// `+` is a space, percent escapes are UTF-8, a key without `=` has the value
/// '' and `get` returns the first value). The `data=` branch follows the
/// page's `atob`, which yields one char per byte (Latin-1), then JSON.parse.
class PageDecoder {
  static PageResult decode(String url) {
    final params = _searchParams(Uri.parse(url).query);
    String? get(String key) {
      for (final entry in params) {
        if (entry.key == key) return entry.value;
      }
      return null;
    }

    bool truthy(String? v) => v != null && v.isNotEmpty;

    final raw = get('data');
    if (truthy(raw)) {
      try {
        var padded = raw!;
        while (padded.length % 4 != 0) {
          padded += '=';
        }
        final bytes = base64.decode(
          padded.replaceAll('-', '+').replaceAll('_', '/'),
        );
        final json = String.fromCharCodes(bytes);
        final m = jsonDecode(json) as Map<String, dynamic>;
        List<String> list(Object? v) =>
            v == null ? const [] : (v as List).cast<String>();
        final d = m['d'] as String?;
        return PageResult.card(
          name: m['n'] as String?,
          blood: m['b'] as String?,
          dob: truthy(d) ? _formatDateIso(d!) : null,
          gender: m['g'] as String?,
          phone: m['p'] as String?,
          allergies: list(m['a']),
          conditions: list(m['c']),
          meds: list(m['m']),
          ecName: m['en'] as String?,
          ecPhone: m['ep'] as String?,
        );
      } catch (_) {
        return const PageResult.invalidData();
      }
    }
    if (truthy(get('name'))) {
      return PageResult.card(
        name: get('name'),
        blood: get('blood'),
        dob: get('dob'),
        gender: get('gender'),
        phone: get('phone'),
        allergies: _splitList(get('allergies')),
        conditions: _splitList(get('conditions')),
        meds: _splitList(get('meds')),
        ecName: get('ec_name'),
        ecPhone: get('ec_phone'),
      );
    }
    return const PageResult.noData();
  }

  static List<MapEntry<String, String>> _searchParams(String query) => [
    for (final pair in query.split('&'))
      if (pair.isNotEmpty) _pair(pair),
  ];

  static MapEntry<String, String> _pair(String pair) {
    final i = pair.indexOf('=');
    final key = i < 0 ? pair : pair.substring(0, i);
    final value = i < 0 ? '' : pair.substring(i + 1);
    return MapEntry(
      Uri.decodeQueryComponent(key),
      Uri.decodeQueryComponent(value),
    );
  }

  static List<String> _splitList(String? v) =>
      v == null || v.isEmpty ? const [] : v.split(', ');

  static String _formatDateIso(String s) {
    final x = s.split('-');
    return x.length == 3 ? '${x[1]}/${x[2]}/${x[0]}' : s;
  }
}

enum PageOutcome { card, noData, invalidData }

class PageResult {
  const PageResult.card({
    this.name,
    this.blood,
    this.dob,
    this.gender,
    this.phone,
    this.allergies = const [],
    this.conditions = const [],
    this.meds = const [],
    this.ecName,
    this.ecPhone,
  }) : outcome = PageOutcome.card;

  const PageResult.noData()
    : outcome = PageOutcome.noData,
      name = null,
      blood = null,
      dob = null,
      gender = null,
      phone = null,
      allergies = const [],
      conditions = const [],
      meds = const [],
      ecName = null,
      ecPhone = null;

  const PageResult.invalidData()
    : outcome = PageOutcome.invalidData,
      name = null,
      blood = null,
      dob = null,
      gender = null,
      phone = null,
      allergies = const [],
      conditions = const [],
      meds = const [],
      ecName = null,
      ecPhone = null;

  final PageOutcome outcome;
  final String? name;
  final String? blood;
  final String? dob;
  final String? gender;
  final String? phone;
  final List<String> allergies;
  final List<String> conditions;
  final List<String> meds;
  final String? ecName;
  final String? ecPhone;

  /// The heading the page renders (`esc(d.name||'Unknown')`).
  String get displayedName => name == null || name!.isEmpty ? 'Unknown' : name!;
}

/// Base64url without padding of the UTF-8 JSON, the `?data=` format both
/// decoders accept.
String dataParam(Map<String, Object?> json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

final fullCard = EmergencyCardData(
  patientName: 'Doe, John',
  bloodType: 'A+',
  dateOfBirth: DateTime(1985, 3, 7),
  gender: 'male',
  patientPhone: '+40 712 345 678',
  allergies: const ['Penicillin', 'Peanuts'],
  conditions: const ['Asthma'],
  medications: const ['Salbutamol 100mcg', 'Ibuprofen'],
  emergencyContactName: 'Jane Doe',
  emergencyContactPhone: '+1 (555) 010-9999',
);

void main() {
  group('EmergencyQrEncoder.encode — URL shape', () {
    test('pins the exact URL for a fully populated card', () {
      expect(
        EmergencyQrEncoder.encode(fullCard),
        'https://emergency.healthwallet.me/'
        '?name=Doe%2C+John'
        '&blood=A%2B'
        '&dob=03%2F07%2F1985'
        '&gender=male'
        '&phone=%2B40+712+345+678'
        '&allergies=Penicillin%2C+Peanuts'
        '&conditions=Asthma'
        '&meds=Salbutamol+100mcg%2C+Ibuprofen'
        '&ec_name=Jane+Doe'
        '&ec_phone=%2B1+%28555%29+010-9999',
      );
    });

    test('a name-only card carries just the name parameter', () {
      expect(
        EmergencyQrEncoder.encode(const EmergencyCardData(patientName: 'Ana')),
        'https://emergency.healthwallet.me/?name=Ana',
      );
    });

    test('uses the legacy query format, never ?data=', () {
      final uri = Uri.parse(EmergencyQrEncoder.encode(fullCard));
      expect(uri.scheme, 'https');
      expect(uri.host, 'emergency.healthwallet.me');
      expect(uri.path, '/');
      expect(uri.fragment, isEmpty);
      expect(uri.queryParameters.containsKey('data'), isFalse);
      expect(uri.queryParameters.keys, [
        'name',
        'blood',
        'dob',
        'gender',
        'phone',
        'allergies',
        'conditions',
        'meds',
        'ec_name',
        'ec_phone',
      ]);
    });

    final omittedWhenNull = <String, EmergencyCardData>{
      'blood': fullCard.copyWith(bloodType: null),
      'dob': fullCard.copyWith(dateOfBirth: null),
      'gender': fullCard.copyWith(gender: null),
      'phone': fullCard.copyWith(patientPhone: null),
      'allergies': fullCard.copyWith(allergies: const []),
      'conditions': fullCard.copyWith(conditions: const []),
      'meds': fullCard.copyWith(medications: const []),
      'ec_name': fullCard.copyWith(emergencyContactName: null),
      'ec_phone': fullCard.copyWith(emergencyContactPhone: null),
    };
    omittedWhenNull.forEach((key, card) {
      test('omits "$key" when the field is null or the list is empty', () {
        final params = Uri.parse(EmergencyQrEncoder.encode(card))
            .queryParameters
            .keys
            .toList();
        expect(params, isNot(contains(key)));
        expect(params, hasLength(9));
        expect(params.first, 'name');
      });
    });

    test('always includes name, as a bare key when it is empty', () {
      expect(
        EmergencyQrEncoder.encode(const EmergencyCardData()),
        'https://emergency.healthwallet.me/?name',
      );
    });

    test('keeps empty-string optional fields as bare keys', () {
      expect(
        EmergencyQrEncoder.encode(
          const EmergencyCardData(patientName: 'A', bloodType: '', gender: ''),
        ),
        'https://emergency.healthwallet.me/?name=A&blood&gender',
      );
    });

    test('joins list items with ", "', () {
      const card = EmergencyCardData(
        patientName: 'A',
        allergies: ['x', 'y', 'z'],
      );
      expect(
        Uri.parse(EmergencyQrEncoder.encode(card)).queryParameters['allergies'],
        'x, y, z',
      );
    });

    test('emits only ASCII (the Apple barcode is declared iso-8859-1)', () {
      const card = EmergencyCardData(
        patientName: 'Zoë Ștefănescu 李小龍 🚑',
        allergies: ['Pénicilline'],
        emergencyContactName: 'Ñandú',
      );
      final url = EmergencyQrEncoder.encode(card);
      expect(url.codeUnits.every((c) => c < 0x80), isTrue);
      expect(url, contains('name=Zo%C3%AB+%C8%98tef%C4%83nescu+'));
    });

    test('percent-encodes every query delimiter', () {
      final url = EmergencyQrEncoder.encode(
        const EmergencyCardData(patientName: "a&b=c#d?e/f+g%h'i"),
      );
      expect(
        url,
        'https://emergency.healthwallet.me/'
        '?name=a%26b%3Dc%23d%3Fe%2Ff%2Bg%25h%27i',
      );
    });
  });

  group('EmergencyQrEncoder.encode — date of birth', () {
    final dates = <DateTime, String>{
      DateTime(1985, 3, 7): '03/07/1985',
      DateTime(2000, 12, 31): '12/31/2000',
      DateTime(1999, 1, 1, 23, 59, 59): '01/01/1999',
      DateTime.utc(1970, 6, 15, 22): '06/15/1970',
      DateTime(5, 2, 3): '02/03/0005',
    };
    dates.forEach((date, expected) {
      test('formats $date as $expected (MM/dd/yyyy, zero padded)', () {
        final url = EmergencyQrEncoder.encode(
          EmergencyCardData(patientName: 'A', dateOfBirth: date),
        );
        expect(Uri.parse(url).queryParameters['dob'], expected);
      });
    });

    for (final locale in ['de', 'es', 'ro', 'en']) {
      test('does not depend on Intl.defaultLocale ($locale)', () async {
        await initializeDateFormatting(locale);
        final previous = Intl.defaultLocale;
        Intl.defaultLocale = locale;
        addTearDown(() => Intl.defaultLocale = previous);
        final url = EmergencyQrEncoder.encode(
          EmergencyCardData(
            patientName: 'A',
            dateOfBirth: DateTime(1985, 3, 7),
          ),
        );
        expect(Uri.parse(url).queryParameters['dob'], '03/07/1985');
      });
    }
  });

  group('docs/index.html decodes what the encoder produces', () {
    test('renders every field of a full card', () {
      final page = PageDecoder.decode(EmergencyQrEncoder.encode(fullCard));
      expect(page.outcome, PageOutcome.card);
      expect(page.displayedName, 'Doe, John');
      expect(page.blood, 'A+');
      expect(page.dob, '03/07/1985');
      expect(page.gender, 'male');
      expect(page.phone, '+40 712 345 678');
      expect(page.allergies, ['Penicillin', 'Peanuts']);
      expect(page.conditions, ['Asthma']);
      expect(page.meds, ['Salbutamol 100mcg', 'Ibuprofen']);
      expect(page.ecName, 'Jane Doe');
      expect(page.ecPhone, '+1 (555) 010-9999');
    });

    final texts = <String>[
      'Zoë Ștefănescu',
      '李小龍',
      'Ambulance 🚑',
      "O'Brien & Sons = 100% #1?",
      'a+b c',
      '   leading and trailing   ',
      'line\nbreak',
    ];
    for (final text in texts) {
      test('round-trips ${jsonEncode(text)} through the page', () {
        final card = EmergencyCardData(
          patientName: text,
          emergencyContactName: text,
          medications: [text],
        );
        final page = PageDecoder.decode(EmergencyQrEncoder.encode(card));
        expect(page.name, text);
        expect(page.ecName, text);
        expect(page.meds, [text]);
      });
    }

    test('missing optional fields come back null or empty', () {
      final page = PageDecoder.decode(
        EmergencyQrEncoder.encode(const EmergencyCardData(patientName: 'A')),
      );
      expect(page.outcome, PageOutcome.card);
      expect(page.blood, isNull);
      expect(page.dob, isNull);
      expect(page.allergies, isEmpty);
      expect(page.ecPhone, isNull);
    });

    // Known gaps, kept visible so a fix updates the test deliberately.
    test('an empty patient name is shown as "No Data" (known gap)', () {
      final page = PageDecoder.decode(
        EmergencyQrEncoder.encode(
          const EmergencyCardData(bloodType: 'O-', allergies: ['Latex']),
        ),
      );
      expect(page.outcome, PageOutcome.noData);
    });

    test('a list item containing ", " is split in two (known gap)', () {
      final page = PageDecoder.decode(
        EmergencyQrEncoder.encode(
          const EmergencyCardData(
            patientName: 'A',
            allergies: ['Penicillin, severe', 'Latex'],
          ),
        ),
      );
      expect(page.allergies, ['Penicillin', 'severe', 'Latex']);
    });
  });

  group('EmergencyQrEncoder.decode — legacy query format', () {
    test('round-trips a full card', () {
      expect(
        EmergencyQrEncoder.decode(EmergencyQrEncoder.encode(fullCard)),
        fullCard,
      );
    });

    test('reads the app deep link the page forwards to', () {
      final query = Uri.parse(EmergencyQrEncoder.encode(fullCard)).query;
      expect(
        EmergencyQrEncoder.decode('healthwallet://emergency?$query'),
        fullCard,
      );
    });

    test('round-trips unicode and delimiter characters', () {
      const card = EmergencyCardData(
        patientName: 'Zoë & 李 = 100%',
        emergencyContactPhone: '+40 (712) 345-678',
        conditions: ['Type 1 diabetes', 'Épilepsie'],
      );
      expect(EmergencyQrEncoder.decode(EmergencyQrEncoder.encode(card)), card);
    });

    test('defaults every field when the query is empty', () {
      expect(
        EmergencyQrEncoder.decode('https://emergency.healthwallet.me/'),
        const EmergencyCardData(),
      );
    });

    test('treats empty list parameters as empty lists', () {
      final card = EmergencyQrEncoder.decode(
        'https://emergency.healthwallet.me/?name=A&allergies=&meds',
      );
      expect(card.allergies, isEmpty);
      expect(card.medications, isEmpty);
    });

    final dobs = <String, DateTime?>{
      '03/07/1985': DateTime(1985, 3, 7),
      '12/31/2000': DateTime(2000, 12, 31),
      '1985-03-07': DateTime(1985, 3, 7),
      'not-a-date': null,
    };
    dobs.forEach((raw, expected) {
      test('parses dob "$raw" as $expected', () {
        final card = EmergencyQrEncoder.decode(
          'https://emergency.healthwallet.me/'
          '?name=A&dob=${Uri.encodeQueryComponent(raw)}',
        );
        expect(card.dateOfBirth, expected);
      });
    });
  });

  group('EmergencyQrEncoder.decode — ?data= base64url format', () {
    final fullJson = <String, Object?>{
      'n': 'Zoë Doe',
      'b': 'AB-',
      'd': '1985-03-07',
      'g': 'female',
      'p': '+40 712 345 678',
      'a': ['Penicillin'],
      'c': ['Asthma', 'Epilepsy'],
      'm': ['Insulin'],
      'en': 'Jon Doe',
      'ep': '+1 555 0100',
    };
    const fullData = EmergencyCardData(
      patientName: 'Zoë Doe',
      bloodType: 'AB-',
      gender: 'female',
      patientPhone: '+40 712 345 678',
      allergies: ['Penicillin'],
      conditions: ['Asthma', 'Epilepsy'],
      medications: ['Insulin'],
      emergencyContactName: 'Jon Doe',
      emergencyContactPhone: '+1 555 0100',
    );

    test('reads every short key', () {
      final card = EmergencyQrEncoder.decode(
        'https://emergency.healthwallet.me/?data=${dataParam(fullJson)}',
      );
      expect(card, fullData.copyWith(dateOfBirth: DateTime(1985, 3, 7)));
    });

    test('takes precedence over legacy parameters, as on the page', () {
      final url =
          'https://emergency.healthwallet.me/'
          '?name=Legacy&data=${dataParam({'n': 'FromData'})}';
      expect(EmergencyQrEncoder.decode(url).patientName, 'FromData');
      expect(PageDecoder.decode(url).name, 'FromData');
    });

    // Payload lengths 1..4 cover every padding remainder (0, 2, 3, 1 '=').
    for (final name in ['A', 'AB', 'ABC', 'ABCD', 'ABCDE']) {
      test('accepts unpadded payloads ("$name")', () {
        final param = dataParam({'n': name});
        expect(param, isNot(contains('=')));
        expect(EmergencyQrEncoder.decodeFromDataParam(param).patientName, name);
        expect(PageDecoder.decode('https://x/?data=$param').name, name);
      });
    }

    test('accepts already padded payloads', () {
      final padded = base64Url.encode(utf8.encode(jsonEncode({'n': 'AB'})));
      expect(padded, endsWith('='));
      expect(EmergencyQrEncoder.decodeFromDataParam(padded).patientName, 'AB');
    });

    test('uses the url-safe alphabet (- and _)', () {
      // '?>?' encodes to 'Pz4_' in base64url ('Pz4/' in plain base64).
      final param = dataParam({'n': '??>>?'});
      expect(param, anyOf(contains('_'), contains('-')));
      expect(
        EmergencyQrEncoder.decodeFromDataParam(param).patientName,
        '??>>?',
      );
      expect(PageDecoder.decode('https://x/?data=$param').name, '??>>?');
    });

    test('defaults absent keys', () {
      expect(
        EmergencyQrEncoder.decodeFromDataParam(dataParam({})),
        const EmergencyCardData(),
      );
    });

    test('treats explicit nulls as absent', () {
      expect(
        EmergencyQrEncoder.decodeFromDataParam(
          dataParam({'n': null, 'a': null, 'd': null, 'b': null}),
        ),
        const EmergencyCardData(),
      );
    });

    test('accepts a full ISO timestamp in "d"', () {
      final card = EmergencyQrEncoder.decodeFromDataParam(
        dataParam({'d': '1985-03-07T10:20:30Z'}),
      );
      expect(card.dateOfBirth, DateTime.utc(1985, 3, 7, 10, 20, 30));
    });

    test('ignores an unparseable "d"', () {
      final card = EmergencyQrEncoder.decodeFromDataParam(
        dataParam({'n': 'A', 'd': '07/03/1985'}),
      );
      expect(card.dateOfBirth, isNull);
      expect(card.patientName, 'A');
    });

    test('the page reformats "d" as MM/DD/YYYY', () {
      final page = PageDecoder.decode(
        'https://x/?data=${dataParam({'n': 'A', 'd': '1985-03-07'})}',
      );
      expect(page.dob, '03/07/1985');
    });

    test('throws on malformed base64', () {
      expect(
        () => EmergencyQrEncoder.decodeFromDataParam('***'),
        throwsFormatException,
      );
      expect(
        PageDecoder.decode('https://x/?data=***').outcome,
        PageOutcome.invalidData,
      );
    });

    test('throws on base64 that is not JSON', () {
      final param = base64Url.encode(utf8.encode('not json'));
      expect(
        () => EmergencyQrEncoder.decodeFromDataParam(param),
        throwsFormatException,
      );
      expect(
        PageDecoder.decode('https://x/?data=$param').outcome,
        PageOutcome.invalidData,
      );
    });

    test('throws on JSON that is not an object', () {
      final param = base64Url.encode(utf8.encode('[1,2]'));
      expect(
        () => EmergencyQrEncoder.decodeFromDataParam(param),
        throwsA(isA<TypeError>()),
      );
    });

    test(
      'the app decodes non-ASCII data= text as UTF-8, the page does not',
      () {
        // docs/index.html runs JSON.parse(atob(...)) without a UTF-8 decode, so
        // non-ASCII text in a data= payload only renders correctly in the app.
        final param = dataParam({'n': 'Zoë'});
        expect(
          EmergencyQrEncoder.decodeFromDataParam(param).patientName,
          'Zoë',
        );
        expect(PageDecoder.decode('https://x/?data=$param').name, 'ZoÃ«');
      },
    );
  });
}
