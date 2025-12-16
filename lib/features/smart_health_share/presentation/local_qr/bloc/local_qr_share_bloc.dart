import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/smart_health_share/domain/local_qr/entities/local_qr_share_config.dart';
import 'package:health_wallet/features/smart_health_share/domain/local_qr/entities/local_qr_share_session.dart';
import 'package:health_wallet/features/smart_health_share/domain/local_qr/repositories/local_qr_share_repository.dart';
import 'package:health_wallet/features/smart_health_share/domain/local_qr/services/ble_data_transfer_service.dart';
import 'package:health_wallet/features/smart_health_share/domain/local_qr/services/local_qr_expiration_service.dart';
import 'package:health_wallet/features/smart_health_share/domain/local_qr/services/local_qr_proximity_service.dart';
import 'package:injectable/injectable.dart';

part 'local_qr_share_event.dart';
part 'local_qr_share_state.dart';
part 'local_qr_share_bloc.freezed.dart';

@injectable
class LocalQRShareBloc extends Bloc<LocalQRShareEvent, LocalQRShareState> {
  final LocalQRShareRepository _localQRShareRepository;
  final RecordsRepository _recordsRepository;
  final LocalQRExpirationService _expirationService;
  final LocalQRProximityService _proximityService;
  final BLEDataTransferService _bleDataTransferService;

  StreamSubscription<int>? _expirationSubscription;
  StreamSubscription<bool>? _proximitySubscription;
  StreamSubscription<double>? _bleTransferSubscription;

  LocalQRShareBloc(
    this._localQRShareRepository,
    this._recordsRepository,
    this._expirationService,
    this._proximityService,
    this._bleDataTransferService,
  ) : super(const LocalQRShareState()) {
    on<LocalQRShareInitialized>(_onInitialized);
    on<LocalQRShareLoadResources>(_onLoadResources);
    on<LocalQRShareResourcesSelected>(_onResourcesSelected);
    on<LocalQRShareConfigChanged>(_onConfigChanged);
    on<LocalQRShareGenerateQrCode>(_onGenerateQrCode);
    on<LocalQRShareTimerTick>(_onTimerTick);
    on<LocalQRShareProximityChanged>(_onProximityChanged);
    on<LocalQRShareBleTransferProgress>(_onBleTransferProgress);
    on<LocalQRShareExpired>(_onExpired);
    on<LocalQRShareStop>(_onStop);
    on<LocalQRShareReset>(_onReset);
  }

  Future<void> _onInitialized(
    LocalQRShareInitialized event,
    Emitter<LocalQRShareState> emit,
  ) async {
    // Always use time + proximity mode (no UI selection needed)
    emit(state.copyWith(
      isLoading: false,
      errorMessage: null,
      session: null,
      config: LocalQRShareConfig.defaultTimeAndLocation,
    ));
    add(const LocalQRShareEvent.loadResources());
  }

  Future<void> _onLoadResources(
    LocalQRShareLoadResources event,
    Emitter<LocalQRShareState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final resources = await _recordsRepository.getResources(
        resourceTypes: [],
        limit: 1000,
      );

      // Don't filter out Patient - allow it to be selected
      final filteredResources = resources;

      emit(state.copyWith(
        isLoading: false,
        availableResources: filteredResources,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load resources: $e',
      ));
    }
  }

  Future<void> _onResourcesSelected(
    LocalQRShareResourcesSelected event,
    Emitter<LocalQRShareState> emit,
  ) async {
    emit(state.copyWith(selectedResourceIds: event.resourceIds));
  }

  Future<void> _onConfigChanged(
    LocalQRShareConfigChanged event,
    Emitter<LocalQRShareState> emit,
  ) async {
    emit(state.copyWith(config: event.config));
  }

  Future<void> _onGenerateQrCode(
    LocalQRShareGenerateQrCode event,
    Emitter<LocalQRShareState> emit,
  ) async {
    emit(state.copyWith(
      isLoading: true,
      errorMessage: null,
      session: null,
    ));

    try {
      // Always enable screenshot prevention for LocalQR
      _expirationService.enableScreenshotPrevention();

      // Generate LocalQR session (peer-to-peer, no issuer)
      final session = await _localQRShareRepository.generateLocalQRCode(
        resourceIds: event.resourceIds,
        config: state.config,
        sourceId: event.sourceId,
      );

      emit(state.copyWith(
        isLoading: false,
        session: session,
      ));

      // Start expiration timer if time-based
      if (state.config.timeBasedExpiration) {
        _expirationSubscription = _expirationService
            .startExpirationTimer(
          expirationMinutes: state.config.expirationMinutes,
          onExpired: () {
            add(const LocalQRShareEvent.expired());
          },
        )
            .listen((remainingSeconds) {
          add(LocalQRShareEvent.timerTick(remainingSeconds));
        });
      }

      // Always start Bluetooth proximity detection (time + proximity mode is always enabled)
      final bluetoothAvailable = await _proximityService.isBluetoothAvailable();
      if (!bluetoothAvailable) {
        final hasPermission =
            await _proximityService.requestBluetoothPermissions();
        if (!hasPermission) {
          emit(state.copyWith(
            errorMessage: 'Bluetooth permissions required for LocalQR sharing',
          ));
          return;
        }
      }

      // Start advertising HealthWallet.me service for peer detection
      // This allows Receive side to detect when Share side closes
      _proximityService.startAdvertising(
        deviceName: 'HealthWallet.me',
        onDisconnected: () {
          // If Receive side disconnects, expire session
          add(const LocalQRShareEvent.expired());
        },
      );

      // Always use BLE mode - wait for receiver to connect, then transfer data
      _proximitySubscription = _proximityService
          .startProximityDetection(
        timeoutSeconds: state.config.proximityTimeoutSeconds,
        onTimeout: () {
          add(const LocalQRShareEvent.expired());
        },
      )
          .listen((isConnected) async {
        if (isConnected) {
          // Receiver connected, start BLE data transfer
          await _startBleDataTransfer(session);
        }
        add(LocalQRShareEvent.proximityChanged(isConnected));
      });
    } catch (e) {
      // Provide user-friendly error message
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to generate QR code: ${e.toString()}',
      ));
    }
  }

  Future<void> _startBleDataTransfer(LocalQRShareSession session) async {
    try {
      if (session.sessionId == null) {
        logger.e('BLE: No session ID found');
        return;
      }

      // Get FHIR bundle data from repository
      final bundle = _localQRShareRepository.getBleDataForSession(session.sessionId!);
      if (bundle == null) {
        logger.e('BLE: No data found for session ${session.sessionId}');
        return;
      }

      // Convert bundle to JSON bytes
      final bundleJson = jsonEncode(bundle);
      final bundleBytes = utf8.encode(bundleJson);

      final sessionId = session.sessionId!;

      // Start BLE transfer
      _bleTransferSubscription = _bleDataTransferService
          .sendData(
        data: bundleBytes,
        sessionId: sessionId,
      )
          .listen((progress) {
        add(LocalQRShareEvent.bleTransferProgress(progress));
        if (progress >= 1.0) {
          logger.d('BLE: Data transfer completed');
        }
      });
    } catch (e) {
      logger.e('BLE: Transfer error: $e');
      // Error will be handled by the proximity detection timeout
    }
  }

  Future<void> _onBleTransferProgress(
    LocalQRShareBleTransferProgress event,
    Emitter<LocalQRShareState> emit,
  ) async {
    if (state.session != null) {
      final updatedSession = state.session!.copyWith(
        bleTransferProgress: event.progress,
      );
      emit(state.copyWith(session: updatedSession));
    }
  }

  Future<void> _onTimerTick(
    LocalQRShareTimerTick event,
    Emitter<LocalQRShareState> emit,
  ) async {
    if (state.session != null) {
      final updatedSession = state.session!.copyWith(
        remainingSeconds: event.remainingSeconds,
      );
      emit(state.copyWith(session: updatedSession));
    }
  }

  Future<void> _onProximityChanged(
    LocalQRShareProximityChanged event,
    Emitter<LocalQRShareState> emit,
  ) async {
    if (state.session != null) {
      final updatedSession = state.session!.copyWith(
        isBluetoothConnected: event.isConnected,
      );
      emit(state.copyWith(session: updatedSession));
    }
  }

  Future<void> _onExpired(
    LocalQRShareExpired event,
    Emitter<LocalQRShareState> emit,
  ) async {
    // Stop all services
    _expirationService.cancelTimer();
    _expirationService.disableScreenshotPrevention();
    _proximityService.stopProximityDetection();
    _proximityService.stopAdvertising();
    _bleTransferSubscription?.cancel();
    _bleTransferSubscription = null;
    await _bleDataTransferService.disconnect();

    // Stop session
    if (state.session != null) {
      await _localQRShareRepository.stopSession(state.session!);
    }

    emit(state.copyWith(
      session: null,
      errorMessage: 'Session expired. Data has been automatically deleted.',
    ));
  }

  Future<void> _onStop(
    LocalQRShareStop event,
    Emitter<LocalQRShareState> emit,
  ) async {
    // Stop all services
    _expirationService.cancelTimer();
    _expirationService.disableScreenshotPrevention();
    _proximityService.stopProximityDetection();
    _proximityService.stopAdvertising();
    _bleTransferSubscription?.cancel();
    _bleTransferSubscription = null;
    await _bleDataTransferService.disconnect();

    // Stop session
    if (state.session != null) {
      await _localQRShareRepository.stopSession(state.session!);
    }

    emit(state.copyWith(session: null));
  }

  Future<void> _onReset(
    LocalQRShareReset event,
    Emitter<LocalQRShareState> emit,
  ) async {
    // Stop all services
    _expirationSubscription?.cancel();
    _proximitySubscription?.cancel();
    _bleTransferSubscription?.cancel();
    _expirationService.cancelTimer();
    _expirationService.disableScreenshotPrevention();
    _proximityService.stopProximityDetection();
    _proximityService.stopAdvertising();
    await _bleDataTransferService.disconnect();

    // Stop session
    if (state.session != null) {
      await _localQRShareRepository.stopSession(state.session!);
    }

    emit(const LocalQRShareState());
  }

  @override
  Future<void> close() {
    _expirationSubscription?.cancel();
    _proximitySubscription?.cancel();
    _bleTransferSubscription?.cancel();
    _expirationService.cancelTimer();
    _expirationService.disableScreenshotPrevention();
    _proximityService.stopProximityDetection();
    _proximityService.stopAdvertising();
    _bleDataTransferService.disconnect();
    return super.close();
  }
}
