import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/smart_health_share/domain/local_qr/services/ble_data_transfer_service.dart';
import 'package:health_wallet/features/smart_health_share/domain/local_qr/services/local_qr_expiration_service.dart';
import 'package:health_wallet/features/smart_health_share/domain/local_qr/services/local_qr_proximity_service.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/entities/shc_receive_result.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/repositories/receive_repository.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/services/jws_signing_service.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/services/qr_processor_service.dart';
import 'package:injectable/injectable.dart';

part 'receive_event.dart';
part 'receive_state.dart';
part 'receive_bloc.freezed.dart';

@injectable
class ReceiveBloc extends Bloc<ReceiveEvent, ReceiveState> {
  final ReceiveRepository _receiveRepository;
  final LocalQRExpirationService _expirationService;
  final LocalQRProximityService _proximityService;
  final QRProcessorService _qrProcessorService;
  final JWSSigningService _jwsSigningService;
  final BLEDataTransferService _bleDataTransferService;
  StreamSubscription<int>? _expirationSubscription;
  StreamSubscription<bool>? _proximitySubscription;
  StreamSubscription<Uint8List>? _bleReceiveSubscription;
  StreamSubscription<BluetoothConnectionState>? _bleConnectionSubscription;

  // Helper function for safe debug logging
  void _debugLog(String location, String message, Map<String, dynamic> data,
      String hypothesisId) {
    try {
      final logFile = File(
          '/Users/beniamin/Work/_TECHSTACKAPPS/HEALTH_WALLET/_WORKPLACE/wp_3/HealthWallet.me/.cursor/debug.log');
      final logEntry = jsonEncode({
        "sessionId": "debug-session",
        "runId": "run1",
        "hypothesisId": hypothesisId,
        "location": location,
        "message": message,
        "data": data,
        "timestamp": DateTime.now().millisecondsSinceEpoch
      });
      if (logFile.existsSync()) {
        logFile.writeAsStringSync('${logFile.readAsStringSync()}\n$logEntry',
            mode: FileMode.append);
      } else {
        logFile.createSync(recursive: true);
        logFile.writeAsStringSync(logEntry);
      }
    } catch (e) {
      // Fallback to console logger if file write fails
      logger.d('DEBUG [$location] $message: $data (hypothesis: $hypothesisId)');
    }
  }

  ReceiveBloc(
    this._receiveRepository,
    this._expirationService,
    this._proximityService,
    this._qrProcessorService,
    this._jwsSigningService,
    this._bleDataTransferService,
  ) : super(const ReceiveState()) {
    on<ReceiveInitialized>(_onInitialized);
    on<ReceiveStartScanning>(_onStartScanning);
    on<ReceiveQrCodeScanned>(_onQrCodeScanned);
    on<ReceiveReset>(_onReset);
    on<ReceiveTimerTick>(_onTimerTick);
    on<ReceiveResourcesExpired>(_onResourcesExpired);
  }

  Future<void> _onInitialized(
    ReceiveInitialized event,
    Emitter<ReceiveState> emit,
  ) async {
    emit(state.copyWith(
      isLoading: false,
      isScanning: false,
      errorMessage: null,
      successMessage: null,
      receiveResult: null,
      receivedResources: null,
      expiresAt: null,
      remainingSeconds: null,
      isPeerToPeer: false,
    ));
  }

  Future<void> _onStartScanning(
    ReceiveStartScanning event,
    Emitter<ReceiveState> emit,
  ) async {
    emit(state.copyWith(
      isScanning: true,
      errorMessage: null,
      successMessage: null,
    ));
  }

  Future<void> _onQrCodeScanned(
    ReceiveQrCodeScanned event,
    Emitter<ReceiveState> emit,
  ) async {
    // #region agent log
    _debugLog('receive_bloc.dart:83', 'QR code scanned - entry',
        {'qrDataLength': event.qrData.length}, 'A');
    // #endregion
    emit(state.copyWith(
      isLoading: true,
      isScanning: false,
      errorMessage: null,
      successMessage: null,
    ));

    try {
      // Check if it's a peer-to-peer LocalQR by decoding JWT and checking issuer
      bool isPeerToPeer = false;
      String? sessionId;
      DateTime? expiresAt;
      String? serviceUuid;
      String? deviceIdentifier;
      String? deviceName;

      if (_qrProcessorService.isShcQr(event.qrData)) {
        try {
          final jwsToken = _qrProcessorService.decodeFromShcQr(event.qrData);
          final payload = _jwsSigningService.parseJwtPayload(jwsToken);
          final issuer = payload['iss'] as String?;
          isPeerToPeer = issuer != null && issuer.contains('/peer');
          // #region agent log
          _debugLog('receive_bloc.dart:101', 'QR parsed - isPeerToPeer check',
              {'isPeerToPeer': isPeerToPeer, 'issuer': issuer}, 'A');
          // #endregion

          // Extract BLE transfer metadata (always BLE mode for LocalQR)
          if (isPeerToPeer && payload.containsKey('metadata')) {
            final metadata = payload['metadata'] as Map<String, dynamic>?;
            sessionId = metadata?['sessionId'] as String?;
            serviceUuid = metadata?['serviceUuid'] as String?;
            deviceIdentifier = metadata?['deviceIdentifier'] as String?;
            deviceName = metadata?['deviceName'] as String?;
            // #region agent log
            _debugLog(
                'receive_bloc.dart:106',
                'Metadata extracted',
                {
                  'sessionId': sessionId,
                  'serviceUuid': serviceUuid,
                  'deviceIdentifier': deviceIdentifier,
                  'deviceName': deviceName,
                  'hasMetadata': payload.containsKey('metadata')
                },
                'A');
            // #endregion

            // Extract expiration time from metadata
            final expiresAtString = metadata?['expiresAt'] as String?;
            if (expiresAtString != null) {
              try {
                expiresAt = DateTime.parse(expiresAtString);
              } catch (e) {
                logger.w('Failed to parse expiresAt from metadata: $e');
              }
            }

            // If no expiration in metadata, use default (15 minutes from now)
            expiresAt ??= DateTime.now().add(const Duration(minutes: 15));
            // #region agent log
            _debugLog('receive_bloc.dart:119', 'ExpiresAt set',
                {'expiresAt': expiresAt!.toIso8601String()}, 'A');
            // #endregion
          }
        } catch (e) {
          // If decoding fails, treat as standard SHC
          isPeerToPeer = false;
          // #region agent log
          _debugLog('receive_bloc.dart:123', 'QR decode failed',
              {'error': e.toString()}, 'A');
          // #endregion
        }
      }

      if (isPeerToPeer) {
        // Always use BLE transfer mode for LocalQR
        if (sessionId != null && expiresAt != null) {
          // #region agent log
          _debugLog(
              'receive_bloc.dart:131',
              'Calling _receiveBleData',
              {
                'sessionId': sessionId,
                'expiresAt': expiresAt.toIso8601String(),
                'serviceUuid': serviceUuid,
                'deviceIdentifier': deviceIdentifier,
                'deviceName': deviceName,
              },
              'A');
          // #endregion
          // BLE transfer mode - receive data via Bluetooth
          await _receiveBleData(
            sessionId!,
            expiresAt!,
            emit,
            serviceUuid: serviceUuid,
            deviceIdentifier: deviceIdentifier,
            deviceName: deviceName,
          );
        } else {
          // #region agent log
          _debugLog(
              'receive_bloc.dart:133',
              'Missing sessionId or expiresAt',
              {
                'sessionId': sessionId,
                'expiresAt': expiresAt?.toIso8601String()
              },
              'A');
          // #endregion
          emit(state.copyWith(
            isLoading: false,
            errorMessage:
                'Invalid LocalQR QR code: missing session ID or expiration',
            isPeerToPeer: true,
          ));
        }
      } else {
        // Standard SHC: Import and store in database
        final result = await _receiveRepository.importHealthCard(event.qrData);

        if (result.success) {
          emit(state.copyWith(
            isLoading: false,
            successMessage:
                'Successfully imported ${result.importedResourceCount} resources',
            receiveResult: result,
            isPeerToPeer: false,
          ));
        } else {
          emit(state.copyWith(
            isLoading: false,
            errorMessage: result.errorMessage ?? 'Failed to import health card',
            receiveResult: result,
            isPeerToPeer: false,
          ));
        }
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onTimerTick(
    ReceiveTimerTick event,
    Emitter<ReceiveState> emit,
  ) async {
    emit(state.copyWith(remainingSeconds: event.remainingSeconds));
  }

  Future<void> _receiveBleData(
    String sessionId,
    DateTime expiresAt,
    Emitter<ReceiveState> emit, {
    String? serviceUuid,
    String? deviceIdentifier,
    String? deviceName,
  }) async {
    // #region agent log
    _debugLog('receive_bloc.dart:175', '_receiveBleData entry',
        {'sessionId': sessionId}, 'B');
    // #endregion
    try {
      // Use service UUID from QR or fallback to default
      final targetServiceUuid =
          serviceUuid ?? _proximityService.getHealthWalletServiceUuid();

      // #region agent log
      _debugLog(
          'receive_bloc.dart:187',
          'Starting BLE scan with connection info',
          {
            'serviceUuid': targetServiceUuid,
            'deviceIdentifier': deviceIdentifier,
            'deviceName': deviceName,
          },
          'B');
      // #endregion

      String? deviceId;

      // Start scanning without strict service UUID filter
      // Note: flutter_blue_plus doesn't support BLE peripheral mode (advertising),
      // so we scan for all devices and match by device name or identifier
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      // Set up timeout timer
      Timer? scanTimeoutTimer;
      bool scanTimedOut = false;
      final scanTimeoutCompleter = Completer<void>();
      StreamSubscription<List<ScanResult>>? scanSubscription;

      scanTimeoutTimer = Timer(const Duration(seconds: 12), () {
        // #region agent log
        _debugLog(
            'receive_bloc.dart:scan-timeout', 'Scan timeout reached', {}, 'B');
        // #endregion
        scanTimedOut = true;
        scanSubscription?.cancel();
        if (!scanTimeoutCompleter.isCompleted) {
          scanTimeoutCompleter.complete();
        }
      });

      // #region agent log
      _debugLog(
          'receive_bloc.dart:scan-setup',
          'Scan timeout timer started, waiting for results or timeout',
          {},
          'B');
      // #endregion

      try {
        // Listen to scan results with timeout handling
        scanSubscription = FlutterBluePlus.scanResults.listen(
          (results) {
            // #region agent log
            _debugLog('receive_bloc.dart:scan-results', 'Scan results received',
                {'resultCount': results.length}, 'B');
            // #endregion

            if (scanTimedOut) return; // Ignore results after timeout

            for (final result in results) {
              final serviceUuids = result.advertisementData.serviceUuids;
              final platformName = result.device.platformName;
              final remoteId = result.device.remoteId.str;
              final advName = result.advertisementData.advName;
              final manufacturerData =
                  result.advertisementData.manufacturerData;

              // #region agent log
              _debugLog(
                  'receive_bloc.dart:check-service',
                  'Checking device',
                  {
                    'serviceUuids':
                        serviceUuids.map((u) => u.toString()).toList(),
                    'expectedUuid': targetServiceUuid,
                    'platformName': platformName,
                    'advName': advName,
                    'remoteId': remoteId,
                    'deviceIdentifier': deviceIdentifier,
                    'deviceName': deviceName,
                    'manufacturerDataLength': manufacturerData.length,
                  },
                  'B');
              // #endregion

              // Match devices by deviceName first (most reliable)
              // Check both platformName and advName (advertisement name)
              bool matches = false;
              if (deviceName != null && deviceName.isNotEmpty) {
                final nameLower = deviceName.toLowerCase();
                matches = platformName.toLowerCase().contains(nameLower) ||
                    (advName.isNotEmpty &&
                        advName.toLowerCase().contains(nameLower));
              }

              // If no deviceName match, try matching by deviceIdentifier
              if (!matches &&
                  deviceIdentifier != null &&
                  deviceIdentifier.isNotEmpty) {
                // Match by deviceIdentifier - could be in remoteId, platformName, or advName
                matches = remoteId.contains(deviceIdentifier) ||
                    platformName.contains(deviceIdentifier) ||
                    (advName.isNotEmpty && advName.contains(deviceIdentifier));
              }

              // Also check if device has the target service UUID (optional, for additional verification)
              if (!matches && targetServiceUuid.isNotEmpty) {
                final hasService = serviceUuids.any(
                  (uuid) =>
                      uuid.toString().toLowerCase() ==
                      targetServiceUuid.toLowerCase(),
                );
                if (hasService) {
                  // If device has the service UUID, accept it even without name/identifier match
                  // This provides fallback when device name isn't available
                  matches = true;
                }
              }

              if (matches) {
                deviceId = remoteId;
                // #region agent log
                _debugLog(
                    'receive_bloc.dart:197',
                    'Device found and matched',
                    {
                      'deviceId': deviceId,
                      'matchedBy': deviceIdentifier != null
                          ? 'deviceIdentifier'
                          : deviceName != null
                              ? 'deviceName'
                              : 'serviceUuid',
                    },
                    'B');
                // #endregion
                scanTimeoutTimer?.cancel();
                scanSubscription?.cancel();
                if (!scanTimeoutCompleter.isCompleted) {
                  scanTimeoutCompleter.complete();
                }
                return;
              }
            }
          },
          onError: (error) {
            // #region agent log
            _debugLog('receive_bloc.dart:scan-stream-error',
                'Scan stream error', {'error': error.toString()}, 'B');
            // #endregion
            scanTimeoutTimer?.cancel();
            scanTimeoutCompleter.completeError(error);
          },
        );

        // Wait for either timeout or device found
        // Add fallback timeout to ensure completer always completes
        Timer? fallbackTimeoutTimer;
        fallbackTimeoutTimer = Timer(const Duration(seconds: 15), () {
          if (!scanTimeoutCompleter.isCompleted) {
            // #region agent log
            _debugLog('receive_bloc.dart:fallback-timeout',
                'Fallback timeout reached - forcing completion', {}, 'B');
            // #endregion
            scanTimedOut = true;
            scanTimeoutCompleter.complete();
          }
        });

        // #region agent log
        _debugLog('receive_bloc.dart:wait-completer',
            'Waiting for completer (timeout or device found)', {}, 'B');
        // #endregion

        try {
          await scanTimeoutCompleter.future;
        } catch (e) {
          // #region agent log
          _debugLog('receive_bloc.dart:completer-error', 'Completer error',
              {'error': e.toString()}, 'B');
          // #endregion
        }

        fallbackTimeoutTimer?.cancel();
        // #region agent log
        _debugLog('receive_bloc.dart:completer-done', 'Completer finished',
            {'deviceId': deviceId, 'scanTimedOut': scanTimedOut}, 'B');
        // #endregion
      } catch (e) {
        // #region agent log
        _debugLog('receive_bloc.dart:scan-error', 'Scan error',
            {'error': e.toString()}, 'B');
        // #endregion
      } finally {
        scanTimeoutTimer?.cancel();
        scanSubscription?.cancel();
        // Ensure scan is stopped
        try {
          await FlutterBluePlus.stopScan();
        } catch (e) {
          // Ignore errors when stopping scan
        }
      }

      // #region agent log
      _debugLog('receive_bloc.dart:after-scan', 'After scan loop',
          {'deviceId': deviceId, 'scanTimedOut': scanTimedOut}, 'B');
      // #endregion

      if (deviceId == null) {
        // #region agent log
        _debugLog('receive_bloc.dart:206', 'No device found - emitting error',
            {}, 'B');
        // #endregion
        emit(state.copyWith(
          isLoading: false,
          errorMessage:
              'Could not find sharing device. Please ensure the sharing device is nearby and Bluetooth is enabled.',
        ));
        return;
      }

      // Establish BLE connection

      // #region agent log
      _debugLog('receive_bloc.dart:215', 'Establishing connection',
          {'deviceId': deviceId}, 'C');
      // #endregion
      final connected = await _bleDataTransferService.establishConnection(
        deviceId: deviceId!,
        sessionId: sessionId,
      );
      // #region agent log
      _debugLog('receive_bloc.dart:220', 'Connection result',
          {'connected': connected}, 'C');
      // #endregion

      if (!connected) {
        // #region agent log
        _debugLog('receive_bloc.dart:221', 'Connection failed - emitting error',
            {}, 'C');
        // #endregion
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to connect to sharing device',
        ));
        return;
      }

      // Subscribe to BLE connection state changes
      _bleConnectionSubscription =
          _bleDataTransferService.connectionStateStream.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          logger.d('BLE: Connection lost, expiring session');
          add(const ReceiveEvent.resourcesExpired());
        }
      });

      // Receive data via BLE
      // #region agent log
      _debugLog('receive_bloc.dart:238', 'Subscribing to receiveData stream',
          {'sessionId': sessionId}, 'D');
      // #endregion
      _bleReceiveSubscription =
          _bleDataTransferService.receiveData(sessionId: sessionId).listen(
        (data) async {
          // #region agent log
          _debugLog('receive_bloc.dart:240', 'Data received from stream',
              {'dataLength': data.length}, 'D');
          // #endregion
          try {
            // Decode received data
            final bundleJson = utf8.decode(data);
            final bundle = jsonDecode(bundleJson) as Map<String, dynamic>;

            logger.d(
                'Received bundle with ${bundle['entry']?.length ?? 0} entries');
            // #region agent log
            _debugLog('receive_bloc.dart:249', 'Calling importBundleForLocalQR',
                {'bundleEntryCount': bundle['entry']?.length ?? 0}, 'E');
            // #endregion

            // Import resources from bundle directly
            final localQrResult =
                await _receiveRepository.importBundleForLocalQR(
              bundle: bundle,
              expiresAt: expiresAt,
            );
            // #region agent log
            _debugLog(
                'receive_bloc.dart:254',
                'Import result',
                {
                  'success': localQrResult.success,
                  'resourceCount': localQrResult.resources.length
                },
                'E');
            // #endregion

            if (!localQrResult.success) {
              // #region agent log
              _debugLog(
                  'receive_bloc.dart:255',
                  'Import failed - emitting error',
                  {'errorMessage': localQrResult.errorMessage},
                  'E');
              // #endregion
              emit(state.copyWith(
                isLoading: false,
                errorMessage:
                    localQrResult.errorMessage ?? 'Failed to import bundle',
                isPeerToPeer: true,
              ));
              return;
            }

            // Setup proximity monitoring
            await _setupProximityMonitoring(localQrResult.expiresAt);

            // #region agent log
            _debugLog(
                'receive_bloc.dart:266',
                'Emitting success state',
                {
                  'resourceCount': localQrResult.resources.length,
                  'isLoading': false
                },
                'E');
            // #endregion
            emit(state.copyWith(
              isLoading: false,
              receivedResources: localQrResult.resources,
              expiresAt: localQrResult.expiresAt,
              remainingSeconds:
                  localQrResult.expiresAt.difference(DateTime.now()).inSeconds,
              isPeerToPeer: true,
            ));
          } catch (e) {
            // #region agent log
            _debugLog('receive_bloc.dart:274', 'Exception in data processing',
                {'error': e.toString()}, 'E');
            // #endregion
            logger.e('BLE: Error processing received data: $e');
            emit(state.copyWith(
              isLoading: false,
              errorMessage: 'Failed to process received data: ${e.toString()}',
            ));
          }
        },
        onError: (error) {
          // #region agent log
          _debugLog('receive_bloc.dart:282', 'Stream onError',
              {'error': error.toString()}, 'D');
          // #endregion
          logger.e('BLE: Receive error: $error');
          emit(state.copyWith(
            isLoading: false,
            errorMessage: 'BLE transfer failed: ${error.toString()}',
          ));
        },
      );
    } catch (e) {
      // #region agent log
      _debugLog('receive_bloc.dart:290', 'Exception in _receiveBleData',
          {'error': e.toString()}, 'B');
      // #endregion
      logger.e('BLE: Connection/receive error: $e');
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'BLE transfer failed: ${e.toString()}',
      ));
    }
  }

  Future<void> _setupProximityMonitoring(DateTime expiresAt) async {
    // Start expiration timer
    _expirationSubscription = _expirationService
        .startExpirationTimerForReceived(
      expiresAt: expiresAt,
      onExpired: () {
        add(const ReceiveEvent.resourcesExpired());
      },
    )
        .listen((remainingSeconds) {
      add(ReceiveEvent.timerTick(remainingSeconds));
    });

    // Start Bluetooth proximity detection to monitor Share side
    final bluetoothAvailable = await _proximityService.isBluetoothAvailable();
    if (bluetoothAvailable) {
      final hasPermission =
          await _proximityService.requestBluetoothPermissions();
      if (hasPermission) {
        // Track if we've ever been connected to detect disconnections
        bool wasConnected = false;

        _proximitySubscription = _proximityService
            .startProximityDetection(
          timeoutSeconds: 5,
          onTimeout: () {
            // Only expire on timeout if we were previously connected
            if (wasConnected) {
              add(const ReceiveEvent.resourcesExpired());
            }
          },
        )
            .listen((isConnected) {
          if (isConnected) {
            wasConnected = true;
          } else {
            // Only expire if we were previously connected (peer disconnected)
            // Don't expire if we were never connected (no peer found is OK in QR mode)
            if (wasConnected) {
              add(const ReceiveEvent.resourcesExpired());
            }
          }
        });
      }
    }
  }

  Future<void> _onResourcesExpired(
    ReceiveResourcesExpired event,
    Emitter<ReceiveState> emit,
  ) async {
    // Cancel timer and proximity detection
    _expirationService.cancelTimer();
    _proximityService.stopProximityDetection();
    _expirationSubscription?.cancel();
    _proximitySubscription?.cancel();
    _bleReceiveSubscription?.cancel();
    _bleReceiveSubscription = null;
    _bleConnectionSubscription?.cancel();
    _bleConnectionSubscription = null;
    await _bleDataTransferService.disconnect();
    _expirationSubscription = null;
    _proximitySubscription = null;

    // Clear resources from state
    emit(state.copyWith(
      receivedResources: null,
      expiresAt: null,
      remainingSeconds: null,
      errorMessage:
          'Session expired. Resources have been automatically deleted.',
    ));
  }

  Future<void> _onReset(
    ReceiveReset event,
    Emitter<ReceiveState> emit,
  ) async {
    // Cancel timer and proximity detection
    _expirationService.cancelTimer();
    _proximityService.stopProximityDetection();
    _expirationSubscription?.cancel();
    _proximitySubscription?.cancel();
    _bleReceiveSubscription?.cancel();
    _bleReceiveSubscription = null;
    _bleConnectionSubscription?.cancel();
    _bleConnectionSubscription = null;
    await _bleDataTransferService.disconnect();
    _expirationSubscription = null;
    _proximitySubscription = null;

    emit(const ReceiveState());
  }

  @override
  Future<void> close() {
    _expirationService.cancelTimer();
    _proximityService.stopProximityDetection();
    _expirationSubscription?.cancel();
    _proximitySubscription?.cancel();
    _bleReceiveSubscription?.cancel();
    _bleConnectionSubscription?.cancel();
    _bleDataTransferService.disconnect();
    return super.close();
  }
}
