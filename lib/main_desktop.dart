import 'package:flutter/material.dart';
import 'package:health_wallet/app/view/app.dart';
import 'package:health_wallet/bootstrap.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/communication/data/services/discovery_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/pairing_storage_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/handover/presentation/bloc/handover_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/desktop/tray/data/services/tray_service.dart';
import 'package:health_wallet/features/desktop/tray/data/services/window_lifecycle_service.dart';
import 'package:health_wallet/features/desktop/tray/presentation/bloc/tray_bloc.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  getIt.registerSingleton<AppPlatform>(AppPlatform.desktop);

  await configureDependencies();

  getIt.registerLazySingleton<CommunicationBloc>(
    () => CommunicationBloc(
      getIt<AppPlatform>(),
      getIt<PairingStorageService>(),
      getIt<TcpService>(),
      getIt<DiscoveryService>(),
    ),
  );

  getIt.registerLazySingleton<TrayBloc>(
    () => TrayBloc(
      getIt<TrayService>(),
      getIt<WindowLifecycleService>(),
    ),
  );

  getIt<CommunicationBloc>().add(const CommunicationInitialised());
  getIt<BackupBloc>().add(const BackupHistoryLoaded());
  getIt<ProcessingBloc>().add(const ProcessingInitialised());
  getIt<LwwSyncBloc>().add(const LwwSyncInitialised());
  getIt<HandoverBloc>().add(const HandoverInitialised());
  getIt<TrayBloc>().add(const TrayInitialised());

  getIt<CommunicationBloc>().stream.listen((commState) {
    getIt<TrayBloc>().add(TrayConnectionStatusChanged(
      connectionStatus: commState.connectionStatus,
      deviceName: commState.connectedDeviceName,
    ));
  });

  getIt<LwwSyncBloc>().stream.listen((syncState) {
    getIt<TrayBloc>().add(TraySyncStatusChanged(
      syncStatus: syncState.syncStatus,
    ));
  });

  await bootstrap(() => const App());
}
