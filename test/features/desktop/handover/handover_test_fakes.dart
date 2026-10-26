// Fakes for the blocs the handover services talk to. Not a test file itself.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';

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
