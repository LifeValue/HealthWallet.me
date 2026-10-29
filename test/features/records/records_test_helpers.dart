import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/data/data_source/shared_notes_datasource.dart';
import 'package:health_wallet/features/records/data/repository/records_repository_impl.dart';
import 'package:health_wallet/features/sync/data/data_source/local/sync_local_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

export '../desktop/lww_sync/lww_sync_test_helpers.dart' show openTestDatabase;

/// The real repository on [db], with in-memory preferences.
Future<RecordsRepositoryImpl> openRepository(AppDatabase db) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return RecordsRepositoryImpl(
    db,
    SyncLocalDataSourceImpl(db, prefs),
    SharedNotesDatasource(),
  );
}

/// Inserts a minimal valid FHIR resource of [type] as a `fhir_resource` row.
/// [raw] is merged over the minimal resource.
Future<void> insertResource(
  AppDatabase db, {
  required String id,
  required String type,
  String? sourceId,
  String? resourceId,
  String? title,
  DateTime? date,
  String? encounterId,
  String? subjectId,
  Map<String, dynamic> raw = const {},
}) async {
  await db
      .into(db.fhirResource)
      .insert(
        FhirResourceCompanion.insert(
          id: id,
          sourceId: Value(sourceId),
          resourceType: Value(type),
          resourceId: Value(resourceId ?? id),
          title: Value(title),
          date: Value(date),
          resourceRaw: jsonEncode({
            'resourceType': type,
            'id': resourceId ?? id,
            ..._required[type] ?? const {},
            ...raw,
          }),
          encounterId: Value(encounterId),
          subjectId: Value(subjectId),
        ),
      );
}

/// Inserts a `sources` row, which notes and patients refer to.
Future<void> insertSource(AppDatabase db, String id) async {
  await db
      .into(db.sources)
      .insert(SourcesCompanion.insert(id: id, labelSource: Value(id)));
}

/// Fields `fhir_r4` requires before it parses a resource.
const _required = <String, Map<String, dynamic>>{
  'Observation': {
    'status': 'final',
    'code': {'text': 'Observation'},
  },
  'Condition': {
    'subject': {'reference': 'Patient/p'},
  },
  'Encounter': {
    'status': 'finished',
    'class': {'code': 'AMB'},
  },
  'DocumentReference': {
    'status': 'current',
    'content': [
      {
        'attachment': {'title': 'doc'},
      },
    ],
  },
  'MedicationRequest': {
    'status': 'active',
    'intent': 'order',
    'subject': {'reference': 'Patient/p'},
    'medicationCodeableConcept': {'text': 'med'},
  },
  'Media': {
    'status': 'completed',
    'content': {'contentType': 'image/png'},
  },
};
