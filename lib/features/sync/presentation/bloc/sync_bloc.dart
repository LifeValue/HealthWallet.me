import 'dart:convert';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:injectable/injectable.dart';
import 'package:health_wallet/features/sync/domain/entities/sync_qr_data.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/user/domain/services/default_patient_service.dart';

part 'sync_event.dart';
part 'sync_state.dart';
part 'sync_bloc.freezed.dart';

@injectable
class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final SyncRepository _syncRepository;
  final RecordsRepository _recordsRepository;
  final DefaultPatientService _defaultPatientService;

  SyncBloc(
    this._syncRepository,
    this._recordsRepository,
    this._defaultPatientService,
  ) : super(const SyncState()) {
    on<SyncInitialised>(_onSyncInitialised);
    on<SyncData>(_onSyncData);

    on<SyncScanQRCode>(_onScanQRCode);
    on<SyncScanNewPressed>(_onSyncScanNewPressed);
    on<SyncCancel>(_onSyncCancel);
    on<LoadDemoData>(_onLoadDemoData);
    on<DataHandled>(_onDataHandled);
    on<TriggerTutorial>(_onTriggerTutorial);
    on<ResetTutorial>(_onResetTutorial);
    on<DemoDataConfirmed>(_onDemoDataConfirmed);
    on<CreateWalletSource>(_onCreateWalletSource);
  }

  _onSyncInitialised(
    SyncInitialised event,
    Emitter<SyncState> emit,
  ) async {
    emit(state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    ));
    try {
      SyncQrData? qrData = await _syncRepository.getCurrentSyncQrData();
      String? lastSyncTime = await _syncRepository.getLastSyncTimestamp();

      emit(state.copyWith(
        syncQrData: qrData,
        lastSyncTime: lastSyncTime,
        syncStatus: qrData != null ? SyncStatus.synced : SyncStatus.initial,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString(), isLoading: false));
    }
  }

  Future<void> _onSyncData(
    SyncData event,
    Emitter<SyncState> emit,
  ) async {
    emit(state.copyWith(
      isLoading: true,
      isQRScanning: false,
      syncStatus: SyncStatus.syncing,
      errorMessage: null,
      successMessage: null,
    ));
    try {
      final qrDataJson = jsonDecode(event.qrData) as Map<String, dynamic>;
      final syncQrData = SyncQrData.fromJson(qrDataJson);

      await _defaultPatientService.createAndSetAsMain();

      await _recordsRepository.clearDemoData();

      Exception? exception;
      _syncRepository.setBearerToken(syncQrData.token);
      for (String baseUrl in syncQrData.serverBaseUrls) {
        _syncRepository.setBaseUrl(baseUrl);

        try {
          await _syncRepository.syncResources(
              endpoint: syncQrData.syncEndpoint);

          exception = null;
          break;
        } on Exception catch (e) {
          exception = e;
          continue;
        }
      }
      if (exception != null) throw exception;

      await _syncRepository.saveSyncQrData(syncQrData);

      emit(state.copyWith(
        isLoading: false,
        syncStatus: SyncStatus.synced,
        syncQrData: syncQrData,
        lastSyncTime: DateTime.now().toIso8601String(),
        hasSyncedData: true,
        syncDialogShown: true,
        errorMessage: null,
        successMessage: "Data was succesfully synced!",
      ));

      add(const DataHandled(
        sourceId: 'sync',
        isSuccess: true,
      ));
    } catch (e) {
      String errorMessage;
      if (e.toString().contains('HandshakeException') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('timeout')) {
        errorMessage =
            'Connection failed. Please check your network and try again.';
      } else if (e.toString().contains('404')) {
        errorMessage =
            'Sync endpoint not found. Please check server configuration.';
      } else if (e.toString().contains('401') || e.toString().contains('403')) {
        errorMessage = 'Authentication failed. Please check your token.';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = 'Invalid sync data format';
      } else {
        errorMessage = 'Data sync failed: $e';
      }

      emit(state.copyWith(
        isLoading: false,
        errorMessage: errorMessage,
        successMessage: null,
        syncStatus: SyncStatus.initial,
      ));
    }
  }

  Future<void> _onScanQRCode(
      SyncScanQRCode event, Emitter<SyncState> emit) async {
    emit(state.copyWith(
      isQRScanning: true,
    ));
  }

  Future<void> _onSyncScanNewPressed(
      SyncScanNewPressed event, Emitter<SyncState> emit) async {
    emit(state.copyWith(
      syncStatus: SyncStatus.syncing,
      successMessage: null,
      errorMessage: null,
    ));
  }

  Future<void> _onSyncCancel(SyncCancel event, Emitter<SyncState> emit) async {
    emit(state.copyWith(
      isQRScanning: false,
      isLoading: false,
      syncStatus: SyncStatus.initial,
      errorMessage: null,
    ));
  }

  Future<void> _onLoadDemoData(
      LoadDemoData event, Emitter<SyncState> emit) async {
    try {
      await _defaultPatientService.createAndSetAsMain();

      // Load demo data - it includes demo patient with source 'demo_data'
      await _recordsRepository.loadDemoData();
      final hasDemoData = await _recordsRepository.hasDemoData();

      emit(state.copyWith(
        hasDemoData: hasDemoData,
      ));

      add(const DataHandled(
        sourceId: 'demo_data',
        isSuccess: true,
      ));
    } catch (e) {
      logger.e('Failed to load demo data: $e');

      add(DataHandled(
        sourceId: 'demo_data',
        isSuccess: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onDataHandled(
      DataHandled event, Emitter<SyncState> emit) async {
    if (event.isSuccess) {
      if (event.sourceId == 'demo_data') {
        final hasDemoData = await _recordsRepository.hasDemoData();
        emit(state.copyWith(
          hasDemoData: hasDemoData,
        ));
      } else if (event.sourceId == 'sync') {
        emit(state.copyWith(
          hasSyncedData: true,
        ));
      }
    }
  }

  Future<void> _onTriggerTutorial(
      TriggerTutorial event, Emitter<SyncState> emit) async {
    emit(state.copyWith(
      shouldShowTutorial: true,
    ));
  }

  Future<void> _onResetTutorial(
      ResetTutorial event, Emitter<SyncState> emit) async {
    emit(state.copyWith(
      shouldShowTutorial: false,
      syncDialogShown: false,
      demoDataConfirmed: false,
    ));
  }

  Future<void> _onDemoDataConfirmed(
      DemoDataConfirmed event, Emitter<SyncState> emit) async {
    emit(state.copyWith(
      demoDataConfirmed: true,
    ));
  }

  Future<void> _onCreateWalletSource(
      CreateWalletSource event, Emitter<SyncState> emit) async {
    try {
      await _defaultPatientService.createAndSetAsMain();
    } catch (e) {
      logger.e('Error creating wallet source: $e');
    }
  }
}
