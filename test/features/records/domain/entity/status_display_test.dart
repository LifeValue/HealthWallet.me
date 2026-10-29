import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/domain/utils/resource_field_mapper.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';

final _en = lookupAppLocalizations(const Locale('en'));
final _de = lookupAppLocalizations(const Locale('de'));

/// The lines a record card shows: the first two that aren't section titles.
List<RecordInfoLine> _cardLines(
  Map<String, dynamic> json, [
  AppLocalizations? l10n,
]) => entityFromJson(
  json,
).additionalInfo(l10n ?? _en).where((l) => !l.isSection).take(2).toList();

void main() {
  setUpAll(initializeDateFormatting);

  group('medication status', () {
    final cases = <(String, Map<String, dynamic>, String)>[
      (
        'MedicationRequest',
        {...medicationRequestJson(), 'status': 'stopped'},
        'Status: Stopped',
      ),
      (
        'MedicationStatement',
        {...medicationStatementJson(), 'status': 'not-taken'},
        'Status: Not taken',
      ),
      (
        'MedicationAdministration',
        {
          'resourceType': 'MedicationAdministration',
          'id': 'medadmin-1',
          'status': 'stopped',
          'medicationCodeableConcept': codeableConcept(text: 'Heparin'),
          'subject': {'reference': 'Patient/pat-1'},
          'effectiveDateTime': '2024-01-10T09:20:00Z',
        },
        'Status: Stopped',
      ),
      (
        'MedicationDispense',
        {
          'resourceType': 'MedicationDispense',
          'id': 'meddisp-1',
          'status': 'cancelled',
          'medicationCodeableConcept': codeableConcept(text: 'Amoxicillin'),
          'subject': {'reference': 'Patient/pat-1'},
        },
        'Status: Cancelled',
      ),
    ];
    for (final (type, json, expected) in cases) {
      test('$type shows its status first, flagged when inactive', () {
        final first = _cardLines(json).first;
        expect(first.info, expected);
        expect(first.icon.path, ResourceFieldMapper.warningIcon.path);
      });
    }

    test('an active medication shows its status without a warning', () {
      final first = _cardLines(medicationRequestJson()).first;
      expect(first.info, 'Status: Active');
      expect(first.icon.path, ResourceFieldMapper.statusIcon.path);
    });

    test('the medication status is shown in the app language', () {
      expect(
        _cardLines({
          ...medicationRequestJson(),
          'status': 'stopped',
        }, _de).first.info,
        'Status: Abgesetzt',
      );
    });
  });

  group('allergy and condition status', () {
    Map<String, dynamic> status(String system, String code) => codeableConcept(
      codings: [coding('http://terminology.hl7.org/CodeSystem/$system', code)],
    );

    test('a refuted allergy says so before its criticality', () {
      final lines = _cardLines({
        ...allergyJson(),
        'criticality': 'high',
        'reaction': [
          {
            'manifestation': [codeableConcept(text: 'Anaphylaxis')],
          },
        ],
        'verificationStatus': status(
          'allergyintolerance-verification',
          'refuted',
        ),
      });
      expect(lines.map((l) => l.info), [
        'Clinical Status: Active',
        'Verification: Refuted',
      ]);
      expect(lines.last.icon.path, ResourceFieldMapper.warningIcon.path);
    });

    test('an inactive allergy is flagged', () {
      final first = _cardLines({
        ...allergyJson(),
        'clinicalStatus': status('allergyintolerance-clinical', 'inactive'),
      }).first;
      expect(first.info, 'Clinical Status: Inactive');
      expect(first.icon.path, ResourceFieldMapper.warningIcon.path);
    });

    test('a resolved condition given only as a code is named and flagged', () {
      final first = _cardLines({
        ...conditionJson(),
        'clinicalStatus': status('condition-clinical', 'resolved'),
      }).first;
      expect(first.info, 'Clinical Status: Resolved');
      expect(first.icon.path, ResourceFieldMapper.warningIcon.path);
    });

    test('an entered-in-error condition is flagged in the app language', () {
      final lines = _cardLines({
        ...conditionJson(),
        'verificationStatus': status(
          'condition-ver-status',
          'entered-in-error',
        ),
      }, _de);
      expect(lines.last.info, 'Verifizierung: Irrtümlich erfasst');
      expect(lines.last.icon.path, ResourceFieldMapper.warningIcon.path);
    });

    test('statusDisplay falls back to the code of a code-only status', () {
      final condition = entityFromJson({
        ...conditionJson(),
        'clinicalStatus': status('condition-clinical', 'resolved'),
      });
      expect(condition.statusDisplay, 'resolved');
    });

    test('a status without a known code keeps its text', () {
      expect(
        _cardLines({
          ...conditionJson(),
          'clinicalStatus': codeableConcept(text: 'chronic'),
        }).first.info,
        'Clinical Status: chronic',
      );
    });
  });

  group('records not done or entered in error', () {
    test('an immunization not given shows why, and no date given', () {
      final json = {
        ...immunizationJson(),
        'status': 'not-done',
        'statusReason': codeableConcept(text: 'Patient refused'),
      };
      final lines = _cardLines(json);
      expect(lines.map((l) => l.info), [
        'Status: Not done',
        'Status Reason: Patient refused',
      ]);
      expect(lines.first.icon.path, ResourceFieldMapper.warningIcon.path);
      expect(
        entityFromJson(json).additionalInfo(_en).map((l) => l.info),
        isNot(contains(startsWith('Date Given'))),
      );
    });

    test('a procedure entered in error is flagged first', () {
      final first = _cardLines({
        ...procedureJson(),
        'status': 'entered-in-error',
      }).first;
      expect(first.info, 'Status: Entered in error');
      expect(first.icon.path, ResourceFieldMapper.warningIcon.path);
    });

    test('an observation entered in error is flagged before its value', () {
      final lines = _cardLines({
        ...observationJson(value: {'valueQuantity': quantity(13.5)}),
        'status': 'entered-in-error',
      });
      expect(lines.first.info, 'Status: Entered in error');
      expect(lines.first.icon.path, ResourceFieldMapper.warningIcon.path);
      expect(lines.last.info, 'Value: 13.50');
    });

    test('a final observation shows its value first', () {
      final json = observationJson(value: {'valueQuantity': quantity(13.5)});
      expect(_cardLines(json).first.info, 'Value: 13.50');
      expect(
        entityFromJson(json).additionalInfo(_en).map((l) => l.info),
        contains('Status: Final'),
      );
    });

    test('a coded interpretation is named and flagged', () {
      final lines = _cardLines(
        observationJson(
          value: {'valueQuantity': quantity(7.1, unit: 'mmol/L')},
          interpretation: [
            codeableConcept(
              codings: [
                coding(
                  'http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation',
                  'HH',
                ),
              ],
            ),
          ],
        ),
        _de,
      );
      expect(lines.last.info, 'Bewertung: Kritisch erhöht');
      expect(lines.last.icon.path, ResourceFieldMapper.warningIcon.path);
    });

    test('an interpretation given as text keeps its text', () {
      expect(
        _cardLines(
          observationJson(
            value: {'valueQuantity': quantity(7.1, unit: 'mmol/L')},
            interpretation: [codeableConcept(text: 'Above range')],
          ),
        ).last.info,
        'Interpretation: Above range',
      );
    });

    test('blood pressure components given only as codes are named', () {
      final json = observationJson(
        code: '85354-9',
        components: [
          {
            'code': codeableConcept(codings: [loinc('8480-6')]),
            'valueQuantity': quantity(128, unit: 'mmHg'),
          },
          {
            'code': codeableConcept(codings: [loinc('8462-4')]),
            'valueQuantity': quantity(82, unit: 'mmHg'),
          },
        ],
      );
      expect(_cardLines(json).map((l) => l.info), [
        'Systolic Blood Pressure: 128.00 mmHg',
        'Diastolic Blood Pressure: 82.00 mmHg',
      ]);
    });

    test('a component with an unknown code keeps its value', () {
      final json = observationJson(
        components: [
          {
            'code': codeableConcept(codings: [loinc('11111-1')]),
            'valueQuantity': quantity(3, unit: 'mg'),
          },
        ],
      );
      expect(_cardLines(json).first.info, '11111-1: 3.00 mg');
    });

    test('a cancelled lab report is flagged', () {
      final first = _cardLines({
        ...diagnosticReportJson(),
        'status': 'cancelled',
      }).first;
      expect(first.info, 'Status: Cancelled');
      expect(first.icon.path, ResourceFieldMapper.warningIcon.path);
    });
  });
}
