import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/home/data/services/specialty_classifier_impl.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/entities/overview_card.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';

void main() {
  setUpAll(initializeDateFormatting);

  final en = lookupAppLocalizations(const Locale('en'));
  final ro = lookupAppLocalizations(const Locale('ro'));
  final prescription =
      entityFromJson(visionPrescriptionJson()) as VisionPrescription;

  test('a stored row is read as a VisionPrescription', () {
    expect(prescription.fhirType, FhirType.VisionPrescription);
    expect(prescription.lensType, VisionLensType.multifocal);
    expect(prescription.displayTitle, 'Multifocal glasses');
    expect(prescription.followUpDate, '2025-03-14');
    expect(prescription.statusDisplay, 'active');
    expect(
      prescription.resourceReferences,
      containsAll(['Patient/pat-1', 'Encounter/enc-1', 'Practitioner/pr-1']),
    );
  });

  test('the title column comes first, then the lens type in the app\'s '
      'language', () {
    expect(
      prescription.copyWith(title: 'Rețetă Ochelari multifocali').displayTitle,
      'Rețetă Ochelari multifocali',
    );
    final previous = Intl.defaultLocale;
    addTearDown(() => Intl.defaultLocale = previous);
    Intl.defaultLocale = 'ro';
    expect(prescription.displayTitle, ro.lensTypeMultifocal);
  });

  test('per-eye rows as printed, right eye first', () {
    final rows = prescription.eyeRows;
    expect(rows.map((r) => r.right), [true, false]);
    expect(
      rows.map((r) => [r.sphere, r.cylinder, r.axis, r.add, r.prism]),
      [
        ['+0.75', null, null, '+1.75', null],
        ['+0.75', '+0.25', '160', '+1.75', null],
      ],
    );
  });

  test('info lines are localized', () {
    List<String> infos(AppLocalizations l10n) =>
        prescription.additionalInfo(l10n).map((l) => l.info).toList();

    expect(
      infos(en),
      containsAll([
        'Lens Type: Multifocal glasses',
        'Status: Active',
        'Prescribed By: Marinescu Elena',
        'Serial number: PR-0000012340',
      ]),
    );
    expect(infos(en).any((i) => i.startsWith('Date Written: ')), isTrue);
    expect(
      infos(en).any((i) => i.startsWith('Recommended Follow-up: ')),
      isTrue,
    );
    expect(
      infos(ro),
      containsAll([
        'Tip de lentile: Ochelari multifocali',
        'Număr de serie: PR-0000012340',
      ]),
    );
  });

  test('a row without the fields FHIR requires is a generic resource', () {
    final malformed = entityFromJson({
      'resourceType': 'VisionPrescription',
      'id': 'vp-bad',
      'lensSpecification': [
        {'eye': 'right'},
      ],
    });
    expect(malformed, isA<GeneralResource>());
    expect(malformed.id, 'vp-bad');
  });

  test('it is a main record, listed under its own category', () {
    expect(FhirType.mainRecordTypes, contains(FhirType.VisionPrescription));
    expect(FhirType.VisionPrescription.name, 'VisionPrescription');
    expect(
      HomeRecordsCategory.visionPrescriptions.resourceTypes,
      [FhirType.VisionPrescription],
    );
  });

  test('it counts as ophthalmology on Home', () {
    expect(
      SpecialtyClassifierImpl().classify(prescription),
      {MedicalSpecialty.ophthalmology},
    );
  });
}
