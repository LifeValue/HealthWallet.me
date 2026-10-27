import 'package:flutter/material.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:intl/intl.dart';

class RecordTypeHeader extends StatelessWidget {
  final FhirType fhirType;
  final DateTime? date;
  final VoidCallback? onTypeTap;

  const RecordTypeHeader({
    super.key,
    required this.fhirType,
    this.date,
    this.onTypeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildTypeBadge(context),
        if (date != null)
          Text(
            DateFormat.yMMMMd(context.l10n.localeName).format(date!),
            style: AppTextStyle.labelMedium.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
      ],
    );
  }

  Widget _buildTypeBadge(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.small,
        vertical: Insets.extraSmall,
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.onSurface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          fhirType.icon.svg(
            width: 15,
            colorFilter: ColorFilter.mode(
              context.colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            fhirType.localizedName(context.l10n),
            style: AppTextStyle.labelSmall,
          ),
        ],
      ),
    );

    if (onTypeTap != null) {
      return GestureDetector(
        onTap: onTypeTap,
        child: badge,
      );
    }

    return badge;
  }
}
