import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:health_wallet/features/backup/data/services/mdns_service.dart';
import 'package:health_wallet/features/backup/data/services/ssdp_service.dart';
import 'package:health_wallet/features/backup/data/services/pairing_storage_service.dart';

class DiscoveryResult {
  final String ip;
  final int port;
  final String method;

  const DiscoveryResult({
    required this.ip,
    required this.port,
    required this.method,
  });
}

@lazySingleton
class DiscoveryService {
  final SsdpService _ssdpService;
  final MdnsService _mdnsService;
  final PairingStorageService _pairingStorage;

  DiscoveryService(
    this._ssdpService,
    this._mdnsService,
    this._pairingStorage,
  );

  Future<DiscoveryResult?> discover() async {
    final savedResult = await _trySavedIp();
    if (savedResult != null) return savedResult;

    final networkResult = await _tryNetworkDiscovery();
    if (networkResult != null) return networkResult;

    debugPrint('[Discovery] All methods failed');
    return null;
  }

  Future<DiscoveryResult?> _trySavedIp() async {
    final pairing = _pairingStorage.loadPairing();
    if (pairing == null) return null;

    debugPrint('[Discovery] Trying saved IP ${pairing.lastIp}:${pairing.lastPort}');

    try {
      final socket = await Socket.connect(
        pairing.lastIp,
        pairing.lastPort,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();

      debugPrint('[Discovery] Saved IP reachable');
      return DiscoveryResult(
        ip: pairing.lastIp,
        port: pairing.lastPort,
        method: 'saved-ip',
      );
    } catch (_) {
      debugPrint('[Discovery] Saved IP unreachable, trying network discovery');
      return null;
    }
  }

  Future<DiscoveryResult?> _tryNetworkDiscovery() async {
    debugPrint('[Discovery] Starting mDNS + SSDP parallel search');

    final mdnsFuture = _mdnsService.search(
      timeout: const Duration(seconds: 3),
    );
    final ssdpFuture = _ssdpService.search(
      timeout: const Duration(seconds: 3),
    );

    final results = await Future.wait([
      mdnsFuture.then((r) => r != null
          ? DiscoveryResult(ip: r.ip, port: r.port, method: 'mdns')
          : null),
      ssdpFuture.then((r) => r != null
          ? DiscoveryResult(ip: r.ip, port: r.port, method: 'ssdp')
          : null),
    ]);

    for (final result in results) {
      if (result != null) {
        debugPrint('[Discovery] Found via ${result.method}: ${result.ip}:${result.port}');
        await _pairingStorage.updateLastConnection(
          ip: result.ip,
          port: result.port,
        );
        return result;
      }
    }

    return null;
  }

  Future<void> startDesktopAdvertising({
    required String ip,
    required int port,
    required String deviceId,
  }) async {
    await _ssdpService.startAdvertising(
      ip: ip,
      port: port,
      deviceId: deviceId,
    );
    await _mdnsService.startAdvertising(port: port);
    debugPrint('[Discovery] Desktop advertising started on $ip:$port');
  }

  Future<void> stopDesktopAdvertising() async {
    await _ssdpService.stopAdvertising();
    await _mdnsService.stopAdvertising();
  }
}
