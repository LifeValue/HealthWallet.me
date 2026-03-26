import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class SsdpService {
  static const _multicastAddress = '239.255.255.250';
  static const _multicastPort = 1900;
  static const _urn = 'urn:healthwallet:device:desktop:1';

  RawDatagramSocket? _socket;
  Timer? _notifyTimer;

  Future<void> startAdvertising({
    required String ip,
    required int port,
    required String deviceId,
  }) async {
    await stopAdvertising();

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _multicastPort,
      reuseAddress: true,
      reusePort: true,
    );

    _socket!.joinMulticast(InternetAddress(_multicastAddress));
    _socket!.broadcastEnabled = true;

    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        if (datagram == null) return;

        final message = utf8.decode(datagram.data);
        if (message.contains('M-SEARCH') && message.contains(_urn)) {
          _sendResponse(
            datagram.address,
            datagram.port,
            ip: ip,
            port: port,
            deviceId: deviceId,
          );
        }
      }
    });

    _sendNotify(ip: ip, port: port, deviceId: deviceId);
    _notifyTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sendNotify(ip: ip, port: port, deviceId: deviceId),
    );

    debugPrint('[SSDP] Advertising on $_multicastAddress:$_multicastPort');
  }

  Future<({String ip, int port, String deviceId})?> search({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final completer = Completer<({String ip, int port, String deviceId})?>();

    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
      reuseAddress: true,
    );

    socket.broadcastEnabled = true;

    Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(null);
        socket.close();
      }
    });

    socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram == null) return;

        final message = utf8.decode(datagram.data);
        if (message.contains(_urn) && !completer.isCompleted) {
          final result = _parseResponse(message);
          if (result != null) {
            completer.complete(result);
            socket.close();
          }
        }
      }
    });

    final searchMessage = 'M-SEARCH * HTTP/1.1\r\n'
        'HOST: $_multicastAddress:$_multicastPort\r\n'
        'MAN: "ssdp:discover"\r\n'
        'MX: 3\r\n'
        'ST: $_urn\r\n'
        '\r\n';

    socket.send(
      utf8.encode(searchMessage),
      InternetAddress(_multicastAddress),
      _multicastPort,
    );

    return completer.future;
  }

  void _sendNotify({
    required String ip,
    required int port,
    required String deviceId,
  }) {
    if (_socket == null) return;

    final notify = 'NOTIFY * HTTP/1.1\r\n'
        'HOST: $_multicastAddress:$_multicastPort\r\n'
        'NT: $_urn\r\n'
        'NTS: ssdp:alive\r\n'
        'LOCATION: tcp://$ip:$port\r\n'
        'USN: uuid:$deviceId::$_urn\r\n'
        'SERVER: HealthWallet Desktop\r\n'
        '\r\n';

    _socket!.send(
      utf8.encode(notify),
      InternetAddress(_multicastAddress),
      _multicastPort,
    );
  }

  void _sendResponse(
    InternetAddress address,
    int responsePort, {
    required String ip,
    required int port,
    required String deviceId,
  }) {
    if (_socket == null) return;

    final response = 'HTTP/1.1 200 OK\r\n'
        'ST: $_urn\r\n'
        'LOCATION: tcp://$ip:$port\r\n'
        'USN: uuid:$deviceId::$_urn\r\n'
        'SERVER: HealthWallet Desktop\r\n'
        '\r\n';

    _socket!.send(utf8.encode(response), address, responsePort);
  }

  ({String ip, int port, String deviceId})? _parseResponse(String message) {
    final locationMatch = RegExp(r'LOCATION:\s*tcp://([^:]+):(\d+)')
        .firstMatch(message);
    final usnMatch = RegExp(r'USN:\s*uuid:([^:]+)::').firstMatch(message);

    if (locationMatch == null) return null;

    return (
      ip: locationMatch.group(1)!,
      port: int.parse(locationMatch.group(2)!),
      deviceId: usnMatch?.group(1) ?? '',
    );
  }

  Future<void> stopAdvertising() async {
    _notifyTimer?.cancel();
    _notifyTimer = null;
    _socket?.close();
    _socket = null;
  }
}
