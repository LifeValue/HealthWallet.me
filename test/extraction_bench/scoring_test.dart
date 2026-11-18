import 'package:flutter_test/flutter_test.dart';

import '../../tool/extraction_bench/src/comparators.dart';
import '../../tool/extraction_bench/src/hungarian.dart';
import '../../tool/extraction_bench/src/scoring.dart';

Map<String, dynamic> _patient({
  String? family,
  String? birthDate,
  String? gender,
}) => {
  'resourceType': 'Patient',
  'name': [
    {'family': ?family},
  ],
  'birthDate': ?birthDate,
  'gender': ?gender,
};

Map<String, dynamic> _obs(
  String text,
  num? value,
  String? unit, {
  String? code,
}) => {
  'resourceType': 'Observation',
  'code': {
    if (code != null)
      'coding': [
        {'system': 'http://loinc.org', 'code': code},
      ],
    'text': text,
  },
  if (value != null) 'valueQuantity': {'value': value, 'unit': ?unit},
};

void main() {
  group('I/O matrix', () {
    test('exact match is TP 1', () {
      final s = scoreResources(
        [_patient(family: 'Müller')],
        [_patient(family: 'Müller')],
      );
      // family TP 1; the four other Patient fields are null on both sides.
      expect(s.total.tp, 5);
      expect(s.total.fp, 0);
      expect(s.total.fn, 0);
      expect(s.total.f1, 1);
    });

    test('correct null on a matched pair earns TP credit', () {
      final s = scoreResources(
        [_patient(family: 'Weiß')],
        [_patient(family: 'Weiß')],
      );
      expect(s.byType['Patient']!.tp, 5);
      expect(s.byType['Patient']!.goldNonNull, 1);
    });

    test('hallucinated field is FP 1', () {
      final s = scoreResources(
        [_patient(family: 'Bălan')],
        [_patient(family: 'Bălan', gender: 'female')],
      );
      expect(s.total.fp, 1);
      expect(s.total.hallucinated, 1);
      expect(s.total.tp, 4);
      expect(s.total.hallucinationRate, 0.5);
    });

    test('hallucinated record is FP per non-null predicted field', () {
      final s = scoreResources(
        [_obs('Hemoglobin', 13.5, 'g/dL', code: '718-7')],
        [
          _obs('Hemoglobin', 13.5, 'g/dL', code: '718-7'),
          _obs('Ferritin', 50, 'ng/mL'),
        ],
      );
      expect(s.total.tp, 2);
      expect(s.total.fp, 2);
      expect(s.total.hallucinated, 2);
      expect(s.total.fn, 0);
    });

    test('omitted field is FN 1', () {
      final s = scoreResources(
        [_patient(family: 'Popescu', birthDate: '1970-01-02')],
        [_patient(family: 'Popescu')],
      );
      expect(s.total.fn, 1);
      expect(s.total.omitted, 1);
      expect(s.total.omissionRate, 0.5);
    });

    test('omitted record is FN per non-null gold field', () {
      final s = scoreResources(
        [_obs('Glucose', 90, 'mg/dL'), _obs('Sodium', 140, 'mmol/L')],
        [_obs('Glucose', 90, 'mg/dL')],
      );
      expect(s.total.fn, 2);
      expect(s.total.omitted, 2);
      expect(s.total.tp, 2);
    });

    test('partial score s adds TP s, FP 1-s, FN 1-s', () {
      final s = scoreResources(
        [
          {
            'resourceType': 'Condition',
            'code': {'text': 'Asthma'},
            'onsetDateTime': '2019-05-12',
          },
        ],
        [
          {
            'resourceType': 'Condition',
            'code': {'text': 'Asthma'},
            'onsetDateTime': '2019',
          },
        ],
      );
      expect(s.total.tp, 1.5);
      expect(s.total.fp, 0.5);
      expect(s.total.fn, 0.5);
    });

    test('convertible units score 1', () {
      expect(
        compareQuantity(
          toQuantity({'value': 13.5, 'unit': 'g/dL', 'code': 'g/dL'})!,
          toQuantity({'value': 135, 'unit': 'g/L'})!,
        ),
        1,
      );
    });

    test('unknown unit pair scores 1 only on equal value and unit text', () {
      final gold = toQuantity({'value': 5, 'unit': 'mmol/L'})!;
      expect(
        compareQuantity(gold, toQuantity({'value': 90, 'unit': 'mg/dL'})!),
        0,
      );
      expect(
        compareQuantity(gold, toQuantity({'value': 5, 'unit': 'mg/dL'})!),
        0,
      );
      expect(
        compareQuantity(gold, toQuantity({'value': 5, 'unit': 'mmol/l'})!),
        1,
      );
      final unknown = toQuantity({'value': 3, 'unit': 'Stk'})!;
      expect(
        compareQuantity(unknown, toQuantity({'value': 3, 'unit': 'stk'})!),
        1,
      );
      expect(
        compareQuantity(unknown, toQuantity({'value': 3, 'unit': 'pcs'})!),
        0,
      );
    });

    test('a proposed pair that agrees on nothing stays unmatched', () {
      final s = scoreResources(
        [_obs('Glucose', 90, 'mg/dL')],
        [_obs('Ferritin', 400, 'ng/mL')],
      );
      expect(s.total.tp, 0);
      expect(s.total.fn, 2);
      expect(s.total.fp, 2);
    });

    test(
      'a cheap pair that agrees on nothing does not strand an agreeing pair',
      () {
        // P1–Q1 (cost 1, all-null fields free) plus P2–Q2 (cost 5) is the
        // cheapest raw assignment, yet neither pair agrees on a field; P1–Q2
        // agrees on the family name and must be the one matched.
        final p1 = _patient(family: 'Müller');
        final p2 = {
          'resourceType': 'Patient',
          'name': [
            {
              'family': 'Weiß',
              'given': ['Anna'],
            },
          ],
          'birthDate': '1980-01-01',
          'gender': 'female',
          'identifier': [
            {'value': 'X1'},
          ],
        };
        final q1 = _patient(family: 'Schmidt');
        final q2 = {
          'resourceType': 'Patient',
          'name': [
            {
              'family': 'Müller',
              'given': ['Hans'],
            },
          ],
          'birthDate': '1970-05-05',
          'gender': 'male',
          'identifier': [
            {'value': 'Z9'},
          ],
        };
        final s = scoreResources([p1, p2], [q1, q2]);
        expect(s.total.tp, 1, reason: 'Müller matched');
        expect(s.total.hallucinated, 4 + 1);
        expect(s.total.omitted, 5);
      },
    );

    test('empty predictions give F1 0 and full omission', () {
      final s = scoreResources([_obs('Glucose', 90, 'mg/dL')], const []);
      expect(s.total.f1, 0);
      expect(s.total.omissionRate, 1);
    });
  });

  group('comparators', () {
    test('text folds case, diacritics and whitespace', () {
      expect(compareText('Hemoglobină', 'HEMOGLOBINA'), 1);
      expect(compareText('Diabet  zaharat tip 2', 'diabet zaharat tip 2'), 1);
      // Extra numbers in the prediction (an ICD code printed on the page) are
      // allowed; Jaccard 4/6.
      expect(
        compareText(
          'Type 2 diabetes mellitus',
          'Type 2 diabetes mellitus (E11.9)',
        ),
        closeTo(4 / 6, 1e-9),
      );
      expect(
        compareText(
          'Type 2 diabetes mellitus (E11.9)',
          'Type 2 diabetes mellitus',
        ),
        0,
      );
      expect(compareText('Atrial fibrillation', 'fibrillation atrial'), 1);
      expect(compareText('Asthma', 'Pneumonia'), 0);
    });

    test('text needs the gold numbers, in order, in the prediction', () {
      expect(compareText('1-0-0', '1-0-1'), 0);
      expect(compareText('1-0-1', '1-0-1'), 1);
      expect(compareText('20 IE zur Nacht', '14 IE zur Nacht'), 0);
      expect(
        compareText('20 IE zur Nacht', '20 IE abends zur Nacht'),
        closeTo(4 / 5, 1e-9),
      );
      expect(
        compareText('1 tablet twice daily', '1 tablet 2 times daily'),
        0.5,
      );
      expect(compareText('Bisoprolol 5 mg', 'Bisoprolol 10 mg'), 0);
      expect(compareText('1-0-0', '1-0'), 0);
    });

    test('identifier ignores spaces and dashes', () {
      expect(compareIdentifier('+49 30 23125 123', '+49-30-23125123'), 1);
      expect(compareIdentifier('12345678Z', '12345678z'), 1);
      expect(compareIdentifier('12345678Z', '12345679Z'), 0);
      expect(compareIdentifier('030 23125123', '030/23125123'), 1);
      expect(compareIdentifier('030 23125123', '(030) 23125 123'), 1);
      expect(compareIdentifier('A.123.456', 'A123456'), 1);
    });

    test('date precision', () {
      expect(compareDate('2025-03-14', '2025-03-14T00:00:00.000+02:00'), 1);
      expect(compareDate('2019-05', '2019-05'), 1);
      expect(compareDate('2019', '2019-05-12'), 0.5);
      expect(compareDate('2019-05-12', '2019-05'), 0.5);
      expect(compareDate('2019-05-12', '2019-06'), 0);
    });

    test('set Jaccard tokenizes elements', () {
      expect(compareSet(['Ana', 'Maria'], ['Ana Maria']), 1);
      expect(compareSet(['Ana', 'Maria'], ['Ana']), 0.5);
    });

    test('concept tiers', () {
      final gold = toConcept({
        'extension': [
          {
            'url': 'alt',
            'valueCoding': {'system': 'http://loinc.org', 'code': '2339-0'},
          },
        ],
        'coding': [
          {
            'system': 'http://loinc.org',
            'code': '2345-7',
            'display': 'Glucose [Mass/volume] in Serum or Plasma',
          },
        ],
        'text': 'Glukose',
      }, alternativeUrl: 'alt')!;
      ConceptValue pred(Map<String, dynamic> m) => toConcept(m)!;
      expect(
        compareConcept(
          gold,
          pred({
            'coding': [
              {'system': 'http://loinc.org/', 'code': '2345-7'},
            ],
          }),
        ),
        1,
      );
      expect(
        compareConcept(
          gold,
          pred({
            'coding': [
              {'system': 'http://loinc.org', 'code': '2339-0'},
            ],
            'text': 'x',
          }),
        ),
        0.75,
      );
      expect(compareConcept(gold, pred({'text': 'Glukose'})), 0.5);
      expect(compareConcept(gold, pred({'text': 'Kreatinin'})), 0);
      final textOnly = toConcept({'text': 'Entlassungsbrief'})!;
      expect(compareConcept(textOnly, pred({'text': 'entlassungsbrief'})), 1);
    });

    test('quantity from strings and missing units', () {
      final gold = toQuantity({'value': 13.5, 'unit': 'g/dl', 'code': 'g/dL'})!;
      expect(compareQuantity(gold, toQuantity('13,5 g/dL')!), 1);
      expect(compareQuantity(gold, toQuantity('13,5')!), 0.5);
      expect(compareQuantity(gold, toQuantity('14')!), 0);
    });
  });

  group('UCUM', () {
    test('unit text normalization', () {
      expect(normalizeUnitText('x10^9/L'), '10*9/L');
      expect(normalizeUnitText('×10^12/l'), '10*12/L');
      expect(normalizeUnitText('µg'), 'ug');
      expect(normalizeUnitText('mg/dl'), 'mg/dL');
      expect(normalizeUnitText('°C'), 'Cel');
      expect(normalizeUnitText('mmHg'), 'mm[Hg]');
      expect(normalizeUnitText('bpm'), '/min');
      expect(normalizeUnitText('mUI/L'), 'm[IU]/L');
    });

    test('conversions', () {
      expect(convertUnit(13.5, 'g/dL', 'g/L'), closeTo(135, 1e-9));
      expect(convertUnit(1, 'mg/dL', 'mg/L'), closeTo(10, 1e-9));
      expect(convertUnit(1, 'kg', 'g'), closeTo(1000, 1e-9));
      expect(convertUnit(180, 'cm', 'm'), closeTo(1.8, 1e-9));
      expect(convertUnit(7.2, 'x10^9/L', '10*3/uL'), closeTo(7.2, 1e-9));
      expect(convertUnit(98.6, '°F', 'Cel'), closeTo(37, 1e-9));
      expect(convertUnit(37, 'Cel', '[degF]'), closeTo(98.6, 1e-9));
      expect(convertUnit(50, 'ug', 'mg'), closeTo(0.05, 1e-12));
      expect(convertUnit(5, 'mmol/L', 'mg/dL'), isNull);
      expect(convertUnit(1, 'kg/m2', 'g/cm2'), closeTo(0.1, 1e-12));
      expect(convertUnit(7.2, 'G/l', '10*9/L'), closeTo(7.2, 1e-9));
      expect(convertUnit(4.5, 'T/l', '10*12/L'), closeTo(4.5, 1e-9));
      expect(convertUnit(1, 'Mg', 'kg'), closeTo(1000, 1e-9));
      expect(convertUnit(1, 'M', 'mol/L'), isNull);
    });

    test('relative tolerance 1e-3', () {
      expect(numbersMatch(100, 100.09), isTrue);
      expect(numbersMatch(100, 100.2), isFalse);
    });
  });

  group('hungarian', () {
    double total(List<List<double>> cost, List<(int, int)> a) =>
        a.fold(0, (s, p) => s + cost[p.$1][p.$2]);

    test('square optimum', () {
      final cost = [
        [4.0, 1.0, 3.0],
        [2.0, 0.0, 5.0],
        [3.0, 2.0, 2.0],
      ];
      final a = hungarian(cost);
      expect(a, [(0, 1), (1, 0), (2, 2)]);
      expect(total(cost, a), 5);
    });

    test('wide matrix assigns every row', () {
      final cost = [
        [9.0, 2.0, 7.0, 8.0],
        [6.0, 4.0, 3.0, 7.0],
      ];
      final a = hungarian(cost);
      expect(a.length, 2);
      expect(total(cost, a), 5);
    });

    test('tall matrix assigns every column', () {
      final cost = [
        [1.0, 10.0],
        [10.0, 10.0],
        [10.0, 2.0],
      ];
      final a = hungarian(cost);
      expect(a, [(0, 0), (2, 1)]);
    });

    test('matches brute force on random matrices', () {
      var seed = 17;
      double next() {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        return (seed % 1000) / 100.0;
      }

      double brute(List<List<double>> c) {
        final n = c.length;
        var best = double.infinity;
        void go(int row, Set<int> used, double acc) {
          if (row == n) {
            if (acc < best) best = acc;
            return;
          }
          for (var j = 0; j < c[0].length; j++) {
            if (used.contains(j)) continue;
            go(row + 1, {...used, j}, acc + c[row][j]);
          }
        }

        go(0, {}, 0);
        return best;
      }

      for (var t = 0; t < 30; t++) {
        final rows = 1 + t % 4;
        final cols = rows + t % 3;
        final cost = [
          for (var i = 0; i < rows; i++)
            [for (var j = 0; j < cols; j++) next()],
        ];
        expect(total(cost, hungarian(cost)), closeTo(brute(cost), 1e-9));
      }
    });
  });
}
