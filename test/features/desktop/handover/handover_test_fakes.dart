// Fakes for the blocs the handover services talk to. Not a test file itself.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart'
    as link;
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';

import '../desktop_test_fakes.dart';

/// Records added events and lets the test push states.
class FakeProcessingBloc extends Fake implements ProcessingBloc {
  FakeProcessingBloc([this._state = const ProcessingState()]);

  final _states = StreamController<ProcessingState>.broadcast();
  final _added = StreamController<ProcessingEvent>.broadcast();
  final List<ProcessingEvent> events = [];
  ProcessingState _state;

  @override
  ProcessingState get state => _state;

  @override
  Stream<ProcessingState> get stream => _states.stream;

  /// Every event added from now on.
  Stream<ProcessingEvent> get addedEvents => _added.stream;

  @override
  void add(ProcessingEvent event) {
    events.add(event);
    _added.add(event);
  }

  void push(ProcessingState state) {
    _state = state;
    _states.add(state);
  }

  @override
  Future<void> close() async {
    await _states.close();
    await _added.close();
  }
}

class FakeLwwSyncBloc extends Fake implements LwwSyncBloc {
  final List<LwwSyncEvent> events = [];

  @override
  void add(LwwSyncEvent event) => events.add(event);
}

/// Two fake links joined like the real one: what one end sends, the other
/// receives, unless that end is down.
({FakeTcpService phone, FakeTcpService desktop}) linkedPair() {
  final phone = FakeTcpService();
  final desktop = FakeTcpService();
  phone.onSend = (type, payload) async {
    if (desktop.isConnected) desktop.deliver(type, payload);
  };
  desktop.onSend = (type, payload) async {
    if (phone.isConnected) phone.deliver(type, payload);
  };
  return (phone: phone, desktop: desktop);
}

/// Takes both ends of [link] down or up, with the state events the
/// services listen to.
void setLinkUp(
  ({FakeTcpService phone, FakeTcpService desktop}) pair,
  bool up,
) {
  final state = up
      ? link.ConnectionState.connected
      : link.ConnectionState.disconnected;
  pair.phone.emitState(state);
  pair.desktop.emitState(state);
}
