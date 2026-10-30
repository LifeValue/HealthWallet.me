import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class MdnsService {
  static const _serviceType = '_healthwallet._tcp';
  static const _serviceName = 'HealthWallet Desktop';

  /// TXT attribute carrying the pairing's discovery token, so a phone picks
  /// its own desktop among several on the network.
  static const tokenAttribute = 't';

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;

  Future<void> startAdvertising({
    required int port,
    required String token,
  }) async {
    await stopAdvertising();

    final service = BonsoirService(
      name: _serviceName,
      type: _serviceType,
      port: port,
      attributes: {tokenAttribute: token},
    );

    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.ready;
    await _broadcast!.start();

    debugPrint('[mDNS] Advertising $_serviceType on port $port');
  }

  /// The first desktop advertising [token], resolved to an address.
  Future<({String ip, int port})?> search({
    required String token,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    await stopDiscovery();
    final completer = Completer<({String ip, int port})?>();
    final discovery = BonsoirDiscovery(type: _serviceType);
    _discovery = discovery;
    await discovery.ready;

    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(null);
    });

    final sub = discovery.eventStream?.listen((event) {
      final service = event.service;
      if (service == null || completer.isCompleted) return;
      switch (event.type) {
        case BonsoirDiscoveryEventType.discoveryServiceFound:
          // Bonsoir doesn't resolve by itself: without this the host never
          // arrives. The TXT attributes may only come with the resolution
          // (Android), so the token is checked then.
          service.resolve(discovery.serviceResolver).catchError((Object e) {
            logger.w('[mDNS] resolving a service failed', e);
          });
        case BonsoirDiscoveryEventType.discoveryServiceResolved:
          if (service is! ResolvedBonsoirService) return;
          if (service.attributes[tokenAttribute] != token) return;
          final host = service.host;
          if (host != null && host.isNotEmpty) {
            completer.complete((ip: host, port: service.port));
          }
        default:
          break;
      }
    });

    await discovery.start();
    final result = await completer.future;
    timer.cancel();
    await sub?.cancel();
    await stopDiscovery();
    return result;
  }

  Future<void> stopAdvertising() async {
    await _broadcast?.stop();
    _broadcast = null;
  }

  Future<void> stopDiscovery() async {
    final discovery = _discovery;
    _discovery = null;
    if (discovery != null && !discovery.isStopped) await discovery.stop();
  }
}
