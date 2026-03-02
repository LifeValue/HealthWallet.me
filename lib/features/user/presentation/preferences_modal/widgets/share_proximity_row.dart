import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/share_records/core/share_permissions_helper.dart';
import 'package:health_wallet/features/share_records/data/service/receive_mode_manager.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/widgets/receive_mode_toggle_button.dart';
import 'package:permission_handler/permission_handler.dart';


class ShareProximityRow extends StatefulWidget {
  const ShareProximityRow({super.key});

  @override
  State<ShareProximityRow> createState() => _ShareProximityRowState();
}

class _ShareProximityRowState extends State<ShareProximityRow>
    with WidgetsBindingObserver {
  bool _permissionsGranted = false;
  bool _checking = true;
  bool _waitingForSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForSettings) {
      _waitingForSettings = false;
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final granted = await SharePermissionsHelper.hasRequiredPermissions();
    if (!mounted) return;

    setState(() {
      _permissionsGranted = granted;
      _checking = false;
    });

    if (granted) {
      final manager = getIt<ReceiveModeManager>();
      final isEnabled =
          context.read<UserBloc>().state.user.isReceiveModeEnabled;
      if (manager.isListening && !isEnabled) {
        context.read<UserBloc>().add(const UserReceiveModeToggled(true));
      }
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await _requestIOSPermissions();
      return;
    }

    final result = await SharePermissionsHelper.requestSharePermissions();
    if (!mounted) return;

    switch (result) {
      case PermissionGranted():
        setState(() => _permissionsGranted = true);
        context.read<UserBloc>().add(const UserReceiveModeToggled(true));

      case PermissionDenied():
        break;

      case PermissionPermanentlyDenied():
        _waitingForSettings = true;
        await SharePermissionsHelper.openSettings();
    }
  }

  Future<void> _requestIOSPermissions() async {
    final bluetoothStatus = await Permission.bluetooth.status;

    if (bluetoothStatus.isPermanentlyDenied) {
      _waitingForSettings = true;
      await SharePermissionsHelper.openSettings();
      return;
    }

    final manager = getIt<ReceiveModeManager>();
    await manager.startListening();

    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      final status = await Permission.bluetooth.status;
      if (status.isGranted || status.isPermanentlyDenied) break;
    }

    if (!mounted) return;

    final btStatus = await Permission.bluetooth.status;
    if (btStatus.isGranted) {
      await manager.stopListening();
      await manager.startListening();
    }

    if (!mounted) return;
    await _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const SizedBox.shrink();

    return InkWell(
      onTap: _permissionsGranted
          ? () {
              final isEnabled =
                  context.read<UserBloc>().state.user.isReceiveModeEnabled;
              context.read<UserBloc>().add(UserReceiveModeToggled(!isEnabled));
            }
          : _requestPermissions,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.small),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Share Proximity',
                    style: AppTextStyle.bodySmall,
                  ),
                  Text(
                    'Advertise to nearby devices',
                    style: AppTextStyle.labelSmall.copyWith(
                      color: context.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (_permissionsGranted)
              const ReceiveModeToggleButton()
            else
              AppButton(
                label: 'Allow',
                onPressed: _requestPermissions,
                fullWidth: false,
                height: 40,
              ),
          ],
        ),
      ),
    );
  }
}
