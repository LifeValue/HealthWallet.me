import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:airdrop/airdrop.dart';
import 'package:flutter/material.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/features/share_records/data/crypto/share_crypto.dart';
import 'package:health_wallet/features/share_records/data/service/share_records_service.dart';
import 'package:health_wallet/features/share_records/domain/services/receive_mode_service.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:injectable/injectable.dart';

@Singleton(as: ReceiveModeService)
class ReceiveModeManager implements ReceiveModeService {
  final ShareRecordsService _shareRecordsService;

  StreamSubscription<Map<String, dynamic>>? _invitationSubscription;
  StreamSubscription<ReceivedData>? _receivedDataSubscription;
  StreamSubscription<List<String>>? _receivedFilesSubscription;
  bool _isListening = false;
  bool _isRestarting = false;

  String? _pendingInvitationId;
  String? _pendingInvitationDeviceName;

  Uint8List? _pendingPayload;

  ReceiveModeManager(this._shareRecordsService);

  @override
  bool get isListening => _isListening;

  @override
  String? get pendingInvitationId => _pendingInvitationId;
  @override
  String? get pendingInvitationDeviceName => _pendingInvitationDeviceName;
  @override
  Uint8List? get pendingPayload => _pendingPayload;

  @override
  void clearPendingInvitation() {
    _pendingInvitationId = null;
    _pendingInvitationDeviceName = null;
  }

  @override
  void clearPendingPayload() {
    _pendingPayload = null;
  }

  @override
  Future<void> startListening() async {
    if (_isListening) {
      debugPrint('[ReceiveMode] Already listening, skipping start');
      return;
    }

    _isListening = true;

    try {
      debugPrint('[ReceiveMode] Starting background listener...');

      try {
        await _shareRecordsService.disconnect();
      } catch (e) {
        debugPrint('[ReceiveMode] Pre-start cleanup failed (non-fatal): $e');
      }

      await _shareRecordsService.startSymmetricDiscovery();

      _subscribeToInvitations();
      _subscribeToReceivedData();

      debugPrint('[ReceiveMode] Background listener started');
    } catch (e) {
      debugPrint('[ReceiveMode] Error starting listener: $e');
      _isListening = false;
    }
  }

  @override
  Future<void> stopListening() async {
    if (!_isListening) {
      debugPrint('[ReceiveMode] Not listening, skipping stop');
      return;
    }

    try {
      debugPrint('[ReceiveMode] Stopping background listener...');
      await _invitationSubscription?.cancel();
      _invitationSubscription = null;
      await _receivedDataSubscription?.cancel();
      _receivedDataSubscription = null;
      await _receivedFilesSubscription?.cancel();
      _receivedFilesSubscription = null;

      await _shareRecordsService.disconnect();
      _isListening = false;
      clearPendingInvitation();
      clearPendingPayload();

      debugPrint('[ReceiveMode] Background listener stopped');
    } catch (e) {
      debugPrint('[ReceiveMode] Error stopping listener: $e');
    }
  }

  @override
  void pauseListening() {
    _invitationSubscription?.cancel();
    _invitationSubscription = null;
    _receivedDataSubscription?.cancel();
    _receivedDataSubscription = null;
    _receivedFilesSubscription?.cancel();
    _receivedFilesSubscription = null;
    debugPrint('[ReceiveMode] Paused all listening (bloc took over)');
  }

  @override
  Future<void> resumeListening() async {
    if (!_isListening) return;
    unawaited(_invitationSubscription?.cancel());
    unawaited(_receivedDataSubscription?.cancel());
    unawaited(_receivedFilesSubscription?.cancel());

    try {
      await _shareRecordsService.startSymmetricDiscovery();
    } catch (e) {
      debugPrint('[ReceiveMode] Failed to restart native receiver: $e');
    }

    _subscribeToInvitations();
    _subscribeToReceivedData();
    debugPrint('[ReceiveMode] Resumed all listening (native restarted)');
  }

  void _subscribeToInvitations() {
    _invitationSubscription = _shareRecordsService.invitationStream.listen((
      invitation,
    ) {
      debugPrint('[ReceiveMode] Invitation received: $invitation');
      _showInvitationNotification(invitation);
    });
  }

  void _subscribeToReceivedData() {
    _receivedDataSubscription = _shareRecordsService.receivedDataStream.listen((
      data,
    ) {
      debugPrint('[ReceiveMode] Data received in background');
      _handleReceivedData(data);
    });

    _receivedFilesSubscription = _shareRecordsService.receivedFilesStream.listen((
      filePaths,
    ) {
      debugPrint(
        '[ReceiveMode] Files received in background: ${filePaths.length} files',
      );
      _handleReceivedFiles(filePaths);
    });
  }

  // The share screen decrypts the payload, since the users have to compare
  // the verification code there.
  void _handleReceivedData(ReceivedData data) {
    if (ShareEnvelope.looksLikeEnvelope(data.data)) {
      _onPayloadReceived(data.data);
    } else {
      debugPrint('[ReceiveMode] Ignoring data that is not a share envelope');
    }
  }

  Future<void> _handleReceivedFiles(List<String> filePaths) async {
    for (final filePath in filePaths) {
      final bytes = await _shareRecordsService.readReceivedFile(filePath);
      if (bytes != null && ShareEnvelope.looksLikeEnvelope(bytes)) {
        _onPayloadReceived(bytes);
        return;
      }
    }
  }

  void _onPayloadReceived(Uint8List payload) {
    _pendingPayload = payload;

    if (_pendingInvitationId != null) {
      debugPrint(
        '[ReceiveMode] Data arrived while invitation pending, stored for BLoC',
      );
      return;
    }

    debugPrint('[ReceiveMode] Auto-navigating to the share screen');
    final router = getIt<AppRouter>();
    router.push(ShareRecordsRoute(hasReceivedData: true));
  }

  void _showInvitationNotification(Map<String, dynamic> invitation) {
    final deviceName =
        invitation['senderDeviceName'] as String? ??
        invitation['deviceName'] as String? ??
        'Unknown Device';
    final invitationId = invitation['invitationId'] as String? ?? '';

    debugPrint('[ReceiveMode] Invitation from: $deviceName');

    if (_pendingInvitationId != null) {
      debugPrint(
        '[ReceiveMode] Already handling an invitation, skipping duplicate',
      );
      return;
    }

    _pendingInvitationId = invitationId;
    _pendingInvitationDeviceName = deviceName;

    if (_pendingPayload != null) {
      debugPrint('[ReceiveMode] Data already received, skipping dialog');
      return;
    }

    _showInvitationDialog(invitationId, deviceName);
  }

  void _showInvitationDialog(String invitationId, String deviceName) {
    final router = getIt<AppRouter>();
    final context = router.navigatorKey.currentContext;

    if (context == null) {
      debugPrint('[ReceiveMode] No context for dialog, navigating directly');
      router.push(
        ShareRecordsRoute(
          pendingInvitationId: invitationId,
          pendingInvitationDeviceName: deviceName,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final textColor = dialogContext.isDarkMode
            ? AppColors.textPrimaryDark
            : AppColors.textPrimary;
        final borderColor = dialogContext.isDarkMode
            ? AppColors.borderDark
            : AppColors.border;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(Insets.normal),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: dialogContext.dialogWidth),
              child: Container(
                decoration: BoxDecoration(
                  color: dialogContext.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Insets.normal),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Incoming Health Records',
                        style: AppTextStyle.titleSmall.copyWith(
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: Insets.small),
                      Text(
                        '$deviceName wants to share health records with you',
                        style: AppTextStyle.bodyMedium.copyWith(
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: Insets.normal),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Assets.icons.information.svg(
                              width: 20,
                              height: 20,
                              colorFilter: const ColorFilter.mode(
                                AppColors.warning,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Records will be view-only and automatically deleted when you exit',
                                style: AppTextStyle.labelLarge.copyWith(
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Insets.normal),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () async {
                                Navigator.of(dialogContext).pop();
                                await _shareRecordsService.rejectInvitation(
                                  invitationId,
                                );
                                clearPendingInvitation();

                                await Future.delayed(
                                  const Duration(seconds: 4),
                                );
                                if (_isListening && !_isRestarting) {
                                  _isRestarting = true;
                                  debugPrint(
                                    '[ReceiveMode] Restarting discovery after rejection',
                                  );
                                  try {
                                    await _shareRecordsService
                                        .startSymmetricDiscovery();
                                  } finally {
                                    _isRestarting = false;
                                  }
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.all(8),
                                fixedSize: const Size.fromHeight(36),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: Text(
                                'Decline',
                                style: AppTextStyle.buttonSmall.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                                router.push(
                                  ShareRecordsRoute(
                                    pendingInvitationId: invitationId,
                                    pendingInvitationDeviceName: deviceName,
                                    invitationPreAccepted: true,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(8),
                                fixedSize: const Size.fromHeight(36),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Accept',
                                style: AppTextStyle.buttonSmall.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  @disposeMethod
  Future<void> dispose() async {
    await stopListening();
  }
}
