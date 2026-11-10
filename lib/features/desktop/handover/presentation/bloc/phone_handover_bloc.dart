import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/desktop/handover/data/services/handover_sender_service.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_protocol.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_session.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:injectable/injectable.dart';

part 'phone_handover_bloc.freezed.dart';
part 'phone_handover_event.dart';
part 'phone_handover_state.dart';

/// The phone's side of handovers: sends a processing session's files to the
/// desktop, then applies what the desktop reports to that session (its
/// draft to review here, a failure, a save or a delete there), and tells the
/// desktop when the phone saves or deletes it first.
@lazySingleton
class PhoneHandoverBloc extends Bloc<PhoneHandoverEvent, PhoneHandoverState> {
  PhoneHandoverBloc(this._sender, this._processing)
    : super(const PhoneHandoverState()) {
    on<PhoneHandoverInitialised>(_onInitialised, transformer: droppable());
    on<PhoneHandoverSendRequested>(_onSendRequested, transformer: concurrent());
    on<PhoneHandoverCancelRequested>(
      (e, _) => _sender.cancelTransfer(e.sessionId),
      transformer: sequential(),
    );
    on<PhoneHandoverTakeBackRequested>(
      _onTakeBackRequested,
      transformer: sequential(),
    );
    on<PhoneHandoverTransferUpdated>(
      (e, emit) => emit(
        state.copyWith(
          transfers: {...state.transfers, e.transfer.sessionId: e.transfer},
        ),
      ),
      transformer: sequential(),
    );
    on<PhoneHandoverDesktopEventReceived>(
      _onDesktopEvent,
      transformer: sequential(),
    );
    on<PhoneHandoverProcessingChanged>(
      _onProcessingChanged,
      transformer: sequential(),
    );
  }

  final HandoverSenderService _sender;
  final ProcessingBloc _processing;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// Handed-over sessions seen, so a delete on this phone is noticed.
  final Set<String> _handedOver = {};

  /// Sessions removed because of the desktop (its save): not a delete to
  /// report back.
  final Set<String> _quiet = {};
  PipelineStatus? _lastStatus;

  void _onInitialised(
    PhoneHandoverInitialised event,
    Emitter<PhoneHandoverState> emit,
  ) {
    if (_subscriptions.isNotEmpty) return;
    _sender.start();
    _subscriptions
      ..add(
        _sender.transfers.listen(
          (t) => add(PhoneHandoverTransferUpdated(transfer: t)),
        ),
      )
      ..add(
        _sender.desktopEvents.listen(
          (e) => add(PhoneHandoverDesktopEventReceived(event: e)),
        ),
      )
      ..add(
        _processing.stream.listen(
          (s) => add(PhoneHandoverProcessingChanged(processing: s)),
        ),
      );
    add(PhoneHandoverProcessingChanged(processing: _processing.state));
  }

  ProcessingSession? _session(String id) =>
      _processing.state.sessions.firstWhereOrNull((s) => s.id == id);

  Future<void> _onSendRequested(
    PhoneHandoverSendRequested event,
    Emitter<PhoneHandoverState> emit,
  ) async {
    final session = _session(event.sessionId);
    if (session == null ||
        session.filePaths.isEmpty ||
        session.status == ProcessingStatus.handedOver ||
        state.transfers[event.sessionId]?.status == HandoverStatus.sending) {
      return;
    }
    // An earlier attempt's outcome isn't shown for this one.
    emit(
      state.copyWith(
        transfers: {...state.transfers}..remove(event.sessionId),
      ),
    );
    final result = await _sender.send(
      session.id,
      session.filePaths,
      phase1Data: phase1DataOf(session),
    );
    if (result.status == HandoverStatus.sent) {
      _processing.add(SessionHandedOver(sessionId: session.id));
    }
  }

  /// The patient step already done on the phone, so the desktop skips it.
  static Map<String, dynamic>? phase1DataOf(ProcessingSession session) {
    if (!session.patient.hasSelection) return null;
    return {
      'patient': stagedPatientToJson(session.patient),
      if (session.encounter.draft != null || session.encounter.existing != null)
        'encounter': stagedEncounterToJson(session.encounter),
      if (session.diagnosticReport != null)
        'diagnosticReport': stagedDiagnosticReportToJson(
          session.diagnosticReport!,
        ),
    };
  }

  Future<void> _onTakeBackRequested(
    PhoneHandoverTakeBackRequested event,
    Emitter<PhoneHandoverState> emit,
  ) async {
    await _sender.withdraw(event.sessionId);
    _processing.add(
      HandoverReturned(
        sessionId: event.sessionId,
        reason: HandoverReturnReason.withdrawn,
      ),
    );
    emit(
      state.copyWith(
        desktopProgress: {...state.desktopProgress}..remove(event.sessionId),
      ),
    );
  }

  Future<void> _onDesktopEvent(
    PhoneHandoverDesktopEventReceived event,
    Emitter<PhoneHandoverState> emit,
  ) async {
    final e = event.event;
    switch (e) {
      case DesktopHandoverProgress(:final sessionId, :final progress):
        emit(
          state.copyWith(
            desktopProgress: {...state.desktopProgress, sessionId: progress},
          ),
        );
        return;
      case DesktopHandoverResult(:final sessionId, :final draft):
        // Applied only to a session this phone still has; a result for
        // anything else is acknowledged and dropped.
        if (_session(sessionId) != null) {
          _processing.add(_draftReceived(sessionId, draft));
        }
        await _sender.acknowledge(sessionId, HandoverMessage.result);
      case DesktopHandoverFailed(:final sessionId, :final failure):
        _processing.add(
          HandoverReturned(
            sessionId: sessionId,
            reason: failure == HandoverFailure.modelNotFound
                ? HandoverReturnReason.noModelOnDesktop
                : HandoverReturnReason.failedOnDesktop,
          ),
        );
        await _sender.acknowledge(sessionId, HandoverMessage.failed);
      case DesktopHandoverSaved(:final sessionId):
        if (_session(sessionId) != null) {
          _quiet.add(sessionId);
          _processing.add(
            SessionSavedElsewhere(sessionId: sessionId, byDesktop: true),
          );
        }
        await _sender.acknowledge(sessionId, HandoverMessage.saved);
      case DesktopHandoverCancelled(:final sessionId):
        _processing.add(
          HandoverReturned(
            sessionId: sessionId,
            reason: HandoverReturnReason.deletedOnDesktop,
          ),
        );
        await _sender.acknowledge(sessionId, HandoverMessage.cancel);
    }
    emit(
      state.copyWith(
        desktopProgress: {...state.desktopProgress}..remove(e.sessionId),
      ),
    );
  }

  static HandoverDraftReceived _draftReceived(
    String sessionId,
    HandoverDraft draft,
  ) => HandoverDraftReceived(
    sessionId: sessionId,
    patient: draft.patient,
    encounter: draft.encounter,
    diagnosticReport: draft.diagnosticReport,
    resources: draft.resources,
  );

  Future<void> _onProcessingChanged(
    PhoneHandoverProcessingChanged event,
    Emitter<PhoneHandoverState> emit,
  ) async {
    final processing = event.processing;
    final sessions = {for (final s in processing.sessions) s.id: s};

    final status = processing.status;
    if (!identical(status, _lastStatus)) {
      _lastStatus = status;
      // Saved here first: the desktop drops its draft.
      if (status case Success(:final sessionId?)
          when sessions[sessionId]?.origin == ProcessingOrigin.handover) {
        _quiet.add(sessionId);
        await _sender.reportSaved(sessionId);
      }
    }

    for (final s in sessions.values) {
      if (s.status == ProcessingStatus.handedOver ||
          s.origin == ProcessingOrigin.handover) {
        _handedOver.add(s.id);
      } else {
        // Taken back or returned: no longer the desktop's.
        _handedOver.remove(s.id);
      }
    }
    for (final id in _handedOver.difference(sessions.keys.toSet())) {
      _handedOver.remove(id);
      // Deleted on this phone: the desktop drops its copy too.
      if (!_quiet.remove(id)) await _sender.withdraw(id);
    }
  }

  @override
  Future<void> close() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    return super.close();
  }
}
