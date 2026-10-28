import 'dart:typed_data';

abstract class ReceiveModeService {
  bool get isListening;

  /// A share screen has taken over the transport (see [pauseListening]).
  bool get isPaused;
  String? get pendingInvitationId;
  String? get pendingInvitationDeviceName;

  /// The encrypted share that arrived before the share screen took over.
  Uint8List? get pendingPayload;

  Future<void> startListening();
  Future<void> stopListening();
  void pauseListening();
  Future<void> resumeListening();
  void clearPendingInvitation();
  void clearPendingPayload();
  Future<void> dispose();
}
