import 'package:fhir_r4/fhir_r4.dart' as fhir;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/records/domain/utils/extractors/fhir_temporal_extractor.dart';

import '../../../../../fixtures/fhir/fhir_fixtures.dart';

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
    final cases = <(String, fhir.Period?, String?)>[
      ('null period', null, null),
      ('empty period', _period(), null),
      (
        'same day collapses the date',
        _period(start: '2024-01-10T09:00:00Z', end: '2024-01-10T09:30:00Z'),
        'Jan 10, 2024, 9:00 AM - 9:30 AM',
      ),
      (
        'different days show both dates',
        _period(start: '2024-01-10T09:00:00Z', end: '2024-01-12T17:15:00Z'),
        'Jan 10, 2024 9:00 AM - Jan 12, 2024 5:15 PM',
      ),
      (
        'start only',
        _period(start: '2024-01-10T09:00:00Z'),
        'From Jan 10, 2024 9:00 AM',
      ),
      (
        'end only',
        _period(end: '2024-01-12T17:15:00Z'),
        'Until Jan 12, 2024 5:15 PM',
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
      skip:
          'BUG: DateTime.tryParse fails on partial FHIR dates, so a period '
          'starting "2024-03" is formatted as null instead of falling back',
    );
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
      skip: 'BUG: an open Range onset renders as "null - 50"',
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
      ('2024-03-15T10:30:00Z', 'Mar 15, 2024, 10:30 AM'),
      ('2024-03-15T22:05:00', 'Mar 15, 2024, 10:05 PM'),
      // Offsets are normalised to UTC before formatting.
      ('2024-03-15T10:30:00+02:00', 'Mar 15, 2024, 8:30 AM'),
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

    test('formatFhirInstant keeps seconds', () {
      expect(
        FhirTemporalExtractor.formatFhirInstant(
          fhir.FhirInstant.fromString('2024-03-15T12:00:07.000Z'),
        ),
        'Mar 15, 2024, 12:00:07 PM',
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
      ('2024-03-15T10:30:00Z', 'Mar 15, 2024, 10:30 AM'),
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
        'Feb 1, 2019, 8:00 AM',
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
        'From Jan 1, 2019 12:00 AM',
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
        '50.00 a',
      ),
      (
        'Range with only a low bound',
        {
          'Range': {
            'low': {'value': 40, 'unit': 'a'},
          },
        },
        '40.00 a',
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
        'May 4, 2022, 8:00 AM',
      ),
      (
        'Period',
        _performed({
          'performedPeriod': {
            'start': '2022-05-04T08:00:00Z',
            'end': '2022-05-04T09:00:00Z',
          },
        }),
        'May 4, 2022, 8:00 AM - 9:00 AM',
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
        '1.00 a',
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
        'Mar 15, 2024, 10:30 AM',
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
        'From Mar 15, 2024 10:30 AM',
      ),
      (
        'Instant',
        _effective({'effectiveInstant': '2024-03-15T10:30:15.000Z'}),
        'Mar 15, 2024, 10:30:15 AM',
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
        'Oct 1, 2023, 8:00 AM',
      ),
      (
        'Period',
        _occurrence({
          'occurrencePeriod': {'end': '2024-05-02T16:00:00Z'},
        }),
        'Until May 2, 2024 4:00 PM',
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
