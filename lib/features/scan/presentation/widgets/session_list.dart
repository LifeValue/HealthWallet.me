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
    super.key,
  });

  final List<ProcessingSession> sessions;

  @override
  Widget build(BuildContext context) {
    sessions.sort();
    return BlocBuilder<ScanBloc, ScanState>(
      builder: (context, state) {
        return ListView.builder(
          shrinkWrap: true,
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            final statusColor = session.status.getColor(context);
            final borderColor = context.colorScheme.primary;

            // Check if THIS specific session is being deleted
            final isThisSessionDeleting = state.deletingSessionId == session.id;

            return InkWell(
              onTap: isThisSessionDeleting
                  ? null
                  : () => context.router
                      .push(ProcessingRoute(sessionId: session.id)),
              child: Padding(
                padding: EdgeInsets.only(
                    bottom: (index < sessions.length - 1) ? 16 : 0),
                child: Opacity(
                  opacity: isThisSessionDeleting ? 0.6 : 1.0,
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isThisSessionDeleting
                            ? context.colorScheme.error.withOpacity(0.5)
                            : session.isProcessing
                                ? borderColor
                                : context.theme.dividerColor,
                        width: session.isProcessing ? 2.0 : 1.0,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isThisSessionDeleting
                                              ? 'Canceling...'
                                              : session.status.toString(),
                                          style: TextStyle(
                                            color: isThisSessionDeleting
                                                ? context.colorScheme.error
                                                : statusColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          DateFormat('MMMM d, HH:mm:ss')
                                              .format(session.createdAt!),
                                        ),
                                        if (isThisSessionDeleting) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Waiting for AI to finish...',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: context.colorScheme.error,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (!isThisSessionDeleting)
                                    IconButton(
                                      onPressed: () => _showDeleteConfirmation(
                                          context, session),
                                      icon: Assets.icons.close.svg(
                                        colorFilter: ColorFilter.mode(
                                          context.colorScheme.onSurface,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                      visualDensity: const VisualDensity(
                                          horizontal: -4, vertical: -4),
                                    ),
                                ],
                              ),
                              if (session.isProcessing &&
                                  !isThisSessionDeleting)
                                CustomProgressIndicator(
                                    progress: session.progress),
                            ],
                          ),
                        ),
                        // Semi-transparent overlay when deleting
                        if (isThisSessionDeleting)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: context.colorScheme.surface
                                    .withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.colorScheme.error,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
