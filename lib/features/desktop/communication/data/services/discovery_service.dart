import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:health_wallet/features/desktop/communication/data/services/mdns_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/ssdp_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/pairing_storage_service.dart';

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

  Future<DiscoveryResult?> discoverViaNetwork() async {
    return _tryNetworkDiscovery();
  }

  Future<DiscoveryResult?> _trySavedIp() async {
    final pairing = _pairingStorage.loadPairing();
    if (pairing == null) return null;

    debugPrint('[Discovery] Using saved IP ${pairing.lastIp}:${pairing.lastPort}');
    return DiscoveryResult(
      ip: pairing.lastIp,
      port: pairing.lastPort,
      method: 'saved-ip',
    );
  }

  Future<DiscoveryResult?> _tryNetworkDiscovery() async {
    debugPrint('[Discovery] Starting mDNS + SSDP parallel search');

    final pairing = _pairingStorage.loadPairing();
    final expectedDeviceId = pairing?.deviceId;

    Future<DiscoveryResult?> safeMdns() async {
      try {
        final r = await _mdnsService.search(timeout: const Duration(seconds: 3));
        return r != null ? DiscoveryResult(ip: r.ip, port: r.port, method: 'mdns') : null;
      } catch (_) {
        return null;
      }
    }

    Future<DiscoveryResult?> safeSsdp() async {
      try {
        final r = await _ssdpService.search(
          timeout: const Duration(seconds: 3),
          expectedDeviceId: expectedDeviceId,
        );
        return r != null ? DiscoveryResult(ip: r.ip, port: r.port, method: 'ssdp') : null;
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([safeMdns(), safeSsdp()]);

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
    try {
      await _ssdpService.startAdvertising(
        ip: ip,
        port: port,
        deviceId: deviceId,
      );
    } catch (e) {
      debugPrint('[Discovery] SSDP advertising failed (non-fatal): $e');
    }
    await _mdnsService.startAdvertising(port: port);
    debugPrint('[Discovery] Desktop advertising started on $ip:$port');
  }

  Future<void> stopDesktopAdvertising() async {
    await _ssdpService.stopAdvertising();
    await _mdnsService.stopAdvertising();
  }
}
