import 'package:fhir_r4/fhir_r4.dart' as fhir;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/domain/utils/extractors/fhir_temporal_extractor.dart';

import '../../../../../fixtures/fhir/fhir_fixtures.dart';
import '../../../../../fixtures/local_time.dart';

fhir.Period _period({String? start, String? end}) => fhir.Period.fromJson({
  'start': ?start,
  'end': ?end,
});

fhir.FhirDateTime _dt(String value) => fhir.FhirDateTime.fromString(value);

/// Parses a Condition and returns its `onset[x]`.
dynamic _onset(Map<String, dynamic> onset) =>
    fhir.Condition.fromJson(conditionJson(onset: onset)).onsetX;

/// Parses a Condition and returns its `abatement[x]`.
dynamic _abatement(Map<String, dynamic> abatement) =>
    fhir.Condition.fromJson(conditionJson(abatement: abatement)).abatementX;

/// Parses a Procedure and returns its `performed[x]`.
dynamic _performed(Map<String, dynamic> performed) {
  final json = procedureJson()..remove('performedPeriod');
  return fhir.Procedure.fromJson({...json, ...performed}).performedX;
}

/// Parses an Observation and returns its `effective[x]`.
dynamic _effective(Map<String, dynamic> effective) => fhir.Observation.fromJson(
  {...observationJson(effectiveDateTime: null), ...effective},
).effectiveX;

/// Parses a ServiceRequest and returns its `occurrence[x]`.
dynamic _occurrence(Map<String, dynamic> occurrence) =>
    fhir.ServiceRequest.fromJson({
      ...minimalResources()['ServiceRequest']!,
      ...occurrence,
    }).occurrenceX;

/// A primitive with no value, only a data-absent-reason extension.
const _dataAbsent = {
  '_value': {
    'extension': [
      {
        'url': 'http://hl7.org/fhir/StructureDefinition/data-absent-reason',
        'valueCode': 'unknown',
      },
    ],
  },
};

const _age45 = {'value': 45, 'unit': 'a', 'system': ucumSystem, 'code': 'a'};

void main() {
  group('extractPeriod', () {
    final cases = <(fhir.Period?, String?)>[
      (null, null),
      (_period(), null),
      (
        _period(start: '2024-01-10T09:00:00Z', end: '2024-01-12'),
        '2024-01-10T09:00:00Z - 2024-01-12',
      ),
      (_period(start: '2024-03'), 'From 2024-03'),
      (_period(end: '2024'), 'Until 2024'),
    ];
    for (final (period, expected) in cases) {
      test('-> $expected', () {
        expect(FhirTemporalExtractor.extractPeriod(period), expected);
      });
    }

    test('extractPeriodStart / extractPeriodEnd', () {
      final period = _period(start: '2024-01-10', end: '2024-01-12');
      expect(FhirTemporalExtractor.extractPeriodStart(period), '2024-01-10');
      expect(FhirTemporalExtractor.extractPeriodEnd(period), '2024-01-12');
      expect(FhirTemporalExtractor.extractPeriodStart(null), isNull);
      expect(FhirTemporalExtractor.extractPeriodEnd(_period()), isNull);
    });
  });

  group('extractPeriodFormatted', () {
    // Whether a period is on one day depends on the user's time zone, not on
    // the UTC dates it is recorded in: 23:30Z-00:30Z is one day in Romania,
    // 21:30Z-22:30Z spans two there. Off UTC, both cases differ from the
    // UTC answer.
    for (final (start, end) in [
      ('2024-01-10T23:30:00Z', '2024-01-11T00:30:00Z'),
      ('2024-01-10T21:30:00Z', '2024-01-10T22:30:00Z'),
    ]) {
      test('$start - $end collapses only when it is one local day', () {
        final sameLocalDay = localDate(start) == localDate(end);
        expect(
          FhirTemporalExtractor.extractPeriodFormatted(
            _period(start: start, end: end),
          ),
          sameLocalDay
              ? '${localDateTime(start)} - ${localTime(end)}'
              : '${localDateTime(start, separator: ' ')} - '
                    '${localDateTime(end, separator: ' ')}',
        );
      });
    }

    final cases = <(String, fhir.Period?, String?)>[
      ('null period', null, null),
      ('empty period', _period(), null),
      (
        'same day collapses the date',
        _period(start: '2024-01-10T09:00:00Z', end: '2024-01-10T09:30:00Z'),
        '${localDateTime('2024-01-10T09:00:00Z')} - '
            '${localTime('2024-01-10T09:30:00Z')}',
      ),
      (
        'different days show both dates',
        _period(start: '2024-01-10T09:00:00Z', end: '2024-01-12T17:15:00Z'),
        '${localDateTime('2024-01-10T09:00:00Z', separator: ' ')} - '
            '${localDateTime('2024-01-12T17:15:00Z', separator: ' ')}',
      ),
      (
        'start only',
        _period(start: '2024-01-10T09:00:00Z'),
        'From ${localDateTime('2024-01-10T09:00:00Z', separator: ' ')}',
      ),
      (
        'end only',
        _period(end: '2024-01-12T17:15:00Z'),
        'Until ${localDateTime('2024-01-12T17:15:00Z', separator: ' ')}',
      ),
    ];
    for (final (name, period, expected) in cases) {
      test(name, () {
        expect(FhirTemporalExtractor.extractPeriodFormatted(period), expected);
      });
    }

    test(
      'keeps partial dates instead of dropping them',
      () {
        expect(
          FhirTemporalExtractor.extractPeriodFormatted(
            _period(start: '2024-03'),
          ),
          'From 2024-03',
        );
      },
    );
  });

  group('extractPeriodFormatted partial dates', () {
    test('an end-only partial date is shown as recorded', () {
      expect(
        FhirTemporalExtractor.extractPeriodFormatted(_period(end: '2024')),
        'Until 2024',
      );
    });

    test('a mixed full and partial period falls back to both raw bounds', () {
      expect(
        FhirTemporalExtractor.extractPeriodFormatted(
          _period(start: '2024-03', end: '2024-04-02T10:00:00Z'),
        ),
        '2024-03 - 2024-04-02T10:00:00Z',
      );
    });

    test('a partial date keeps the translated From and Until', () {
      final de = lookupAppLocalizations(const Locale('de'));
      expect(
        FhirTemporalExtractor.extractPeriodFormatted(
          _period(start: '2024-03'),
          l10n: de,
        ),
        'Ab 2024-03',
      );
      expect(
        FhirTemporalExtractor.extractPeriodFormatted(
          _period(end: '2024'),
          l10n: de,
        ),
        de.untilDate('2024'),
      );
    });

    test('a full start with a partial end falls back to both raw bounds', () {
      expect(
        FhirTemporalExtractor.extractPeriodFormatted(
          _period(start: '2024-04-02T10:00:00Z', end: '2025'),
        ),
        '2024-04-02T10:00:00Z - 2025',
      );
    });
  });

  group('open ranges on onset and abatement', () {
    test('an onset Range without a high bound keeps its direction', () {
      expect(
        FhirTemporalExtractor.extractOnsetX(
          _onset({
            'onsetRange': {
              'low': {'value': 40, 'unit': 'a'},
            },
          }),
        ),
        '≥ 40',
      );
    });

    test('an abatement Range without a low bound keeps its direction', () {
      expect(
        FhirTemporalExtractor.extractAbatementX(
          _abatement({
            'abatementRange': {
              'high': {'value': 50, 'unit': 'a'},
            },
          }),
        ),
        '≤ 50',
      );
    });

    test('an empty Range is null', () {
      expect(
        FhirTemporalExtractor.extractAbatementX(
          _abatement({
            'abatementRange': {
              'low': {'unit': 'a'},
            },
          }),
        ),
        isNull,
      );
      expect(
        FhirTemporalExtractor.extractOnsetX(
          _onset({
            'onsetRange': {
              'high': {'unit': 'a'},
            },
          }),
        ),
        isNull,
      );
    });
  });

  group('extractOnsetX / extractAbatementX', () {
    final cases = <(String, Map<String, dynamic>, String?)>[
      ('dateTime', {'DateTime': '2019-02-01'}, '2019-02-01'),
      ('partial dateTime', {'DateTime': '2019'}, '2019'),
      ('Age', {'Age': _age45}, '45 a'),
      (
        'Age without unit',
        {
          'Age': {'value': 3},
        },
        '3 years',
      ),
      (
        'Age without value',
        {
          'Age': {'unit': 'a'},
        },
        null,
      ),
      (
        'Age with an empty unit',
        {
          'Age': {'value': 3, 'unit': ' '},
        },
        '3 years',
      ),
      (
        'Period',
        {
          'Period': {'start': '2019-01-01', 'end': '2019-06-01'},
        },
        '2019-01-01 - 2019-06-01',
      ),
      (
        'Range',
        {
          'Range': {
            'low': {'value': 40, 'unit': 'a'},
            'high': {'value': 50, 'unit': 'a'},
          },
        },
        '40 - 50',
      ),
      ('string', {'String': 'childhood'}, 'childhood'),
    ];

    for (final (name, suffixes, expected) in cases) {
      final key = suffixes.keys.single;
      final value = suffixes.values.single;
      test('onset $name -> $expected', () {
        expect(
          FhirTemporalExtractor.extractOnsetX(_onset({'onset$key': value})),
          expected,
        );
      });
      test('abatement $name -> $expected', () {
        expect(
          FhirTemporalExtractor.extractAbatementX(
            _abatement({'abatement$key': value}),
          ),
          expected,
        );
      });
    }

    test('return null for null and unsupported types', () {
      expect(FhirTemporalExtractor.extractOnsetX(null), isNull);
      expect(FhirTemporalExtractor.extractAbatementX(null), isNull);
      expect(
        FhirTemporalExtractor.extractOnsetX(fhir.FhirBoolean(true)),
        isNull,
      );
      expect(
        FhirTemporalExtractor.extractAbatementX(fhir.FhirBoolean(true)),
        isNull,
      );
    });

    test(
      'a Range without a low bound does not print "null"',
      () {
        final onset = _onset({
          'onsetRange': {
            'high': {'value': 50, 'unit': 'a'},
          },
        });
        expect(
          FhirTemporalExtractor.extractOnsetX(onset),
          isNot(contains('null')),
        );
      },
    );
  });

  group('extractPerformedX / extractEffectiveX / extractOccurrenceX', () {
    test('performed[x]', () {
      expect(FhirTemporalExtractor.extractPerformedX(null), isNull);
      expect(
        FhirTemporalExtractor.extractPerformedX(
          _performed({'performedDateTime': '2022-05-04T08:00:00Z'}),
        ),
        '2022-05-04T08:00:00Z',
      );
      expect(
        FhirTemporalExtractor.extractPerformedX(
          _performed({
            'performedPeriod': {'start': '2022-05-04'},
          }),
        ),
        'From 2022-05-04',
      );
      expect(
        FhirTemporalExtractor.extractPerformedX(
          _performed({'performedString': 'last summer'}),
        ),
        isNull,
      );
    });

    test('effective[x]', () {
      expect(FhirTemporalExtractor.extractEffectiveX(null), isNull);
      expect(
        FhirTemporalExtractor.extractEffectiveX(
          _effective({'effectiveDateTime': '2024-03'}),
        ),
        '2024-03',
      );
      expect(
        FhirTemporalExtractor.extractEffectiveX(
          _effective({
            'effectivePeriod': {'end': '2024-03-16'},
          }),
        ),
        'Until 2024-03-16',
      );
      expect(
        FhirTemporalExtractor.extractEffectiveX(
          _effective({'effectiveInstant': '2024-03-15T10:30:00.000Z'}),
        ),
        startsWith('2024-03-15T10:30:00'),
      );
      expect(
        FhirTemporalExtractor.extractEffectiveX(
          _effective({
            'effectiveTiming': {'code': codeableConcept(text: 'BID')},
          }),
        ),
        isNull,
      );
    });

    test('occurrence[x]', () {
      expect(FhirTemporalExtractor.extractOccurrenceX(null), isNull);
      expect(
        FhirTemporalExtractor.extractOccurrenceX(
          fhir.Immunization.fromJson(immunizationJson()).occurrenceX,
        ),
        '2023-10-01T08:00:00Z',
      );
      expect(
        FhirTemporalExtractor.extractOccurrenceX(
          fhir.Immunization.fromJson({
            ...immunizationJson()..remove('occurrenceDateTime'),
            'occurrenceString': 'Fall 2023',
          }).occurrenceX,
        ),
        'Fall 2023',
      );
      expect(
        FhirTemporalExtractor.extractOccurrenceX(
          _occurrence({
            'occurrencePeriod': {'start': '2024-05-01', 'end': '2024-05-02'},
          }),
        ),
        '2024-05-01 - 2024-05-02',
      );
      expect(
        FhirTemporalExtractor.extractOccurrenceX(
          _occurrence({
            'occurrenceTiming': {'code': codeableConcept(text: 'Weekly')},
          }),
        ),
        isNull,
      );
    });
  });

  group('extractDateTime', () {
    test('handles every date-like type and falls back to toString', () {
      expect(FhirTemporalExtractor.extractDateTime(null), isNull);
      expect(FhirTemporalExtractor.extractDateTime(_dt('2024-03')), '2024-03');
      expect(
        FhirTemporalExtractor.extractDateTime(
          fhir.FhirDate.fromString('1985-07-14'),
        ),
        '1985-07-14',
      );
      expect(
        FhirTemporalExtractor.extractDateTime(
          fhir.FhirInstant.fromString('2024-03-15T10:30:00.000Z'),
        ),
        startsWith('2024-03-15T10:30:00'),
      );
      expect(
        FhirTemporalExtractor.extractDateTime(
          _period(start: '2024-01-01', end: '2024-01-02'),
        ),
        '2024-01-01 - 2024-01-02',
      );
      expect(
        FhirTemporalExtractor.extractDateTime(fhir.FhirString('yesterday')),
        'yesterday',
      );
    });
  });

  group('formatFhirDateTime / formatFhirDate / formatFhirInstant', () {
    final dateTimeCases = <(String, String)>[
      // A time in UTC or with an offset is shown in the phone's time zone.
      ('2024-03-15T10:30:00Z', localDateTime('2024-03-15T10:30:00Z')),
      ('2024-03-15T10:30:00+02:00', localDateTime('2024-03-15T10:30:00+02:00')),
      // A time without an offset is already local.
      ('2024-03-15T22:05:00', 'Mar 15, 2024, 10:05 PM'),
      // A date-only value is shown with a synthetic midnight time.
      ('2024-03-15', 'Mar 15, 2024, 12:00 AM'),
      // Partial dates cannot be parsed and are returned verbatim.
      ('2024-03', '2024-03'),
      ('2024', '2024'),
    ];
    for (final (input, expected) in dateTimeCases) {
      test('formatFhirDateTime($input) -> $expected', () {
        expect(FhirTemporalExtractor.formatFhirDateTime(_dt(input)), expected);
      });
    }

    final dateCases = <(String, String)>[
      ('1985-07-14', 'Jul 14, 1985'),
      ('1985-07', '1985-07'),
      ('1985', '1985'),
    ];
    for (final (input, expected) in dateCases) {
      test('formatFhirDate($input) -> $expected', () {
        expect(
          FhirTemporalExtractor.formatFhirDate(fhir.FhirDate.fromString(input)),
          expected,
        );
      });
    }

    test('formatFhirInstant keeps seconds, in local time', () {
      expect(
        FhirTemporalExtractor.formatFhirInstant(
          fhir.FhirInstant.fromString('2024-03-15T12:00:07.000Z'),
        ),
        localDateTime('2024-03-15T12:00:07.000Z', withSeconds: true),
      );
    });

    test('an instant saved in UTC is shown at the local hour it happened', () {
      // An attachment saved at 17:17 in Bucharest is stored as 15:17 UTC
      // and must show 5:17 PM there, not 3:17 PM.
      final savedAt = DateTime(2026, 10, 29, 17, 17, 3);
      expect(
        FhirTemporalExtractor.formatFhirInstant(
          fhir.FhirInstant.fromDateTime(savedAt.toUtc()),
        ),
        'Oct 29, 2026, 5:17:03 PM',
      );
    });

    test('return null for null or value-less primitives', () {
      expect(FhirTemporalExtractor.formatFhirDateTime(null), isNull);
      expect(FhirTemporalExtractor.formatFhirDate(null), isNull);
      expect(FhirTemporalExtractor.formatFhirInstant(null), isNull);
      expect(
        FhirTemporalExtractor.formatFhirDateTime(
          fhir.FhirDateTime.fromJson(_dataAbsent),
        ),
        isNull,
      );
      expect(
        FhirTemporalExtractor.formatFhirDate(
          fhir.FhirDate.fromJson(_dataAbsent),
        ),
        isNull,
      );
      expect(
        FhirTemporalExtractor.formatFhirInstant(
          fhir.FhirInstant.fromJson(_dataAbsent),
        ),
        isNull,
      );
    });
  });

  group('formatDateTimeString', () {
    final cases = <(String?, String?)>[
      (null, null),
      ('', null),
      ('2024-03-15', 'Mar 15, 2024'),
      ('2024-03-15T10:30:00Z', localDateTime('2024-03-15T10:30:00Z')),
      ('2024-03-15 18:45', 'Mar 15, 2024, 6:45 PM'),
      ('2024-03', '2024-03'),
      ('not a date', 'not a date'),
    ];
    for (final (input, expected) in cases) {
      test('$input -> $expected', () {
        expect(FhirTemporalExtractor.formatDateTimeString(input), expected);
      });
    }
  });

  group('extractOnsetXFormatted / extractAbatementXFormatted', () {
    final cases = <(String, Map<String, dynamic>, String?)>[
      (
        'dateTime',
        {'DateTime': '2019-02-01T08:00:00Z'},
        localDateTime('2019-02-01T08:00:00Z'),
      ),
      ('Age', {'Age': _age45}, '45 a'),
      (
        'Age without value',
        {
          'Age': {'unit': 'a'},
        },
        null,
      ),
      (
        'Age without unit',
        {
          'Age': {'value': 7},
        },
        '7 years',
      ),
      (
        'Period',
        {
          'Period': {'start': '2019-01-01T00:00:00Z'},
        },
        'From ${localDateTime('2019-01-01T00:00:00Z', separator: ' ')}',
      ),
      (
        'Range',
        {
          'Range': {
            'low': {'value': 40, 'unit': 'a'},
            'high': {'value': 50, 'unit': 'a'},
          },
        },
        '40.00 a - 50.00 a',
      ),
      (
        'Range with only a high bound',
        {
          'Range': {
            'high': {'value': 50, 'unit': 'a'},
          },
        },
        '≤ 50.00 a',
      ),
      (
        'Range with only a low bound',
        {
          'Range': {
            'low': {'value': 40, 'unit': 'a'},
          },
        },
        '≥ 40.00 a',
      ),
      ('string', {'String': 'adolescence'}, 'adolescence'),
    ];

    for (final (name, suffixes, expected) in cases) {
      final key = suffixes.keys.single;
      final value = suffixes.values.single;
      test('onset $name -> $expected', () {
        expect(
          FhirTemporalExtractor.extractOnsetXFormatted(
            _onset({'onset$key': value}),
          ),
          expected,
        );
      });
      test('abatement $name -> $expected', () {
        expect(
          FhirTemporalExtractor.extractAbatementXFormatted(
            _abatement({'abatement$key': value}),
          ),
          expected,
        );
      });
    }

    test('abatement boolean renders Yes / No', () {
      expect(
        FhirTemporalExtractor.extractAbatementXFormatted(
          fhir.FhirBoolean(true),
        ),
        'Yes',
      );
      expect(
        FhirTemporalExtractor.extractAbatementXFormatted(
          fhir.FhirBoolean(false),
        ),
        'No',
      );
    });

    test('return null for null and unsupported types', () {
      expect(FhirTemporalExtractor.extractOnsetXFormatted(null), isNull);
      expect(FhirTemporalExtractor.extractAbatementXFormatted(null), isNull);
      expect(
        FhirTemporalExtractor.extractOnsetXFormatted(fhir.FhirBoolean(true)),
        isNull,
      );
      expect(
        FhirTemporalExtractor.extractAbatementXFormatted(fhir.FhirInteger(1)),
        isNull,
      );
    });
  });

  group('extractPerformedXFormatted', () {
    final cases = <(String, dynamic, String?)>[
      ('null', null, null),
      (
        'dateTime',
        _performed({'performedDateTime': '2022-05-04T08:00:00Z'}),
        localDateTime('2022-05-04T08:00:00Z'),
      ),
      (
        'Period',
        _performed({
          'performedPeriod': {
            'start': '2022-05-04T08:00:00Z',
            'end': '2022-05-04T09:00:00Z',
          },
        }),
        '${localDateTime('2022-05-04T08:00:00Z')} - '
            '${localTime('2022-05-04T09:00:00Z')}',
      ),
      ('string', _performed({'performedString': 'last summer'}), 'last summer'),
      ('Age', _performed({'performedAge': _age45}), '45 a'),
      (
        'Age without value',
        _performed({
          'performedAge': {'unit': 'a'},
        }),
        null,
      ),
      (
        'Range',
        _performed({
          'performedRange': {
            'low': {'value': 1, 'unit': 'a'},
            'high': {'value': 2, 'unit': 'a'},
          },
        }),
        '1.00 a - 2.00 a',
      ),
      (
        'open Range',
        _performed({
          'performedRange': {
            'low': {'value': 1, 'unit': 'a'},
          },
        }),
        '≥ 1.00 a',
      ),
      (
        'Range with only a high bound',
        _performed({
          'performedRange': {
            'high': {'value': 2, 'unit': 'a'},
          },
        }),
        '≤ 2.00 a',
      ),
      (
        'empty Range',
        _performed({
          'performedRange': {
            'low': {'unit': 'a'},
          },
        }),
        null,
      ),
      ('unsupported', fhir.FhirBoolean(true), null),
    ];
    for (final (name, value, expected) in cases) {
      test('$name -> $expected', () {
        expect(
          FhirTemporalExtractor.extractPerformedXFormatted(value),
          expected,
        );
      });
    }
  });

  group('extractEffectiveXFormatted', () {
    final cases = <(String, dynamic, String?)>[
      ('null', null, null),
      (
        'dateTime',
        _effective({'effectiveDateTime': '2024-03-15T10:30:00Z'}),
        localDateTime('2024-03-15T10:30:00Z'),
      ),
      (
        'partial dateTime',
        _effective({'effectiveDateTime': '2024-03'}),
        '2024-03',
      ),
      (
        'Period',
        _effective({
          'effectivePeriod': {'start': '2024-03-15T10:30:00Z'},
        }),
        'From ${localDateTime('2024-03-15T10:30:00Z', separator: ' ')}',
      ),
      (
        'Instant',
        _effective({'effectiveInstant': '2024-03-15T10:30:15.000Z'}),
        localDateTime('2024-03-15T10:30:15.000Z', withSeconds: true),
      ),
      (
        'Timing with code',
        _effective({
          'effectiveTiming': {
            'code': codeableConcept(
              codings: [
                coding(
                  'http://terminology.hl7.org/CodeSystem/v3-GTSAbbreviation',
                  'BID',
                  'Twice a day',
                ),
              ],
            ),
          },
        }),
        'Twice a day',
      ),
      (
        'Timing without code',
        _effective({
          'effectiveTiming': {
            'event': ['2024-03-15T10:30:00Z'],
          },
        }),
        null,
      ),
    ];
    for (final (name, value, expected) in cases) {
      test('$name -> $expected', () {
        expect(
          FhirTemporalExtractor.extractEffectiveXFormatted(value),
          expected,
        );
      });
    }
  });

  group('extractOccurrenceXFormatted', () {
    final cases = <(String, dynamic, String?)>[
      ('null', null, null),
      (
        'dateTime',
        fhir.Immunization.fromJson(immunizationJson()).occurrenceX,
        localDateTime('2023-10-01T08:00:00Z'),
      ),
      (
        'Period',
        _occurrence({
          'occurrencePeriod': {'end': '2024-05-02T16:00:00Z'},
        }),
        'Until ${localDateTime('2024-05-02T16:00:00Z', separator: ' ')}',
      ),
      (
        'string',
        fhir.Immunization.fromJson({
          ...immunizationJson()..remove('occurrenceDateTime'),
          'occurrenceString': 'Fall 2023',
        }).occurrenceX,
        'Fall 2023',
      ),
      (
        'Timing with code',
        _occurrence({
          'occurrenceTiming': {'code': codeableConcept(text: 'Weekly')},
        }),
        'Weekly',
      ),
      (
        'Timing without code',
        _occurrence({
          'occurrenceTiming': {
            'event': ['2024-03-15T10:30:00Z'],
          },
        }),
        null,
      ),
    ];
    for (final (name, value, expected) in cases) {
      test('$name -> $expected', () {
        expect(
          FhirTemporalExtractor.extractOccurrenceXFormatted(value),
          expected,
        );
      });
    }
  });
}
