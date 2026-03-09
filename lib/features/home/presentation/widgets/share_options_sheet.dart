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
        value: 'export_ips',
        child: ListTile(
          leading: Assets.icons.download.svg(
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(
              colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          ),
          title: Text('Export IPS (PDF)', style: AppTextStyle.menuItem),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      if (Platform.isIOS)
        PopupMenuItem<String>(
          value: 'apple_wallet',
          child: ListTile(
            leading: Assets.icons.wallet.svg(
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                colorScheme.onSurface,
                BlendMode.srcIn,
              ),
            ),
            title:
                Text('Add IPS to Apple Wallet', style: AppTextStyle.menuItem),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (Platform.isAndroid)
        PopupMenuItem<String>(
          value: 'google_wallet',
          child: ListTile(
            leading: Assets.icons.wallet.svg(
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                colorScheme.onSurface,
                BlendMode.srcIn,
              ),
            ),
            title:
                Text('Add IPS to Google Wallet', style: AppTextStyle.menuItem),
            contentPadding: EdgeInsets.zero,
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
