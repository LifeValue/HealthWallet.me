import 'package:airdrop/airdrop.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/share_records/domain/entity/entity.dart';

part 'share_records_state.freezed.dart';

enum ShareMode {
  idle,
  sending,
  receiving,
}

enum SharePhase {
  selectingRecords,
  discoveringPeers,
  connecting,
  transferring,
  monitoringSession,
  viewingRecords,
  sessionEnded,
  error,
}

@freezed
class ShareRecordsState with _$ShareRecordsState {
  const ShareRecordsState._();

  const factory ShareRecordsState({
    @Default(ShareMode.idle) ShareMode mode,
    @Default(SharePhase.discoveringPeers) SharePhase phase,
    @Default(ShareSelection()) ShareSelection selection,
    @Default([]) List<PeerDevice> discoveredPeers,
    PeerDevice? selectedPeer,
    TransferProgress? transferProgress,
    EphemeralRecordsContainer? receivedData,
    Duration? viewingTimeRemaining,
    @Default(false) bool isSessionActive,
    @Default(false) bool isDataDestroyed,
    String? pendingInvitationId,
    String? pendingInvitationDeviceName,
    String? errorMessage,
    String? statusMessage,
    @Default(false) bool showSettingsDialog,
    @Default(false) bool showExitConfirmationDialog,
    String? connectionMethod,
    @Default(0) int connectionRetryCount,
    String? connectionHealthStatus,
    @Default(false) bool wifiToggleNeeded,
    @Default(Duration(minutes: 30)) Duration defaultViewingDuration,
    @Default(Duration(minutes: 30)) Duration selectedViewingDuration,
    DateTime? sessionStartedAt,
    @Default(0) int extensionsUsed,
    @Default(5) int maxExtensions,
    int? pendingExtendDurationSeconds,
    @Default(false) bool extensionRequestPending,
    @Default([]) List<FhirType> appliedFilters,
  }) = _ShareRecordsState;

  factory ShareRecordsState.initial() => const ShareRecordsState();

  bool get isSending => mode == ShareMode.sending;

  bool get isReceiving => mode == ShareMode.receiving;

  bool get isTransferring => phase == SharePhase.transferring;

  bool get isViewing => phase == SharePhase.viewingRecords;

  bool get hasError => phase == SharePhase.error;

  bool get hasPendingInvitation => pendingInvitationId != null;

  bool get canRequestExtension =>
      extensionsUsed < maxExtensions &&
      isSessionActive &&
      !extensionRequestPending;

  int get selectedCount => selection.selectedRecords.length;

  int get receivedCount => receivedData?.recordCount ?? 0;

  bool get isDefaultDuration => selectedViewingDuration == defaultViewingDuration;

  double get progressPercentage {
    if (transferProgress == null) return 0.0;
    if (transferProgress!.totalBytes == 0) return 0.0;
    return transferProgress!.bytesTransferred / transferProgress!.totalBytes;
  }
}
