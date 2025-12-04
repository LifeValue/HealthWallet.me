import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'form_fields.dart';

class DialogHeader extends StatelessWidget {
  final Color textColor;
  final VoidCallback onCancel;
  final String title;
  final String? subtitle;

  const DialogHeader({
    super.key,
    required this.textColor,
    required this.onCancel,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.normal, vertical: Insets.small),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                FormFields.buildIconButton(Assets.icons.user, textColor, () {}),
                const SizedBox(width: Insets.small),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTextStyle.bodySmall
                            .copyWith(fontWeight: FontWeight.w500),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: AppTextStyle.bodySmall.copyWith(
                            color: textColor.withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          FormFields.buildIconButton(Assets.icons.close, textColor, onCancel),
        ],
      ),
    );
  }
}
