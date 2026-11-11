import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/mdns_service.dart';

/// Bonjour without a network, where starting a browse can hang.
class _FakeBonsoir extends BonsoirPlatformInterface {
  final discoveries = <_FakeDiscovery>[];

  /// What starting the n-th browse waits on; by default nothing.
  final startGates = <int, Future<void>>{};

  @override
  BonsoirAction<BonsoirBroadcastEvent> createBroadcastAction(
    BonsoirService service, {
    bool printLogs = false,
  }) => throw UnimplementedError();

  @override
  BonsoirAction<BonsoirDiscoveryEvent> createDiscoveryAction(
    String type, {
    bool printLogs = false,
  }) {
    final discovery = _FakeDiscovery(
      type,
      startGates[discoveries.length] ?? Future<void>.value(),
    );
    discoveries.add(discovery);
    return discovery;
  }
}

class _FakeDiscovery extends BonsoirAction<BonsoirDiscoveryEvent>
    with ServiceResolver {
  _FakeDiscovery(this.type, this._started);

  final String type;
  final Future<void> _started;
  // Single-subscription with an async onCancel, so cancelling completes in
  // the fake zone: a broadcast controller's cancel completes in the root
  // zone, which fakeAsync never runs.
  late final _events = StreamController<BonsoirDiscoveryEvent>(
    onCancel: () async {},
  );
  int stops = 0;

  @override
  Stream<BonsoirDiscoveryEvent> get eventStream => _events.stream;

  @override
  Future<void> get ready async {}

  @override
  bool get isReady => stops == 0;

  @override
  bool get isStopped => stops > 0;

  @override
  Future<void> start() => _started;

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> resolveService(BonsoirService service) async {}

  /// A desktop with the token `tok` resolved at [host]:[port].
  void resolved(String host, int port) => _events.add(
    BonsoirDiscoveryEvent(
      type: BonsoirDiscoveryEventType.discoveryServiceResolved,
      service: ResolvedBonsoirService(
        name: 'HealthWallet Desktop',
        type: type,
        port: port,
        host: host,
        attributes: {MdnsService.tokenAttribute: 'tok'},
      ),
    ),
  );
}

/// A search given up while its browse was still starting must not stop the
/// search that came after it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  const timeout = Duration(seconds: 3);

  group('overlapping searches', () {
    test('a search whose start returns late stops only its own browse, not '
        'the newer one', () {
      fakeAsync((async) {
        final firstStarted = Completer<void>();
        bonsoir.startGates[0] = firstStarted.future;

        List<({String ip, int port})>? firstResult;
        // E.g. the attempt that ran this search was given up after 60 s.
        unawaited(
          mdns
              .search(token: 'tok', timeout: timeout)
              .then((r) => firstResult = r),
        );
        async.elapse(timeout * 2);
        expect(firstResult, isNull);

        List<({String ip, int port})>? secondResult;
        unawaited(
          mdns
              .search(token: 'tok', timeout: timeout)
              .then((r) => secondResult = r),
        );
        async.flushMicrotasks();
        final [first, second] = bonsoir.discoveries;
        expect(first.isStopped, isTrue);
        expect(second.isStopped, isFalse);

        // The old start finally returns.
        firstStarted.complete();
        async.flushMicrotasks();
        expect(firstResult, isEmpty);
        expect(second.isStopped, isFalse);

        // The newer search still hears its desktop, and stops its browse.
        second.resolved('10.0.0.5', 49152);
        async.elapse(timeout);
        expect(secondResult, [(ip: '10.0.0.5', port: 49152)]);
        expect(second.stops, 1);
        expect(first.stops, 1);
      });
    });

    test('a search stops its own browse when it ends while still the '
        'current one', () {
      fakeAsync((async) {
        List<({String ip, int port})>? result;
        unawaited(
          mdns.search(token: 'tok', timeout: timeout).then((r) => result = r),
        );
        async.elapse(timeout);

        expect(result, isEmpty);
        expect(bonsoir.discoveries.single.stops, 1);

        // Nothing is left to stop.
        unawaited(mdns.stopDiscovery());
        async.flushMicrotasks();
        expect(bonsoir.discoveries.single.stops, 1);
      });
    });
  });
}
