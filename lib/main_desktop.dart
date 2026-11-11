import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:health_wallet/app/view/app.dart';
import 'package:health_wallet/bootstrap.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/services/startup_hardening.dart';
import 'package:health_wallet/features/desktop/backup/data/services/safety_copy_expiry_scheduler.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/data/services/discovery_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/pairing_storage_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/handover/presentation/bloc/handover_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/desktop/tray/data/services/tray_service.dart';
import 'package:health_wallet/features/desktop/tray/data/services/window_lifecycle_service.dart';
import 'package:health_wallet/features/desktop/tray/presentation/bloc/tray_bloc.dart';
import 'package:health_wallet/features/holders/domain/services/holder_linking_service.dart';
import 'package:health_wallet/features/processing/domain/services/ai_model_selection_guard.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  unawaited(hardenStartup(releaseMode: kReleaseMode));

  getIt.registerSingleton<AppPlatform>(AppPlatform.desktop);

  await configureDependencies();

  // Before the first screen asks whose records to show.
  await getIt<HolderLinkingService>().linkUnassigned();

  // Before anything reads the selected AI model.
  await getIt<AiModelSelectionGuard>().replaceUnsupportedModel();

  getIt.registerLazySingleton<CommunicationBloc>(
    () => CommunicationBloc(
      getIt<AppPlatform>(),
      getIt<PairingStorageService>(),
      getIt<TcpService>(),
      getIt<DiscoveryService>(),
      onPhoneConnected: () {
        getIt<BackupBloc>().sendBackupStatus();
      },
    ),
  );

  getIt.registerLazySingleton<TrayBloc>(
    () => TrayBloc(
      getIt<TrayService>(),
      getIt<WindowLifecycleService>(),
    ),
  );

  getIt<WindowLifecycleService>().beforeQuit = () async {
    // A batch being applied finishes first, then the phone is told this app
    // is quitting, so it reconnects later by itself.
    await getIt<LwwSyncBloc>().shutdown();
    await getIt<CommunicationBloc>().shutdown();
    await getIt<SafetyCopyExpiryScheduler>().dispose();
  };

  getIt<CommunicationBloc>().add(const CommunicationInitialised());
  getIt<BackupBloc>().add(const BackupHistoryLoaded());
  // Deletes each safety copy when it expires while the app stays open.
  unawaited(getIt<SafetyCopyExpiryScheduler>().start());
  getIt<ProcessingBloc>().add(const ProcessingInitialised());
  getIt<LwwSyncBloc>().add(const LwwSyncInitialised());
  getIt<HandoverBloc>().add(const HandoverInitialised());
  getIt<TrayBloc>().add(const TrayInitialised());

  getIt<CommunicationBloc>().stream
      .distinct(
        (a, b) =>
            a.connectionStatus == b.connectionStatus &&
            a.connectedDeviceName == b.connectedDeviceName,
      )
      .listen((commState) {
        getIt<TrayBloc>().add(
          TrayConnectionStatusChanged(
            connectionStatus: commState.connectionStatus,
            deviceName: commState.connectedDeviceName,
          ),
        );
      });

  getIt<LwwSyncBloc>().stream
      .distinct((a, b) => a.syncStatus == b.syncStatus)
      .listen((syncState) {
        getIt<TrayBloc>().add(
          TraySyncStatusChanged(
            syncStatus: syncState.syncStatus,
          ),
        );
      });

  await bootstrap(() => const App());
}
