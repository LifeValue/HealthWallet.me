import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/desktop_card.dart';
import 'package:health_wallet/core/l10n/l10n.dart';

class ProcessingCard extends StatelessWidget {
  const ProcessingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return DesktopCard(
      title: context.l10n.desktopProcessingHistory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRow(context,
              icon: Icons.phone_android,
              label: context.l10n.desktopScannedOnPhone,
              count: '-'),
          _buildRow(context,
              icon: Icons.desktop_mac,
              label: context.l10n.desktopProcessedOnDesktop,
              count: '-'),
          _buildRow(context,
              icon: Icons.file_upload_outlined,
              label: context.l10n.desktopImportedOnDesktop,
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
