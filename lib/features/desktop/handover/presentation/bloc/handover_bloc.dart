import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/desktop/handover/data/services/handover_service.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_protocol.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_session.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:injectable/injectable.dart';

part 'handover_bloc.freezed.dart';
part 'handover_event.dart';
part 'handover_state.dart';

/// The desktop's side of handovers: turns a received document into a
/// processing session with the phone's id, and tells the phone how that
/// session goes (progress, the draft, a failure, a save or a delete here).
@lazySingleton
class HandoverBloc extends Bloc<HandoverEvent, HandoverState> {
  HandoverBloc(this._service, this._processing)
    : super(HandoverState.initial()) {
    on<HandoverInitialised>(_onInitialised, transformer: droppable());
    on<HandoverTransferUpdated>(
      _onTransferUpdated,
      transformer: sequential(),
    );
    on<HandoverPhoneEventReceived>(
      _onPhoneEvent,
      transformer: sequential(),
    );
    on<HandoverProcessingChanged>(
      _onProcessingChanged,
      transformer: sequential(),
    );
  }

  final HandoverService _service;
  final ProcessingBloc _processing;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// Handover sessions seen in the processing list, so a delete is noticed.
  final Set<String> _known = {};

  /// Received documents whose session doesn't exist yet.
  final Set<String> _importing = {};

  /// Sessions removed because of the phone (its save or its cancel), or
  /// saved here: their removal is not a delete to report.
  final Set<String> _quiet = {};

  final Map<String, double> _sentProgress = {};
  PipelineStatus? _lastStatus;

  Future<void> _onInitialised(
    HandoverInitialised event,
    Emitter<HandoverState> emit,
  ) async {
    if (_subscriptions.isNotEmpty) return;
    _service.start();
    _subscriptions
      ..add(
        _service.transfers.listen(
          (t) => add(HandoverTransferUpdated(transfer: t)),
        ),
      )
      ..add(
        _service.phoneEvents.listen(
          (e) => add(HandoverPhoneEventReceived(event: e)),
        ),
      )
      ..add(
        _processing.stream.listen(
          (s) => add(HandoverProcessingChanged(processing: s)),
        ),
      );
    add(HandoverProcessingChanged(processing: _processing.state));
  }

  void _onTransferUpdated(
    HandoverTransferUpdated event,
    Emitter<HandoverState> emit,
  ) {
    final t = event.transfer;
    final transfers = {...state.transfers};
    if (t.status == HandoverStatus.receiving) {
      transfers[t.sessionId] = t;
    } else {
      transfers.remove(t.sessionId);
    }
    emit(state.copyWith(transfers: transfers));
  }

  Future<void> _onPhoneEvent(
    HandoverPhoneEventReceived event,
    Emitter<HandoverState> emit,
  ) async {
    switch (event.event) {
      case IncomingHandoverReceived(:final sessionId, :final filePaths):
        final phase1 = _phase1(event.event as IncomingHandoverReceived);
        _importing.add(sessionId);
        // A document sent again replaces its earlier session.
        _quiet.add(sessionId);
        _sentProgress.remove(sessionId);
        await _service.forget(sessionId);
        _processing.add(
          DocumentImported(
            filePaths: filePaths,
            origin: ProcessingOrigin.handover,
            sessionId: sessionId,
            phase1Patient: phase1?.patient,
            phase1Encounter: phase1?.encounter,
            phase1DiagnosticReport: phase1?.diagnosticReport,
          ),
        );
      case IncomingHandoverCancelled(:final sessionId):
        final session = _session(sessionId);
        if (session != null) {
          _quiet.add(sessionId);
          _processing.add(SessionCleared(session: session));
        }
        await _service.forget(sessionId);
      case IncomingHandoverSaved(:final sessionId):
        if (_session(sessionId) != null) {
          _quiet.add(sessionId);
          _processing.add(
            SessionSavedElsewhere(sessionId: sessionId, byDesktop: false),
          );
        }
        await _service.forget(sessionId);
    }
  }

  ({
    StagedPatient patient,
    StagedEncounter? encounter,
    StagedDiagnosticReport? diagnosticReport,
  })?
  _phase1(IncomingHandoverReceived received) {
    final data = received.phase1Data;
    if (data == null || data['patient'] is! Map<String, dynamic>) return null;
    try {
      return (
        patient: stagedPatientFromJson(data['patient'] as Map<String, dynamic>),
        encounter: data['encounter'] is Map<String, dynamic>
            ? stagedEncounterFromJson(data['encounter'] as Map<String, dynamic>)
            : null,
        diagnosticReport: data['diagnosticReport'] is Map<String, dynamic>
            ? stagedDiagnosticReportFromJson(
                data['diagnosticReport'] as Map<String, dynamic>,
              )
            : null,
      );
    } on Object catch (e) {
      // Read again from the document instead.
      logger.w('[Handover] the phone\'s patient step was unreadable', e);
      return null;
    }
  }

  ProcessingSession? _session(String id) =>
      _processing.state.sessions.firstWhereOrNull((s) => s.id == id);

  Future<void> _onProcessingChanged(
    HandoverProcessingChanged event,
    Emitter<HandoverState> emit,
  ) async {
    final processing = event.processing;
    final handovers = {
      for (final s in processing.sessions)
        if (s.origin == ProcessingOrigin.handover) s.id: s,
    };

    for (final s in handovers.values) {
      if (_importing.remove(s.id)) {
        _quiet.remove(s.id);
        // Processing holds its own copies now.
        await _service.discardFiles(s.id);
      }
      _known.add(s.id);
      if (s.isProcessing) {
        final last = _sentProgress[s.id] ?? -1;
        if (s.progress - last >= 0.05 || s.progress < last) {
          _sentProgress[s.id] = s.progress;
          await _service.sendProgress(s.id, s.progress);
        }
      } else if (s.status == ProcessingStatus.draft) {
        await _service.sendResult(s.id, HandoverDraft.of(s));
      }
    }

    final status = processing.status;
    if (!identical(status, _lastStatus)) {
      _lastStatus = status;
      await _onStatus(status, handovers);
    }

    for (final id in _known.difference(handovers.keys.toSet())) {
      _known.remove(id);
      _sentProgress.remove(id);
      await _service.forget(id);
      // Deleted by the desktop's user: the document goes back to the phone.
      if (!_quiet.remove(id)) await _service.sendCancelled(id);
    }
  }

  Future<void> _onStatus(
    PipelineStatus status,
    Map<String, ProcessingSession> handovers,
  ) async {
    switch (status) {
      case Failure(:final sessionId?, :final reason)
          when handovers.containsKey(sessionId) ||
              _importing.contains(sessionId):
        if (_importing.remove(sessionId)) {
          _quiet.remove(sessionId);
          await _service.discardFiles(sessionId);
        }
        await _service.sendFailed(
          sessionId,
          reason == PipelineFailureReason.modelNotFound
              ? HandoverFailure.modelNotFound
              : HandoverFailure.failed,
        );
      case CapacityFailure(:final sessionId)
          when handovers.containsKey(sessionId):
        await _service.sendFailed(sessionId, HandoverFailure.failed);
      case Success(:final sessionId?) when handovers.containsKey(sessionId):
        _quiet.add(sessionId);
        await _service.sendSaved(sessionId);
      default:
        break;
    }
  }

  @override
  Future<void> close() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _service.stop();
    return super.close();
  }
}
