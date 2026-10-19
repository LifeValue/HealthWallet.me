import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';

class SpecialtyPicker extends StatelessWidget {
  final MedicalSpecialty? currentSpecialty;
  final ValueChanged<MedicalSpecialty?> onSelected;

  const SpecialtyPicker({
    required this.currentSpecialty,
    required this.onSelected,
    super.key,
  });

  static Future<MedicalSpecialty?> show(
    BuildContext context, {
    MedicalSpecialty? current,
  }) {
    return showModalBottomSheet<MedicalSpecialty?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      isScrollControlled: true,
      builder: (_) => SpecialtyPicker(
        currentSpecialty: current,
        onSelected: (s) => Navigator.of(context).pop(s),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(
          left: Insets.normal,
          right: Insets.normal,
          top: Insets.normal,
          bottom: Insets.medium,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Specialty',
                  style: AppTextStyle.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.primaryTextColor,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: context.colorScheme.onSurface,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: Insets.small),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: Insets.small,
                crossAxisSpacing: Insets.small,
                childAspectRatio: 3.2,
              ),
              itemCount: MedicalSpecialty.values.length,
              itemBuilder: (context, index) {
                final specialty = MedicalSpecialty.values[index];
                final isSelected = specialty == currentSpecialty;
                return _SpecialtyItem(
                  specialty: specialty,
                  isSelected: isSelected,
                  onTap: () => onSelected(specialty),
                );
              },
            ),
            if (currentSpecialty != null) ...[
              const SizedBox(height: Insets.smallNormal),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => onSelected(null),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colorScheme.error,
                  ),
                  child: Text(
                    'Remove Specialty',
                    style: AppTextStyle.labelLarge.copyWith(
                      color: context.colorScheme.error,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpecialtyItem extends StatelessWidget {
  final MedicalSpecialty specialty;
  final bool isSelected;
  final VoidCallback onTap;

  const _SpecialtyItem({
    required this.specialty,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.small,
          vertical: Insets.extraSmall,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? context.colorScheme.primary
                : context.borderColor,
          ),
          color: isSelected
              ? context.colorScheme.primary.withValues(alpha: 0.08)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? context.colorScheme.primary
                    : context.surfaceColor,
              ),
              child: Center(
                child: specialty.icon.svg(
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(
                    isSelected
                        ? context.colorScheme.onPrimary
                        : context.colorScheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Insets.small),
            Expanded(
              child: Text(
                specialty.displayName,
                style: AppTextStyle.labelLarge.copyWith(
                  color: isSelected
                      ? context.colorScheme.primary
                      : context.primaryTextColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
