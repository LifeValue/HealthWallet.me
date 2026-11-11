// Fakes for driving CommunicationBloc on either side without a network. Not
// a test file itself.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/data/services/discovery_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/pairing_storage_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/communication_service.dart';

import '../../../desktop_test_fakes.dart';

/// [FakeTcpService] with what the bloc uses on the phone and the desktop.
/// Starts with no link.
class BlocTcpService extends FakeTcpService {
  BlocTcpService() {
    state = ConnectionState.disconnected;
  }

  final _approvals = StreamController<PendingApproval?>.broadcast();
  final _approved = StreamController<PeerInfo>.broadcast();
  final failures = StreamController<LinkFailure>.broadcast();

  /// Every address the phone tried, as `ip:port`.
  final connectAttempts = <String>[];

  /// Answers a connection attempt: completes once the desktop accepted,
  /// throws as the real service does. By default nothing listens there.
  Future<void> Function(String ip, int port)? onConnect;

  /// Answers the handshake over MPC; by default the Mac never shows up.
  Future<void> Function()? onConnectOverMpc;

  int mpcHandshakes = 0;
  int mpcCancels = 0;
  final disconnectReasons = <String>[];

  /// Desktop: the server's port, or why it doesn't start.
  int serverPort = 50123;
  Exception? startServerError;
  final serverStarts = <({List<String> keys, int port})>[];
  List<String>? serverKeys;
  int approvals = 0;
  int declines = 0;
  int? keyIndex;
  LinkTransport linkTransport = LinkTransport.tcp;

  /// Why the desktop ended the last session, and why the phone's ended.
  String? closeReason;
  LinkFailure? clientFailure;

  @override
  String? get lastPeerCloseReason => closeReason;

  @override
  LinkFailure? get lastClientFailure => clientFailure;

  @override
  Stream<PendingApproval?> get approvalRequests => _approvals.stream;

  @override
  Stream<PeerInfo> get peerApproved => _approved.stream;

  @override
  Stream<LinkFailure> get serverFailures => failures.stream;

  @override
  void attachMpc(CommunicationService? transport, {required bool asServer}) {}

  @override
  LinkTransport? get transport => isConnected ? linkTransport : null;

  @override
  int? get activeKeyIndex => keyIndex;

  @override
  Future<void> connectToServer({
    required String ip,
    required int port,
    required String pairingKey,
    required String expectedDeviceId,
    required String localDeviceId,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    connectAttempts.add('$ip:$port');
    final answer = onConnect;
    if (answer == null) {
      throw const SocketException('Connection refused');
    }
    await answer(ip, port);
  }

  @override
  Future<void> connectOverMpc({
    required String pairingKey,
    required String expectedDeviceId,
    required String localDeviceId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    mpcHandshakes++;
    final answer = onConnectOverMpc;
    if (answer == null) {
      throw const LinkException(LinkFailure.noAnswer, 'MPC not connected');
    }
    await answer();
  }

  @override
  void cancelMpcClient() => mpcCancels++;

  @override
  Future<void> disconnect({String reason = 'user'}) async {
    disconnectReasons.add(reason);
    await super.disconnect(reason: reason);
  }

  @override
  Future<int> startServer({
    required List<String> pairingKeys,
    required String deviceId,
    required String deviceName,
    required String? pairedPeerId,
    int port = TcpService.defaultPort,
  }) async {
    serverStarts.add((keys: pairingKeys, port: port));
    final error = startServerError;
    if (error != null) throw error;
    serverKeys = pairingKeys;
    return serverPort;
  }

  @override
  void updateServerKeys(List<String> pairingKeys) => serverKeys = pairingKeys;

  @override
  void approvePending() => approvals++;

  @override
  void declinePending() => declines++;

  void requestApproval(PendingApproval? request) => _approvals.add(request);

  void approve(PeerInfo peer) => _approved.add(peer);

  @override
  Future<void> close() async {
    await _approvals.close();
    await _approved.close();
    await failures.close();
    await super.close();
  }
}

/// Pairing storage in memory.
class FakePairingStorage extends Fake implements PairingStorageService {
  FakePairingStorage([this.stored]);

  DevicePairing? stored;
  final saved = <DevicePairing>[];

  /// Addresses saved after a handshake passed there, as `ip:port`.
  final lastConnections = <String>[];

  Future<String> Function() localId = () async => 'phone-1';

  @override
  Future<DevicePairing?> load() async => stored;

  @override
  Future<void> savePairing(DevicePairing pairing) async {
    stored = pairing;
    saved.add(pairing);
  }

  @override
  Future<String> localDeviceId() => localId();

  @override
  Future<void> updateLastConnection({
    required String ip,
    required int port,
  }) async => lastConnections.add('$ip:$port');
}

/// Network discovery that answers what the test says.
class FakeDiscovery extends Fake implements DiscoveryService {
  /// What a search finds; by default nothing.
  Future<List<DiscoveryResult>> Function() onSearch = () async => const [];
  int searches = 0;
  final advertised = <({String? ip, int port, String token})>[];

  @override
  Future<List<DiscoveryResult>> discoverViaNetwork({
    required String deviceId,
    required String token,
  }) {
    searches++;
    return onSearch();
  }

  @override
  Future<void> startDesktopAdvertising({
    required String? ip,
    required int port,
    required String deviceId,
    required String token,
  }) async => advertised.add((ip: ip, port: port, token: token));
}

/// MPC as the bloc sees it; [connect] is scripted by the test.
class FakeMpc implements CommunicationService {
  final _states = StreamController<CommunicationState>.broadcast();

  /// Answers the phone starting to browse for the Mac.
  Future<void> Function() onConnect = () async {};
  int connects = 0;
  int disconnects = 0;
  final serverStarts = <({int port, String? token})>[];

  @override
  TransportType get transportType => TransportType.multipeerConnectivity;

  @override
  CommunicationState get currentState => CommunicationState.disconnected;

  @override
  Stream<CommunicationState> get stateStream => _states.stream;

  @override
  Stream<Uint8List> get dataStream => const Stream.empty();

  @override
  Future<void> startServer({required int port, String? token}) async =>
      serverStarts.add((port: port, token: token));

  @override
  Future<void> connect({
    required String address,
    required int port,
    String? token,
  }) {
    connects++;
    return onConnect();
  }

  @override
  Future<void> send(Uint8List data) async {}

  @override
  Future<void> disconnect() async {
    disconnects++;
    final error = disconnectError;
    if (error != null) throw error;
  }

  /// Why stopping fails, e.g. a platform call that errors.
  Exception? disconnectError;

  @override
  Future<void> dispose() => _states.close();

  void emitState(CommunicationState state) => _states.add(state);
}

/// A desktop the phone paired with, last seen at 10.0.0.2:49152.
DevicePairing pairedDesktop() => DevicePairing.generate(
  deviceName: 'Desk',
  localIp: '10.0.0.2',
);

DiscoveryResult found(String ip, int port) =>
    DiscoveryResult(ip: ip, port: port, method: 'mdns');

/// A network interface with one IPv4 address.
class FakeInterface extends Fake implements NetworkInterface {
  FakeInterface(this.name, String address)
    : addresses = [_FakeAddress(address)];

  @override
  final String name;

  @override
  final List<InterfaceAddress> addresses;
}

class _FakeAddress extends Fake implements InterfaceAddress {
  _FakeAddress(this.address);

  @override
  final String address;

  @override
  bool get isLoopback => false;

  @override
  bool get isLinkLocal => false;
}
