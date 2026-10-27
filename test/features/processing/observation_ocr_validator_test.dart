import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/data/utils/observation_ocr_validator.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_observation.dart';

MappingObservation _obs(String name, String value, String unit) => MappingObservation(
      id: name,
      observationName: MappedProperty(value: name, confidenceLevel: 1),
      value: MappedProperty(value: value, confidenceLevel: 1),
      unit: MappedProperty(value: unit, confidenceLevel: 1),
    );

List<String> _names(List<Object> resources) =>
    resources.whereType<MappingObservation>().map((o) => o.observationName.value).toList();

void main() {
  final ai = [_obs('Anti-tiroglobulina', '15.1', 'UI/mL')];

  test('adds no observation from phone numbers, addresses, page footers or range rows', () {
    // Lines a 4-page Romanian lab report gave the validator on an iPhone,
    // each of which it used to add as an observation.
    const ocr = 'Telefon: 0700 654 321\n'
        'Ale Exemplului Nr 10 e2, 80 Cluj\n'
        'Pagina 1 din 4\n'
        'Trimestrul 1: 189 - 4051 pUl/mL\n'
        'Trimestrul 2: 953 – 5636 µUI/mL\n'
        'Cod doc: 2 v2.0';

    final out = ObservationOcrValidator.validate(ai, ocr);

    expect(_names(out), ['Anti-tiroglobulina']);
  });

  test('still adds a missed result line with a lab unit', () {
    const ocr = 'Hemoglobina 14.2 g/dL 12 - 16\n'
        'Vitamina B12 450 pg/mL\n'
        'TSH 4.21 µUI/mL 0.27 - 4.2\n'
        'Leucocite 6,2 x10^9/L 4 - 10\n'
        'VSH 12 mm/h < 20\n'
        'Hematocrit 41 % 36 - 46';

    final out = ObservationOcrValidator.validate(ai, ocr);

    expect(_names(out), ['Anti-tiroglobulina', 'Hemoglobina', 'Vitamina B12', 'TSH', 'Leucocite', 'VSH', 'Hematocrit']);
  });

  test('corrects an AI value from a matching result line, not from a phone number', () {
    final out = ObservationOcrValidator.validate(
      [_obs('Glucoza', '59', 'mg/dL'), _obs('Telefon', '0700', '')],
      'Glucoza 95 mg/dL 70 - 110\nTelefon 0700 654 321',
    );

    final values = {for (final o in out.whereType<MappingObservation>()) o.observationName.value: o.value.value};
    expect(values, {'Glucoza': '95', 'Telefon': '0700'});
  });
}
