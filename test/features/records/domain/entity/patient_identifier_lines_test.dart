import 'package:fhir_r4/fhir_r4.dart'
    show CodeableConcept, Coding, FhirCode, FhirString, Identifier;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';

final _en = lookupAppLocalizations(const Locale('en'));

Patient _withNhs(String value) => Patient(
  id: 'p',
  identifier: [
    Identifier(
      type: CodeableConcept(
        coding: [Coding(code: FhirCode('NH'))],
        text: FhirString('NHS Number'),
      ),
      value: FhirString(value),
    ),
  ],
);

List<String> _lines(Patient patient) => [
  for (final line in patient.additionalInfo(_en)) line.info,
];

void main() {
  test('another kind of identifier is listed with its value', () {
    expect(
      _lines(_withNhs('943 476 5919')),
      contains('NHS Number: 943 476 5919'),
    );
  });

  test('the default holder\'s placeholder is listed as a dash, not as an '
      'identifier', () {
    final lines = _lines(_withNhs('default_patient'));

    expect(lines, contains('NHS Number: -'));
    expect(lines.where((l) => l.contains('default_patient')), isEmpty);
  });
}
