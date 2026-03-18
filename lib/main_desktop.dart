import 'package:flutter/material.dart';
import 'package:health_wallet/app/view/app.dart';
import 'package:health_wallet/bootstrap.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  getIt.registerSingleton<AppPlatform>(AppPlatform.desktop);

  await configureDependencies();

  getIt<ScanBloc>().add(const ScanInitialised());

  await bootstrap(() => const App());
}
