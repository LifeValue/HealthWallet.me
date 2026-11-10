import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/data/extractors/clearvis/clearvis_io_extractor.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_organization.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_vision_prescription.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extractor.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/visit_reconciler.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

import 'clearvis_io_extractor_test.dart' show fixture;

const _source = 'wallet-p1';

/// What saving [extraction] for patient `p1` would store.
List<IFhirResource> _saved(LayoutExtraction extraction) {
  final visit = extraction.encounter.toFhirResource(
    sourceId: _source,
    subjectId: 'p1',
    encounterId: extraction.encounter.id,
  );
  return [
    visit,
    extraction.organization.toFhirResource(sourceId: _source),
    ?extraction.practitioner?.toFhirResource(sourceId: _source),
    for (final r in extraction.resources)
      r.toFhirResource(
        sourceId: _source,
        subjectId: 'p1',
        encounterId: visit.id,
      ),
  ];
}

List<MappingVisionPrescription> _staged(LayoutStaging staging) =>
    staging.resources.whereType<MappingVisionPrescription>().toList();

void main() {
  const extractor = ClearvisIoExtractor();
  const reconciler = VisitReconciler();
  LayoutExtraction read(String name) => extractor.extract(fixture(name))!;

  test('someone new: everything is staged as new', () {
    final staging = reconciler.reconcile(read('clearvis_exam'), const []);
    expect(staging.encounter.mode, ImportMode.createNew);
    expect(staging.resources.first, isA<MappingOrganization>());
    expect(_staged(staging).map((p) => p.existingId), ['', '', '']);
  });

  test('the visit is found by its key and its prescriptions by value', () {
    final stored = _saved(read('clearvis_prescriptions'));
    final staging = reconciler.reconcile(read('clearvis_exam'), stored);

    expect(staging.encounter.mode, ImportMode.linkExisting);
    expect(staging.encounter.existing!.id, stored.first.id);
    expect(staging.resources.whereType<MappingOrganization>(), isEmpty);
    final byType = {
      for (final p in stored.whereType<VisionPrescription>()) p.lensType: p.id,
    };
    expect(
      _staged(staging).map((p) => p.existingId),
      _staged(staging).map((p) => byType[p.lensType]),
    );
    expect(
      _staged(staging).map((p) => p.completesExisting),
      everyElement(false),
    );
  });

  test('a prescription whose values differ is staged as new', () {
    final stored = _saved(read('clearvis_prescriptions'));
    final exam = read('clearvis_exam');
    final changed = LayoutExtraction(
      extractorId: exam.extractorId,
      version: exam.version,
      clinicKey: exam.clinicKey,
      patient: exam.patient,
      organization: exam.organization,
      encounter: exam.encounter,
      resources: [
        for (final p in exam.resources.cast<MappingVisionPrescription>())
          p.lensType == VisionLensType.reading
              ? p.copyWith(leftAxis: const MappedProperty(value: '165'))
              : p,
      ],
    );

    final staging = reconciler.reconcile(changed, stored);

    expect(
      {for (final p in _staged(staging)) p.lensType: p.existingId.isNotEmpty},
      {
        VisionLensType.distance: true,
        VisionLensType.multifocal: true,
        VisionLensType.reading: false,
      },
    );
  });

  test('several visits with the key: a new draft, nothing matched', () {
    final first = _saved(read('clearvis_prescriptions'));
    final second = _saved(read('clearvis_prescriptions'));
    final staging = reconciler.reconcile(read('clearvis_exam'), [
      ...first,
      ...second,
    ]);

    expect(staging.encounter.mode, ImportMode.createNew);
    expect(staging.encounter.existing, isNull);
    expect(_staged(staging).map((p) => p.existingId), ['', '', '']);
  });

  test('a serial already in the wallet is the same prescription', () {
    final stored = _saved(read('clearvis_prescriptions'));
    // The visit was moved or edited away: the serial still finds it.
    final withoutVisit = stored.whereType<VisionPrescription>().toList();
    final staging = reconciler.reconcile(
      read('clearvis_prescriptions'),
      withoutVisit,
    );
    expect(staging.encounter.mode, ImportMode.createNew);
    expect(
      _staged(staging).map((p) => p.existingId),
      withoutVisit.map((p) => p.id),
    );
  });

  test('another clinic\'s visit with the same number and date is not it', () {
    final stored = _saved(read('clearvis_prescriptions_second_tenant'));
    final staging = reconciler.reconcile(read('clearvis_exam'), stored);
    expect(staging.encounter.mode, ImportMode.createNew);
  });
}
