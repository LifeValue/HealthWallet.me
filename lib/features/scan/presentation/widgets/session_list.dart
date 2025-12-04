import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/dialogs/alert_dialogs.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:health_wallet/features/scan/presentation/widgets/custom_progress_indicator.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:intl/intl.dart';

class SessionList extends StatelessWidget {
  const SessionList({
    required this.sessions,
    this.activeSessionId,
    super.key,
  });

  final List<ProcessingSession> sessions;
  final String? activeSessionId;

  @override
  Widget build(BuildContext context) {
    sessions.sort();
    return ListView.builder(
        shrinkWrap: true,
        itemCount: sessions.length,
        itemBuilder: (context, index) {
          final session = sessions[index];
          final isProcessing = session.status == ProcessingStatus.processing;
          final isInterrupted = isProcessing && activeSessionId != session.id;
          final statusLabel =
              isInterrupted ? 'Interrupted' : session.status.toString();
          final statusColor = isInterrupted
              ? context.colorScheme.error
              : session.status.getColor(context);
          final borderColor = isInterrupted
              ? context.colorScheme.error
              : context.colorScheme.primary;

          return InkWell(
            onTap: () =>
                context.router.push(ProcessingRoute(sessionId: session.id)),
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: (index < sessions.length - 1) ? 16 : 0),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color:
                        isProcessing ? borderColor : context.theme.dividerColor,
                    width: isProcessing ? 2.0 : 1.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(
                                height: 6,
                              ),
                              Text(DateFormat('MMMM d, HH:mm:ss')
                                  .format(session.createdAt!)),
                            ],
                          ),
                          IconButton(
                            onPressed: () =>
                                _showDeleteConfirmation(context, session),
                            icon: Assets.icons.close.svg(
                              colorFilter: ColorFilter.mode(
                                context.colorScheme.onSurface,
                                BlendMode.srcIn,
                              ),
                            ),
                            visualDensity: const VisualDensity(
                                horizontal: -4, vertical: -4),
                          )
                        ],
                      ),
                      if (isProcessing)
                        CustomProgressIndicator(progress: session.progress),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
  }

  void _showDeleteConfirmation(
      BuildContext context, ProcessingSession session) {
    final scanBloc = context.read<ScanBloc>();

    AlertDialogs.showConfirmation(
      context: context,
      title: 'Delete Session',
      message: 'Are you sure you want to delete this session?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      warningText: 'This action cannot be undone.',
      confirmButtonColor: context.colorScheme.error,
      onConfirm: () {
        scanBloc.add(ScanSessionCleared(session: session));
      },
    );
  }
}
