import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

import 'package:health_wallet/features/desktop/handover/data/services/handover_service.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_session.dart';

part 'handover_event.dart';
part 'handover_state.dart';
part 'handover_bloc.freezed.dart';

@lazySingleton
class HandoverBloc extends Bloc<HandoverEvent, HandoverState> {
  final HandoverService _handoverService;

  StreamSubscription<HandoverSession>? _sessionUpdateSub;

  HandoverBloc(this._handoverService) : super(HandoverState.initial()) {
    on<HandoverInitialised>(_onInitialised);
    on<HandoverOfferReceived>(_onOfferReceived);
    on<HandoverFileReceived>(_onFileReceived);
    on<HandoverProcessingComplete>(_onProcessingComplete);
  }

  Future<void> _onInitialised(
    HandoverInitialised event,
    Emitter<HandoverState> emit,
  ) async {
    _sessionUpdateSub = _handoverService.sessionUpdates.listen((session) {
      final updated = Map<String, HandoverSession>.from(state.activeSessions);
      updated[session.sessionId] = session;
      emit(state.copyWith(activeSessions: updated));
    });

    _handoverService.startListening(
      onOfferReceived: (session) => add(HandoverOfferReceived(session: session)),
      onFileReceived: (sessionId) => add(HandoverFileReceived(sessionId: sessionId)),
      onProcessingComplete: (sessionId) =>
          add(HandoverProcessingComplete(sessionId: sessionId)),
    );
  }

  Future<void> _onOfferReceived(
    HandoverOfferReceived event,
    Emitter<HandoverState> emit,
  ) async {
    final updated = Map<String, HandoverSession>.from(state.activeSessions);
    updated[event.session.sessionId] = event.session;
    emit(state.copyWith(activeSessions: updated, error: null));
  }

  Future<void> _onFileReceived(
    HandoverFileReceived event,
    Emitter<HandoverState> emit,
  ) async {
    final current = state.activeSessions[event.sessionId];
    if (current == null) return;

    final updatedSession = current.copyWith(
      receivedCount: current.receivedCount + 1,
      progress: (current.receivedCount + 1) / current.fileCount * 0.5,
    );

    final updated = Map<String, HandoverSession>.from(state.activeSessions);
    updated[event.sessionId] = updatedSession;
    emit(state.copyWith(activeSessions: updated));
  }

  Future<void> _onProcessingComplete(
    HandoverProcessingComplete event,
    Emitter<HandoverState> emit,
  ) async {
    final current = state.activeSessions[event.sessionId];
    if (current == null) return;

    final updatedSession = current.copyWith(
      status: HandoverStatus.complete,
      progress: 1.0,
    );

    final updated = Map<String, HandoverSession>.from(state.activeSessions);
    updated[event.sessionId] = updatedSession;
    emit(state.copyWith(activeSessions: updated));
  }

  @override
  Future<void> close() {
    _sessionUpdateSub?.cancel();
    _handoverService.stopListening();
    return super.close();
  }
}
