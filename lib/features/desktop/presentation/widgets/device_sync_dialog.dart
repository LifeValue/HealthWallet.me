import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/connection_dialog.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/sync_dialog.dart';

class DeviceSyncDialog {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: getIt<CommunicationBloc>()),
                BlocProvider.value(value: getIt<LwwSyncBloc>()),
              ],
              child: BlocBuilder<CommunicationBloc, DesktopSyncState>(
                builder: (context, commState) {
                  return BlocBuilder<LwwSyncBloc, LwwSyncState>(
                    builder: (context, syncState) {
                      return Container(
                        decoration: BoxDecoration(
                          color: context.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                left: Insets.medium,
                                right: Insets.medium,
                                top: Insets.normal,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Device Sync',
                                    style: AppTextStyle.bodyMedium.copyWith(
                                      color: context.colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => Navigator.of(context).pop(),
                                    child: Icon(
                                      Icons.close,
                                      size: 20,
                                      color: context.colorScheme.onSurface
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.all(Insets.medium),
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ConnectionSection(commState: commState),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: Insets.normal),
                                        child: Divider(
                                          color: context.colorScheme.onSurface
                                              .withValues(alpha: 0.06),
                                          height: 1,
                                        ),
                                      ),
                                      SyncSection(
                                        commState: commState,
                                        syncState: syncState,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
