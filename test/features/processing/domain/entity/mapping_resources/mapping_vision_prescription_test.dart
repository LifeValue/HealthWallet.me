import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_identifier.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_vision_prescription.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/record_completion.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

MappedProperty _v(String value) => MappedProperty(value: value);

final _specialtyMeta = fhir_r4.FhirMeta(
  tag: [
    fhir_r4.Coding(
      system: fhir_r4.FhirUri('http://healthwallet.me/specialty'),
      code: fhir_r4.FhirCode('ophthalmology'),
    ),
  ],
);

List<String> _tags(Map<String, dynamic> raw) => [
  for (final t in (raw['meta']?['tag'] as List?) ?? const [])
    '${t['system']}#${t['code']}',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final prescription = MappingVisionPrescription(
    id: 'vp-1',
    lensType: VisionLensType.multifocal,
    serial: _v('PR-0000012340'),
    serialSystem: 'http://healthwallet.me/clinic/c/document',
    dateWritten: _v('2024-03-14'),
    followUpDate: _v('2025-03-14'),
    prescriberRef: 'Practitioner/pr-1',
    prescriberName: _v('Marinescu Elena'),
    rightSphere: _v('+0.75'),
    rightAdd: _v('1.75'),
    leftSphere: _v('+0.75'),
    leftCylinder: _v('+0.25'),
    leftAxis: _v('160'),
    leftAdd: _v('1.75'),
    provenance: 'clearvis.io@1',
  );

  test('toFhirResource round-trips through fhir_r4.VisionPrescription', () {
    final resource = prescription.toFhirResource(
      sourceId: 'wallet-p1',
      subjectId: 'p1',
      encounterId: 'enc-1',
    );
    final fhir = fhir_r4.VisionPrescription.fromJson(resource.rawResource);

    expect(fhir.status.valueString, 'active');
    expect(fhir.dateWritten.valueString, '2024-03-14');
    expect(fhir.patient.reference!.valueString, 'Patient/p1');
    expect(fhir.encounter!.reference!.valueString, 'Encounter/enc-1');
    expect(fhir.prescriber.reference!.valueString, 'Practitioner/pr-1');
    expect(fhir.identifier!.single.value!.valueString, 'PR-0000012340');
    expect(fhir.lensSpecification.map((l) => l.eye.valueString), [
      'right',
      'left',
    ]);
    final left = fhir.lensSpecification.last;
    expect(left.sphere!.valueDouble, 0.75);
    expect(left.cylinder!.valueDouble, 0.25);
    expect(left.axis!.valueInt, 160);
    expect(left.add!.valueDouble, 1.75);
    expect(
      left.product.coding!.map((c) => '${c.system}#${c.code}'),
      [
        'http://terminology.hl7.org/CodeSystem/ex-visionprescriptionproduct#lens',
        'http://healthwallet.me/lens-type#multifocal',
      ],
    );
    expect(fhir.lensSpecification.first.cylinder, isNull);
    expect(
      fhir.extension_!.single.url.valueString,
      'http://healthwallet.me/fhir/StructureDefinition/recommended-follow-up',
    );

    final entity = resource as VisionPrescription;
    expect(entity.lensType, VisionLensType.multifocal);
    expect(entity.followUpDate, '2025-03-14');
  });

  test('without an examiner the clinic is a placeholder prescriber', () {
    final raw = prescription
        .copyWith(prescriberRef: '', clinicName: 'Optica Exemplu 1')
        .toFhirResource(subjectId: 'p1')
        .rawResource;
    final fhir = fhir_r4.VisionPrescription.fromJson(raw);
    expect(fhir.prescriber.display!.valueString, 'Optica Exemplu 1');
    expect(fhir.prescriber.reference, isNull);
    expect(
      fhir.prescriber.extension_!.single.url.valueString,
      'http://healthwallet.me/fhir/StructureDefinition/placeholder',
    );
  });

  test('the provenance tag is merged with the specialty tag', () {
    final raw = prescription
        .toFhirResource(subjectId: 'p1', meta: _specialtyMeta)
        .rawResource;
    expect(_tags(raw), [
      'http://healthwallet.me/specialty#ophthalmology',
      'http://healthwallet.me/extractor#clearvis.io@1',
    ]);

    final encounter = MappingEncounter(
      id: 'e1',
      encounterType: _v('Eye examination'),
      periodStart: _v('2024-03-14'),
      specialty: _v('Ophthalmology'),
      provenance: 'clearvis.io@1',
      identifiers: const [
        MappingIdentifier(system: 'http://healthwallet.me/visit/x', value: 'k'),
      ],
    ).toFhirResource(subjectId: 'p1').rawResource;
    expect(_tags(encounter), [
      'http://healthwallet.me/specialty#ophthalmology',
      'http://healthwallet.me/extractor#clearvis.io@1',
    ]);
    expect(encounter['identifier'], [
      {'system': 'http://healthwallet.me/visit/x', 'value': 'k'},
    ]);
  });

  test('a staged session keeps every field through its JSON', () {
    final staged = prescription.copyWith(
      existingId: 'row-1',
      completesExisting: true,
    );
    expect(MappingResource.fromJson(staged.toJson()), staged);

    const encounter = MappingEncounter(
      id: 'e1',
      provenance: 'clearvis.io@1',
      identifiers: [MappingIdentifier(system: 's', value: 'v')],
    );
    expect(MappingEncounter.fromJson(encounter.toJson()), encounter);
    expect(
      (encounter.copyWithMap({
        'encounterType': 'x',
      }) as MappingEncounter).identifiers,
      encounter.identifiers,
    );
  });

  test('a clinic-scoped patient number is a record number of its clinic', () {
    final patient = MappingPatient(
      id: 'p1',
      familyName: _v('Popescu'),
      patientIdentifier: _v('PA-01234'),
      identifierLabel: MappingPatient.genericIdentifierLabel,
      identifierSystem:
          'http://healthwallet.me/clinic/optica-exemplu-1/patient',
    );
    final identifier =
        (patient.toFhirResource().rawResource['identifier'] as List).single
            as Map;
    expect(
      identifier['system'],
      'http://healthwallet.me/clinic/optica-exemplu-1/patient',
    );
    expect(identifier['type']['coding'][0]['code'], 'MR');
    expect(MappingPatient.fromJson(patient.toJson()), patient);
  });

  group('completing a stored prescription', () {
    Map<String, dynamic> raw(MappingVisionPrescription p) =>
        p.toFhirResource(subjectId: 'p1', encounterId: 'enc-1').rawResource;

    final fromExam = prescription.copyWith(
      serial: const MappedProperty(),
      followUpDate: const MappedProperty(),
      prescriberRef: '',
      prescriberName: const MappedProperty(),
      clinicName: 'Optica Exemplu 1',
    );

    test('fills empty fields and replaces only the placeholder', () {
      final completed = RecordCompletion.visionPrescription(
        raw(fromExam),
        raw(prescription),
        provenance: 'clearvis.io@1',
      )!;
      final fhir = fhir_r4.VisionPrescription.fromJson(completed);
      expect(fhir.identifier!.single.value!.valueString, 'PR-0000012340');
      expect(fhir.prescriber.reference!.valueString, 'Practitioner/pr-1');
      expect(fhir.extension_, hasLength(1));
    });

    test('never changes a value the stored record has', () {
      final edited = {
        ...raw(fromExam),
        'dateWritten': '2024-03-20',
        'prescriber': {'display': 'Dr. Typed By Hand'},
      };
      final completed = RecordCompletion.visionPrescription(
        edited,
        raw(prescription),
        provenance: 'clearvis.io@1',
      )!;
      expect(completed['dateWritten'], '2024-03-20');
      expect(completed['prescriber'], {'display': 'Dr. Typed By Hand'});
    });

    test('a record that has everything is left alone', () {
      expect(
        RecordCompletion.visionPrescription(
          raw(prescription),
          raw(fromExam),
          provenance: 'clearvis.io@1',
        ),
        isNull,
      );
    });
  });

  test('every field the review shows edits exactly that field', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final keys = prescription.getFieldDescriptors(en).keys.toList();
    expect(keys, hasLength(16));
    for (final key in keys) {
      final edited = prescription.copyWithMap({
        key: 'edited',
      }) as MappingVisionPrescription;
      final before = prescription.getFieldDescriptors(en);
      final after = edited.getFieldDescriptors(en);
      for (final other in keys) {
        expect(
          after[other]!.value,
          other == key ? 'edited' : before[other]!.value,
          reason: '$key changed $other',
        );
      }
      expect(edited.existingId, prescription.existingId);
      expect(edited.provenance, prescription.provenance);
    }
  });

  test('prism and base round-trip through toFhirResource', () {
    final raw = prescription
        .copyWith(
          rightPrism: _v('0.5'),
          rightBase: _v('up'),
          leftPrism: _v('1,25'),
          leftBase: _v('In'),
        )
        .toFhirResource(subjectId: 'p1')
        .rawResource;
    final fhir = fhir_r4.VisionPrescription.fromJson(raw);
    final prisms = [
      for (final lens in fhir.lensSpecification)
        (
          lens.prism!.single.amount.valueDouble,
          lens.prism!.single.base.valueString,
        ),
    ];
    expect(prisms, [(0.5, 'up'), (1.25, 'in')]);
    expect(
      VisionPrescription.fromFhir(fhir, id: 'vp-1').eyeRows.map((r) => r.prism),
      ['0.50 up', '1.25 in'],
    );
  });

  test('the printed title is the record\'s title, before the lens type', () {
    final titled =
        prescription
                .copyWith(title: 'Rețetă Ochelari multifocali')
                .toFhirResource(subjectId: 'p1')
            as VisionPrescription;
    expect(titled.title, 'Rețetă Ochelari multifocali');
    expect(titled.displayTitle, 'Rețetă Ochelari multifocali');
    expect(
      titled.copyWith(title: '').displayTitle,
      'Rețetă Ochelari multifocali',
      reason: 'the lenses keep the printed title too',
    );
    final untitled =
        prescription.toFhirResource(subjectId: 'p1') as VisionPrescription;
    expect(untitled.title, isEmpty);
    expect(untitled.displayTitle, 'Multifocal glasses');
  });
}
