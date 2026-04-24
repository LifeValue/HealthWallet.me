import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:health_wallet/app/view/app.dart';
import 'package:health_wallet/bootstrap.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/services/deep_link_service.dart';
import 'package:health_wallet/core/services/share_intent_service.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/communication/data/services/discovery_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/pairing_storage_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey('lww_offline_queue')) {
    debugPrint('[MAIN] Clearing lww_offline_queue to free memory');
    await prefs.remove('lww_offline_queue');
  }

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  getIt.registerSingleton<AppPlatform>(AppPlatform.mobile);

  await configureDependencies();

  getIt.registerLazySingleton<CommunicationBloc>(
    () => CommunicationBloc(
      getIt<AppPlatform>(),
      getIt<PairingStorageService>(),
      getIt<TcpService>(),
      getIt<DiscoveryService>(),
    ),
  );

  getIt<CommunicationBloc>().add(const CommunicationInitialised());

  getIt<ShareIntentService>().initialize();
  getIt<DeepLinkService>().initialize();
  getIt<ProcessingBloc>().add(const ProcessingInitialised());

  getIt<LwwSyncBloc>().add(const LwwSyncInitialised());

  FlutterNativeSplash.remove();

  await bootstrap(() => const App());
}
