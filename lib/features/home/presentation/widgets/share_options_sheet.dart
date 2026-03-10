import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/wallet_pass/domain/repository/wallet_pass_repository.dart';
import 'package:health_wallet/features/wallet_pass/presentation/bloc/wallet_pass_bloc.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/gen/assets.gen.dart';

Future<void> showShareOptionsMenu(
  BuildContext context, {
  required RelativeRect position,
  String? patientName,
  String? patientId,
}) async {
  final colorScheme = Theme.of(context).colorScheme;

  final value = await showMenu<String>(
    context: context,
    position: position,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: colorScheme.onSurface.withValues(alpha: 0.2),
      ),
    ),
    items: [
      PopupMenuItem<String>(
        height: 40,
        value: 'export_ips',
        child: Row(
          children: [
            Assets.icons.download.svg(
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                colorScheme.onSurface,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 12),
            Text('Export IPS (PDF)', style: AppTextStyle.menuItem),
          ],
        ),
      ),
      if (Platform.isIOS)
        PopupMenuItem<String>(
          height: 40,
          value: 'apple_wallet',
          child: Row(
            children: [
              Assets.icons.wallet.svg(
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  colorScheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
              Text('Add IPS to Apple Wallet', style: AppTextStyle.menuItem),
            ],
          ),
        ),
      if (Platform.isAndroid)
        PopupMenuItem<String>(
          height: 40,
          value: 'google_wallet',
          child: Row(
            children: [
              Assets.icons.wallet.svg(
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  colorScheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
              Text('Add IPS to Google Wallet', style: AppTextStyle.menuItem),
            ],
          ),
        ),
    ],
  );

  if (value == null) return;
  if (!context.mounted) return;

  switch (value) {
    case 'export_ips':
      context.read<RecordsBloc>().add(
            RecordsSharePressed(
              patientName: patientName,
              patientId: patientId,
            ),
          );
    case 'apple_wallet':
      context.read<WalletPassBloc>().add(
            WalletPassRequested(
              type: WalletPassType.apple,
              patientId: patientId ?? '',
            ),
          );
    case 'google_wallet':
      context.read<WalletPassBloc>().add(
            WalletPassRequested(
              type: WalletPassType.google,
              patientId: patientId ?? '',
            ),
          );
  }
}
