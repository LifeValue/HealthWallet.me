import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_dropdown_field.dart';

class FormFields {
  static Widget buildFieldLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.smaller),
      child: Text(label,
          style: AppTextStyle.bodySmall.copyWith(
            color: context.isDarkMode
                ? AppColors.textPrimaryDark
                : AppColors.textPrimary,
          )),
    );
  }

  static Widget buildTextField(
    BuildContext context,
    String label,
    String value,
    ValueChanged<String>? onChanged, {
    TextEditingController? controller,
    String? hintText,
  }) {
    final textController = controller ?? TextEditingController(text: value);

    if (controller == null && textController.text != value) {
      final selection = textController.selection;
      textController.text = value;
      if (selection.end == textController.text.length) {
        textController.selection = TextSelection.fromPosition(
          TextPosition(offset: value.length),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildFieldLabel(context, label),
        Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  context.isDarkMode ? AppColors.borderDark : AppColors.border,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: textController,
            enabled: onChanged != null,
            onChanged: onChanged,
            style: AppTextStyle.labelLarge.copyWith(
              color: context.isDarkMode
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Insets.small,
                vertical: Insets.small,
              ),
              border: InputBorder.none,
              isDense: true,
              hintText: hintText,
              hintStyle: AppTextStyle.labelLarge.copyWith(
                color: context.isDarkMode
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget buildDropdownField(
    BuildContext context,
    String label,
    String value,
    List<String> items,
    ValueChanged<String>? onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildFieldLabel(context, label),
        AppDropdownField<String>(
          value: value,
          items: items,
          getDisplayText: (item) => item,
          onChanged: onChanged,
        ),
      ],
    );
  }

  static Widget buildActionButtons({
    required VoidCallback onCancel,
    required VoidCallback? onSave,
    required bool isLoading,
    String cancelLabel = 'Cancel',
    String saveLabel = 'Save details',
  }) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: isLoading ? null : onCancel,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: Insets.small),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            child: Text(cancelLabel, style: AppTextStyle.buttonSmall),
          ),
        ),
        const SizedBox(width: Insets.small),
        Expanded(
          child: ElevatedButton(
            onPressed: isLoading ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: Insets.small),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(saveLabel, style: AppTextStyle.buttonSmall),
          ),
        ),
      ],
    );
  }

  static Widget buildIconButton(
    dynamic icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
      child: IconButton(
        icon: icon.svg(
          width: 24.0,
          height: 24.0,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
