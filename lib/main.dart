import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:health_wallet/app/view/app.dart';
import 'package:health_wallet/bootstrap.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/services/deep_link_service.dart';
import 'package:health_wallet/core/services/share_intent_service.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await configureDependencies();

  getIt<ShareIntentService>().initialize();
  getIt<DeepLinkService>().initialize();
  getIt<ScanBloc>().add(const ScanInitialised());

  FlutterNativeSplash.remove();

  await FlutterGemma.initialize();

  await bootstrap(() => const App());
}
