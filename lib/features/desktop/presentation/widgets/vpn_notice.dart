import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';

/// Warning line shown when a VPN may block the phone-desktop link.
class VpnNotice extends StatelessWidget {
  const VpnNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.vpn_lock, size: 14, color: AppColors.warning),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: AppTextStyle.labelSmall.copyWith(
              color: AppColors.warning,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}
