import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/records/data/services/repository_attachment_browse_service.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';

import '../../../../helpers/log_capture.dart';

IFhirResource _resource(
  Map<String, dynamic> json, {
  String encounterId = '',
  String title = '',
  DateTime? date,
}) => IFhirResource.fromLocalDto(
  FhirResourceLocalDto(
    id: json['id'] as String,
    resourceType: json['resourceType'] as String,
    resourceRaw: jsonEncode({..._requiredFields(json), ...json}),
    sourceId: 'src-1',
    resourceId: json['id'] as String,
    title: title,
    date: date,
    encounterId: encounterId,
  ),
);

/// The fields fhir_r4 needs to parse each type, so the entities are real.
Map<String, dynamic> _requiredFields(Map<String, dynamic> json) =>
    switch (json['resourceType']) {
      'Condition' => {
        'subject': {'reference': 'Patient/pat-1'},
      },
      'Encounter' => {
        'status': 'finished',
        'class': {'code': 'AMB'},
      },
      'DocumentReference' => {'status': 'current'},
      _ => {},
    };

Map<String, dynamic> _ref(String reference) => {'reference': reference};

IFhirResource _document(
  String id, {
  String url = 'file://docs/report.pdf',
  String contentType = 'application/pdf',
  String encounterId = '',
  List<String> related = const [],
  List<String> encounters = const [],
}) => _resource(
  {
    'resourceType': 'DocumentReference',
    'id': id,
    'content': [
      {
        'attachment': {'contentType': contentType, 'url': url},
      },
    ],
    'context': {
      if (related.isNotEmpty) 'related': [for (final r in related) _ref(r)],
      if (encounters.isNotEmpty)
        'encounter': [for (final e in encounters) _ref(e)],
    },
  },
  encounterId: encounterId,
  title: '$id title',
);

class _FakeRecordsRepository extends Fake implements RecordsRepository {
  List<IFhirResource> records = [];
  List<IFhirResource> documents = [];
  List<IFhirResource> related = [];
  Map<String, IFhirResource> references = {};
  Error? relatedError;
  Error? documentsError;
  Error? referenceError;

  @override
  Future<List<IFhirResource>> getResources({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 20,
    int offset = 0,
    DateFilter? dateFilter,
  }) async {
    if (resourceTypes.length == 1 &&
        resourceTypes.single == FhirType.DocumentReference) {
      if (documentsError != null) throw documentsError!;
      return List.of(documents);
    }
    return List.of(records);
  }

  @override
  Future<List<IFhirResource>> getRelatedResourcesForEncounter({
    required String encounterId,
    String? sourceId,
  }) async {
    if (relatedError != null) throw relatedError!;
    return related;
  }

  @override
  Future<IFhirResource?> resolveReference(String reference) async {
    if (referenceError != null) throw referenceError!;
    return references[reference];
  }
}

class _FakePathResolver extends Fake implements PathResolver {
  _FakePathResolver(this.root);

  final String root;
  final failing = <String>{};

  @override
  Future<String> toAbsolute(String path) async {
    if (failing.contains(path)) throw const FileSystemException('bad path');
    return '$root/$path';
  }
}

class _FakeSpecialtyClassifier extends Fake implements SpecialtyClassifier {
  Set<MedicalSpecialty> result = {};

  @override
  Set<MedicalSpecialty> classify(
    IFhirResource resource, {
    MedicalSpecialty? override,
  }) => result;
}

void main() {
  final logs = captureLogs();
  late Directory root;
  late _FakeRecordsRepository repository;
  late _FakePathResolver pathResolver;
  late _FakeSpecialtyClassifier classifier;
  late RepositoryAttachmentBrowseService service;

  setUp(() {
    root = Directory.systemTemp.createTempSync('attachment_browse_test');
    Directory('${root.path}/docs').createSync();
    File('${root.path}/docs/report.pdf').writeAsStringSync('%PDF');
    repository = _FakeRecordsRepository();
    pathResolver = _FakePathResolver(root.path);
    classifier = _FakeSpecialtyClassifier();
    service = RepositoryAttachmentBrowseService(
      repository,
      pathResolver,
      classifier,
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  group('loadEntries', () {
    test('sorts by date, newest first, undated last, and skips '
        'supporting resources', () async {
      repository.records = [
        _resource({
          'resourceType': 'Condition',
          'id': 'old',
        }, date: DateTime(2020)),
        _resource({'resourceType': 'Condition', 'id': 'undated'}),
        _resource({'resourceType': 'Patient', 'id': 'pat-1'}),
        _resource({
          'resourceType': 'Condition',
          'id': 'new',
        }, date: DateTime(2024)),
        _resource({'resourceType': 'Condition', 'id': 'undated-2'}),
      ];

      final entries = await service.loadEntries();

      expect(entries.map((e) => e.record.id), [
        'new',
        'old',
        'undated',
        'undated-2',
      ]);
    });

    test('counts linked documents and finds a thumbnail', () async {
      repository.records = [
        _resource({'resourceType': 'Condition', 'id': 'cond-1'}),
        _resource({'resourceType': 'Encounter', 'id': 'enc-1'}),
      ];
      repository.documents = [
        _document('doc-related', related: ['Condition/cond-1']),
        _document('doc-enc', encounterId: 'enc-1'),
        _document('doc-enc-list', encounters: ['Encounter/enc-1']),
        _document(
          'doc-enc-other',
          encounterId: 'enc-1',
          related: ['Condition/cond-1'],
        ),
      ];

      final entries = await service.loadEntries();
      final condition = entries.firstWhere((e) => e.record.id == 'cond-1');
      final encounter = entries.firstWhere((e) => e.record.id == 'enc-1');

      expect(condition.attachmentCount, 2);
      expect(condition.thumbnailPath, '${root.path}/docs/report.pdf');
      expect(encounter.attachmentCount, 2);
      expect(logs, isEmpty);
    });

    test(
      'a missing file or a non-image attachment gives no thumbnail',
      () async {
        repository.records = [
          _resource({'resourceType': 'Condition', 'id': 'cond-1'}),
        ];
        repository.documents = [
          _document(
            'doc-1',
            url: 'file://docs/missing.pdf',
            related: ['Condition/cond-1'],
          ),
          _document(
            'doc-2',
            contentType: 'text/plain',
            related: ['Condition/cond-1'],
          ),
        ];

        final entries = await service.loadEntries();

        expect(entries.single.attachmentCount, 2);
        expect(entries.single.thumbnailPath, isNull);
      },
    );

    test('a thumbnail path that cannot be resolved is logged', () async {
      pathResolver.failing.add('docs/report.pdf');
      repository.records = [
        _resource({'resourceType': 'Condition', 'id': 'cond-1'}),
      ];
      repository.documents = [
        _document('doc-1', related: ['Condition/cond-1']),
      ];

      final entries = await service.loadEntries();

      expect(entries.single.thumbnailPath, isNull);
      expect(logs, loggedWarning('Could not resolve the attachment thumbnail'));
    });
  });

  group('loadDetail', () {
    final encounter = _resource({
      'resourceType': 'Encounter',
      'id': 'enc-1',
      'subject': {'reference': 'Patient/pat-1', 'display': 'Jane From Subject'},
      'performer': [
        {'display': 'Clinic From Performer'},
      ],
      'participant': [
        {
          'individual': {'display': 'Dr. From Participant'},
        },
      ],
    });

    test('reads names and attachments from the related resources', () async {
      repository.related = [
        _resource({
          'resourceType': 'Patient',
          'id': 'pat-1',
          'name': [
            {
              'given': ['Jane'],
              'family': 'Doe',
            },
          ],
        }),
        _resource({
          'resourceType': 'Organization',
          'id': 'org-1',
          'name': 'Springfield Clinic',
        }),
        _resource({
          'resourceType': 'Practitioner',
          'id': 'pr-1',
          'name': [
            {'family': 'House'},
          ],
        }),
        _document('doc-1', encounterId: 'enc-1'),
      ];
      repository.documents = [
        _document('doc-1', encounterId: 'enc-1'),
        _document('doc-2', related: ['Encounter/enc-1']),
        _document('doc-3', related: ['Condition/other']),
      ];

      final detail = await service.loadDetail(encounter);

      expect(detail.patientName, 'Jane Doe');
      expect(detail.organizationName, 'Springfield Clinic');
      expect(detail.practitionerName, 'House');
      expect(detail.attachments.map((a) => a.id), ['doc-1', 'doc-2']);
      expect(detail.attachments.first.filePath, '${root.path}/docs/report.pdf');
      expect(detail.attachments.first.title, 'doc-1 title');
      expect(logs, isEmpty);
    });

    test(
      'takes the specialty from the record tag, else classifies it',
      () async {
        final tagged = _resource({
          'resourceType': 'Condition',
          'id': 'cond-1',
          'meta': {
            'tag': [
              {
                'system': 'http://healthwallet.me/specialty',
                'display': 'Cardiology',
              },
            ],
          },
        });
        classifier.result = {MedicalSpecialty.dermatology};
        // Malformed JSON can't go through fhir_r4, so build the entity.
        const untagged = Condition(
          id: 'cond-2',
          resourceId: 'cond-2',
          rawResource: {
            'meta': {'tag': 'not a list'},
          },
        );

        expect((await service.loadDetail(tagged)).specialtyName, 'Cardiology');
        expect(
          (await service.loadDetail(untagged)).specialtyName,
          MedicalSpecialty.dermatology.displayName,
        );
      },
    );

    test('falls back to the record context when related loading fails, '
        'and logs it', () async {
      repository.relatedError = StateError('db closed');

      final detail = await service.loadDetail(encounter);

      expect(detail.patientName, 'Jane From Subject');
      expect(detail.organizationName, 'Clinic From Performer');
      expect(detail.practitionerName, 'Dr. From Participant');
      expect(logs, loggedWarning('Could not load the resources related to'));
    });

    test(
      'a related resource that cannot be read is logged and skipped',
      () async {
        pathResolver.failing.add('docs/report.pdf');
        repository.related = [_document('doc-1', encounterId: 'enc-1')];

        final detail = await service.loadDetail(encounter);

        expect(detail.attachments.single.filePath, isNull);
        expect(logs, loggedWarning('Could not resolve the attachment file'));
      },
    );

    test('a failing document lookup is logged', () async {
      repository.documentsError = StateError('db closed');

      final detail = await service.loadDetail(encounter);

      expect(detail.attachments, isEmpty);
      expect(logs, loggedWarning('Could not load the documents linked to'));
    });

    test('resolves the subject when the record names no one', () async {
      final record = _resource({
        'resourceType': 'Condition',
        'id': 'cond-1',
        'subject': {'reference': 'Patient/pat-9'},
      });
      repository.references = {
        'Patient/pat-9': const Patient(
          id: 'pat-9',
          rawResource: {'name': 'Plain Name'},
        ),
      };

      expect((await service.loadDetail(record)).patientName, 'Plain Name');

      repository.referenceError = StateError('db closed');
      expect((await service.loadDetail(record)).patientName, isNull);
      expect(
        logs,
        loggedWarning('Could not resolve the patient Patient/pat-9'),
      );
    });

    test('malformed names and context leave the names unknown', () async {
      // Malformed JSON can't go through fhir_r4, so build the entities.
      const record = Condition(
        id: 'cond-1',
        resourceId: 'cond-1',
        rawResource: {'performer': 'not a list'},
      );
      repository.related = [
        const Practitioner(
          id: 'pr-1',
          rawResource: {
            'name': [
              {'given': 'not a list'},
            ],
          },
        ),
      ];

      final detail = await service.loadDetail(record);

      expect(detail.practitionerName, isNull);
      expect(detail.organizationName, isNull);
    });
  });
}
