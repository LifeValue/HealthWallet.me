import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_bloc.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_event.dart';

void showExtendOptionsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Insets.normal),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Extend Session',
              style: AppTextStyle.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Request additional viewing time',
              style: AppTextStyle.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: Insets.normal),
            _buildExtendOption(context, ctx, 60, '1 minute'),
            _buildExtendOption(context, ctx, 180, '3 minutes'),
            _buildExtendOption(context, ctx, 300, '5 minutes'),
          ],
        ),
      ),
    ),
  );
}

Widget _buildExtendOption(
  BuildContext parentContext,
  BuildContext sheetContext,
  int durationSeconds,
  String label,
) {
  return ListTile(
    leading: const Icon(Icons.timer_outlined),
    title: Text(label),
    onTap: () {
      Navigator.of(sheetContext).pop();
      parentContext.read<ShareRecordsBloc>().add(
            ShareRecordsEvent.sessionExtendRequested(durationSeconds),
          );
    },
  );
}
