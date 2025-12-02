import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
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
    return ListView.builder(
        shrinkWrap: true,
        itemCount: sessions.length,
        itemBuilder: (context, index) {
          final session = sessions[index];
          final isInProgress = session.status == ProcessingStatus.processing;

          return InkWell(
            onTap: () => context.router.push(FhirMapperRoute(sessionId: session.id)),
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: (index < sessions.length - 1) ? 16 : 0),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isInProgress
                        ? context.colorScheme.primary
                        : context.theme.dividerColor,
                    width: isInProgress ? 2.0 : 1.0,
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
                              Text(session.status.toString(),style: TextStyle(
                                color: session.status.getColor(context),
                                fontWeight: FontWeight.w600,
                              ),),
                              const SizedBox(height: 6,),
                              Text(DateFormat('MMMM d, HH:mm:ss')
                                  .format(session.createdAt!)),
                            ],
                          ),
                          if (session.status != ProcessingStatus.processing)
                            IconButton(
                              onPressed: () => context
                                  .read<ScanBloc>()
                                  .add(ScanSessionCleared(session: session)),
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
                      if (isInProgress)
                        CustomProgressIndicator(progress: session.progress),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
  }
}