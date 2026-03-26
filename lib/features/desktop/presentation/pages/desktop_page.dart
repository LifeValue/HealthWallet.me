import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/backup_card.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/connection_card.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/connection_chip.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/processing_card.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/sync_status_card.dart';

@RoutePage()
class DesktopPage extends StatelessWidget {
  const DesktopPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<CommunicationBloc>()
            ..add(const CommunicationInitialised()),
        ),
        BlocProvider(
          create: (_) =>
              getIt<BackupBloc>()..add(const BackupHistoryLoaded()),
        ),
        BlocProvider.value(
          value: getIt<LwwSyncBloc>(),
        ),
      ],
      child: BlocBuilder<CommunicationBloc, DesktopSyncState>(
        builder: (context, commState) {
          return BlocBuilder<BackupBloc, BackupState>(
            builder: (context, backupState) {
              return BlocBuilder<LwwSyncBloc, LwwSyncState>(
                builder: (context, syncState) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(Insets.medium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context, commState),
                        const SizedBox(height: Insets.medium),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: ConnectionCard(state: commState)),
                            const SizedBox(width: Insets.medium),
                            Expanded(
                              child: Column(
                                children: [
                                  SyncStatusCard(
                                    commState: commState,
                                    syncState: syncState,
                                  ),
                                  const SizedBox(height: Insets.medium),
                                  BackupCard(
                                    syncState: commState,
                                    backupState: backupState,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Insets.medium),
                        const ProcessingCard(),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DesktopSyncState state) {
    return Row(
      children: [
        Icon(Icons.sync, size: 28, color: context.colorScheme.primary),
        const SizedBox(width: Insets.small),
        Text(
          'Sync',
          style: AppTextStyle.titleMedium
              .copyWith(color: context.colorScheme.onSurface),
        ),
        const Spacer(),
        ConnectionChip(state: state),
      ],
    );
  }
}
