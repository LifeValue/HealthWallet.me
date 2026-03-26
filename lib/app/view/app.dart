import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/services/bluetooth_state_service.dart';
import 'package:health_wallet/features/share_records/core/share_permissions_helper.dart';
import 'package:health_wallet/features/share_records/domain/services/receive_mode_service.dart';
import 'package:health_wallet/features/user/domain/repository/user_repository.dart';
import 'package:health_wallet/core/navigation/observers/order_route_observer.dart';
import 'package:health_wallet/core/theme/theme.dart';
import 'package:health_wallet/core/utils/patient_source_utils.dart';
import 'package:health_wallet/features/notifications/bloc/notification_bloc.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/home/data/data_source/local/home_local_data_source.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/features/sync/domain/use_case/get_sources_use_case.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_selection_service.dart';
import 'package:health_wallet/features/wallet_pass/presentation/bloc/wallet_pass_bloc.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSymmetricDiscovery();
    _listenBluetoothState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopSymmetricDiscovery();
    super.dispose();
  }

  void _listenBluetoothState() {
    getIt<BluetoothStateService>().startListening();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startSymmetricDiscovery();
    } else if (state == AppLifecycleState.paused) {
      _stopSymmetricDiscovery();
    }
  }

  Future<void> _startSymmetricDiscovery() async {
    if (getIt<AppPlatform>().isDesktop) return;

    try {
      final userRepository = getIt<UserRepository>();
      final user = await userRepository.getCurrentUser();
      if (!user.isReceiveModeEnabled) return;

      final hasPermissions =
          await SharePermissionsHelper.hasRequiredPermissions();
      if (!hasPermissions) return;

      final bluetoothOn = await getIt<BluetoothStateService>().isEnabled();
      if (!bluetoothOn) {
        await userRepository
            .updateUser(user.copyWith(isReceiveModeEnabled: false));
        return;
      }

      final manager = getIt<ReceiveModeService>();
      if (!manager.isListening) {
        await manager.startListening();
      }
    } catch (e) {
      debugPrint('[App] Discovery skipped: $e');
    }
  }

  Future<void> _stopSymmetricDiscovery() async {
    if (getIt<AppPlatform>().isDesktop) return;

    final manager = getIt<ReceiveModeService>();
    if (manager.isListening) {
      await manager.stopListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = getIt<AppRouter>();
    final routeObserver = getIt<AppRouteObserver>();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
            create: (_) => getIt<UserBloc>()..add(const UserInitialised())),
        BlocProvider(
            create: (_) => getIt<SyncBloc>()..add(const SyncInitialised())),
        BlocProvider(create: (_) => getIt<RecordsBloc>()),
        BlocProvider.value(value: getIt<ScanBloc>()),
        BlocProvider(
          create: (_) => HomeBloc(
            getIt<GetSourcesUseCase>(),
            HomeLocalDataSourceImpl(),
            getIt<RecordsRepository>(),
            getIt<SyncRepository>(),
            getIt<PatientDeduplicationService>(),
            getIt<PatientSelectionService>(),
          )..add(const HomeInitialised()),
        ),
        BlocProvider(
          create: (_) => getIt<PatientBloc>()..add(const PatientInitialised()),
        ),
        BlocProvider.value(value: getIt<NotificationBloc>()),
        BlocProvider(create: (_) => getIt<WalletPassBloc>()),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<SyncBloc, SyncState>(
            listener: (context, state) {
              _handleSyncBlocStateChange(context, state);
            },
          ),
          BlocListener<ScanBloc, ScanState>(
            listenWhen: (previous, current) =>
                previous.status != current.status &&
                current.status == const ScanStatus.success(),
            listener: (context, state) {
              _handleScanSuccess(context);
            },
          ),
          BlocListener<RecordsBloc, RecordsState>(
            listenWhen: (previous, current) =>
                current.status == const RecordsStatus.deleted(),
            listener: (context, state) {
              context
                  .read<PatientBloc>()
                  .add(const PatientPatientsLoaded());
              context
                  .read<HomeBloc>()
                  .add(const HomeRefreshPreservingOrder());
            },
          ),
        ],
        child: BlocBuilder<UserBloc, UserState>(
          builder: (context, state) {
            return MaterialApp.router(
              scrollBehavior: const MaterialScrollBehavior().copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              title: 'HealthWallet.me',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode:
                  state.user.isDarkMode ? ThemeMode.dark : ThemeMode.light,
              locale: state.appLocale,
              routerConfig: router.config(
                navigatorObservers: () => [routeObserver],
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) {
                return child!;
              },
            );
          },
        ),
      ),
    );
  }
}

void _handleScanSuccess(BuildContext context) {
  context.read<PatientBloc>().add(const PatientPatientsLoaded());
  context.read<HomeBloc>().add(const HomeScanCompleted());
  context.read<RecordsBloc>().add(const RecordsInitialised());
}

void _handleSyncBlocStateChange(BuildContext context, SyncState state) {
  if (state.shouldShowTutorial) {
    context.read<HomeBloc>().add(const HomeRefreshPreservingOrder());
  }

  if (state.syncStatus == SyncStatus.synced) {
    context.read<RecordsBloc>().add(const RecordsInitialised());
    context.read<UserBloc>().add(const UserDataUpdatedFromSync());
    context.read<PatientBloc>().add(const PatientPatientsLoaded());

    Future.delayed(const Duration(milliseconds: 500), () {
      if (context.mounted) {
        final homeState = context.read<HomeBloc>().state;
        final currentSource =
            homeState.selectedSource.isEmpty ? 'All' : homeState.selectedSource;
        PatientSourceUtils.reloadHomeWithPatientFilter(context, currentSource);
      }
    });
  }
}
