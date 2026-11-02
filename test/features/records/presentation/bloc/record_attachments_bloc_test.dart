import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/features/records/data/repository/records_repository_impl.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_attachments/bloc/record_attachments_bloc.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';

import '../../records_test_helpers.dart';

class _FakeSourceTypeService extends Fake implements SourceTypeService {}

class _FakeSyncRepository extends Fake implements SyncRepository {}

class _FakeStrings extends Fake implements AppStringsProvider {}

void main() {
  late AppDatabase db;
  late Directory docs;
  late RecordsRepositoryImpl repository;
  late RecordAttachmentsBloc bloc;

  setUp(() async {
    db = openTestDatabase();
    docs = Directory.systemTemp.createTempSync('attachments_bloc_docs');
    repository = await openRepository(db, documentsPath: docs.path);
    bloc = RecordAttachmentsBloc(
      repository,
      _FakeSourceTypeService(),
      _FakeSyncRepository(),
      db,
      DocumentsPathResolver(docs.path),
      _FakeStrings(),
    );
  });

  tearDown(() async {
    await bloc.close();
    await db.close();
    docs.deleteSync(recursive: true);
  });

  Future<RecordAttachmentsState> settled() => bloc.stream.firstWhere(
    (s) => s.status != const RecordAttachmentsStatus.loading(),
  );

  test('lists the files attached to a record, with their paths', () async {
    File('${docs.path}/scan.pdf').writeAsBytesSync([1]);
    await insertResource(
      db,
      id: 'doc',
      type: 'DocumentReference',
      raw: {
        'content': [
          {
            'attachment': {
              'title': 'scan.pdf',
              'contentType': 'application/pdf',
              'url': 'file://scan.pdf',
            },
          },
        ],
        'context': {
          'related': [
            {'reference': 'Condition/cond'},
          ],
        },
      },
    );

    bloc.add(
      const RecordAttachmentsInitialised(
        resource: Condition(id: 'cond', resourceId: 'cond'),
      ),
    );
    final state = await settled();

    expect(state.attachments.single.title, 'scan.pdf');
    expect(state.attachments.single.filePath, '${docs.path}/scan.pdf');
  });

  test('a file whose record names no patient is not attached', () async {
    final picked = File('${docs.path}/picked.pdf')..writeAsBytesSync([1]);
    // An allergy whose patient reference is missing.
    const allergy = AllergyIntolerance(id: 'allergy', resourceId: 'allergy');
    bloc.add(const RecordAttachmentsInitialised(resource: allergy));
    await settled();

    bloc.add(RecordAttachmentsFileAttached([picked]));
    final state = await settled();

    expect(
      state.status,
      isA<RecordAttachmentsStatus>().having(
        (s) => s.maybeWhen(error: (_) => true, orElse: () => false),
        'error',
        isTrue,
      ),
    );
    final documents = await (db.select(
      db.fhirResource,
    )..where((r) => r.resourceType.equals('DocumentReference'))).get();
    expect(documents, isEmpty);
  });
}
