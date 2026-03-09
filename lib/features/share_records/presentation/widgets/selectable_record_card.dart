import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:intl/intl.dart';

class SelectableRecordCard extends StatelessWidget {
  final IFhirResource resource;
  final bool isSelected;
  final VoidCallback onToggle;

  const SelectableRecordCard({
    super.key,
    required this.resource,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: Insets.normal,
        vertical: Insets.extraSmall,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? AppColors.primary
              : context.theme.dividerColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.05)
          : context.colorScheme.surface,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(Insets.normal),
          child: Row(
            children: [
              _buildCheckbox(context),
              const SizedBox(width: Insets.normal),
              _buildTypeIcon(context),
              const SizedBox(width: Insets.normal),
              Expanded(
                child: _buildContent(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Checkbox(
        value: isSelected,
        onChanged: (_) => onToggle(),
        activeColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildTypeIcon(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: context.colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: resource.fhirType.icon.svg(
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(
            context.colorScheme.onSurface.withValues(alpha: 0.7),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.small,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: context.colorScheme.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                resource.fhirType.display,
                style: AppTextStyle.labelSmall.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            if (resource.date != null)
              Text(
                DateFormat.yMMMd().format(resource.date!),
                style: AppTextStyle.labelSmall.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
        const SizedBox(height: Insets.extraSmall),
        Text(
          resource.displayTitle,
          style: AppTextStyle.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
            color: context.colorScheme.onSurface,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (resource.additionalInfo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Insets.extraSmall),
            child: Row(
              children: [
                resource.additionalInfo.first.icon.svg(
                  width: 14,
                  colorFilter: ColorFilter.mode(
                    context.colorScheme.onSurface.withValues(alpha: 0.5),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    resource.additionalInfo.first.info,
                    style: AppTextStyle.labelSmall.copyWith(
                      color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
