import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/desktop_card.dart';

class ProcessingCard extends StatelessWidget {
  const ProcessingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return DesktopCard(
      title: 'Processing History',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRow(context,
              icon: Icons.phone_android,
              label: 'Scanned on Phone',
              count: '-'),
          _buildRow(context,
              icon: Icons.desktop_mac,
              label: 'Processed on Desktop',
              count: '-'),
          _buildRow(context,
              icon: Icons.file_upload_outlined,
              label: 'Imported on Desktop',
              count: '-'),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String count,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.small),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: context.colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: Insets.small),
          Text(label,
              style: AppTextStyle.labelSmall
                  .copyWith(color: context.colorScheme.onSurface)),
          const Spacer(),
          Text(count,
              style: AppTextStyle.labelSmall.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}
