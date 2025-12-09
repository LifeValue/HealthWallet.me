import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:injectable/injectable.dart';

abstract class ScanLocalDataSource {
  Future<int> cacheProcessingSession(ProcessingSessionsCompanion entity);
  Future<List<ProcessingSessionDto>> getProcessingSessions();
  Future<int> updateProcessingSession(
    String id,
    ProcessingSessionsCompanion entity,
  );
  Future<int> deleteProcessingSession(String id);
}

@LazySingleton(as: ScanLocalDataSource)
class ScanLocalDataSourceImpl implements ScanLocalDataSource {
  final AppDatabase appDatabase;

  const ScanLocalDataSourceImpl(this.appDatabase);

  @override
  Future<int> cacheProcessingSession(ProcessingSessionsCompanion entity) async {
    return appDatabase
        .into(appDatabase.processingSessions)
        .insertOnConflictUpdate(entity);
  }

  @override
  Future<List<ProcessingSessionDto>> getProcessingSessions() async {
    return (appDatabase.select(appDatabase.processingSessions)).get();
  }

  @override
  Future<int> updateProcessingSession(
    String id,
    ProcessingSessionsCompanion entity,
  ) async {
    return (appDatabase.update(appDatabase.processingSessions)
          ..where((t) => t.id.equals(id)))
        .write(entity);
  }

  @override
  Future<int> deleteProcessingSession(String id) async {
    return (appDatabase.delete(appDatabase.processingSessions)
          ..where((t) => t.id.equals(id)))
        .go();
  }
}
