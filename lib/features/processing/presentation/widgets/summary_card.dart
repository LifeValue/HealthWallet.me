import 'package:flutter/material.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

class SummaryCard extends StatelessWidget {
  final int totalPagesForOcr;

  const SummaryCard({
    super.key,
    required this.totalPagesForOcr,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.summaryTitle,
          style: AppTextStyle.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.pagesAvailableForProcessing(totalPagesForOcr),
          style: AppTextStyle.bodySmall.copyWith(
            color: context.colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
