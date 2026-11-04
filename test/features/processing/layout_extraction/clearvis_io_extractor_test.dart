import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/processing/data/extractors/clearvis/clearvis_io_extractor.dart';
import 'package:health_wallet/features/processing/data/extractors/clearvis/clearvis_text.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_vision_prescription.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extractor.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extractor_registry.dart';
import 'package:health_wallet/features/records/domain/entity/vision_prescription/vision_prescription.dart';

/// De-identified Apple Vision OCR text (macOS `.accurate`, pages at 200 dpi,
/// one line per observation), as the app reads it.
String fixture(String name) => File(
  'test/features/processing/layout_extraction/fixtures/$name.txt',
).readAsStringSync();

typedef _Eye = (String, String, String, String);

(_Eye, _Eye) _eyes(MappingVisionPrescription p) => (
  (
    p.rightSphere.value,
    p.rightCylinder.value,
    p.rightAxis.value,
    p.rightAdd.value,
  ),
  (p.leftSphere.value, p.leftCylinder.value, p.leftAxis.value, p.leftAdd.value),
);

List<MappingVisionPrescription> _prescriptions(LayoutExtraction x) =>
    x.resources.cast<MappingVisionPrescription>();

void main() {
  const extractor = ClearvisIoExtractor();

  group('prescriptions document', () {
    for (final name in [
      'clearvis_prescriptions',
      'clearvis_prescriptions_noisy',
    ]) {
      test('$name: every field as printed', () {
        final text = fixture(name);
        expect(
          extractor.score(text),
          greaterThanOrEqualTo(LayoutExtractorRegistry.threshold),
        );
        final x = extractor.extract(text)!;

        expect(x.extractorId, 'clearvis.io');
        expect(x.clinicKey, 'optica-exemplu-1');
        expect(x.provenance, 'clearvis.io@1');

        expect(x.patient.givenName.value, 'Ioana Maria');
        expect(x.patient.familyName.value, 'Popescu');
        expect(x.patient.dateOfBirth.value, '1983-07-11');
        expect(x.patient.patientIdentifier.value, 'PA-01234');
        expect(
          x.patient.identifierSystem,
          'http://healthwallet.me/clinic/optica-exemplu-1/patient',
        );

        expect(x.organization.organizationName.value, 'Optica Exemplu 1');
        expect(
          x.organization.address.value,
          'Strada Exemplu, nr. 1, 400000 Cluj-Napoca',
        );
        expect(x.organization.phone.value, '0700000000');
        expect(x.practitioner!.practitionerName.value, 'Marinescu Elena');

        expect(x.encounter.periodStart.value, '2024-03-14');
        expect(
          x.encounter.specialty.value,
          MedicalSpecialty.ophthalmology.displayName,
        );
        expect(x.visitKey!.system, 'http://healthwallet.me/visit/clearvis.io');
        expect(x.visitKey!.value, 'optica-exemplu-1|PA-01234|2024-03-14');

        final prescriptions = _prescriptions(x);
        expect(prescriptions.map((p) => p.lensType), [
          VisionLensType.multifocal,
          VisionLensType.distance,
          VisionLensType.reading,
        ]);
        expect(prescriptions.map((p) => p.serial.value), [
          'PR-0000012340',
          'PR-0000012341',
          'PR-0000012342',
        ]);
        for (final p in prescriptions) {
          expect(p.dateWritten.value, '2024-03-14');
          expect(p.followUpDate.value, '2025-03-14');
          expect(p.prescriberRef, 'Practitioner/${x.practitioner!.id}');
          expect(p.prescriberName.value, 'Marinescu Elena');
          expect(
            p.serialSystem,
            'http://healthwallet.me/clinic/optica-exemplu-1/document',
          );
          expect(p.provenance, 'clearvis.io@1');
        }
        expect(_eyes(prescriptions[0]), (
          ('+0.75', '', '', '1.75'),
          ('+0.75', '+0.25', '160', '1.75'),
        ));
        expect(_eyes(prescriptions[1]), (
          ('+0.75', '', '', ''),
          ('+0.75', '+0.25', '160', ''),
        ));
        expect(_eyes(prescriptions[2]), (
          ('+2.50', '', '', ''),
          ('+2.50', '+0.25', '160', ''),
        ));
      });
    }

    test('the clinic and examiner get the same ids every time', () {
      final a = extractor.extract(fixture('clearvis_prescriptions'))!;
      final b = extractor.extract(fixture('clearvis_prescriptions_noisy'))!;
      expect(a.organization.id, b.organization.id);
      expect(a.practitioner!.id, b.practitioner!.id);
    });
  });

  group('exam document', () {
    for (final name in ['clearvis_exam', 'clearvis_exam_noisy']) {
      test('$name: the visit and the prescriptions it lists', () {
        final x = extractor.extract(fixture(name))!;

        expect(x.clinicKey, 'optica-exemplu-1');
        expect(x.patient.givenName.value, 'Ioana Maria');
        expect(x.patient.familyName.value, 'Popescu');
        expect(x.patient.dateOfBirth.value, '1983-07-11');
        expect(x.patient.patientIdentifier.value, 'PA-01234');
        expect(x.organization.organizationName.value, 'Optica Exemplu 1');
        expect(
          x.organization.address.value,
          'Strada Exemplu, nr. 1, 400000 Cluj-Napoca',
        );
        expect(x.organization.phone.value, '0700000000');
        expect(x.practitioner, isNull);

        expect(x.encounter.periodStart.value, '2024-03-14');
        expect(
          x.encounter.identifiers.map((i) => i.value),
          ['optica-exemplu-1|PA-01234|2024-03-14', 'EE-0000054321'],
        );

        final prescriptions = _prescriptions(x);
        expect(prescriptions.map((p) => p.lensType), [
          VisionLensType.distance,
          VisionLensType.multifocal,
          VisionLensType.reading,
        ]);
        for (final p in prescriptions) {
          expect(p.serial.value, isEmpty);
          expect(p.prescriberRef, isEmpty, reason: 'the clinic placeholder');
          expect(p.clinicName, 'Optica Exemplu 1');
          expect(p.followUpDate.value, isEmpty);
          expect(p.dateWritten.value, '2024-03-14');
        }
        expect(_eyes(prescriptions[0]), (
          ('+0.75', '', '', ''),
          ('+0.75', '+0.25', '160', ''),
        ));
        expect(_eyes(prescriptions[1]), (
          ('+0.75', '', '', '1.75'),
          ('+0.75', '+0.25', '160', '1.75'),
        ));
        expect(_eyes(prescriptions[2]), (
          ('+2.50', '', '', ''),
          ('+2.50', '+0.25', '160', ''),
        ));
      });
    }

    test('both documents of the visit share its key and supporting ids', () {
      final prescriptions = extractor.extract(
        fixture('clearvis_prescriptions'),
      )!;
      final exam = extractor.extract(fixture('clearvis_exam'))!;
      expect(exam.visitKey, prescriptions.visitKey);
      expect(exam.organization.id, prescriptions.organization.id);
    });
  });

  test('a second tenant scopes the same patient number to its clinic', () {
    final first = extractor.extract(fixture('clearvis_prescriptions'))!;
    final other = extractor.extract(
      fixture('clearvis_prescriptions_second_tenant'),
    )!;

    expect(other.clinicKey, 'vizual-optic-centru');
    expect(other.patient.patientIdentifier.value, 'PA-01234');
    expect(other.patient.givenName.value, 'Andrei Mihai');
    expect(
      other.patient.identifierSystem,
      isNot(first.patient.identifierSystem),
    );
    expect(other.visitKey!.value, isNot(first.visitKey!.value));
    expect(other.organization.id, isNot(first.organization.id));
    expect(_prescriptions(other).map((p) => p.serial.value), [
      'PR-0000098760',
      'PR-0000098761',
      'PR-0000098762',
    ]);
  });

  group('required fields', () {
    String without(String text, Pattern line) =>
        text.split('\n').where((l) => !l.contains(line)).join('\n');

    test('no patient name: nothing is extracted', () {
      final text = without(
        without(fixture('clearvis_prescriptions'), 'Ioana Maria Popescu'),
        'Marinescu Elena',
      );
      expect(extractor.score(text), greaterThanOrEqualTo(0.5));
      expect(extractor.extract(text), isNull);
    });

    test('no date: nothing is extracted', () {
      final text = without(fixture('clearvis_exam'), '14.03.2024');
      expect(extractor.extract(text), isNull);
    });

    test('per-eye values that make no two eyes: nothing is extracted', () {
      final text = without(fixture('clearvis_prescriptions'), '+2.50 D');
      expect(extractor.extract(text), isNull);
    });

    for (final name in ['clearvis_prescriptions', 'clearvis_exam']) {
      test('$name without the store name: nothing is extracted', () {
        final text = fixture(name)
            .split('\n')
            .where(
              (l) => !l.contains('Optica Exemplu 1') && !l.contains('Locul'),
            )
            .join('\n');
        expect(extractor.extract(text), isNull);
      });

      test('$name without the patient number: nothing is extracted', () {
        expect(extractor.extract(without(fixture(name), 'PA-01234')), isNull);
      });
    }

    test('a date that does not exist is not read', () {
      expect(ClearvisText.isoDate('31.02.2024'), isNull);
      expect(ClearvisText.isoDate('29.02.2024'), '2024-02-29');
      expect(ClearvisText.isoDate('29.02.2023'), isNull);
      final text = fixture(
        'clearvis_exam',
      ).replaceAll('14.03.2024', '31.02.2024');
      expect(extractor.extract(text), isNull);
    });
  });

  test('the exam\'s store comes from its footer when OCR misses it', () {
    final text = fixture('clearvis_exam')
        .split('\n')
        .where((l) => l != 'Optica Exemplu 1')
        .join('\n');
    final x = extractor.extract(text)!;
    expect(x.organization.organizationName.value, 'Optica Exemplu 1');
    expect(
      x.organization.address.value,
      'Strada Exemplu, nr. 1, 400000 Cluj-Napoca',
    );
  });

  test('two patients of one clinic share its Organization and examiner', () {
    final first = extractor.extract(fixture('clearvis_prescriptions'))!;
    final relative = extractor.extract(
      fixture('clearvis_prescriptions')
          .replaceAll('Ioana Maria Popescu', 'Mihai Popescu')
          .replaceAll('PA-01234', 'PA-05678'),
    )!;
    expect(relative.patient.patientIdentifier.value, 'PA-05678');
    expect(relative.visitKey, isNot(first.visitKey));
    expect(relative.organization.id, first.organization.id);
    expect(relative.practitioner!.id, first.practitioner!.id);
  });

  test('titles are the headings the documents print', () {
    final prescriptions = extractor.extract(
      fixture('clearvis_prescriptions'),
    )!;
    expect(_prescriptions(prescriptions).map((p) => p.title), [
      'Retetă Ochelari multifocali',
      'Rețetă Ochelari monofocali pentru vedere la distanță',
      'Rețetă Ochelari monofocali pentru citit',
    ]);
    expect(
      prescriptions.encounter.encounterType.value,
      'Retetă Ochelari multifocali',
    );

    final exam = extractor.extract(fixture('clearvis_exam'))!;
    expect(
      exam.encounter.encounterType.value,
      'REZULTAT EXAMINARE OFTALMOLOGICĂ',
    );
    expect(_prescriptions(exam).map((p) => p.title), [
      'Rețetă ochelari monofocali la distanță',
      'Rețetă ochelari multifocali',
      'Rețetă de ochelari monofocali pentru citit',
    ]);
  });

  test('the visit names the clinic as its service provider', () {
    for (final name in ['clearvis_prescriptions', 'clearvis_exam']) {
      final x = extractor.extract(fixture(name))!;
      expect(
        x.encounter.serviceProviderRef,
        'Organization/${x.organization.id}',
      );
      final raw = x.encounter.toFhirResource(subjectId: 'p1').rawResource;
      expect(raw['serviceProvider'], {
        'reference': 'Organization/${x.organization.id}',
      });
    }
  });
}
