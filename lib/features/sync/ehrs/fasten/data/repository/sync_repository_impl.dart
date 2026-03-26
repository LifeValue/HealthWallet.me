import 'dart:convert';
import 'dart:developer';

import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/sync/data/data_source/local/sync_local_data_source.dart';
import 'package:health_wallet/features/sync/data/remote/sync_remote_data_source.dart';
import 'package:health_wallet/features/sync/ehrs/fasten/data/remote/source_remote_data_source.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart'
    as entity;
import 'package:health_wallet/features/sync/ehrs/fasten/domain/entities/sync_qr_data.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:injectable/injectable.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
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
    List<FhirResourceDto> resources =
        await _remoteDataSource.getResources(endpoint: endpoint);

    await _localDataSource.cacheFhirResources(resources
        .map((resource) =>
            resource.populateEncounterIdFromRaw().populateSubjectIdFromRaw())
        .toList());
    await _localDataSource
        .setLastSyncTimestamp(DateTime.now().toIso8601String());
  }

  @override
  Future<String?> getLastSyncTimestamp() {
    return _localDataSource.getLastSyncTimestamp();
  }

  @override
  Future<List<entity.Source>> getSources() async {
    // Always get local sources first to ensure wallet source is preserved
    final localSources = await _localDataSource.getSources();

    try {
      // Try to get sources from backend API
      final backendSources = await _sourceRemoteDataSource.getSources();

      if (backendSources.isNotEmpty) {
        // Use backend sources directly
        final enrichedSources = backendSources;

        // Merge backend sources with local sources, preserving local sources
        final mergedSources = <entity.Source>[];

        // Add all backend sources
        mergedSources.addAll(enrichedSources);

        // Add local sources that are not in backend (like wallet)
        for (final localSource in localSources) {
          if (!enrichedSources
              .any((backendSource) => backendSource.id == localSource.id)) {
            mergedSources.add(entity.Source(
              id: localSource.id,
              platformName: localSource.platformName,
              logo: localSource.logo,
              labelSource: localSource.labelSource,
              platformType: localSource.platformType,
            ));
          }
        }

        // Cache backend sources to local database for persistence
        final localSourcesToCache = enrichedSources;
        await _localDataSource.cacheSources(localSourcesToCache);

        return mergedSources;
      }
    } catch (e) {
      // If backend is not available, fall back to local sources
    }

    // Fallback to local sources only
    final mappedSources = localSources
        .map(
          (e) => entity.Source(
            id: e.id,
            platformName: e.platformName,
            logo: e.logo,
            labelSource: e.labelSource,
            platformType: e.platformType,
          ),
        )
        .toList();

    return mappedSources;
  }

  @override
  void setBaseUrl(String baseUrl) {
    if (!baseUrl.endsWith("/")) {
      baseUrl += "/";
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
  Future<void> createWalletSource() async {
    return _localDataSource.createWalletSource();
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
    log("remove");
    await _prefs.remove(_tokenKey);
  }

  @override
  Future saveResources(List<IFhirResource> resources) async {
    await _localDataSource.cacheFhirResources(
        resources.map((resource) => resource.toDto()).toList());
  }
}
