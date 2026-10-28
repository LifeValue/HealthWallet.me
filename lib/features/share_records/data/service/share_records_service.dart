import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:airdrop/airdrop.dart';
import 'package:flutter/foundation.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';
import 'package:health_wallet/features/share_records/data/mapper/fhir_bundle_mapper.dart';
import 'package:health_wallet/features/share_records/data/service/secure_share_session.dart';
import 'package:health_wallet/features/share_records/domain/entity/entity.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

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

  /// A key exchange over this session's message channel; one per transfer.
  SecureShareSession createSecureSession() =>
      SecureShareSession(_AirdropMessageTransport(_airdropService));

  /// Encrypts [payload] with [session] and hands the envelope to the plugin.
  Future<String?> prepareFilesForSending(
    SharePayload payload,
    SecureShareSession session,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/share_${payload.id}.bin');

    try {
      final plaintext = utf8.encode(jsonEncode(payload.toJson()));
      await tempFile.writeAsBytes(await session.seal(plaintext));

      await _airdropService.addFiles(filePaths: [tempFile.path]);

      return tempFile.path;
    } catch (e) {
      debugPrint('[TRANSFER:❌] Error preparing files: $e');
      await cleanupTempFile(tempFile.path);
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

  /// Parses a decrypted payload into a view-only session container.
  Future<EphemeralRecordsContainer?> parsePayload(Uint8List bytes) async {
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

  static const _sessionDirPrefix = 'share_session_';
  static const _payloadFilePrefix = 'share_';

  /// Deletes the decrypted attachments of a receive session.
  Future<void> deleteSessionFiles(String sessionId) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final sessionDir = Directory(
        '${tempDir.path}/$_sessionDirPrefix$sessionId',
      );
      if (await sessionDir.exists()) {
        await sessionDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('[TRANSFER] Error deleting session files: $e');
    }
  }

  /// Removes what a share left in the temp directory when the app was killed
  /// or crashed mid-session: decrypted attachments and encrypted payloads.
  /// Run at startup, before any share can be in progress.
  Future<void> sweepLeftovers() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) return;
      await for (final entity in tempDir.list(followLinks: false)) {
        final name = entity.uri.pathSegments.lastWhere(
          (segment) => segment.isNotEmpty,
          orElse: () => '',
        );
        final isSessionDir =
            entity is Directory && name.startsWith(_sessionDirPrefix);
        final isPayload =
            entity is File &&
            name.startsWith(_payloadFilePrefix) &&
            name.endsWith('.bin');
        if (isSessionDir || isPayload) {
          await entity.delete(recursive: true);
        }
      }
    } catch (e) {
      debugPrint('[TRANSFER] Error sweeping share leftovers: $e');
    }
  }

  Future<String> _createSessionTempDir(String sessionId) async {
    final tempDir = await getTemporaryDirectory();
    final sessionDir = Directory(
      '${tempDir.path}/$_sessionDirPrefix$sessionId',
    );
    if (!await sessionDir.exists()) {
      await sessionDir.create(recursive: true);
    }
    return sessionDir.path;
  }

  /// Reads a file the plugin received and deletes it.
  Future<Uint8List?> readReceivedFile(String filePath) async {
    final file = File(filePath);
    try {
      final bytes = await file.readAsBytes();
      await file.delete();
      debugPrint('[TRANSFER] Deleted temp file: $filePath');
      return bytes;
    } catch (e) {
      debugPrint('[TRANSFER] Error reading received file: $e');
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('[TRANSFER] Error deleting received file: $e');
      }
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

  Stream<int> get sessionExtendRequestStream =>
      _airdropService.sessionExtendRequestStream;

  Stream<int> get sessionExtendAcceptedStream =>
      _airdropService.sessionExtendAcceptedStream;

  Stream<void> get sessionExtendRejectedStream =>
      _airdropService.sessionExtendRejectedStream;

  Stream<void> get viewingStartedStream => _airdropService.viewingStartedStream;

  Stream<void> get invitationRejectedStream =>
      _airdropService.invitationRejectedStream;

  Stream<void> get wifiToggleNeededStream =>
      _airdropService.wifiToggleNeededStream;

  Stream<Map<String, dynamic>> get connectionHealthStream =>
      _airdropService.connectionHealthStream;
}

class _AirdropMessageTransport implements ShareMessageTransport {
  final AirdropService _airdropService;

  _AirdropMessageTransport(this._airdropService);

  @override
  Stream<Uint8List> get messages => _airdropService.sessionMessageStream;

  @override
  Future<void> send(Uint8List message) =>
      _airdropService.sendSessionMessage(message);
}
