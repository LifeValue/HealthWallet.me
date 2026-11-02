import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/user/domain/services/patient_edit_service.dart';
import 'package:injectable/injectable.dart';

part 'patient_bloc.freezed.dart';
part 'patient_event.dart';
part 'patient_state.dart';

@injectable
class PatientBloc extends Bloc<PatientEvent, PatientState> {
  final HolderService _holderService;
  final HolderSelection _selection;
  final PatientEditService _patientEditService;
  late final StreamSubscription<HolderScope> _scopeChanges;

  /// The last selection shown, so the one this bloc asked for isn't shown
  /// twice when it also arrives through [HolderSelection.changes].
  HolderScope? _shown;

  PatientBloc(
    this._holderService,
    this._selection,
    this._patientEditService,
  ) : super(const PatientState()) {
    on<PatientInitialised>(_onInitialised, transformer: restartable());
    on<PatientPatientsLoaded>(_onPatientsLoaded, transformer: restartable());
    on<PatientScopeChanged>(_onScopeChanged, transformer: sequential());
    on<PatientReorder>(_onPatientReorder, transformer: droppable());
    on<PatientDataUpdatedFromSync>(
      _onDataUpdatedFromSync,
      transformer: droppable(),
    );
    on<PatientEditStarted>(_onEditStarted, transformer: sequential());
    on<PatientEditCancelled>(_onEditCancelled, transformer: sequential());
    on<PatientEditSaved>(_onEditSaved, transformer: droppable());
    on<PatientSelectionChanged>(
      _onSelectionChanged,
      transformer: sequential(),
    );
    on<PatientHolderAnswered>(_onHolderAnswered, transformer: droppable());
    _scopeChanges = _selection.changes.listen(
      (scope) => add(PatientScopeChanged(scope)),
    );
  }

  @override
  Future<void> close() async {
    await _scopeChanges.cancel();
    return super.close();
  }

  /// The holder a listed patient stands for.
  String _holderIdOf(String patientId) =>
      state.patientGroups[patientId]?.id ?? patientId;

  Future<void> _onInitialised(
    PatientInitialised event,
    Emitter<PatientState> emit,
  ) async {
    await _loadPatients(emit);
  }

  Future<void> _loadPatients(
    Emitter<PatientState> emit, {
    bool preserveOrder = false,
  }) async {
    emit(state.copyWith(status: const PatientStatus.loading()));
    try {
      _show(emit, await _selection.refresh(), preserveOrder: preserveOrder);
    } catch (e) {
      logger.e('Error in _loadPatients: $e');
      emit(state.copyWith(status: PatientStatus.failure(e)));
    }
  }

  /// A selection made elsewhere (a scan, the demo data) or the people read
  /// again by someone else.
  Future<void> _onScopeChanged(
    PatientScopeChanged event,
    Emitter<PatientState> emit,
  ) async {
    if (identical(event.scope, _shown) || !event.scope.loaded) return;
    final moved = event.scope.holder?.patientId != state.selectedPatientId;
    _show(emit, event.scope, preserveOrder: !moved);
  }

  /// One patient per person. The selected person comes first, unless the
  /// list keeps its order (after an edit, or when only the people changed),
  /// which also keeps what is expanded.
  void _show(
    Emitter<PatientState> emit,
    HolderScope scope, {
    required bool preserveOrder,
  }) {
    _shown = scope;
    final holders = scope.directory.holders;
    final selected = scope.holder;
    final patients = [for (final h in holders) h.representativePatient];
    if (preserveOrder) {
      final position = {
        for (final (i, p) in state.patients.indexed) _holderIdOf(p.id): i,
      };
      final holderOf = {for (final h in holders) h.patientId: h.id};
      int at(Patient p) => position[holderOf[p.id]] ?? position.length;
      patients.sort((a, b) => at(a).compareTo(at(b)));
    } else if (selected != null) {
      patients
        ..removeWhere((p) => p.id == selected.patientId)
        ..insert(0, selected.representativePatient);
    }
    final ids = {for (final p in patients) p.id};

    emit(
      state.copyWith(
        status: const PatientStatus.success(),
        patients: patients,
        allPatientsAcrossSources: [
          for (final h in holders) ...h.allPatientInstances,
        ],
        patientGroups: {for (final h in holders) h.patientId: h},
        holderQuestions: scope.directory.questions,
        selectedPatientId: selected?.patientId,
        expandedPatientIds: preserveOrder
            ? state.expandedPatientIds.intersection(ids)
            : {?selected?.patientId},
      ),
    );
  }

  Future<void> _onPatientsLoaded(
    PatientPatientsLoaded event,
    Emitter<PatientState> emit,
  ) async {
    await _loadPatients(emit, preserveOrder: event.preserveOrder);
  }

  Future<void> _onPatientReorder(
    PatientReorder event,
    Emitter<PatientState> emit,
  ) async {
    final currentExpandedIds = Set<String>.from(state.expandedPatientIds);
    final currentPatients = List<Patient>.from(state.patients);

    if (currentExpandedIds.contains(event.patientId)) {
      return;
    }

    final selectedPatient = currentPatients.firstWhere(
      (patient) => patient.id == event.patientId,
      orElse: () => currentPatients.first,
    );

    emit(
      state.copyWith(
        animationPhase: PatientAnimationPhase.collapsing,
        animatingPatientId: event.patientId,
      ),
    );

    if (currentExpandedIds.isNotEmpty) {
      final collapsingPatientId = currentExpandedIds.first;

      emit(
        state.copyWith(
          collapsingPatientId: collapsingPatientId,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 560));

      currentExpandedIds.clear();
      emit(
        state.copyWith(
          expandedPatientIds: currentExpandedIds,
          collapsingPatientId: '',
        ),
      );

      await Future.delayed(const Duration(milliseconds: 840));
    }

    emit(
      state.copyWith(
        animationPhase: PatientAnimationPhase.swapping,
        swappingFromPatientId: currentPatients[0].id,
        swappingToPatientId: event.patientId,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 140));

    currentPatients.remove(selectedPatient);
    currentPatients.insert(0, selectedPatient);

    emit(
      state.copyWith(
        patients: currentPatients,
        selectedPatientId: selectedPatient.id,
        swappingFromPatientId: '',
        swappingToPatientId: '',
      ),
    );
    await _selection.select(_holderIdOf(selectedPatient.id));

    await Future.delayed(const Duration(milliseconds: 560));

    currentExpandedIds.add(event.patientId);
    emit(
      state.copyWith(
        animationPhase: PatientAnimationPhase.expanding,
        expandedPatientIds: currentExpandedIds,
        expandingPatientId: event.patientId,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 840));

    emit(
      state.copyWith(
        expandingPatientId: '',
      ),
    );

    await Future.delayed(const Duration(milliseconds: 140));

    emit(
      state.copyWith(
        animationPhase: PatientAnimationPhase.none,
        animatingPatientId: '',
        collapsingPatientId: '',
        expandingPatientId: '',
        swappingFromPatientId: '',
        swappingToPatientId: '',
      ),
    );
  }

  Future<void> _onHolderAnswered(
    PatientHolderAnswered event,
    Emitter<PatientState> emit,
  ) async {
    try {
      await _holderService.answer(event.ask.question, holderId: event.holderId);
    } catch (e, s) {
      logger.e('Saving whose records arrived failed', e, s);
    }
    await _loadPatients(emit, preserveOrder: true);
  }

  Future<void> _onDataUpdatedFromSync(
    PatientDataUpdatedFromSync event,
    Emitter<PatientState> emit,
  ) async {}

  Future<void> _onEditStarted(
    PatientEditStarted event,
    Emitter<PatientState> emit,
  ) async {
    final patient = state.patients.firstWhere(
      (p) => p.id == event.patientId,
      orElse: () => state.patients.first,
    );

    emit(
      state.copyWith(
        isEditingPatient: true,
        editingPatient: patient,
      ),
    );
  }

  Future<void> _onEditCancelled(
    PatientEditCancelled event,
    Emitter<PatientState> emit,
  ) async {
    emit(
      state.copyWith(
        isEditingPatient: false,
        editingPatient: null,
      ),
    );
  }

  Future<void> _onEditSaved(
    PatientEditSaved event,
    Emitter<PatientState> emit,
  ) async {
    emit(state.copyWith(status: const PatientStatus.loading()));

    try {
      final currentPatient = state.patients.firstWhere(
        (p) => p.id == event.patientId,
        orElse: () => throw Exception('Patient not found: ${event.patientId}'),
      );

      final wasExpanded = state.expandedPatientIds.contains(event.patientId);

      final availableSources = event.availableSources.cast<Source>();

      await _patientEditService.savePatientEdits(
        currentPatient: currentPatient,
        given: event.given,
        family: event.family,
        birthDate: event.birthDate,
        gender: event.gender,
        identifierValue: event.identifierValue,
        contactPhone: event.contactPhone,
        availableSources: availableSources,
      );

      await _loadPatients(emit, preserveOrder: true);

      final finalExpandedIds = wasExpanded
          ? state.expandedPatientIds
          : <String>{};

      final currentBloodType = await _patientEditService.getCurrentBloodType(
        currentPatient,
      );
      if (currentBloodType != event.bloodType) {
        await _patientEditService.updateBloodTypeObservation(
          currentPatient,
          event.bloodType,
        );
      }

      emit(
        state.copyWith(
          isEditingPatient: false,
          editingPatient: null,
          expandedPatientIds: finalExpandedIds,
          animationPhase: PatientAnimationPhase.none,
          animatingPatientId: '',
          collapsingPatientId: '',
          expandingPatientId: '',
          swappingFromPatientId: '',
          swappingToPatientId: '',
        ),
      );
    } catch (e) {
      logger.e('Error in _onEditSaved: $e');
      emit(
        state.copyWith(
          status: PatientStatus.failure(e),
          isEditingPatient: false,
          editingPatient: null,
        ),
      );
    }
  }

  Future<void> _onSelectionChanged(
    PatientSelectionChanged event,
    Emitter<PatientState> emit,
  ) async {
    try {
      final updatedPatients = List<Patient>.from(state.patients);
      final index = updatedPatients.indexWhere((p) => p.id == event.patientId);
      if (index > 0) {
        final patient = updatedPatients.removeAt(index);
        updatedPatients.insert(0, patient);
      }

      emit(
        state.copyWith(
          patients: updatedPatients,
          selectedPatientId: event.patientId,
          expandedPatientIds: {event.patientId},
        ),
      );
      await _selection.select(_holderIdOf(event.patientId));
    } catch (e) {
      logger.e('Error in _onSelectionChanged: $e');
      emit(
        state.copyWith(
          status: PatientStatus.failure(e),
        ),
      );
    }
  }
}
