import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
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

class App extends StatelessWidget {
  const App({super.key});

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
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<SyncBloc, SyncState>(
            listener: (context, state) {
              _handleSyncBlocStateChange(context, state);
            },
          ),
        ],
        child: BlocBuilder<UserBloc, UserState>(
          builder: (context, state) {
            return MaterialApp.router(
              title: 'HealthWallet.me',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode:
                  state.user.isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
