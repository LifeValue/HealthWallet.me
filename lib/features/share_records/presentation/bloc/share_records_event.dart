import 'package:airdrop/airdrop.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/share_records/domain/entity/entity.dart';

part 'share_records_event.freezed.dart';

@freezed
sealed class ShareRecordsEvent with _$ShareRecordsEvent {
  const factory ShareRecordsEvent.initialized() = ShareRecordsInitialized;

  const factory ShareRecordsEvent.disposed() = ShareRecordsDisposed;

  const factory ShareRecordsEvent.sendModeSelected() = SendModeSelected;

  const factory ShareRecordsEvent.receiveModeSelected() = ReceiveModeSelected;

  const factory ShareRecordsEvent.modeCleared() = ModeCleared;

  const factory ShareRecordsEvent.recordToggled(IFhirResource resource) =
      RecordToggled;

  const factory ShareRecordsEvent.allRecordsSelected(
      List<IFhirResource> resources) = AllRecordsSelected;

  const factory ShareRecordsEvent.allRecordsDeselected() = AllRecordsDeselected;

  const factory ShareRecordsEvent.selectionConfirmed() = SelectionConfirmed;

  const factory ShareRecordsEvent.viewingDurationChanged(Duration duration) =
      ViewingDurationChanged;

  const factory ShareRecordsEvent.defaultViewingDurationSet() =
      DefaultViewingDurationSet;

  const factory ShareRecordsEvent.discoveryStarted({
    @Default(true) bool useBluetooth,
  }) = DiscoveryStarted;

  const factory ShareRecordsEvent.symmetricDiscoveryStarted() =
      SymmetricDiscoveryStarted;

  const factory ShareRecordsEvent.peerDiscovered(PeerDevice peer) =
      PeerDiscovered;

  const factory ShareRecordsEvent.peerSelected(String deviceId) = PeerSelected;

  const factory ShareRecordsEvent.transferStarted() = TransferStarted;

  const factory ShareRecordsEvent.transferProgressUpdated(
      TransferProgress progress) = TransferProgressUpdated;

  const factory ShareRecordsEvent.transferCompleted() = TransferCompleted;

  const factory ShareRecordsEvent.transferFailed(String error) = TransferFailed;

  const factory ShareRecordsEvent.transferCancelled() = TransferCancelled;

  const factory ShareRecordsEvent.connectionRetried() = ConnectionRetried;

  const factory ShareRecordsEvent.invitationReceived({
    required String invitationId,
    required String deviceName,
  }) = InvitationReceived;

  const factory ShareRecordsEvent.invitationAccepted(String invitationId) =
      InvitationAccepted;

  const factory ShareRecordsEvent.invitationRejected(String invitationId) =
      InvitationRejected;

  const factory ShareRecordsEvent.dataReceived(ReceivedData data) = DataReceived;

  const factory ShareRecordsEvent.filesReceived(List<String> filePaths) =
      FilesReceived;

  const factory ShareRecordsEvent.ephemeralDataParsed(
      EphemeralRecordsContainer container) = EphemeralDataParsed;

  const factory ShareRecordsEvent.sessionEndRequested() = SessionEndRequested;

  const factory ShareRecordsEvent.continueViewing() = ContinueViewing;

  const factory ShareRecordsEvent.appBackgrounded() = AppBackgrounded;

  const factory ShareRecordsEvent.navigationExitDetected() =
      NavigationExitDetected;

  const factory ShareRecordsEvent.dataDestructionConfirmed() =
      DataDestructionConfirmed;

  const factory ShareRecordsEvent.dataDestroyed() = DataDestroyed;

  const factory ShareRecordsEvent.timerTicked() = TimerTicked;

  const factory ShareRecordsEvent.killSessionRequested() = KillSessionRequested;

  const factory ShareRecordsEvent.remoteSessionKilled() = RemoteSessionKilled;

  const factory ShareRecordsEvent.receiverInitializedWithInvitation({
    required String invitationId,
    required String deviceName,
    @Default(false) bool preAccepted,
  }) = ReceiverInitializedWithInvitation;

  const factory ShareRecordsEvent.receiverInitializedWithData() =
      ReceiverInitializedWithData;

  const factory ShareRecordsEvent.sessionExtendRequested(int durationSeconds) =
      SessionExtendRequested;

  const factory ShareRecordsEvent.remoteExtendRequest(int durationSeconds) =
      RemoteExtendRequest;

  const factory ShareRecordsEvent.extendAccepted(int durationSeconds) =
      ExtendAccepted;

  const factory ShareRecordsEvent.extendRejected() = ExtendRejected;

  const factory ShareRecordsEvent.remoteExtendAccepted(int durationSeconds) =
      RemoteExtendAccepted;

  const factory ShareRecordsEvent.remoteExtendRejected() = RemoteExtendRejected;

  const factory ShareRecordsEvent.viewingStartedReceived() = ViewingStartedReceived;

  const factory ShareRecordsEvent.remoteInvitationRejected() = RemoteInvitationRejected;

  const factory ShareRecordsEvent.filtersApplied(List<FhirType> filters) = ShareFiltersApplied;

  const factory ShareRecordsEvent.wifiToggleRequested() = WifiToggleRequested;

  const factory ShareRecordsEvent.connectionHealthUpdated(Map<String, dynamic> health) = ConnectionHealthUpdated;
}
