import 'dart:convert';
import 'dart:developer';

import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/sync/data/data_source/local/sync_local_data_source.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/features/sync/data/remote/sync_remote_data_source.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart'
    as entity;
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/ehrs/fasten/data/remote/source_remote_data_source.dart';
import 'package:health_wallet/features/sync/ehrs/fasten/domain/entities/sync_qr_data.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@Injectable(as: SyncRepository)
class SyncRepositoryImpl implements SyncRepository {
  final SyncRemoteDataSource _remoteDataSource;
  final SyncLocalDataSource _localDataSource;
  final SourceRemoteDataSource _sourceRemoteDataSource;
  final SharedPreferences _prefs;

  SyncRepositoryImpl(
    this._remoteDataSource,
    this._localDataSource,
    this._sourceRemoteDataSource,
    this._prefs,
  );

  static const String _tokenKey = 'sync_token';

  @override
  Future<void> syncResources({required String endpoint}) async {
    final List<FhirResourceDto> resources = await _remoteDataSource
        .getResources(endpoint: endpoint);

    await _localDataSource.cacheFhirResources(
      resources
          .map(
            (resource) => resource
                .populateEncounterIdFromRaw()
                .populateSubjectIdFromRaw(),
          )
          .toList(),
    );
    await _localDataSource.setLastSyncTimestamp(
      DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<String?> getLastSyncTimestamp() {
    return _localDataSource.getLastSyncTimestamp();
  }

  /// The local sources, after storing what the provider lists. Read from
  /// the database, so each source keeps its holder, the label the user gave
  /// it and its tombstone.
  @override
  Future<List<entity.Source>> getSources() async {
    try {
      final backendSources = await _sourceRemoteDataSource.getSources();
      if (backendSources.isNotEmpty) {
        await _localDataSource.cacheProviderSources(backendSources);
      }
    } catch (e) {
      // Offline or not connected to Fasten: the stored sources are shown.
      logger.w('Fetching the provider sources failed', e);
    }
    return _localDataSource.getSources();
  }

  @override
  void setBaseUrl(String baseUrl) {
    if (!baseUrl.endsWith('/')) {
      baseUrl += '/';
    }
    _remoteDataSource.updateBaseUrl(baseUrl);
    _sourceRemoteDataSource.updateBaseUrl(baseUrl);
  }

  @override
  void setBearerToken(String token) {
    _remoteDataSource.updateAuthorizationToken(token);
    _sourceRemoteDataSource.updateAuthorizationToken(token);
  }

  @override
  Future<void> saveSyncQrData(SyncQrData qrData) async {
    await _prefs.setString(_tokenKey, jsonEncode(qrData.toJson()));
  }

  @override
  Future<SyncQrData?> getCurrentSyncQrData() async {
    final qrDataJsonString = _prefs.getString(_tokenKey);
    if (qrDataJsonString == null) return null;

    try {
      final qrDataJson = jsonDecode(qrDataJsonString) as Map<String, dynamic>;
      final qrData = SyncQrData.fromJson(qrDataJson);

      if (qrData.tokenMeta.isExpired) {
        await clearToken();
        return null;
      }

      return qrData;
    } catch (e) {
      await clearToken();
      return null;
    }
  }

  @override
  Future<void> updateSourceLabel(String sourceId, String newLabel) async {
    return _localDataSource.updateSourceLabel(sourceId, newLabel);
  }

  @override
  Future<void> createDemoDataSource() async {
    return _localDataSource.createDemoDataSource();
  }

  @override
  Future<void> deleteSource(String sourceId) async {
    return _localDataSource.deleteSource(sourceId);
  }

  @override
  Future<void> cacheSources(List<entity.Source> sources) async {
    return _localDataSource.cacheSources(sources);
  }

  Future<void> clearToken() async {
    log('remove');
    await _prefs.remove(_tokenKey);
  }

  @override
  Future saveResources(List<IFhirResource> resources) async {
    await _localDataSource.cacheFhirResources(
      resources.map((resource) => resource.toDto()).toList(),
    );
  }
}
