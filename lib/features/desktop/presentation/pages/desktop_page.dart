import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
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
    return BlocProvider(
      create: (_) =>
          getIt<CommunicationBloc>()..add(const CommunicationInitialised()),
      child: BlocBuilder<CommunicationBloc, DesktopSyncState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(Insets.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, state),
                const SizedBox(height: Insets.medium),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: ConnectionCard(state: state)),
                    const SizedBox(width: Insets.medium),
                    Expanded(
                      child: Column(
                        children: [
                          BackupCard(state: state),
                          const SizedBox(height: Insets.medium),
                          SyncStatusCard(state: state),
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
