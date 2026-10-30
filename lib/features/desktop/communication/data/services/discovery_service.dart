import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/desktop/communication/data/services/mdns_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/ssdp_service.dart';
import 'package:injectable/injectable.dart';

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

  DiscoveryService(this._ssdpService, this._mdnsService);

  /// SSDP multicast needs an entitlement Apple grants on request; iPhones
  /// find the desktop through Bonjour (and MPC) instead.
  static bool get _ssdpAvailable => !Platform.isIOS;

  /// Addresses where the paired desktop may be listening, Bonjour first. They
  /// are only candidates: the handshake proves which one is the desktop, and
  /// only an address that passed it is saved.
  Future<List<DiscoveryResult>> discoverViaNetwork({
    required String deviceId,
    required String token,
  }) async {
    debugPrint('[Discovery] mDNS + SSDP search');

    Future<DiscoveryResult?> mdns() async {
      try {
        final r = await _mdnsService.search(token: token);
        return r == null
            ? null
            : DiscoveryResult(ip: r.ip, port: r.port, method: 'mdns');
      } catch (e) {
        logger.w('[Discovery] mDNS search failed', e);
        return null;
      }
    }

    Future<DiscoveryResult?> ssdp() async {
      if (!_ssdpAvailable) return null;
      try {
        final r = await _ssdpService.search(
          timeout: const Duration(seconds: 3),
          expectedDeviceId: deviceId,
        );
        return r == null
            ? null
            : DiscoveryResult(ip: r.ip, port: r.port, method: 'ssdp');
      } catch (e) {
        logger.w('[Discovery] SSDP search failed', e);
        return null;
      }
    }

    final results = await Future.wait([mdns(), ssdp()]);
    final seen = <String>{};
    return [
      for (final r in results)
        if (r != null && seen.add('${r.ip}:${r.port}')) r,
    ];
  }

  Future<void> startDesktopAdvertising({
    required String? ip,
    required int port,
    required String deviceId,
    required String token,
  }) async {
    if (ip != null) {
      try {
        await _ssdpService.startAdvertising(
          ip: ip,
          port: port,
          deviceId: deviceId,
        );
      } catch (e) {
        logger.w('[Discovery] SSDP advertising failed', e);
      }
    }
    try {
      await _mdnsService.startAdvertising(port: port, token: token);
    } catch (e) {
      logger.w('[Discovery] mDNS advertising failed', e);
    }
    debugPrint('[Discovery] Desktop advertising on port $port');
  }

  Future<void> stopDesktopAdvertising() async {
    await _ssdpService.stopAdvertising();
    await _mdnsService.stopAdvertising();
  }
}
