import 'dart:async';
import 'dart:typed_data';

import 'package:airdrop/airdrop.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/features/share_records/data/service/receive_mode_manager.dart';
import 'package:health_wallet/features/share_records/data/service/share_records_service.dart';
import 'package:health_wallet/features/share_records/domain/entity/entity.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';
import '../../share_test_helpers.dart';

class _FakeShareRecordsService extends Fake implements ShareRecordsService {
  final invitations = StreamController<Map<String, dynamic>>.broadcast();
  final received = StreamController<ReceivedData>.broadcast();
  final receivedFiles = StreamController<List<String>>.broadcast();

  final calls = <String>[];
  final parsedFiles = <String>[];
  Error? disconnectError;
  int discoveryFailures = 0;
  EphemeralRecordsContainer? dataResult;
  Map<String, EphemeralRecordsContainer?> fileResults = {};

  Future<void> close() async {
    await invitations.close();
    await received.close();
    await receivedFiles.close();
  }

  @override
  Stream<Map<String, dynamic>> get invitationStream => invitations.stream;

  @override
  Stream<ReceivedData> get receivedDataStream => received.stream;

  @override
  Stream<List<String>> get receivedFilesStream => receivedFiles.stream;

  @override
  Future<void> disconnect() async {
    calls.add('disconnect');
    if (disconnectError != null) throw disconnectError!;
  }

  @override
  Future<void> startSymmetricDiscovery() async {
    calls.add('startSymmetricDiscovery');
    if (discoveryFailures > 0) {
      discoveryFailures--;
      throw StateError('radio off');
    }
  }

  @override
  Future<void> rejectInvitation(String invitationId) async {
    calls.add('rejectInvitation:$invitationId');
  }

  @override
  Future<EphemeralRecordsContainer?> parseReceivedData(
    ReceivedData receivedData,
  ) async => dataResult;

  @override
  Future<EphemeralRecordsContainer?> parseReceivedFile(String filePath) async {
    parsedFiles.add(filePath);
    return fileResults[filePath];
  }
}

class _FakeAppRouter extends Fake implements AppRouter {
  _FakeAppRouter(this.navigatorKey);

  @override
  final GlobalKey<NavigatorState> navigatorKey;

  final pushed = <PageRouteInfo>[];

  @override
  Future<T?> push<T extends Object?>(
    PageRouteInfo route, {
    OnNavigationFailure? onFailure,
  }) async {
    pushed.add(route);
    return null;
  }
}

ShareRecordsRouteArgs _args(PageRouteInfo route) {
  expect(route.routeName, ShareRecordsRoute.name);
  return route.args! as ShareRecordsRouteArgs;
}

EphemeralRecordsContainer _container(String sessionId) =>
    EphemeralRecordsContainer(
      sessionId: sessionId,
      senderDeviceName: 'Pixel 8',
      receivedAt: DateTime.now(),
      viewDuration: const Duration(minutes: 5),
      records: [record(conditionJson())],
    );

ReceivedData _data() => ReceivedData(
  fileName: 'share.json',
  data: Uint8List(0),
  totalFiles: 1,
  currentFile: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeShareRecordsService service;
  late _FakeAppRouter router;
  late ReceiveModeManager manager;

  setUp(() {
    service = _FakeShareRecordsService();
    router = _FakeAppRouter(GlobalKey<NavigatorState>());
    getIt.registerSingleton<AppRouter>(router);
    manager = ReceiveModeManager(service);
  });

  tearDown(() async {
    await getIt.reset();
    await service.close();
  });

  group('start / stop', () {
    test('startListening resets the radio and starts discovery once', () async {
      await manager.startListening();
      await manager.startListening();

      expect(manager.isListening, isTrue);
      expect(service.calls, ['disconnect', 'startSymmetricDiscovery']);
    });

    test('a failing pre-start disconnect is not fatal', () async {
      service.disconnectError = StateError('not connected');

      await manager.startListening();

      expect(manager.isListening, isTrue);
      expect(service.calls.last, 'startSymmetricDiscovery');
    });

    test('a failing discovery leaves the manager stopped', () async {
      service.discoveryFailures = 1;

      await manager.startListening();

      expect(manager.isListening, isFalse);
      service.invitations.add({'invitationId': 'inv-1'});
      await pumpEventQueue();
      expect(manager.pendingInvitationId, isNull);
    });

    test('stopListening disconnects and clears pending state', () async {
      await manager.startListening();
      service.dataResult = _container('s1');
      service.invitations.add({'invitationId': 'inv-1'});
      service.received.add(_data());
      await pumpEventQueue();
      expect(manager.pendingInvitationId, 'inv-1');
      expect(manager.pendingReceivedData, isNotNull);

      await manager.stopListening();

      expect(manager.isListening, isFalse);
      expect(manager.pendingInvitationId, isNull);
      expect(manager.pendingInvitationDeviceName, isNull);
      expect(manager.pendingReceivedData, isNull);
      expect(service.calls.last, 'disconnect');

      service.invitations.add({'invitationId': 'inv-2'});
      await pumpEventQueue();
      expect(manager.pendingInvitationId, isNull);
    });

    test('stopListening is a no-op when not listening', () async {
      await manager.stopListening();
      expect(service.calls, isEmpty);
    });

    test('a failing disconnect on stop is swallowed', () async {
      await manager.startListening();
      service.disconnectError = StateError('busy');

      await expectLater(manager.stopListening(), completes);
    });

    test('dispose stops listening', () async {
      await manager.startListening();
      await manager.dispose();
      expect(manager.isListening, isFalse);
    });
  });

  group('pause / resume', () {
    test('paused managers ignore events until resumed', () async {
      await manager.startListening();
      manager.pauseListening();

      service.invitations.add({'invitationId': 'inv-1'});
      await pumpEventQueue();
      expect(manager.pendingInvitationId, isNull);

      await manager.resumeListening();
      expect(
        service.calls.where((c) => c == 'startSymmetricDiscovery'),
        hasLength(2),
      );

      service.invitations.add({'invitationId': 'inv-2'});
      await pumpEventQueue();
      expect(manager.pendingInvitationId, 'inv-2');
    });

    test('resume still subscribes when discovery fails', () async {
      await manager.startListening();
      manager.pauseListening();
      service.discoveryFailures = 1;

      await manager.resumeListening();

      service.invitations.add({'invitationId': 'inv-3'});
      await pumpEventQueue();
      expect(manager.pendingInvitationId, 'inv-3');
    });

    test('resume does nothing when not listening', () async {
      await manager.resumeListening();
      expect(service.calls, isEmpty);
    });
  });

  group('invitations without a navigator', () {
    setUp(() => manager.startListening());

    test('navigate straight to the share screen', () async {
      service.invitations.add({
        'invitationId': 'inv-1',
        'senderDeviceName': 'Pixel 8',
        'deviceName': 'ignored',
      });
      await pumpEventQueue();

      expect(manager.pendingInvitationId, 'inv-1');
      expect(manager.pendingInvitationDeviceName, 'Pixel 8');
      final args = _args(router.pushed.single);
      expect(args.pendingInvitationId, 'inv-1');
      expect(args.pendingInvitationDeviceName, 'Pixel 8');
      expect(args.invitationPreAccepted, isFalse);
    });

    test('fall back to deviceName, then Unknown Device', () async {
      service.invitations.add({'invitationId': 'inv-1', 'deviceName': 'iPad'});
      await pumpEventQueue();
      expect(manager.pendingInvitationDeviceName, 'iPad');

      manager.clearPendingInvitation();
      service.invitations.add(<String, dynamic>{});
      await pumpEventQueue();
      expect(manager.pendingInvitationId, '');
      expect(manager.pendingInvitationDeviceName, 'Unknown Device');
    });

    test('ignore duplicates while one is pending', () async {
      service.invitations.add({'invitationId': 'inv-1'});
      service.invitations.add({'invitationId': 'inv-2'});
      await pumpEventQueue();

      expect(manager.pendingInvitationId, 'inv-1');
      expect(router.pushed, hasLength(1));
    });

    test('skip the dialog when data already arrived', () async {
      service.dataResult = _container('s1');
      service.received.add(_data());
      await pumpEventQueue();
      router.pushed.clear();

      service.invitations.add({'invitationId': 'inv-1'});
      await pumpEventQueue();

      expect(manager.pendingInvitationId, 'inv-1');
      expect(router.pushed, isEmpty);
    });
  });

  group('received data', () {
    setUp(() => manager.startListening());

    test('opens the viewer when no invitation is pending', () async {
      final container = _container('s1');
      service.dataResult = container;

      service.received.add(_data());
      await pumpEventQueue();

      expect(manager.pendingReceivedData, container);
      expect(_args(router.pushed.single).hasReceivedData, isTrue);

      manager.clearPendingReceivedData();
      expect(manager.pendingReceivedData, isNull);
    });

    test('is stored for the BLoC while an invitation is pending', () async {
      service.invitations.add({'invitationId': 'inv-1'});
      await pumpEventQueue();
      router.pushed.clear();
      service.dataResult = _container('s1');

      service.received.add(_data());
      await pumpEventQueue();

      expect(manager.pendingReceivedData?.sessionId, 's1');
      expect(router.pushed, isEmpty);
    });

    test('ignores payloads that fail to parse', () async {
      service.received.add(_data());
      await pumpEventQueue();

      expect(manager.pendingReceivedData, isNull);
      expect(router.pushed, isEmpty);
    });

    test('uses the first received file that parses', () async {
      service.fileResults = {'/b.json': _container('from-b')};

      service.receivedFiles.add(['/a.json', '/b.json', '/c.json']);
      await pumpEventQueue();

      expect(service.parsedFiles, ['/a.json', '/b.json']);
      expect(manager.pendingReceivedData?.sessionId, 'from-b');
      expect(router.pushed, hasLength(1));
    });

    test('ignores received files that fail to parse', () async {
      service.receivedFiles.add(['/a.json']);
      await pumpEventQueue();

      expect(manager.pendingReceivedData, isNull);
      expect(router.pushed, isEmpty);
    });
  });

  group('invitation dialog', () {
    Future<void> showInvitation(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(navigatorKey: router.navigatorKey, home: const Scaffold()),
      );
      await manager.startListening();
      service.invitations.add({
        'invitationId': 'inv-1',
        'senderDeviceName': 'Pixel 8',
      });
      await tester.pumpAndSettle();
    }

    testWidgets('describes the incoming share', (tester) async {
      await showInvitation(tester);

      expect(find.text('Incoming Health Records'), findsOneWidget);
      expect(
        find.text('Pixel 8 wants to share health records with you'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Records will be view-only and automatically deleted when you exit',
        ),
        findsOneWidget,
      );
      expect(router.pushed, isEmpty);
    });

    testWidgets('Accept closes the dialog and opens the share screen', (
      tester,
    ) async {
      await showInvitation(tester);

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(find.text('Incoming Health Records'), findsNothing);
      final args = _args(router.pushed.single);
      expect(args.pendingInvitationId, 'inv-1');
      expect(args.pendingInvitationDeviceName, 'Pixel 8');
      expect(args.invitationPreAccepted, isTrue);
    });

    testWidgets('Decline rejects and restarts discovery after 4 seconds', (
      tester,
    ) async {
      await showInvitation(tester);

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();

      expect(find.text('Incoming Health Records'), findsNothing);
      expect(service.calls, contains('rejectInvitation:inv-1'));
      expect(manager.pendingInvitationId, isNull);
      expect(service.calls.last, 'rejectInvitation:inv-1');

      await tester.pump(const Duration(seconds: 4));
      expect(service.calls.last, 'startSymmetricDiscovery');
      expect(router.pushed, isEmpty);
    });

    testWidgets('Decline does not restart discovery once stopped', (
      tester,
    ) async {
      await showInvitation(tester);

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      // The subscriptions were created outside the fake-async zone, so their
      // cancellation has to complete on the real event loop.
      await tester.runAsync(manager.stopListening);
      expect(manager.isListening, isFalse);

      await tester.pump(const Duration(seconds: 4));
      expect(service.calls.last, 'disconnect');
    });
  });
}
