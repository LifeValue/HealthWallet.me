import 'dart:async';

import 'package:flutter/material.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/connection_dialog.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';

class HandoverReconnectDialog extends StatefulWidget {
  final ProcessingSession session;

  const HandoverReconnectDialog({super.key, required this.session});

  @override
  State<HandoverReconnectDialog> createState() =>
      _HandoverReconnectDialogState();
}

class _HandoverReconnectDialogState extends State<HandoverReconnectDialog> {
  late final CommunicationBloc _commBloc;
  StreamSubscription? _sub;
  bool _showPairing = false;
  bool _reconnecting = false;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _commBloc = getIt<CommunicationBloc>();
    _sub = _commBloc.stream.listen(_onStateChange);
    _attemptReconnect();
  }

  void _attemptReconnect() {
    if (_commBloc.state.pairedDevice == null) {
      setState(() => _showPairing = true);
      return;
    }

    setState(() => _reconnecting = true);
    _commBloc.add(const CommunicationConnectionRequested());

    _timeout = Timer(const Duration(seconds: 15), () {
      if (mounted && _reconnecting) {
        setState(() {
          _reconnecting = false;
          _showPairing = true;
        });
      }
    });
  }

  void _onStateChange(DesktopSyncState state) {
    if (!mounted) return;

    if (state.connectionStatus == ConnectionStatus.connected) {
      _timeout?.cancel();
      Navigator.of(context).pop(true);
    }
  }

  void _openPairing() {
    Navigator.of(context).pop('pair');
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(Insets.medium),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Connect to Desktop',
                  style: AppTextStyle.bodyMedium.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Icon(
                    Icons.close,
                    size: 20,
                    color:
                        context.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.normal),
            if (_reconnecting) ...[
              const SizedBox(height: Insets.normal),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colorScheme.primary,
                ),
              ),
              const SizedBox(height: Insets.small),
              Text(
                'Reconnecting to ${_commBloc.state.pairedDevice?.deviceName ?? 'Desktop'}...',
                style: AppTextStyle.labelSmall.copyWith(
                  color:
                      context.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: Insets.normal),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Scan QR Code',
                  variant: AppButtonVariant.primary,
                  height: 40,
                  onPressed: _openPairing,
                ),
              ),
            ],
            if (_showPairing) ...[
              Text(
                _commBloc.state.pairedDevice != null
                    ? 'Could not reconnect. Scan QR code to pair again.'
                    : 'Scan the QR code on your desktop app to pair.',
                style: AppTextStyle.bodySmall.copyWith(
                  color:
                      context.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.normal),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Scan QR Code',
                  variant: AppButtonVariant.primary,
                  height: 40,
                  onPressed: _openPairing,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
