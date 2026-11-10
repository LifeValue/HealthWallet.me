import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/navigation/observers/order_route_observer.dart';
import 'package:health_wallet/core/services/bluetooth_state_service.dart';
import 'package:health_wallet/core/theme/theme.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/features/app_lock/presentation/bloc/app_lock_bloc.dart';
import 'package:health_wallet/features/app_lock/presentation/widgets/app_lock_overlay.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/phone_approval_listener.dart';
import 'package:health_wallet/features/desktop/tray/presentation/bloc/tray_bloc.dart';
import 'package:health_wallet/features/holders/presentation/widgets/holder_question_listener.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/notifications/bloc/notification_bloc.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/widgets/capture_error_listener.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/ips_export_error_listener.dart';
import 'package:health_wallet/features/share_records/core/share_permissions_helper.dart';
import 'package:health_wallet/features/share_records/domain/services/receive_mode_service.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/sync/presentation/widgets/sync_error_listener.dart';
import 'package:health_wallet/features/user/domain/entity/user.dart';
import 'package:health_wallet/features/user/domain/repository/user_repository.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/features/wallet_pass/presentation/bloc/wallet_pass_bloc.dart';
import 'package:health_wallet/features/wallet_pass/presentation/widgets/wallet_pass_error_listener.dart';
import 'package:intl/intl.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  final AppLockBloc _appLockBloc = getIt<AppLockBloc>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appLockBloc.add(const AppLockStarted());
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
    _appLockBloc.add(AppLockLifecycleChanged(state));
    if (state == AppLifecycleState.resumed) {
      _startSymmetricDiscovery();
      _reconnectDesktopIfNeeded();
    } else if (state == AppLifecycleState.paused) {
      _stopSymmetricDiscovery();
    }
  }

  void _reconnectDesktopIfNeeded() {
    if (getIt<AppPlatform>().isDesktop) return;
    try {
      final commBloc = getIt<CommunicationBloc>();
      if (commBloc.state.pairedDevice != null &&
          commBloc.state.connectionStatus == ConnectionStatus.disconnected) {
        commBloc.add(const CommunicationConnectionRequested());
      }
    } catch (e) {
      logger.w('Could not reconnect to the paired desktop', e);
    }
  }

  Future<void> _startSymmetricDiscovery() async {
    if (getIt<AppPlatform>().isDesktop) return;

    final userRepository = getIt<UserRepository>();
    final User user;
    try {
      user = await userRepository.getCurrentUser();
    } catch (e) {
      // Before onboarding there is no user yet, so nothing to listen for.
      logger.w('Receive mode not started: $e');
      return;
    }
    if (!user.isReceiveModeEnabled) return;

    final hasPermissions =
        await SharePermissionsHelper.hasRequiredPermissions();
    if (!hasPermissions) return;

    final bluetoothOn = await getIt<BluetoothStateService>().isEnabled();
    if (!bluetoothOn) {
      await userRepository.updateUser(
        user.copyWith(isReceiveModeEnabled: false),
      );
      return;
    }

    final manager = getIt<ReceiveModeService>();
    if (!manager.isListening) {
      await manager.startListening();
    }
  }

  Future<void> _stopSymmetricDiscovery() async {
    if (getIt<AppPlatform>().isDesktop) return;

    final manager = getIt<ReceiveModeService>();
    // A share screen owns the transport while receive mode is paused;
    // stopping now would cut a live share (e.g. the sender's screen locks).
    if (manager.isListening && !manager.isPaused) {
      await manager.stopListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = getIt<AppRouter>();
    final routeObserver = getIt<AppRouteObserver>();

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _appLockBloc),
        BlocProvider(
          create: (_) => getIt<UserBloc>()..add(const UserInitialised()),
        ),
        BlocProvider(
          create: (_) => getIt<SyncBloc>()..add(const SyncInitialised()),
        ),
        BlocProvider(create: (_) => getIt<RecordsBloc>()),
        BlocProvider.value(value: getIt<ProcessingBloc>()),
        BlocProvider.value(
          value: getIt<HomeBloc>()..add(const HomeInitialised()),
        ),
        BlocProvider(
          create: (_) => getIt<PatientBloc>()..add(const PatientInitialised()),
        ),
        BlocProvider.value(value: getIt<NotificationBloc>()),
        BlocProvider(create: (_) => getIt<WalletPassBloc>()),
        if (getIt<AppPlatform>().isDesktop)
          BlocProvider.value(value: getIt<TrayBloc>()),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<SyncBloc, SyncState>(
            listenWhen: (previous, current) =>
                previous.syncStatus != current.syncStatus ||
                previous.shouldShowTutorial != current.shouldShowTutorial,
            listener: _handleSyncBlocStateChange,
          ),
          BlocListener<ProcessingBloc, ProcessingState>(
            listenWhen: (previous, current) =>
                previous.status != current.status && current.status is Success,
            listener: (context, state) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                _handleScanSuccess(context);
              });
            },
          ),
          BlocListener<RecordsBloc, RecordsState>(
            listenWhen: (previous, current) =>
                current.status == const RecordsStatus.deleted(),
            listener: (context, state) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                // Home follows when the people are read again.
                context.read<PatientBloc>().add(const PatientPatientsLoaded());
              });
            },
          ),
        ],
        child: BlocBuilder<UserBloc, UserState>(
          buildWhen: (previous, current) =>
              previous.user.isDarkMode != current.user.isDarkMode ||
              previous.appLocale != current.appLocale,
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
              themeMode: state.user.isDarkMode
                  ? ThemeMode.dark
                  : ThemeMode.light,
              locale: state.appLocale,
              routerConfig: router.config(
                navigatorObservers: () => [routeObserver],
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) {
                getIt<AppStringsProvider>().update(context.l10n);
                Intl.defaultLocale = context.l10n.localeName;
                return PhoneApprovalListener(
                  child: AppLockOverlay(
                    child: IpsExportErrorListener(
                      child: WalletPassErrorListener(
                        child: CaptureErrorListener(
                          child: SyncErrorListener(
                            child: HolderQuestionListener(child: child!),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      context.read<HomeBloc>().add(const HomeRefreshPreservingOrder());
    });
  }

  if (state.syncStatus == SyncStatus.synced) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      context.read<RecordsBloc>().add(const RecordsInitialised());
      context.read<UserBloc>().add(const UserDataUpdatedFromSync());
      context.read<PatientBloc>().add(const PatientPatientsLoaded());

      AppSimpleDialog.showSuccess(
        context: context,
        title: context.l10n.success,
        message: context.l10n.syncDataLoadedSuccessfully,
      );
    });
    // Reading the people again (PatientPatientsLoaded) moves Home to the
    // new records through the selection.
  }
}
