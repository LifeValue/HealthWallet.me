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

    test('the status is shown in the app language', () {
      expect(
        _cardLines({
          ...medicationRequestJson(),
          'status': 'stopped',
        }, _de).first.info,
        'Status: Abgesetzt',
      );
    });
  });
}
