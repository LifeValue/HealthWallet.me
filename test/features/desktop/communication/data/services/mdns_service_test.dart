import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/mdns_service.dart';

import '../../../../../helpers/log_capture.dart';

/// Bonjour as the plugin reports it, without a network: what [start] finds
/// is scripted by the test.
class _FakeBonsoir extends BonsoirPlatformInterface {
  final discoveries = <_FakeDiscovery>[];
  final broadcasts = <_FakeBroadcast>[];

  /// Runs when a discovery starts, to report what it finds.
  void Function(_FakeDiscovery discovery)? onDiscoveryStarted;

  @override
  BonsoirAction<BonsoirBroadcastEvent> createBroadcastAction(
    BonsoirService service, {
    bool printLogs = false,
  }) {
    final broadcast = _FakeBroadcast(service);
    broadcasts.add(broadcast);
    return broadcast;
  }

  @override
  BonsoirAction<BonsoirDiscoveryEvent> createDiscoveryAction(
    String type, {
    bool printLogs = false,
  }) {
    final discovery = _FakeDiscovery(type, this);
    discoveries.add(discovery);
    return discovery;
  }
}

class _FakeDiscovery extends BonsoirAction<BonsoirDiscoveryEvent>
    with ServiceResolver {
  _FakeDiscovery(this.type, this._bonsoir);

  final String type;
  final _FakeBonsoir _bonsoir;
  final _events = StreamController<BonsoirDiscoveryEvent>.broadcast();
  final resolveRequests = <String>[];

  /// What resolving a service found by name answers; a name without an
  /// answer fails to resolve.
  final answers = <String, ResolvedBonsoirService>{};
  bool _stopped = false;

  @override
  Stream<BonsoirDiscoveryEvent> get eventStream => _events.stream;

  @override
  Future<void> get ready async {}

  @override
  bool get isReady => !_stopped;

  @override
  bool get isStopped => _stopped;

  @override
  Future<void> start() async => _bonsoir.onDiscoveryStarted?.call(this);

  @override
  Future<void> stop() async => _stopped = true;

  void emit(BonsoirDiscoveryEventType type, [BonsoirService? service]) =>
      _events.add(BonsoirDiscoveryEvent(type: type, service: service));

  /// A service found on the network, before it is resolved.
  void found(String name) => emit(
    BonsoirDiscoveryEventType.discoveryServiceFound,
    BonsoirService(name: name, type: type, port: 0),
  );

  @override
  Future<void> resolveService(BonsoirService service) async {
    resolveRequests.add(service.name);
    final answer = answers[service.name];
    if (answer == null) throw StateError('no answer for ${service.name}');
    emit(BonsoirDiscoveryEventType.discoveryServiceResolved, answer);
  }
}

class _FakeBroadcast extends BonsoirAction<BonsoirBroadcastEvent> {
  _FakeBroadcast(this.service);

  final BonsoirService service;
  bool started = false;
  bool stopped = false;

  @override
  Stream<BonsoirBroadcastEvent>? get eventStream => null;

  @override
  Future<void> get ready async {}

  @override
  bool get isReady => !stopped;

  @override
  bool get isStopped => stopped;

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> stop() async => stopped = true;
}

ResolvedBonsoirService _desktop(
  String name, {
  required String? host,
  required int port,
  String token = 'tok',
}) => ResolvedBonsoirService(
  name: name,
  type: '_healthwallet._tcp',
  port: port,
  host: host,
  attributes: {MdnsService.tokenAttribute: token},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final logs = captureLogs();

  late BonsoirPlatformInterface original;
  late _FakeBonsoir bonsoir;
  late MdnsService mdns;

  setUp(() {
    original = BonsoirPlatformInterface.instance;
    bonsoir = _FakeBonsoir();
    BonsoirPlatformInterface.instance = bonsoir;
    mdns = MdnsService();
  });

  tearDown(() => BonsoirPlatformInterface.instance = original);

  const timeout = Duration(milliseconds: 50);

  group('search', () {
    test(
      'returns every desktop with the token, not only the first, so a '
      'stale entry from before a restart does not hide the live one',
      () async {
        bonsoir.onDiscoveryStarted = (d) {
          d.answers['HealthWallet Desktop'] = _desktop(
            'HealthWallet Desktop',
            host: 'desk.local.',
            port: 49152,
          );
          d.answers['HealthWallet Desktop (2)'] = _desktop(
            'HealthWallet Desktop (2)',
            host: 'desk.local.',
            port: 50123,
          );
          d.found('HealthWallet Desktop');
          d.found('HealthWallet Desktop (2)');
        };

        expect(await mdns.search(token: 'tok', timeout: timeout), [
          (ip: 'desk.local.', port: 49152),
          (ip: 'desk.local.', port: 50123),
        ]);
        expect(bonsoir.discoveries.single.type, '_healthwallet._tcp');
        expect(bonsoir.discoveries.single.resolveRequests, [
          'HealthWallet Desktop',
          'HealthWallet Desktop (2)',
        ]);
      },
    );

    test('skips other desktops, unusable answers and repeats', () async {
      bonsoir.onDiscoveryStarted = (d) {
        d
          ..emit(BonsoirDiscoveryEventType.discoveryStarted)
          ..emit(
            BonsoirDiscoveryEventType.discoveryServiceResolved,
            _desktop('other', host: '10.0.0.7', port: 49152, token: 'x'),
          )
          ..emit(
            BonsoirDiscoveryEventType.discoveryServiceResolved,
            _desktop('no host', host: null, port: 49152),
          )
          ..emit(
            BonsoirDiscoveryEventType.discoveryServiceResolved,
            _desktop('empty host', host: '', port: 49152),
          )
          ..emit(
            // Resolved, but reported without its address.
            BonsoirDiscoveryEventType.discoveryServiceResolved,
            BonsoirService(name: 'bare', type: d.type, port: 1),
          )
          ..emit(
            BonsoirDiscoveryEventType.discoveryServiceLost,
            _desktop('gone', host: '10.0.0.8', port: 49152),
          );
        for (var i = 0; i < 2; i++) {
          d.emit(
            BonsoirDiscoveryEventType.discoveryServiceResolved,
            _desktop('mine', host: '10.0.0.9', port: 49152),
          );
        }
      };

      expect(await mdns.search(token: 'tok', timeout: timeout), [
        (ip: '10.0.0.9', port: 49152),
      ]);
    });

    test('nothing found is an empty list, and a failed resolution is '
        'logged', () async {
      bonsoir.onDiscoveryStarted = (d) => d.found('unresolvable');

      expect(await mdns.search(token: 'tok', timeout: timeout), isEmpty);
      expect(logs, loggedWarning('resolving a service failed'));
    });

    test('stops browsing when done, and a new search stops the one before '
        'it', () async {
      final first = mdns.search(token: 'tok', timeout: timeout * 4);
      await Future<void>.delayed(Duration.zero);
      final second = mdns.search(token: 'tok', timeout: timeout);
      await Future<void>.delayed(Duration.zero);
      expect(bonsoir.discoveries[0].isStopped, isTrue);
      expect(bonsoir.discoveries[1].isStopped, isFalse);

      await Future.wait([first, second]);

      expect(bonsoir.discoveries.every((d) => d.isStopped), isTrue);
    });
  });

  group('advertising', () {
    test('advertises the port with the token, replacing what was '
        'advertised before', () async {
      await mdns.startAdvertising(port: 49152, token: 'tok');
      await mdns.startAdvertising(port: 50123, token: 'tok2');

      final [first, second] = bonsoir.broadcasts;
      expect(first.stopped, isTrue);
      expect(second.started, isTrue);
      expect(second.stopped, isFalse);
      expect(second.service.type, '_healthwallet._tcp');
      expect(second.service.port, 50123);
      expect(second.service.attributes, {MdnsService.tokenAttribute: 'tok2'});

      await mdns.stopAdvertising();
      expect(second.stopped, isTrue);
    });

    test('stopping without advertising does nothing', () async {
      await mdns.stopAdvertising();
      await mdns.stopDiscovery();
      expect(bonsoir.broadcasts, isEmpty);
    });
  });
}
