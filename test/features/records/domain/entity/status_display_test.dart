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
}
