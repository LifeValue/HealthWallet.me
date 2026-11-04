import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart' hide Source;
import 'package:health_wallet/core/data/local/soft_delete.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/utils/fhir_reference_utils.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_attachments/bloc/record_attachments_bloc.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';

import '../../../../../../helpers/log_capture.dart';
import '../../../../../share_records/share_test_helpers.dart';

/// Reads live DocumentReferences from the test database and soft-deletes
/// them, like the real repository, plus [extraDocuments] that the database
/// cannot hold.
/// A stored attachment that can be read but not deleted.
class _UndeletableFile extends Fake implements File {
  _UndeletableFile(this._file);

  final File _file;

  @override
  String get path => _file.path;

  @override
  Uri get uri => _file.uri;

  @override
  Future<bool> exists() => _file.exists();

  @override
  bool existsSync() => _file.existsSync();

  @override
  Future<Uint8List> readAsBytes() => _file.readAsBytes();

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async =>
      throw FileSystemException('Operation not permitted', path);
}

/// Makes every file under [directory] undeletable.
final class _UndeletableFilesIn extends IOOverrides {
  _UndeletableFilesIn(this.directory);

  final String directory;

  @override
  File createFile(String path) {
    final file = super.createFile(path);
    return path.startsWith('$directory/') ? _UndeletableFile(file) : file;
  }
}

class _FakeRecordsRepository extends Fake implements RecordsRepository {
  _FakeRecordsRepository(this._db);

  final AppDatabase _db;
  final extraDocuments = <IFhirResource>[];
  final encounterRecords = <IFhirResource>[];
  final encounterRequests = <String>[];
  int documentReads = 0;
  Error? error;

  @override
  Future<List<IFhirResource>> getResources({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 20,
    int offset = 0,
    DateFilter? dateFilter,
  }) async {
    if (error != null) throw error!;
    expect(resourceTypes, [FhirType.DocumentReference]);
    documentReads++;
    final rows =
        await (_db.select(_db.fhirResource)..where(
              (t) =>
                  t.resourceType.equals('DocumentReference') &
                  t.deletedAt.isNull(),
            ))
            .get();
    return [...rows.map(IFhirResource.fromLocalDto), ...extraDocuments];
  }

  /// The documents linked to [resource]: by encounter for an encounter,
  /// by `context.related` for any other record.
  @override
  Future<List<IFhirResource>> getAttachedDocuments(
    IFhirResource resource,
  ) async {
    final documents = await getResources(
      resourceTypes: [FhirType.DocumentReference],
    );
    bool refersTo(Object? references) =>
        references is List &&
        references.any(
          (r) =>
              r is Map &&
              FhirReferenceUtils.extractReferenceId(
                    r['reference']?.toString(),
                  ) ==
                  resource.resourceId,
        );
    return [
      for (final doc in documents)
        if (resource.fhirType == FhirType.Encounter
            ? doc.encounterId == resource.resourceId ||
                  refersTo(doc.rawResource['context']?['encounter'])
            : refersTo(doc.rawResource['context']?['related']))
          doc,
    ];
  }

  @override
  Future<void> deleteResource(String resourceId) =>
      _db.softDeleteResources([resourceId]);

  @override
  Future<List<IFhirResource>> getRelatedResourcesForEncounter({
    required String encounterId,
    String? sourceId,
  }) async {
    encounterRequests.add(encounterId);
    return encounterRecords;
  }
}

class _FakeSyncRepository extends Fake implements SyncRepository {
  final sources = <Source>[
    const Source(id: 'wallet-src'),
    const Source(id: 'fasten-src', platformType: 'fasten'),
  ];

  @override
  Future<List<Source>> getSources() async => sources;
}

class _FakeSourceTypeService extends Fake implements SourceTypeService {
  @override
  bool isSourceWritable(String platformType) => platformType == 'wallet';
}

class _FakeHolderService extends Fake implements HolderService {
  final walletRequests = <String>[];

  @override
  Future<Source> walletSourceForPatient(String patientId) async {
    walletRequests.add(patientId);
    return Source(id: 'wallet-$patientId');
  }
}

/// The app entity for [json] as read from the database.
IFhirResource _record(
  Map<String, dynamic> json, {
  String sourceId = 'wallet-src',
  String title = 'Record title',
  String? encounterId,
}) => IFhirResource.fromLocalDto(
  FhirResourceLocalDto(
    id: '${sourceId}_${json['id']}',
    sourceId: sourceId,
    resourceType: json['resourceType'] as String,
    resourceId: json['id'] as String,
    title: title,
    encounterId: encounterId,
    resourceRaw: jsonEncode(json),
  ),
);

IFhirResource _observation({
  String id = 'obs-1',
  String sourceId = 'wallet-src',
  String? subject = 'Patient/pat-1',
  String? encounter,
  List<String> derivedFrom = const [],
  String title = 'Glucose',
}) => _record(
  {
    'resourceType': 'Observation',
    'id': id,
    'status': 'final',
    'code': {'text': title},
    if (subject != null) 'subject': {'reference': subject},
    if (encounter != null) 'encounter': {'reference': encounter},
    if (derivedFrom.isNotEmpty)
      'derivedFrom': [
        for (final ref in derivedFrom) {'reference': ref},
      ],
  },
  sourceId: sourceId,
  title: title,
);

IFhirResource _encounter({String id = 'enc-1'}) => _record({
  'resourceType': 'Encounter',
  'id': id,
  'status': 'finished',
  'class': {'code': 'AMB'},
  'subject': {'reference': 'Patient/pat-1'},
}, title: 'Checkup');

Map<String, dynamic> _documentJson({
  required String id,
  String? url,
  String? title,
  String? contentType = 'application/pdf',
  List<String> related = const [],
  List<String> encounters = const [],
}) => {
  'resourceType': 'DocumentReference',
  'id': id,
  'status': 'current',
  'content': [
    {
      'attachment': {
        'contentType': ?contentType,
        'url': ?url,
        'title': ?title,
      },
    },
  ],
  if (related.isNotEmpty || encounters.isNotEmpty)
    'context': {
      if (encounters.isNotEmpty)
        'encounter': [
          for (final ref in encounters) {'reference': ref},
        ],
      if (related.isNotEmpty)
        'related': [
          for (final ref in related) {'reference': ref},
        ],
    },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final logs = captureLogs();

  late Directory root;
  late Directory docs;
  late AppDatabase db;
  late _FakeRecordsRepository repository;
  late _FakeSyncRepository syncRepository;
  late _FakeSourceTypeService sourceTypeService;
  late _FakeHolderService holderService;
  late AppStringsProvider strings;
  late RecordAttachmentsBloc bloc;

  setUp(() {
    root = mockPathProvider();
    docs = Directory('${root.path}/Documents');
    db = AppDatabase(NativeDatabase.memory());
    repository = _FakeRecordsRepository(db);
    syncRepository = _FakeSyncRepository();
    sourceTypeService = _FakeSourceTypeService();
    holderService = _FakeHolderService();
    strings = AppStringsProvider();
    bloc = RecordAttachmentsBloc(
      repository,
      sourceTypeService,
      holderService,
      syncRepository,
      db,
      PathResolver(),
      strings,
    );
  });

  tearDown(() async {
    await bloc.close();
    await db.close();
  });

  /// Adds [event] and returns the first state that is not loading.
  Future<RecordAttachmentsState> run(RecordAttachmentsEvent event) {
    final done = bloc.stream.firstWhere(
      (s) => s.status != const RecordAttachmentsStatus.loading(),
    );
    bloc.add(event);
    return done;
  }

  Future<RecordAttachmentsState> open(
    IFhirResource resource, {
    List<IFhirResource> ephemeralRecords = const [],
  }) => run(
    RecordAttachmentsInitialised(
      resource: resource,
      ephemeralRecords: ephemeralRecords,
    ),
  );

  Future<void> storeDocument(
    Map<String, dynamic> json, {
    String sourceId = 'wallet-src',
    String title = 'Document title',
    String? encounterId,
  }) => db
      .into(db.fhirResource)
      .insert(
        FhirResourceCompanion.insert(
          id: '${sourceId}_${json['id']}',
          sourceId: drift.Value(sourceId),
          resourceId: drift.Value(json['id'] as String),
          resourceType: const drift.Value('DocumentReference'),
          title: drift.Value(title),
          encounterId: drift.Value(encounterId),
          resourceRaw: jsonEncode(json),
        ),
      );

  Future<List<FhirResourceLocalDto>> documentRows() => (db.select(
    db.fhirResource,
  )..where((t) => t.resourceType.equals('DocumentReference'))).get();

  /// The DocumentReferences that are not deleted.
  Future<List<FhirResourceLocalDto>> liveDocumentRows() async => [
    for (final row in await documentRows())
      if (row.deletedAt == null) row,
  ];

  /// Expects the row [id] to be a tombstone written now, in milliseconds.
  Future<void> expectTombstone(String id, int beforeMs) async {
    final row =
        (await db
                .customSelect(
                  'SELECT deleted_at, updated_at FROM fhir_resource WHERE id = ?',
                  variables: [drift.Variable.withString(id)],
                )
                .getSingle())
            .data;
    expect(row['deleted_at'] as int, greaterThanOrEqualTo(beforeMs));
    expect(row['updated_at'], row['deleted_at']);
  }

  Map<String, dynamic> attachmentOf(FhirResourceLocalDto row) =>
      ((jsonDecode(row.resourceRaw) as Map)['content'] as List)
              .first['attachment']
          as Map<String, dynamic>;

  /// A file the user picked, outside the documents directory.
  File picked(String name, {String folder = 'picked', String content = 'x'}) =>
      File('${root.path}/$folder/$name')
        ..createSync(recursive: true)
        ..writeAsStringSync(content);

  List<String> storedFiles() =>
      docs
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toList()
        ..sort();

  group('view', () {
    test('a DocumentReference shows its own file', () async {
      File('${docs.path}/my report.pdf').writeAsStringSync('pdf');
      final document = _record(
        _documentJson(
          id: 'doc-1',
          url: 'file://my%20report.pdf',
          title: 'My report.pdf',
        ),
      );

      final state = await open(document);

      expect(state.status, const RecordAttachmentsStatus.success());
      expect(state.resource, document);
      expect(state.attachments, hasLength(1));
      final info = state.attachments.single;
      expect(info.documentReference, document);
      expect(info.title, 'My report.pdf');
      expect(info.contentType, 'application/pdf');
      expect(info.filePath, '${docs.path}/my report.pdf');
      expect(repository.documentReads, 0);
    });

    test('an absolute URL inside the documents directory resolves', () async {
      File('${docs.path}/scan.png').writeAsStringSync('png');
      final document = _record(
        _documentJson(
          id: 'doc-1',
          url: 'file://${docs.path}/scan.png',
          contentType: 'image/png',
        ),
      );

      final info = (await open(document)).attachments.single;

      expect(info.filePath, '${docs.path}/scan.png');
      expect(info.contentType, 'image/png');
      expect(info.title, 'Record title');
    });

    test('a missing or non-local file has no path', () async {
      final missing = _record(
        _documentJson(id: 'doc-1', url: 'file://gone.pdf', title: 'gone.pdf'),
      );
      final remote = _record(
        _documentJson(id: 'doc-2', url: 'https://example.com/a.pdf'),
      );
      final noUrl = _record(
        _documentJson(id: 'doc-3', contentType: null),
        title: 'No file',
      );

      final missingInfo = (await open(missing)).attachments.single;
      final remoteInfo = (await open(remote)).attachments.single;
      final noUrlInfo = (await open(noUrl)).attachments.single;

      expect(missingInfo.title, 'gone.pdf');
      expect(missingInfo.filePath, isNull);
      expect(remoteInfo.filePath, isNull);
      expect(noUrlInfo.filePath, isNull);
      expect(noUrlInfo.contentType, isNull);
      expect(noUrlInfo.title, 'No file');
    });

    test('an unreadable attachment falls back to the record title', () async {
      final document = DocumentReference(
        id: 'local-doc',
        title: 'Broken',
        rawResource: {'content': 'not a list'},
      );

      final state = await open(document);

      expect(state.status, const RecordAttachmentsStatus.success());
      expect(state.attachments.single.title, 'Broken');
      expect(state.attachments.single.filePath, isNull);
      expect(state.attachments.single.contentType, isNull);
    });

    test('a record lists the documents related to it', () async {
      File('${docs.path}/a.pdf').writeAsStringSync('a');
      await storeDocument(
        _documentJson(
          id: 'doc-1',
          url: 'file://a.pdf',
          title: 'a.pdf',
          related: ['Observation/obs-1'],
        ),
      );
      await storeDocument(
        _documentJson(id: 'doc-2', related: ['Observation/obs-2']),
      );
      await storeDocument(_documentJson(id: 'doc-3'));
      await storeDocument(
        _documentJson(id: 'doc-4', encounters: ['Encounter/enc-1']),
        encounterId: 'enc-1',
      );
      repository.extraDocuments.addAll([
        DocumentReference(id: 'empty'),
        DocumentReference(
          id: 'odd',
          rawResource: {
            'context': {'related': 'Observation/obs-1'},
          },
        ),
      ]);

      final state = await open(_observation(encounter: 'Encounter/enc-1'));

      expect(state.status, const RecordAttachmentsStatus.success());
      expect(state.attachments.map((a) => a.title), ['a.pdf']);
      expect(state.attachments.single.filePath, '${docs.path}/a.pdf');
      expect(repository.encounterRequests, isEmpty);
    });

    test(
      'an encounter lists its own documents first, then its records\'',
      () async {
        await storeDocument(
          _documentJson(
            id: 'doc-1',
            title: 'lab.pdf',
            related: ['Observation/obs-1'],
            encounters: ['Encounter/enc-1'],
          ),
        );
        await storeDocument(
          _documentJson(id: 'doc-2', title: 'by-column.pdf'),
          encounterId: 'enc-1',
        );
        await storeDocument(
          _documentJson(
            id: 'doc-3',
            title: 'direct.pdf',
            related: ['Encounter/enc-1'],
            encounters: ['Encounter/enc-1'],
          ),
        );
        await storeDocument(
          _documentJson(
            id: 'doc-4',
            title: 'unknown-record.pdf',
            related: ['Observation/obs-9'],
            encounters: ['Encounter/enc-1'],
          ),
        );
        await storeDocument(
          _documentJson(
            id: 'doc-5',
            title: 'other.pdf',
            encounters: ['Encounter/enc-2'],
          ),
        );
        await storeDocument(
          _documentJson(
            id: 'doc-6',
            title: 'related-only.pdf',
            related: ['Encounter/enc-1'],
          ),
        );
        await storeDocument(
          _documentJson(
            id: 'doc-7',
            title: 'x-ray.pdf',
            related: ['Observation/obs-2'],
            encounters: ['Encounter/enc-1'],
          ),
        );
        repository.encounterRecords.addAll([
          _observation(encounter: 'Encounter/enc-1'),
          _observation(
            id: 'obs-2',
            encounter: 'Encounter/enc-1',
            title: 'Chest X-ray',
          ),
        ]);

        final state = await open(_encounter());

        expect(repository.encounterRequests, ['enc-1']);
        expect(state.attachments.map((a) => a.title), [
          'by-column.pdf',
          'direct.pdf',
          'unknown-record.pdf',
          'lab.pdf',
          'x-ray.pdf',
        ]);
        final lab = state.attachments[3];
        expect(lab.sourceRecordTitle, 'Glucose');
        expect(lab.sourceRecordType, FhirType.Observation);
        expect(state.attachments.last.sourceRecordTitle, 'Chest X-ray');
        expect(state.attachments.first.sourceRecordTitle, isNull);
      },
    );

    test('records shown from a share are related in memory', () async {
      final document = _record(
        _documentJson(id: 'doc-1', title: 'shared.pdf'),
        sourceId: 'share',
      );
      final unrelated = _record(
        _documentJson(id: 'doc-2', title: 'unrelated.pdf'),
        sourceId: 'share',
      );
      final observation = _observation(
        sourceId: 'share',
        derivedFrom: ['DocumentReference/doc-1'],
      );

      final state = await open(
        observation,
        ephemeralRecords: [observation, document, unrelated],
      );

      expect(state.attachments.map((a) => a.title), ['shared.pdf']);
      expect(repository.documentReads, 0);
    });

    test('a shared encounter relates documents in memory', () async {
      final encounter = _encounter();
      final observation = _observation(encounter: 'Encounter/enc-1');
      final direct = _record(
        _documentJson(
          id: 'doc-1',
          title: 'direct.pdf',
          encounters: ['Encounter/enc-1'],
        ),
      );
      final viaObservation = _record(
        _documentJson(
          id: 'doc-2',
          title: 'lab.pdf',
          related: ['Observation/obs-1'],
          encounters: ['Encounter/enc-1'],
        ),
      );

      final state = await open(
        encounter,
        ephemeralRecords: [encounter, observation, viaObservation, direct],
      );

      expect(state.attachments.map((a) => a.title), ['direct.pdf', 'lab.pdf']);
      expect(state.attachments.last.sourceRecordTitle, 'Glucose');
      expect(repository.documentReads, 0);
      expect(repository.encounterRequests, isEmpty);
    });

    test('a failed read shows the error state', () async {
      repository.error = StateError('db down');

      final state = await open(_observation());

      expect(state.status, isNot(const RecordAttachmentsStatus.success()));
      expect(
        state.status,
        RecordAttachmentsStatus.error(repository.error),
      );
    });
  });

  group('attach', () {
    test(
      'copies the file under a unique name and saves a DocumentReference',
      () async {
        final source = picked('report.pdf', content: 'hello');
        await open(_observation(encounter: 'Encounter/enc-1'));

        final state = await run(RecordAttachmentsFileAttached([source]));

        expect(state.status, const RecordAttachmentsStatus.success());
        final stored = storedFiles();
        expect(stored, hasLength(1));
        expect(stored.single, matches(RegExp(r'^report_[0-9a-f]{8}\.pdf$')));
        expect(
          File('${docs.path}/${stored.single}').readAsStringSync(),
          'hello',
        );
        expect(source.existsSync(), isTrue);

        final row = (await documentRows()).single;
        expect(row.title, 'report.pdf');
        expect(row.sourceId, 'wallet-src');
        expect(row.id, 'wallet-src_${row.resourceId}');
        expect(row.encounterId, 'enc-1');
        expect(row.subjectId, 'pat-1');
        final json = jsonDecode(row.resourceRaw) as Map<String, dynamic>;
        expect(json['id'], row.resourceId);
        expect(json['subject']['reference'], 'Patient/pat-1');
        expect(json['context']['encounter'][0]['reference'], 'Encounter/enc-1');
        expect(json['context']['related'][0]['reference'], 'Observation/obs-1');
        expect(json['identifier'][0]['value'], isNot(row.resourceId));
        expect(attachmentOf(row), {
          'contentType': 'application/pdf',
          'url': 'file://${stored.single}',
          'title': 'report.pdf',
          'size': 5,
        });

        expect(state.attachments, hasLength(1));
        expect(state.attachments.single.title, 'report.pdf');
        expect(
          state.attachments.single.filePath,
          '${docs.path}/${stored.single}',
        );
        expect(holderService.walletRequests, isEmpty);
      },
    );

    test('two files with the same name are both kept', () async {
      final first = picked('report.pdf', folder: 'a', content: 'first');
      final second = picked('report.pdf', folder: 'b', content: 'second');
      await open(_observation());

      final state = await run(RecordAttachmentsFileAttached([first, second]));

      final stored = storedFiles();
      expect(stored, hasLength(2));
      expect(
        stored.map((n) => File('${docs.path}/$n').readAsStringSync()).toSet(),
        {'first', 'second'},
      );
      final rows = await documentRows();
      expect(rows.map((r) => r.title), ['report.pdf', 'report.pdf']);
      expect(rows.map((r) => r.id).toSet(), hasLength(2));
      expect(rows.map((r) => attachmentOf(r)['url']).toSet(), hasLength(2));
      expect(state.attachments.map((a) => a.title), [
        'report.pdf',
        'report.pdf',
      ]);
    });

    test('attaching the same name again later keeps the first file', () async {
      await open(_observation());
      await run(RecordAttachmentsFileAttached([picked('scan.jpg')]));

      await run(
        RecordAttachmentsFileAttached([
          picked('scan.jpg', folder: 'later', content: 'new'),
        ]),
      );

      expect(storedFiles(), hasLength(2));
      expect(await documentRows(), hasLength(2));
    });

    test('a name with spaces and accents is stored sanitised', () async {
      await open(_observation());

      final state = await run(
        RecordAttachmentsFileAttached([picked('Blood test é 1.PNG')]),
      );

      final stored = storedFiles().single;
      expect(stored, matches(RegExp(r'^Blood_test___1_[0-9a-f]{8}\.PNG$')));
      final row = (await documentRows()).single;
      expect(row.title, 'Blood test é 1.PNG');
      expect(attachmentOf(row)['title'], 'Blood test é 1.PNG');
      expect(attachmentOf(row)['url'], 'file://$stored');
      expect(attachmentOf(row)['contentType'], 'image/png');
      expect(state.attachments.single.filePath, '${docs.path}/$stored');
    });

    test('each file type gets its content type', () async {
      await open(_observation());
      const types = {
        'a.jpg': 'image/jpeg',
        'b.jpeg': 'image/jpeg',
        'c.png': 'image/png',
        'd.pdf': 'application/pdf',
        'e.doc': 'application/msword',
        'f.docx': 'application/msword',
        'g.txt': 'text/plain',
        'h.zip': 'application/octet-stream',
        'noext': 'application/octet-stream',
      };

      await run(
        RecordAttachmentsFileAttached([for (final n in types.keys) picked(n)]),
      );

      final rows = await documentRows();
      expect({
        for (final r in rows) r.title: attachmentOf(r)['contentType'],
      }, types);
    });

    test(
      'a record of a read-only source attaches to the wallet source',
      () async {
        await open(_observation(sourceId: 'fasten-src'));

        await run(RecordAttachmentsFileAttached([picked('a.pdf')]));

        expect(holderService.walletRequests, ['pat-1']);
        expect((await documentRows()).single.sourceId, 'wallet-pat-1');
      },
    );

    test(
      'a record of an unknown source attaches to the wallet source',
      () async {
        await open(_observation(sourceId: 'gone-src'));

        await run(RecordAttachmentsFileAttached([picked('a.pdf')]));

        expect(holderService.walletRequests, ['pat-1']);
        expect((await documentRows()).single.sourceId, 'wallet-pat-1');
      },
    );

    test(
      'a record without a subject attaches without a subject',
      () async {
        await open(_observation(subject: null));

        await run(RecordAttachmentsFileAttached([picked('a.pdf')]));

        final row = (await documentRows()).single;
        final json = jsonDecode(row.resourceRaw) as Map<String, dynamic>;
        expect(json['subject'], isNull);
        expect(row.subjectId, isNull);
      },
      skip:
          'BUG: the DocumentReference gets the reference "Patient/" and an '
          'empty subject_id',
    );

    test('an encounter attaches its own id and subject', () async {
      await open(_encounter());

      await run(RecordAttachmentsFileAttached([picked('a.pdf')]));

      final row = (await documentRows()).single;
      expect(row.encounterId, 'enc-1');
      expect(row.subjectId, 'pat-1');
      final json = jsonDecode(row.resourceRaw) as Map<String, dynamic>;
      expect(json['context']['related'][0]['reference'], 'Encounter/enc-1');
    });

    test('a patient attaches with itself as subject', () async {
      await open(_record({'resourceType': 'Patient', 'id': 'pat-7'}));

      await run(RecordAttachmentsFileAttached([picked('a.pdf')]));

      final row = (await documentRows()).single;
      expect(row.subjectId, 'pat-7');
      expect(row.encounterId, isNull);
    });

    test('urn:uuid references give the subject and encounter', () async {
      await open(
        _observation(subject: 'urn:uuid:pat-u', encounter: 'urn:uuid:enc-u'),
      );

      await run(RecordAttachmentsFileAttached([picked('a.pdf')]));

      final row = (await documentRows()).single;
      expect(row.subjectId, 'pat-u');
      expect(row.encounterId, 'enc-u');
    });

    test('an encounter listed in the record context is used', () async {
      Future<String?> attachedEncounter(List<Object> encounters) async {
        await db.delete(db.fhirResource).go();
        await open(
          Observation(
            id: 'wallet-src_obs-c',
            sourceId: 'wallet-src',
            resourceId: 'obs-c',
            rawResource: {
              'subject': {'reference': 'Patient/pat-1'},
              'context': {'encounter': encounters},
            },
          ),
        );
        await run(RecordAttachmentsFileAttached([picked('a.pdf')]));
        return (await documentRows()).single.encounterId;
      }

      expect(
        await attachedEncounter([
          {'reference': 'Encounter/enc-c'},
        ]),
        'enc-c',
      );
      expect(
        await attachedEncounter([
          {'reference': 'urn:uuid:enc-u'},
        ]),
        'enc-u',
      );
      expect(
        await attachedEncounter([
          {'reference': 'Location/l-1'},
        ]),
        isNull,
      );
      expect(
        await attachedEncounter([
          {'display': 'No reference'},
        ]),
        isNull,
      );
      expect(await attachedEncounter([]), isNull);
    });

    test('a DocumentReference cannot get attachments', () async {
      await open(_record(_documentJson(id: 'doc-1')));

      final state = await run(RecordAttachmentsFileAttached([picked('a.pdf')]));

      expect(
        state.status,
        RecordAttachmentsStatus.error(
          strings.l10n.cannotAttachToDocumentReference,
        ),
      );
      expect(storedFiles(), isEmpty);
      expect(await documentRows(), isEmpty);
    });

    test('a failed copy shows a translated error and saves nothing', () async {
      await open(_observation());

      final state = await run(
        RecordAttachmentsFileAttached([File('${root.path}/missing.pdf')]),
      );

      expect(
        state.status,
        RecordAttachmentsStatus.error(strings.l10n.attachFileFailed),
      );
      expect(storedFiles(), isEmpty);
      expect(await documentRows(), isEmpty);
    });

    test('a failed save removes the copied file', () async {
      await open(_observation());
      await db.customStatement('DROP TABLE fhir_resource');

      final state = await run(RecordAttachmentsFileAttached([picked('a.pdf')]));

      expect(
        state.status,
        RecordAttachmentsStatus.error(strings.l10n.attachFileFailed),
      );
      expect(storedFiles(), isEmpty);
    });

    test(
      'a copy that cannot be removed after a failed save is logged',
      () async {
        // The bloc's handlers run in the zone it was created in.
        await bloc.close();
        bloc = IOOverrides.runWithIOOverrides(
          () => RecordAttachmentsBloc(
            repository,
            sourceTypeService,
            holderService,
            syncRepository,
            db,
            PathResolver(),
            strings,
          ),
          _UndeletableFilesIn(docs.path),
        );
        await open(_observation());
        await db.customStatement('DROP TABLE fhir_resource');

        final state = await run(
          RecordAttachmentsFileAttached([picked('a.pdf')]),
        );

        expect(
          state.status,
          RecordAttachmentsStatus.error(strings.l10n.attachFileFailed),
        );
        expect(storedFiles(), hasLength(1));
        expect(
          logs,
          loggedWarning('Removing an unsaved attachment copy failed'),
        );
      },
    );

    test('when a later file fails, the files saved before it are '
        'listed', () async {
      await open(_observation());
      await db.customStatement(
        'CREATE TEMP TRIGGER fail_b BEFORE INSERT ON fhir_resource '
        "WHEN NEW.title = 'b.pdf' BEGIN SELECT RAISE(ABORT, 'boom'); END",
      );
      final reloaded = bloc.stream.firstWhere(
        (s) => s.status == const RecordAttachmentsStatus.success(),
      );

      final state = await run(
        RecordAttachmentsFileAttached([picked('a.pdf'), picked('b.pdf')]),
      );

      expect(
        state.status,
        RecordAttachmentsStatus.error(strings.l10n.attachFileFailed),
      );
      final listed = await reloaded;
      expect(listed.attachments.map((a) => a.title), ['a.pdf']);
      expect(storedFiles(), hasLength(1));
      expect((await documentRows()).map((r) => r.title), ['a.pdf']);
    });
  });

  group('uniqueStoredFileName', () {
    Future<String> name(String original) =>
        RecordAttachmentsBloc.uniqueStoredFileName(docs.path, original);

    test('keeps a safe name and adds a suffix before the extension', () async {
      expect(
        await name('report.v2.pdf'),
        matches(r'^report\.v2_[0-9a-f]{8}\.pdf$'),
      );
      expect(await name('notes'), matches(r'^notes_[0-9a-f]{8}$'));
      expect(
        await name('my-file_1.txt'),
        matches(r'^my-file_1_[0-9a-f]{8}\.txt$'),
      );
    });

    test('two calls give different names', () async {
      expect(await name('a.pdf'), isNot(await name('a.pdf')));
    });

    test('never gives a hidden or empty name', () async {
      expect(await name('.pdf'), matches(r'^file_[0-9a-f]{8}\.pdf$'));
      expect(await name('..report.pdf'), matches(r'^report_[0-9a-f]{8}\.pdf$'));
      expect(await name('отчет.pdf'), matches(r'^file_[0-9a-f]{8}\.pdf$'));
      expect(await name(''), matches(r'^file_[0-9a-f]{8}$'));
      expect(await name('report.'), matches(r'^report\._[0-9a-f]{8}$'));
    });

    test('shortens long names and ignores a long extension', () async {
      final long = await name('${'a' * 300}.pdf');
      expect(long, matches(RegExp('^a{100}_[0-9a-f]{8}\\.pdf\$')));

      final odd = await name('archive.${'x' * 20}');
      expect(odd, startsWith('archive.xxxx'));
      expect(odd, matches(r'_[0-9a-f]{8}$'));
      expect(odd.length, lessThan(120));
    });
  });

  group('delete', () {
    test('tombstones the record and removes its file, keeping a same-name '
        'one', () async {
      await open(_observation());
      await run(
        RecordAttachmentsFileAttached([
          picked('report.pdf', folder: 'a', content: 'first'),
          picked('report.pdf', folder: 'b', content: 'second'),
        ]),
      );
      final rows = await documentRows();
      final first = rows.first;
      final firstFile = attachmentOf(first)['url'].toString().substring(7);
      final document = IFhirResource.fromLocalDto(first);
      final before = DateTime.now().millisecondsSinceEpoch;

      final state = await run(RecordAttachmentsFileDeleted(document));

      expect(state.status, const RecordAttachmentsStatus.success());
      expect(await documentRows(), hasLength(2), reason: 'rows are kept');
      await expectTombstone(first.id, before);
      expect((await liveDocumentRows()).map((r) => r.id), [rows.last.id]);
      expect(storedFiles(), hasLength(1));
      expect(storedFiles(), isNot(contains(firstFile)));
      expect(state.attachments, hasLength(1));
      expect(
        File(state.attachments.single.filePath!).readAsStringSync(),
        'second',
      );
    });

    test('tombstones the record when its file is already gone', () async {
      await storeDocument(
        _documentJson(
          id: 'doc-1',
          url: 'file://gone.pdf',
          related: ['Observation/obs-1'],
        ),
      );
      await open(_observation());
      final row = (await documentRows()).single;
      final before = DateTime.now().millisecondsSinceEpoch;

      final state = await run(
        RecordAttachmentsFileDeleted(IFhirResource.fromLocalDto(row)),
      );

      expect(state.status, const RecordAttachmentsStatus.success());
      await expectTombstone(row.id, before);
      expect(await liveDocumentRows(), isEmpty);
      expect(state.attachments, isEmpty);
    });

    test('a remote or missing URL leaves other files alone', () async {
      File('${docs.path}/keep.pdf').writeAsStringSync('keep');
      await storeDocument(
        _documentJson(id: 'doc-1', url: 'https://example.com/keep.pdf'),
      );
      await storeDocument(_documentJson(id: 'doc-2'));
      await open(_observation());
      final rows = await documentRows();

      await run(
        RecordAttachmentsFileDeleted(IFhirResource.fromLocalDto(rows[0])),
      );
      await run(
        RecordAttachmentsFileDeleted(IFhirResource.fromLocalDto(rows[1])),
      );

      expect(await liveDocumentRows(), isEmpty);
      expect(storedFiles(), ['keep.pdf']);
    });

    test('an unreadable attachment is still deleted', () async {
      await storeDocument(_documentJson(id: 'doc-1'));
      await open(_observation());
      final row = (await documentRows()).single;
      final before = DateTime.now().millisecondsSinceEpoch;

      final state = await run(
        RecordAttachmentsFileDeleted(
          DocumentReference(
            id: row.id,
            rawResource: const {'content': 'not a list'},
          ),
        ),
      );

      expect(state.status, const RecordAttachmentsStatus.success());
      await expectTombstone(row.id, before);
      expect(await liveDocumentRows(), isEmpty);
    });

    test(
      'a failed delete shows a translated error and keeps the file',
      () async {
        await open(_observation());
        await run(RecordAttachmentsFileAttached([picked('a.pdf')]));
        final document = IFhirResource.fromLocalDto(
          (await documentRows()).single,
        );
        await db.customStatement('DROP TABLE fhir_resource');

        final state = await run(RecordAttachmentsFileDeleted(document));

        expect(
          state.status,
          RecordAttachmentsStatus.error(strings.l10n.attachmentDeleteFailed),
        );
        expect(storedFiles(), hasLength(1));
      },
    );
  });
}
