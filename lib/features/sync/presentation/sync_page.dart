import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/data/services/pairing_storage_service.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/device_sync_dialog.dart';
import 'package:health_wallet/features/sync/presentation/widgets/sync_placeholder_widget.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/sync/presentation/widgets/qr_scanner_widget.dart';
import 'package:health_wallet/features/sync/presentation/widgets/sync_loading_widget.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

@RoutePage()
class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: getIt<CommunicationBloc>()),
        BlocProvider.value(value: getIt<LwwSyncBloc>()),
      ],
      child: BlocListener<SyncBloc, SyncState>(
        listenWhen: (previous, current) {
          return current.syncDialogShown && !previous.syncDialogShown;
        },
        listener: (context, state) {
          if (state.syncDialogShown) {
            _handleSyncCompletion(context);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              context.l10n.syncTitle,
              style: AppTextStyle.titleMedium,
            ),
            backgroundColor: context.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                context.router.pop();
              },
            ),
          ),
          body: GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return BlocBuilder<SyncBloc, SyncState>(
      builder: (context, syncState) {
        if (syncState.isQRScanning) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: QRScannerWidget(
              cancelButtonText: 'Cancel',
              onQRCodeDetected: (qrData) {
                _handleQRCodeDetected(context, qrData);
              },
              onCancel: () {
                context.read<SyncBloc>().add(const SyncCancel());
              },
            ),
          );
        }

        if (syncState.syncStatus == SyncStatus.syncing && syncState.isLoading) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SyncLoadingWidget(
              onCancel: () {
                context.read<SyncBloc>().add(const SyncCancel());
              },
              cancelButtonText: 'Cancel',
            ),
          );
        }

        return SyncPlaceholderWidget(
          onSyncPressed: null,
          recordTypeName: null,
        );
      },
    );
  }

  void _handleQRCodeDetected(BuildContext context, String qrData) {
    debugPrint('[QR_SCAN] Raw QR data (${qrData.length} chars): ${qrData.substring(0, qrData.length > 200 ? 200 : qrData.length)}...');

    try {
      final json = jsonDecode(qrData) as Map<String, dynamic>;
      debugPrint('[QR_SCAN] Parsed JSON keys: ${json.keys.toList()}');

      if (json.containsKey('pairing_key') && json.containsKey('device_id')) {
        debugPrint('[QR_SCAN] Detected: Desktop pairing QR');
        final pairing = DevicePairing(
          deviceId: json['device_id'] as String,
          deviceName: json['device_name'] as String,
          pairingKey: json['pairing_key'] as String,
          lastIp: json['ip'] as String,
          lastPort: json['port'] as int,
          pairedAt: DateTime.now(),
          os: json['os'] as String?,
        );

        _handleBackupPairing(context, pairing);
        return;
      }

      if (json.containsKey('token') || json.containsKey('bearer')) {
        debugPrint('[QR_SCAN] Detected: Fasten Health sync QR');
      } else {
        debugPrint('[QR_SCAN] Unknown JSON QR format, forwarding to SyncBloc');
      }
    } catch (e) {
      debugPrint('[QR_SCAN] Not valid JSON: $e');
      debugPrint('[QR_SCAN] Forwarding raw data to SyncBloc');
    }

    debugPrint('[QR_SCAN] Dispatching SyncData event');
    context.read<SyncBloc>().add(SyncData(qrData: qrData));
  }

  Future<void> _handleBackupPairing(
    BuildContext context,
    DevicePairing pairing,
  ) async {
    final pairingStorage = getIt<PairingStorageService>();

    await pairingStorage.savePairing(pairing);
    context.read<SyncBloc>().add(const SyncCancel());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.pairedWithDevice(pairing.deviceName))),
    );

    final commBloc = getIt<CommunicationBloc>();
    commBloc.add(CommunicationPairingCompleted(pairing: pairing));
  }

  Future<void> _handleSyncCompletion(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingShown = prefs.getBool('onboarding_shown') ?? false;

    await AppSimpleDialog.showSuccess(
      context: context,
      title: context.l10n.success,
      message: context.l10n.syncDataLoadedSuccessfully,
      onOkPressed: () {
        context.router.pushAndPopUntil(
          DashboardRoute(),
          predicate: (_) => false,
        );

        if (!onboardingShown) {
          Future.delayed(const Duration(milliseconds: 400), () {
            try {
              context.read<SyncBloc>().add(const TriggerTutorial());
            } catch (e) {
            }
          });
        }
      },
    );
  }
}
