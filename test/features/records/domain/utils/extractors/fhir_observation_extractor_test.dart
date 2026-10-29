import 'package:fhir_r4/fhir_r4.dart' as fhir;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/utils/extractors/fhir_observation_extractor.dart';

import '../../../../../fixtures/fhir/fhir_fixtures.dart';

/// Parses a FHIR Observation into the app entity.
Observation _obs(Map<String, dynamic> json) =>
    entityFromJson(json) as Observation;

/// Returns the parsed `value[x]` of an Observation with [value].
dynamic _value(Map<String, dynamic> value) =>
    fhir.Observation.fromJson(observationJson(value: value)).valueX;

Observation _vital(
  String code, {
  Map<String, dynamic> value = const {},
  String? display,
  String? text,
}) => _obs(
  observationJson(
    code: code,
    codeDisplay: display,
    codeText: text,
    value: value,
  ),
);

Map<String, dynamic> _interpretation(String code) => codeableConcept(
  codings: [
    coding(
      'http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation',
      code,
    ),
  ],
);

void main() {
  group('extractObservationValue', () {
    final cases = <(String, Map<String, dynamic>, String?)>[
      (
        'Quantity',
        {'valueQuantity': quantity(13.5, unit: 'g/dL', code: 'g/dL')},
        '13.50 g/dL',
      ),
      (
        'CodeableConcept text',
        {
          'valueCodeableConcept': codeableConcept(
            text: 'Positive',
            codings: [coding(snomedSystem, '10828004', 'Positive (qualifier)')],
          ),
        },
        'Positive',
      ),
      (
        'CodeableConcept display',
        {
          'valueCodeableConcept': codeableConcept(
            codings: [coding(snomedSystem, '260385009', 'Negative')],
          ),
        },
        'Negative',
      ),
      ('string', {'valueString': 'Clear, yellow'}, 'Clear, yellow'),
      ('boolean', {'valueBoolean': true}, 'true'),
      ('integer', {'valueInteger': 3}, '3'),
      (
        'Range',
        {
          'valueRange': {'low': quantity(1), 'high': quantity(2.5)},
        },
        '1.00 - 2.50',
      ),
      (
        'Ratio',
        {
          'valueRatio': {
            'numerator': quantity(1),
            'denominator': quantity(128),
          },
        },
        '1.00 / 128.00',
      ),
      ('time', {'valueTime': '10:30:00'}, '10:30:00'),
      ('dateTime', {'valueDateTime': '2024-03'}, '2024-03'),
      (
        'Period',
        {
          'valuePeriod': {'start': '2024-01-01', 'end': '2024-01-02'},
        },
        '2024-01-01 - 2024-01-02',
      ),
      (
        'SampledData (unsupported)',
        {
          'valueSampledData': {
            'origin': quantity(0),
            'period': 10,
            'dimensions': 1,
            'data': '1 2 3',
          },
        },
        null,
      ),
      ('no value', const {}, null),
    ];
    for (final (name, value, expected) in cases) {
      test('$name -> $expected', () {
        expect(
          FhirObservationExtractor.extractObservationValue(_value(value)),
          expected,
        );
      });
    }

    test('returns null for null', () {
      expect(FhirObservationExtractor.extractObservationValue(null), isNull);
    });

    test(
      'does not print "null" for a Quantity without unit',
      () {
        expect(
          FhirObservationExtractor.extractObservationValue(
            _value({'valueQuantity': quantity(7.2)}),
          ),
          '7.20',
        );
      },
    );

    test('keeps the comparator of a Quantity', () {
      expect(
        FhirObservationExtractor.extractObservationValue(
          _value({
            'valueQuantity': {
              ...quantity(60, unit: 'mL/min/1.73m2'),
              'comparator': '>',
            },
          }),
        ),
        '>60.00 mL/min/1.73m2',
      );
      expect(
        FhirObservationExtractor.extractObservationValueForRegion(
          _value({
            'valueQuantity': {
              ...quantity(20, unit: 'copies/mL'),
              'comparator': '<',
            },
          }),
          RegionPreset.europe,
        ),
        '<20.00 copies/mL',
      );
      expect(
        FhirObservationExtractor.extractObservationValueForRegion(
          _value({
            'valueQuantity': {
              ...quantity(70, unit: 'mg/dL'),
              'comparator': '<=',
            },
          }),
          RegionPreset.europe,
          codes: {'2339-0'},
        ),
        '<=3.88 mmol/L',
      );
    });

    test('falls back to the UCUM code of a Quantity without unit', () {
      expect(
        FhirObservationExtractor.extractObservationValue(
          _value({'valueQuantity': quantity(7.2, code: 'mmol/L')}),
        ),
        '7.20 mmol/L',
      );
    });

    test('returns null for a Quantity without value', () {
      expect(
        FhirObservationExtractor.extractObservationValue(
          _value({'valueQuantity': quantity(null, unit: 'mmHg')}),
        ),
        isNull,
      );
    });

    test(
      'does not print "null" for an open Range',
      () {
        expect(
          FhirObservationExtractor.extractObservationValue(
            _value({
              'valueRange': {'high': quantity(5)},
            }),
          ),
          '≤ 5.00',
        );
        expect(
          FhirObservationExtractor.extractObservationValue(
            _value({
              'valueRange': {'low': quantity(1, unit: 'mmol/L')},
            }),
          ),
          '≥ 1.00 mmol/L',
        );
      },
    );
  });

  group('convertQuantityForRegion', () {
    final cases = <(double, String, RegionPreset, double, String)>[
      (70, 'kg', RegionPreset.us, 154.3234, 'lbs'),
      (70, 'kilograms', RegionPreset.uk, 154.3234, 'lbs'),
      (70, 'kg', RegionPreset.europe, 70, 'kg'),
      (154.3234, 'lbs', RegionPreset.europe, 70, 'kg'),
      (154.3234, '[lb_av]', RegionPreset.europe, 70, 'kg'),
      (154.3234, 'lb', RegionPreset.us, 154.3234, 'lb'),
      (37, '°C', RegionPreset.us, 98.6, '°F'),
      (37, 'Cel', RegionPreset.us, 98.6, '°F'),
      (37, 'Cel', RegionPreset.uk, 37, 'Cel'),
      (98.6, '[degF]', RegionPreset.europe, 37, '°C'),
      (98.6, 'degF', RegionPreset.uk, 37, '°C'),
      (98.6, '°F', RegionPreset.us, 98.6, '°F'),
      (120, 'mmHg', RegionPreset.us, 120, 'mmHg'),
    ];
    for (final (value, unit, region, expectedValue, expectedUnit) in cases) {
      test('$value $unit in ${region.name} -> '
          '$expectedValue $expectedUnit', () {
        final result = FhirObservationExtractor.convertQuantityForRegion(
          value,
          unit,
          region,
        );
        expect(result.value, closeTo(expectedValue, 0.01));
        expect(result.unit, expectedUnit);
      });
    }

    final glucoseCases =
        <(String, double, String, RegionPreset, double, String)>[
          ('2339-0', 99.1, 'mg/dL', RegionPreset.europe, 5.5, 'mmol/L'),
          ('2345-7', 99.1, 'mg/dL', RegionPreset.uk, 5.5, 'mmol/L'),
          ('15074-8', 5.5, 'mmol/L', RegionPreset.us, 99.1, 'mg/dL'),
          ('2339-0', 5.5, 'mmol/L', RegionPreset.uk, 5.5, 'mmol/L'),
        ];
    for (final (code, value, unit, region, expectedValue, expectedUnit)
        in glucoseCases) {
      test('glucose $code $value $unit in ${region.name} -> '
          '$expectedValue $expectedUnit', () {
        final result = FhirObservationExtractor.convertQuantityForRegion(
          value,
          unit,
          region,
          codes: {code},
        );
        expect(result.value, closeTo(expectedValue, 0.01));
        expect(result.unit, expectedUnit);
      });
    }

    // Only glucose converts between mg/dL and mmol/L; the factor depends on
    // the analyte's molar mass, so any other lab stays as reported.
    final otherLabs = <(String, double, String, RegionPreset)>[
      ('2093-3', 200, 'mg/dL', RegionPreset.europe), // cholesterol
      ('17861-6', 9.5, 'mg/dL', RegionPreset.europe), // calcium
      ('2160-0', 1.0, 'mg/dL', RegionPreset.uk), // creatinine
      ('2951-2', 140, 'mmol/L', RegionPreset.us), // sodium
    ];
    for (final (code, value, unit, region) in otherLabs) {
      test('keeps $code $value $unit in ${region.name}', () {
        final result = FhirObservationExtractor.convertQuantityForRegion(
          value,
          unit,
          region,
          codes: {code},
        );
        expect(result.value, value);
        expect(result.unit, unit);
      });
    }

    test('keeps lengths that are not a body height', () {
      final lesion = FhirObservationExtractor.convertQuantityForRegion(
        2.3,
        'cm',
        RegionPreset.us,
        codes: {'21889-1'},
      );
      expect(lesion.value, 2.3);
      expect(lesion.unit, 'cm');
      final uncoded = FhirObservationExtractor.convertQuantityForRegion(
        45,
        'cm',
        RegionPreset.us,
      );
      expect(uncoded.unit, 'cm');
    });

    final heightCases = <(double, String)>[
      (175, '5\'9"'),
      (182.88, '6\'0"'),
      // 71.85 in rounds to 12 inches and must roll over to the next foot.
      (182.5, '6\'0"'),
      (152.4, '5\'0"'),
    ];
    for (final (cm, display) in heightCases) {
      test('$cm cm in US -> $display', () {
        final result = FhirObservationExtractor.convertQuantityForRegion(
          cm,
          'cm',
          RegionPreset.us,
          codes: {'8302-2'},
        );
        expect(result.unit, display);
        expect(result.value, cm);
      });
    }
  });

  test('shows a spelled-out unit in the app language', () {
    final ro = lookupAppLocalizations(const Locale('ro'));
    final heartRate = _value({
      'valueQuantity': quantity(72, unit: 'beats/min', code: '/min'),
    });
    expect(
      FhirObservationExtractor.extractObservationValue(heartRate, l10n: ro),
      '72.00 bătăi/min',
    );
    expect(
      FhirObservationExtractor.extractObservationValueForRegion(
        _value({'valueQuantity': quantity(200, unit: 'pounds')}),
        RegionPreset.us,
        l10n: ro,
      ),
      '200.00 livre',
    );
  });

  group('extractObservationValueForRegion', () {
    test('converts quantities to the regional unit', () {
      expect(
        FhirObservationExtractor.extractObservationValueForRegion(
          _value({'valueQuantity': quantity(70, unit: 'kg', code: 'kg')}),
          RegionPreset.us,
        ),
        '154.32 lbs',
      );
      expect(
        FhirObservationExtractor.extractObservationValueForRegion(
          _value({'valueQuantity': quantity(100, unit: 'mg/dL')}),
          RegionPreset.europe,
          codes: {'2339-0'},
        ),
        '5.55 mmol/L',
      );
      expect(
        FhirObservationExtractor.extractObservationValueForRegion(
          _value({'valueQuantity': quantity(37.2, unit: 'Cel')}),
          RegionPreset.us,
        ),
        '98.96 °F',
      );
    });

    test('shows a non-glucose mg/dL lab as reported', () {
      expect(
        FhirObservationExtractor.extractObservationValueForRegion(
          _value({'valueQuantity': quantity(200, unit: 'mg/dL')}),
          RegionPreset.europe,
          codes: {'2093-3'},
        ),
        '200.00 mg/dL',
      );
    });

    test('returns only the ft/in display for heights in the US', () {
      expect(
        FhirObservationExtractor.extractObservationValueForRegion(
          _value({'valueQuantity': quantity(175, unit: 'cm')}),
          RegionPreset.us,
          codes: {'8302-2'},
        ),
        '5\'9"',
      );
      expect(
        FhirObservationExtractor.extractObservationValueForRegion(
          _value({'valueQuantity': quantity(175, unit: 'centimeters')}),
          RegionPreset.europe,
          codes: {'8302-2'},
        ),
        '175.00 cm',
      );
    });

    test('keeps a length that is not a body height', () {
      expect(
        FhirObservationExtractor.extractObservationValueForRegion(
          _value({'valueQuantity': quantity(2.3, unit: 'cm')}),
          RegionPreset.us,
        ),
        '2.30 cm',
      );
    });

    test('keeps units that need no conversion', () {
      expect(
        FhirObservationExtractor.extractObservationValueForRegion(
          _value({'valueQuantity': quantity(120, unit: 'mmHg')}),
          RegionPreset.us,
        ),
        '120.00 mmHg',
      );
      expect(
        FhirObservationExtractor.extractObservationValueForRegion(
          _value({'valueQuantity': quantity(7)}),
          RegionPreset.europe,
        ),
        '7.00',
      );
    });

    test('converts pounds and inches for the Europe region', () {
      expect(
        FhirObservationExtractor.extractObservationValueForRegion(
          _value({'valueQuantity': quantity(200, unit: 'pounds')}),
          RegionPreset.europe,
        ),
        '90.72 kg',
      );
      expect(
        FhirObservationExtractor.extractObservationValueForRegion(
          _value({'valueQuantity': quantity(70, unit: 'inches')}),
          RegionPreset.europe,
          codes: {'8302-2'},
        ),
        '177.80 cm',
      );
      expect(
        FhirObservationExtractor.extractObservationValueForRegion(
          _value({'valueQuantity': quantity(70, unit: 'inches')}),
          RegionPreset.us,
          codes: {'8302-2'},
        ),
        '5\'10"',
      );
    });

    test('delegates non-quantity values to extractObservationValue', () {
      expect(
        FhirObservationExtractor.extractObservationValueForRegion(
          _value({'valueString': 'Trace'}),
          RegionPreset.us,
        ),
        'Trace',
      );
      expect(
        FhirObservationExtractor.extractObservationValueForRegion(
          null,
          RegionPreset.us,
        ),
        isNull,
      );
    });

    test(
      'does not render "null" for a Quantity without value',
      () {
        expect(
          FhirObservationExtractor.extractObservationValueForRegion(
            _value({'valueQuantity': quantity(null, unit: 'mmHg')}),
            RegionPreset.us,
          ),
          isNull,
        );
      },
    );
  });

  group('isVitalSign', () {
    test('recognises vital LOINC codes on the observation code', () {
      expect(
        FhirObservationExtractor.isVitalSign(
          _vital('8867-4', value: {'valueQuantity': quantity(72)}),
        ),
        isTrue,
      );
    });

    test('recognises a vital in a later coding', () {
      final observation = _obs({
        ...observationJson(),
        'code': codeableConcept(
          codings: [
            coding('urn:oid:1.2.3', 'LOCAL-HR'),
            {'system': 'urn:no-code'},
            loinc('8867-4', 'Heart rate'),
          ],
        ),
      });
      expect(FhirObservationExtractor.isVitalSign(observation), isTrue);
    });

    test('recognises vitals in components only', () {
      final observation = _obs({
        ...bloodPressureJson(),
        'code': codeableConcept(text: 'Blood pressure'),
      });
      expect(FhirObservationExtractor.isVitalSign(observation), isTrue);
    });

    test('returns false for labs and components without vitals', () {
      expect(
        FhirObservationExtractor.isVitalSign(
          _vital('718-7', value: {'valueQuantity': quantity(13.5)}),
        ),
        isFalse,
      );
      final observation = _obs(
        observationJson(
          components: [
            {'code': codeableConcept(text: 'no coding'), 'valueString': 'x'},
            {
              'code': codeableConcept(codings: [loinc('718-7')]),
              'valueString': 'y',
            },
          ],
        ),
      );
      expect(FhirObservationExtractor.isVitalSign(observation), isFalse);
      expect(
        FhirObservationExtractor.isVitalSign(const Observation()),
        isFalse,
      );
    });
  });

  group('extractVitalSignTitle', () {
    test('prefers code.text, then coding.display', () {
      expect(
        FhirObservationExtractor.extractVitalSignTitle(
          _vital('8867-4', display: 'Heart rate', text: 'Pulse'),
        ),
        'Pulse',
      );
      expect(
        FhirObservationExtractor.extractVitalSignTitle(
          _vital('8867-4', display: 'Heart rate'),
        ),
        'Heart rate',
      );
    });

    const titles = {
      '8867-4': 'Heart Rate',
      '85354-9': 'Blood Pressure',
      '8310-5': 'Temperature',
      '2708-6': 'Blood Oxygen',
      '29463-7': 'Weight',
      '8302-2': 'Height',
      '39156-5': 'BMI',
      '8480-6': 'Systolic Blood Pressure',
      '8462-4': 'Diastolic Blood Pressure',
      '9279-1': 'Respiratory Rate',
      '2339-0': 'Blood Glucose',
      '55284-4': 'Vital Sign',
      '718-7': 'Vital Sign',
    };
    for (final MapEntry(key: code, value: title) in titles.entries) {
      test('maps code-only $code to "$title"', () {
        expect(
          FhirObservationExtractor.extractVitalSignTitle(_vital(code)),
          title,
        );
      });
    }

    test('falls back to "Vital Sign"', () {
      expect(
        FhirObservationExtractor.extractVitalSignTitle(const Observation()),
        'Vital Sign',
      );
      final noCode = _obs({
        ...observationJson(),
        'code': codeableConcept(
          codings: [
            {'system': loincSystem},
          ],
        ),
      });
      expect(
        FhirObservationExtractor.extractVitalSignTitle(noCode),
        'Vital Sign',
      );
    });
  });

  group('extractVitalSignValue', () {
    final quantityCases = <(String, num, String)>[
      ('8867-4', 72.4, '72'),
      ('8480-6', 128.6, '129'),
      ('8462-4', 81.2, '81'),
      ('2708-6', 97.6, '98'),
      ('8310-5', 37.24, '37.2'),
      ('29463-7', 70.06, '70.1'),
      ('39156-5', 24.31, '24.3'),
      ('8302-2', 175.5, '176'),
      ('2339-0', 105.4, '105'),
      ('2339-0', 5.43, '5.4'),
      ('718-7', -120.4, '-120'),
    ];
    for (final (code, value, expected) in quantityCases) {
      test('Quantity $value for $code -> $expected', () {
        expect(
          FhirObservationExtractor.extractVitalSignValue(
            _vital(code, value: {'valueQuantity': quantity(value)}),
          ),
          expected,
        );
      });
    }

    test('uses the default rounding when the code has no coding', () {
      final observation = _obs({
        ...observationJson(value: {'valueQuantity': quantity(12.34)}),
        'code': codeableConcept(text: 'Unknown'),
      });
      expect(
        FhirObservationExtractor.extractVitalSignValue(observation),
        '12.3',
      );
    });

    final otherCases = <(String, Map<String, dynamic>, String)>[
      ('Quantity without value', {'valueQuantity': quantity(null)}, 'N/A'),
      ('string', {'valueString': '120/80'}, '120/80'),
      ('integer', {'valueInteger': 18}, '18'),
      (
        'CodeableConcept with text',
        {'valueCodeableConcept': codeableConcept(text: 'Normal')},
        'Normal',
      ),
      (
        'CodeableConcept without text',
        {
          'valueCodeableConcept': codeableConcept(
            codings: [coding(snomedSystem, '17621005', 'Normal')],
          ),
        },
        'N/A',
      ),
      ('boolean', {'valueBoolean': false}, 'N/A'),
      ('missing', const {}, 'N/A'),
    ];
    for (final (name, value, expected) in otherCases) {
      test('$name -> $expected', () {
        expect(
          FhirObservationExtractor.extractVitalSignValue(
            _vital('8867-4', value: value),
          ),
          expected,
        );
      });
    }
  });

  group('extractVitalSignUnit', () {
    test('uses the Quantity unit', () {
      expect(
        FhirObservationExtractor.extractVitalSignUnit(
          _vital(
            '8867-4',
            value: {'valueQuantity': quantity(72, unit: 'beats/min')},
          ),
        ),
        'beats/min',
      );
      expect(
        FhirObservationExtractor.extractVitalSignUnit(
          _vital('8867-4', value: {'valueQuantity': quantity(72)}),
        ),
        '',
      );
    });

    const units = {
      '8867-4': 'BPM',
      '85354-9': 'mmHg',
      '8310-5': '°F',
      '2708-6': '%',
      '29463-7': 'kg',
      '8302-2': 'cm',
      '39156-5': 'kg/m²',
      '8480-6': 'mmHg',
      '8462-4': 'mmHg',
      '9279-1': '/min',
      '2339-0': 'mg/dL',
      '718-7': '',
    };
    for (final MapEntry(key: code, value: unit) in units.entries) {
      test('maps $code without Quantity to "$unit"', () {
        expect(
          FhirObservationExtractor.extractVitalSignUnit(
            _vital(code, value: {'valueString': 'x'}),
          ),
          unit,
        );
      });
    }

    test('returns "" without code', () {
      expect(
        FhirObservationExtractor.extractVitalSignUnit(const Observation()),
        '',
      );
      final noCode = _obs({
        ...observationJson(value: {'valueString': 'x'}),
        'code': codeableConcept(
          codings: [
            {'system': loincSystem},
          ],
        ),
      });
      expect(FhirObservationExtractor.extractVitalSignUnit(noCode), '');
    });
  });

  group('extractVitalSignStatus', () {
    const statuses = {
      'H': 'High',
      'L': 'Low',
      'N': 'Normal',
      'A': 'Abnormal',
      'AA': 'Critically Abnormal',
      'HH': 'Critically High',
      'LL': 'Critically Low',
      'U': 'Uncertain',
      'R': 'Resistant',
      'I': 'Intermediate',
      'S': 'Susceptible',
      'MS': 'Moderately Susceptible',
      'VS': 'Very Susceptible',
      'POS': 'Unknown',
    };
    for (final MapEntry(key: code, value: status) in statuses.entries) {
      test('$code -> $status', () {
        final observation = _obs(
          observationJson(interpretation: [_interpretation(code)]),
        );
        expect(
          FhirObservationExtractor.extractVitalSignStatus(observation),
          status,
        );
      });
    }

    test('returns null without a coded interpretation', () {
      expect(
        FhirObservationExtractor.extractVitalSignStatus(const Observation()),
        isNull,
      );
      expect(
        FhirObservationExtractor.extractVitalSignStatus(
          _obs(observationJson(interpretation: [])),
        ),
        isNull,
      );
      expect(
        FhirObservationExtractor.extractVitalSignStatus(
          _obs(
            observationJson(interpretation: [codeableConcept(text: 'High')]),
          ),
        ),
        isNull,
      );
      expect(
        FhirObservationExtractor.extractVitalSignStatus(
          _obs(
            observationJson(
              interpretation: [
                {
                  'coding': [
                    {'display': 'High'},
                  ],
                },
              ],
            ),
          ),
        ),
        isNull,
      );
    });
  });

  group('extractInterpretation', () {
    test('joins the texts of the interpretations', () {
      final interpretations = [
        fhir.CodeableConcept.fromJson(codeableConcept(text: 'High')),
        'not a concept',
        fhir.CodeableConcept.fromJson(_interpretation('H')),
        fhir.CodeableConcept.fromJson(
          codeableConcept(
            codings: [
              coding(
                'http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation',
                'A',
                'Abnormal',
              ),
            ],
          ),
        ),
      ];
      expect(
        FhirObservationExtractor.extractInterpretation(interpretations),
        'High, Abnormal',
      );
    });

    test('returns null when nothing is readable', () {
      expect(FhirObservationExtractor.extractInterpretation(null), isNull);
      expect(FhirObservationExtractor.extractInterpretation(const []), isNull);
      expect(
        FhirObservationExtractor.extractInterpretation([
          fhir.CodeableConcept.fromJson(_interpretation('H')),
        ]),
        isNull,
      );
    });
  });

  group('extractBloodTypeFromObservations', () {
    Observation bloodType(
      Map<String, dynamic> value, {
      String code = '34530-6',
      String? display = 'ABO and Rh group [Type] in Blood',
      DateTime? date,
    }) => _obs(
      observationJson(code: code, codeDisplay: display, value: value),
    ).copyWith(date: date);

    test('returns null for an empty list', () {
      expect(
        FhirObservationExtractor.extractBloodTypeFromObservations(const []),
        isNull,
      );
    });

    test('reads valueCodeableConcept.text', () {
      expect(
        FhirObservationExtractor.extractBloodTypeFromObservations([
          bloodType({'valueCodeableConcept': codeableConcept(text: 'A+')}),
        ]),
        'A+',
      );
    });

    test('reads string values of ABO and Rh observations', () {
      expect(
        FhirObservationExtractor.extractBloodTypeFromObservations([
          bloodType({'valueString': 'O-'}, code: '883-9'),
        ]),
        'O-',
      );
      expect(
        FhirObservationExtractor.extractBloodTypeFromObservations([
          bloodType({'valueString': 'AB+'}, code: '10331-7'),
        ]),
        'AB+',
      );
    });

    test('falls back to the display of the observation coding', () {
      expect(
        FhirObservationExtractor.extractBloodTypeFromObservations([
          bloodType({
            'valueCodeableConcept': codeableConcept(text: 'see report'),
          }, display: 'B-'),
        ]),
        'B-',
      );
    });

    test('picks the most recent valid observation', () {
      final older = bloodType({'valueString': 'A+'}, date: DateTime(2010));
      final newer = bloodType({'valueString': 'B+'}, date: DateTime(2020));
      final invalid = bloodType({
        'valueString': 'pending',
      }, date: DateTime(2024));
      expect(
        FhirObservationExtractor.extractBloodTypeFromObservations([
          older,
          invalid,
          newer,
        ]),
        'B+',
      );
    });

    test('ignores non blood-type and uncoded observations', () {
      final hemoglobin = _obs(observationJson(value: {'valueString': 'A+'}));
      final textOnly = _obs({
        ...observationJson(value: {'valueString': 'A+'}),
        'code': codeableConcept(text: 'Blood type'),
      });
      final codeless = _obs({
        ...observationJson(value: {'valueString': 'A+'}),
        'code': codeableConcept(
          codings: [
            {'system': loincSystem, 'display': 'Blood type'},
          ],
        ),
      });
      expect(
        FhirObservationExtractor.extractBloodTypeFromObservations([
          hemoglobin,
          textOnly,
          codeless,
          bloodType({
            'valueCodeableConcept': codeableConcept(text: 'Unknown'),
          }, display: null),
        ]),
        isNull,
      );
    });

    test(
      'reads the coded value of valueCodeableConcept',
      () {
        expect(
          FhirObservationExtractor.extractBloodTypeFromObservations([
            bloodType({
              'valueCodeableConcept': codeableConcept(
                codings: [coding(snomedSystem, '278149003', 'A+')],
              ),
            }),
          ]),
          'A+',
        );
      },
    );

    test('reads a SNOMED blood group code without display', () {
      expect(
        FhirObservationExtractor.extractBloodTypeFromObservations([
          bloodType({
            'valueCodeableConcept': codeableConcept(
              codings: [coding(snomedSystem, '278152006')],
            ),
          }),
        ]),
        'B-',
      );
    });

    test(
      'maps SNOMED blood group displays to the short form',
      () {
        expect(
          FhirObservationExtractor.extractBloodTypeFromObservations([
            bloodType({
              'valueCodeableConcept': codeableConcept(
                text: 'Blood group A Rh(D) positive',
              ),
            }),
          ]),
          'A+',
        );
      },
    );
  });
}
