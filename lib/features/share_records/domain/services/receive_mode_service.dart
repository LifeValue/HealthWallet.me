import 'package:health_wallet/features/share_records/domain/entity/entity.dart';

abstract class ReceiveModeService {
  bool get isListening;
  String? get pendingInvitationId;
  String? get pendingInvitationDeviceName;
  EphemeralRecordsContainer? get pendingReceivedData;

  Future<void> startListening();
  Future<void> stopListening();
  void pauseListening();
  Future<void> resumeListening();
  void clearPendingInvitation();
  void clearPendingReceivedData();
}
