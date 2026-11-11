import 'dart:convert';

import 'package:fhir_r4/fhir_r4.dart'
    show
        AdministrativeGender,
        CodeableConcept,
        Coding,
        FhirBoolean,
        FhirCode,
        FhirString,
        HumanName,
        Identifier,
        Reference;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:intl/date_symbol_data_local.dart';

final _en = lookupAppLocalizations(const Locale('en'));

/// An Epic-style patient: `_given` carries extensions the FHIR parser
/// rejects.
Map<String, dynamic> _epicPatient() => {
  'resourceType': 'Patient',
  'id': 'pat-1',
  'active': true,
  'gender': 'male',
  'name': [
    {
      'family': 'Pop',
      'given': ['Ana'],
      '_given': [
        {
          'extension': [
            {'url': 'http://epic.com/extension/initial', 'valueBoolean': 1},
          ],
        },
      ],
    },
  ],
  'generalPractitioner': [
    {'reference': 'Practitioner/gp-1', 'display': 'Dr. Ion'},
    {'reference': 'Practitioner/gp-2', 'display': 'Dr. Maria'},
  ],
  'managingOrganization': {
    'reference': 'Organization/org-1',
    'display': 'City Clinic',
  },
};

Identifier _identifier(
  String value, {
  String? code,
  String? display,
  String? text,
}) => Identifier(
  type: CodeableConcept(
    coding: [
      Coding(code: code == null ? null : FhirCode(code), display: display?.f),
    ],
    text: text?.f,
  ),
  value: FhirString(value),
);

extension on String {
  FhirString get f => FhirString(this);
}

List<String> _lines(Patient patient) => [
  for (final line in patient.additionalInfo(_en)) line.info,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => initializeDateFormatting('en'));

  group('building', () {
    test('from local data reads the row and the resource, without the '
        'extensions that break parsing', () {
      final patient = Patient.fromLocalData(
        FhirResourceLocalDto(
          id: 'row-1',
          sourceId: 'src-1',
          resourceType: 'Patient',
          resourceId: 'pat-1',
          title: 'Ana Pop',
          date: DateTime(2024, 3, 1),
          resourceRaw: jsonEncode(_epicPatient()),
          encounterId: 'enc-1',
          subjectId: 'pat-1',
          specialtyOverride: 'cardiology',
        ),
      );

      expect(patient.id, 'row-1');
      expect(patient.sourceId, 'src-1');
      expect(patient.resourceId, 'pat-1');
      expect(patient.title, 'Ana Pop');
      expect(patient.date, DateTime(2024, 3, 1));
      expect(patient.encounterId, 'enc-1');
      expect(patient.subjectId, 'pat-1');
      expect(patient.specialtyOverride, 'cardiology');
      expect(patient.name!.first.family?.valueString, 'Pop');
      expect(patient.rawResource['name'][0].containsKey('_given'), isFalse);
      expect(patient.gender, AdministrativeGender.male);
      expect(patient.fhirType, FhirType.Patient);
    });

    test('from local data defaults what the row leaves out', () {
      final patient = Patient.fromLocalData(
        FhirResourceLocalDto(
          id: 'row-1',
          resourceRaw: jsonEncode({'resourceType': 'Patient'}),
        ),
      );

      expect(patient.sourceId, isEmpty);
      expect(patient.resourceId, isEmpty);
      expect(patient.title, isEmpty);
      expect(patient.encounterId, isEmpty);
      expect(patient.subjectId, isEmpty);
    });

    test('from a sync DTO reads every field, without the extensions that '
        'break parsing', () {
      final patient = Patient.fromDto(
        FhirResourceDto(
          id: 'row-1',
          sourceId: 'src-1',
          resourceType: 'Patient',
          resourceId: 'pat-1',
          title: 'Ana Pop',
          date: DateTime(2024, 3, 1),
          resourceRaw: _epicPatient(),
          encounterId: 'enc-1',
          subjectId: 'pat-1',
        ),
      );

      expect(patient.id, 'row-1');
      expect(patient.sourceId, 'src-1');
      expect(patient.resourceId, 'pat-1');
      expect(patient.title, 'Ana Pop');
      expect(patient.date, DateTime(2024, 3, 1));
      expect(patient.encounterId, 'enc-1');
      expect(patient.subjectId, 'pat-1');
      expect(patient.active?.valueBoolean, isTrue);
      expect(patient.generalPractitioner, hasLength(2));
      expect(patient.managingOrganization?.display?.valueString, 'City Clinic');
      expect(patient.rawResource['name'][0].containsKey('_given'), isFalse);
    });

    test('from an empty sync DTO is an empty patient', () {
      final patient = Patient.fromDto(const FhirResourceDto());

      expect(patient.id, isEmpty);
      expect(patient.sourceId, isEmpty);
      expect(patient.resourceId, isEmpty);
      expect(patient.title, isEmpty);
      expect(patient.encounterId, isEmpty);
      expect(patient.subjectId, isEmpty);
      expect(patient.rawResource, isEmpty);
    });

    test('back to a DTO keeps the row and the resource', () {
      final patient = Patient.fromDto(
        FhirResourceDto(
          id: 'row-1',
          sourceId: 'src-1',
          resourceId: 'pat-1',
          title: 'Ana Pop',
          date: DateTime(2024, 3, 1),
          resourceRaw: _epicPatient(),
          encounterId: 'enc-1',
          subjectId: 'pat-1',
        ),
      );

      final dto = patient.toDto();

      expect(dto.id, 'row-1');
      expect(dto.sourceId, 'src-1');
      expect(dto.resourceType, 'Patient');
      expect(dto.resourceId, 'pat-1');
      expect(dto.title, 'Ana Pop');
      expect(dto.date, DateTime(2024, 3, 1));
      expect(dto.resourceRaw, patient.rawResource);
      expect(dto.encounterId, 'enc-1');
      expect(dto.subjectId, 'pat-1');
    });
  });

  group('displayTitle', () {
    test('is the title when there is one', () {
      expect(
        Patient(
          title: 'Ana',
          name: [HumanName(family: 'Pop'.f)],
        ).displayTitle,
        'Ana',
      );
    });

    test('is the first name without a title', () {
      expect(
        Patient(
          name: [
            HumanName(family: 'Pop'.f, given: ['Ana'.f]),
            HumanName(family: 'Other'.f),
          ],
        ).displayTitle,
        'Ana, Pop',
      );
    });

    test('is the record type without a usable name', () {
      expect(const Patient().displayTitle, FhirType.Patient.display);
      expect(const Patient(name: []).displayTitle, FhirType.Patient.display);
      expect(
        Patient(name: [HumanName(text: 'Ana Pop'.f)]).displayTitle,
        FhirType.Patient.display,
      );
    });
  });

  group('additionalInfo', () {
    test('lists the birth date, the age and each phone with its use', () {
      final patient = Patient.fromDto(
        const FhirResourceDto(
          resourceRaw: {
            'resourceType': 'Patient',
            'birthDate': '1985-07-14',
            'telecom': [
              {'system': 'phone', 'value': '0722 000 000', 'use': 'mobile'},
              {'system': 'phone', 'value': '021 000 000'},
            ],
          },
        ),
      );

      final lines = _lines(patient);

      expect(lines, contains('${_en.fieldDateOfBirth}: Jul 14, 1985'));
      expect(
        lines.where((l) => l.startsWith('${_en.fieldAge}: ')),
        hasLength(1),
      );
      expect(lines, contains('${_en.fieldPhone}: 0722 000 000 (mobile)'));
      expect(lines, contains('${_en.fieldPhone}: 021 000 000'));
    });

    test('picks the gender icon for male, female and any other gender', () {
      SvgGenImage iconFor(AdministrativeGender gender) =>
          Patient(
                gender: gender,
              )
              .additionalInfo(_en)
              .firstWhere((l) => l.info.contains(_en.fieldGender))
              .icon;

      expect(iconFor(AdministrativeGender.male), Assets.icons.genderMale);
      expect(iconFor(AdministrativeGender.female), Assets.icons.genderFemale);
      expect(iconFor(AdministrativeGender.other), Assets.icons.user);
      expect(
        _lines(const Patient(gender: AdministrativeGender.other)),
        contains('${_en.fieldGender}: other'),
      );
    });

    test('lists a national id under its country label', () {
      final lines = _lines(
        Patient(
          identifier: [
            _identifier('1850714123456', code: 'SS', text: 'CNP'),
          ],
        ),
      );

      expect(lines, contains('CNP: 1850714123456'));
    });

    test('names other identifiers by their text, coding display or code', () {
      final lines = _lines(
        Patient(
          identifier: [
            _identifier('A1', code: 'XX', text: 'Insurance card'),
            _identifier('B2', code: 'YY', display: 'Member number'),
            _identifier('C3', code: 'ZZ'),
            _identifier('D4'),
            Identifier(
              type: CodeableConcept(coding: [Coding(code: FhirCode('WW'))]),
            ),
          ],
        ),
      );

      expect(lines, contains('Insurance card: A1'));
      expect(lines, contains('Member number: B2'));
      expect(lines, contains('ZZ: C3'));
      expect(lines.where((l) => l.contains('D4')), isEmpty);
      expect(lines.where((l) => l.startsWith('WW')), isEmpty);
    });

    test('lists the general practitioners and the managing organization', () {
      final lines = _lines(
        Patient(
          generalPractitioner: [
            Reference(display: 'Dr. Ion'.f),
            Reference(display: 'Dr. Maria'.f),
          ],
          managingOrganization: Reference(display: 'City Clinic'.f),
        ),
      );

      expect(
        lines,
        contains('${_en.fieldGeneralPractitioner}: Dr. Ion, Dr. Maria'),
      );
      expect(
        lines,
        contains('${_en.fieldManagingOrganization}: City Clinic'),
      );
    });

    test('lists no practitioner line for practitioners without a name, or '
        'none', () {
      for (final practitioners in [
        <Reference>[],
        [Reference(reference: 'Practitioner/gp-1'.f)],
      ]) {
        final lines = _lines(Patient(generalPractitioner: practitioners));

        expect(
          lines.where((l) => l.startsWith(_en.fieldGeneralPractitioner)),
          isEmpty,
        );
      }
    });
  });

  test('refers to its organization and practitioners, once each', () {
    final patient = Patient(
      managingOrganization: Reference(reference: 'Organization/org-1'.f),
      generalPractitioner: [
        Reference(reference: 'Practitioner/gp-1'.f),
        Reference(reference: 'Practitioner/gp-1'.f),
        Reference(display: 'No reference'.f),
      ],
    );

    expect(patient.resourceReferences, [
      'Organization/org-1',
      'Practitioner/gp-1',
    ]);
    expect(const Patient().resourceReferences, isEmpty);
  });

  test('is active only when marked active', () {
    expect(Patient(active: FhirBoolean(true)).statusDisplay, 'Active');
    expect(Patient(active: FhirBoolean(false)).statusDisplay, 'Inactive');
    expect(const Patient().statusDisplay, 'Inactive');
  });
}
