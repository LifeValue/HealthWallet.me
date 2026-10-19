import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/ehrs/fasten/domain/entities/sync_qr_data.dart';

abstract class SyncRepository {
  Future<List<Source>> getSources();
  Future<void> syncResources({required String endpoint});
  Future<String?> getLastSyncTimestamp();
  void setBaseUrl(String baseUrl);
  void setBearerToken(String token);
  Future<void> saveSyncQrData(SyncQrData qrData);
  Future<SyncQrData?> getCurrentSyncQrData();
  Future<void> updateSourceLabel(String sourceId, String newLabel);
  Future<void> createWalletSource();
  Future<void> createDemoDataSource();
  Future<void> deleteSource(String sourceId);
  Future<void> cacheSources(List<Source> sources);
  Future saveResources(List<IFhirResource> resources);
}
