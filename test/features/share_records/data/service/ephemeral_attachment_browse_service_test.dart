import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/share_records/data/service/ephemeral_attachment_browse_service.dart';

import '../../../../helpers/log_capture.dart';

/// Classifies a record as cardiology when its title mentions the heart.
class _FakeSpecialtyClassifier extends Fake implements SpecialtyClassifier {
  @override
  EncounterSpecialties indexEncounters(Iterable<IFhirResource> resources) => {};

  @override
  Set<MedicalSpecialty> classify(
    IFhirResource resource, {
    MedicalSpecialty? override,
    EncounterSpecialties? encounterSpecialties,
  }) => resource.title.contains('heart')
      ? {MedicalSpecialty.cardiology}
      : {MedicalSpecialty.generalCare};
}

void main() {
  final logs = captureLogs();

  EphemeralAttachmentBrowseService serviceOf(List<IFhirResource> records) =>
      EphemeralAttachmentBrowseService(records, _FakeSpecialtyClassifier());

  group('loadEntries', () {
    test('keeps to the date filter, with undated records', () async {
      final service = serviceOf([
        Condition(id: 'in', date: DateTime(2024, 5)),
        Condition(id: 'out', date: DateTime(2023, 5)),
        const Condition(id: 'undated'),
      ]);

      final entries = await service.loadEntries(
        dateFilter: const DateFilter(fromYear: 2024),
      );

      expect(entries.map((e) => e.record.id), ['in', 'undated']);
    });

    test('keeps to the specialty', () async {
      final service = serviceOf([
        const Condition(id: 'heart', title: 'heart failure'),
        const Condition(id: 'skin', title: 'eczema'),
      ]);

      final entries = await service.loadEntries(
        specialties: [MedicalSpecialty.cardiology],
      );

      expect(entries.map((e) => e.record.id), ['heart']);
    });
  });

  group('a received file whose name has unencoded accents', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('ephemeral_browse'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('still gives the thumbnail and the detail', () async {
      final path = '${dir.path}/Scrisoare medicală_1a2b3c4d.pdf';
      File(path).writeAsStringSync('%PDF');
      const encounter = Encounter(id: 'e1', resourceId: 'enc-1');
      final service = serviceOf([
        encounter,
        DocumentReference(
          id: 'd1',
          resourceId: 'doc-1',
          encounterId: 'enc-1',
          rawResource: {
            'resourceType': 'DocumentReference',
            'content': [
              {
                'attachment': {
                  'contentType': 'application/pdf',
                  'url': 'file://$path',
                },
              },
            ],
          },
        ),
      ]);

      final entries = await service.loadEntries();
      final detail = await service.loadDetail(encounter);

      expect(entries.single.thumbnailPath, path);
      expect(detail.attachments.map((a) => a.filePath), [path]);
      expect(logs, isEmpty);
    });
  });

  group('loadDetail', () {
    test('a name it cannot read is logged and left unknown', () async {
      const record = Condition(
        id: 'c1',
        rawResource: {
          'subject': {'reference': 'Patient/p1'},
        },
      );
      final service = serviceOf([
        record,
        const Patient(
          id: 'p1',
          resourceId: 'p1',
          rawResource: {
            'name': [
              {'given': 'Jane'},
            ],
          },
        ),
      ]);

      final detail = await service.loadDetail(record);

      expect(detail.patientName, isNull);
      expect(logs, loggedWarning('Could not read a person name'));
    });

    test('a specialty tag it cannot read is logged and the record is '
        'classified instead', () async {
      const record = Condition(
        id: 'c1',
        title: 'heart failure',
        rawResource: {
          'meta': {'tag': 'not a list'},
        },
      );
      final service = serviceOf([record]);

      final detail = await service.loadDetail(record);

      expect(detail.specialtyName, MedicalSpecialty.cardiology.displayName);
      expect(logs, loggedWarning('Could not read the specialty tag'));
    });
  });
}
