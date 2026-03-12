import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:airdrop/airdrop.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';
import 'package:health_wallet/features/share_records/domain/entity/entity.dart';
import 'package:health_wallet/features/share_records/data/mapper/fhir_bundle_mapper.dart';

@lazySingleton
class ShareRecordsService {
  final AirdropService _airdropService = AirdropService();

  Stream<TransferProgress> get progressStream => _airdropService.progressStream;
  Stream<TransferStatus> get statusStream => _airdropService.statusStream;
  Stream<Map<String, dynamic>> get peerDiscoveryStream =>
      _airdropService.peerDiscoveryStream;
  Stream<Map<String, dynamic>> get invitationStream =>
      _airdropService.invitationStream;
  Stream<ReceivedData> get receivedDataStream =>
      _airdropService.receivedDataStream;

  Stream<List<String>> get receivedFilesStream =>
      _airdropService.receivedFilesStream;

  Future<void> startDiscovery({bool useBluetooth = true}) async {
    await _airdropService.startDiscovery(useBluetooth: useBluetooth);
  }

  Future<void> selectPeer(String deviceId) async {
    await _airdropService.selectDevice(deviceId: deviceId);
  }

  Future<String?> prepareFilesForSending(SharePayload payload) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/share_${payload.id}.json');

    try {
      final jsonString = jsonEncode(payload.toJson());
      await tempFile.writeAsString(jsonString);

      await _airdropService.addFiles(filePaths: [tempFile.path]);

      return tempFile.path;
    } catch (e) {
      debugPrint('[TRANSFER:❌] Error preparing files: $e');
      return null;
    }
  }

  Future<void> cleanupTempFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[TRANSFER:❌] Error cleaning up temp file: $e');
    }
  }

  Future<SharePayload> createPayload({
    required List<IFhirResource> resources,
    required String deviceName,
    int expiresInSeconds = 300,
    Map<String, List<RecordNote>> notesMap = const {},
    List<String> activeFilters = const [],
  }) {
    return FhirBundleMapper.toSharePayload(
      records: resources,
      deviceName: deviceName,
      expiresInSeconds: expiresInSeconds,
      notesMap: notesMap,
      activeFilters: activeFilters,
    );
  }

  Future<EphemeralRecordsContainer?> _parsePayloadBytes(Uint8List bytes) async {
    try {
      final jsonString = utf8.decode(bytes);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final payload = SharePayload.fromJson(json);

      final sessionTempDir = await _createSessionTempDir(payload.id);
      final result = await FhirBundleMapper.parseBundle(
        payload.bundle,
        tempDir: sessionTempDir,
      );

      return EphemeralRecordsContainer(
        sessionId: payload.id,
        senderDeviceName: payload.senderDeviceName,
        receivedAt: DateTime.now(),
        viewDuration: Duration(seconds: payload.expiresInSeconds),
        records: result.resources,
        isExpired: false,
        notes: result.notes,
        tempAttachmentPaths: result.tempFilePaths,
        activeFilters: payload.activeFilters,
      );
    } catch (e) {
      debugPrint('[TRANSFER] Error parsing payload: $e');
      return null;
    }
  }

  Future<String> _createSessionTempDir(String sessionId) async {
    final tempDir = await getTemporaryDirectory();
    final sessionDir = Directory('${tempDir.path}/share_session_$sessionId');
    if (!await sessionDir.exists()) {
      await sessionDir.create(recursive: true);
    }
    return sessionDir.path;
  }

  Future<EphemeralRecordsContainer?> parseReceivedData(ReceivedData receivedData) {
    return _parsePayloadBytes(receivedData.data);
  }

  Future<EphemeralRecordsContainer?> parseReceivedFile(String filePath) async {
    final file = File(filePath);
    try {
      final bytes = await file.readAsBytes();
      await file.delete();
      debugPrint('[TRANSFER] Deleted temp file: $filePath');
      return _parsePayloadBytes(bytes);
    } catch (e) {
      debugPrint('[TRANSFER] Error parsing received file: $e');
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      return null;
    }
  }

  static PeerType get localPeerType {
    if (Platform.isAndroid) return PeerType.android;
    if (Platform.isIOS) return PeerType.ios;
    return PeerType.android;
  }

  Future<void> startReceivingInMemory() async {
    final peer = localPeerType;
    await _airdropService.receiveDataInMemory(
      peer: peer,
      useBluetooth: true,
    );
  }

  Future<void> startSymmetricDiscovery() async {
    await _airdropService.startSymmetricDiscovery();
  }

  Future<void> acceptInvitation(String invitationId) async {
    await _airdropService.acceptInvitation(invitationId: invitationId);
  }

  Future<void> rejectInvitation(String invitationId) async {
    await _airdropService.rejectInvitation(invitationId: invitationId);
  }

  Future<void> disconnect() async {
    await _airdropService.disconnect();
  }

  Future<void> cancelTransfer() async {
    await _airdropService.cancelTransfer();
  }

  Future<void> startReady({bool useBluetooth = true}) async {
    await _airdropService.startReady(useBluetooth: useBluetooth);
  }

  Future<void> sendKillSignal() async {
    await _airdropService.sendKillSignal();
  }

  Future<void> sendExtendRequest({required int durationSeconds}) async {
    await _airdropService.sendExtendRequest(durationSeconds: durationSeconds);
  }

  Future<void> sendExtendAccepted({required int durationSeconds}) async {
    await _airdropService.sendExtendAccepted(durationSeconds: durationSeconds);
  }

  Future<void> sendExtendRejected() async {
    await _airdropService.sendExtendRejected();
  }

  Future<void> sendViewingStarted() async {
    await _airdropService.sendViewingStarted();
  }

  Stream<void> get killSignalStream => _airdropService.killSignalStream;

  Stream<void> get sessionEndedStream => _airdropService.sessionEndedStream;

  Stream<int> get sessionExtendRequestStream => _airdropService.sessionExtendRequestStream;

  Stream<int> get sessionExtendAcceptedStream => _airdropService.sessionExtendAcceptedStream;

  Stream<void> get sessionExtendRejectedStream => _airdropService.sessionExtendRejectedStream;

  Stream<void> get viewingStartedStream => _airdropService.viewingStartedStream;

  Stream<void> get invitationRejectedStream => _airdropService.invitationRejectedStream;

  Stream<void> get wifiToggleNeededStream => _airdropService.wifiToggleNeededStream;

  Stream<Map<String, dynamic>> get connectionHealthStream => _airdropService.connectionHealthStream;
}
