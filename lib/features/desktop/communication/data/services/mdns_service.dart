import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class MdnsService {
  static const _serviceType = '_healthwallet._tcp';
  static const _serviceName = 'HealthWallet Desktop';

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;

  Future<void> startAdvertising({
    required int port,
  }) async {
    await stopAdvertising();

    final service = BonsoirService(
      name: _serviceName,
      type: _serviceType,
      port: port,
    );

    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.ready;
    await _broadcast!.start();

    debugPrint('[mDNS] Advertising $_serviceType on port $port');
  }

  Future<({String ip, int port})?> search({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final completer = Completer<({String ip, int port})?>();

    _discovery = BonsoirDiscovery(type: _serviceType);
    await _discovery!.ready;

    Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(null);
        _discovery?.stop();
      }
    });

    _discovery!.eventStream?.listen((event) {
      if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved) {
        final service = event.service;
        if (service == null || completer.isCompleted) return;

        final resolved = service as ResolvedBonsoirService;
        final ip = resolved.host;
        if (ip != null) {
          completer.complete((ip: ip, port: resolved.port));
          _discovery?.stop();
        }
      }
    });

    await _discovery!.start();

    return completer.future;
  }

  Future<void> stopAdvertising() async {
    await _broadcast?.stop();
    _broadcast = null;
  }

  Future<void> stopDiscovery() async {
    await _discovery?.stop();
    _discovery = null;
  }
}
