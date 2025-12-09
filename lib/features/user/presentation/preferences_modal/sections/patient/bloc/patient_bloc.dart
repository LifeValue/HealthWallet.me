import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/services/patient_edit_service.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'patient_bloc.freezed.dart';
part 'patient_event.dart';
part 'patient_state.dart';

@injectable
class PatientBloc extends Bloc<PatientEvent, PatientState> {
  final RecordsRepository _recordsRepository;
  final PatientDeduplicationService _deduplicationService;
  final PatientEditService _patientEditService;
  static const String _selectedPatientIdKey = 'selected_patient_id';

  PatientBloc(
    this._recordsRepository,
    this._deduplicationService,
    this._patientEditService,
  ) : super(const PatientState()) {
    on<PatientInitialised>(_onInitialised);
    on<PatientPatientsLoaded>(_onPatientsLoaded);
    on<PatientReorder>(_onPatientReorder);
    on<PatientDataUpdatedFromSync>(_onDataUpdatedFromSync);
    on<PatientEditStarted>(_onEditStarted);
    on<PatientEditCancelled>(_onEditCancelled);
    on<PatientEditSaved>(_onEditSaved);
    on<PatientSelectionChanged>(_onSelectionChanged);
  }

  Future<void> _saveSelectedPatient(String patientId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedPatientIdKey, patientId);
  }

  Future<String?> _loadSelectedPatient() async {
    final prefs = await SharedPreferences.getInstance();
    final patientId = prefs.getString(_selectedPatientIdKey);
    return patientId;
  }

  Future<void> _onInitialised(
    PatientInitialised event,
    Emitter<PatientState> emit,
  ) async {
    await _loadPatients(emit);
  }

  PatientGroup? _findMatchingGroupByOldPatient(
    Map<String, PatientGroup> newGroups,
    PatientGroup oldGroup,
  ) {
    final oldRepresentative = oldGroup.representativePatient;
    
    for (final group in newGroups.values) {
      final hasMatchingResourceId = group.allPatientInstances
          .any((p) => p.resourceId == oldRepresentative.resourceId);
      
      if (hasMatchingResourceId) {
        return group;
      }
      
      final oldIdentifiers = oldRepresentative.identifier
          ?.where((id) => id.value?.isNotEmpty == true)
          .map((id) => id.value)
          .toSet();
      final newIdentifiers = group.representativePatient.identifier
          ?.where((id) => id.value?.isNotEmpty == true)
          .map((id) => id.value)
          .toSet();
      
      if (oldIdentifiers != null &&
          newIdentifiers != null &&
          oldIdentifiers.intersection(newIdentifiers).isNotEmpty) {
        return group;
      }
    }
    
    return null;
  }

  Future<void> _loadPatients(
    Emitter<PatientState> emit, {
    bool preserveOrder = false,
    String? preservePatientId,
  }) async {
    emit(state.copyWith(status: const PatientStatus.loading()));

    try {
      int? oldPosition;
      if (preserveOrder && preservePatientId != null) {
        oldPosition =
            state.patients.indexWhere((p) => p.id == preservePatientId);
      }

      final allPatientsResources = await _recordsRepository.getResources(
        resourceTypes: [FhirType.Patient],
        limit: 100,
      );

      final allPatients = allPatientsResources.whereType<Patient>().toList();

      final uniquePatients =
          _deduplicationService.getUniquePatients(allPatients);

      final patientGroups =
          _deduplicationService.deduplicatePatients(allPatients);

      final patientGroups_enhanced =
          await _deduplicationService.enhancePatientGroupsWithSubjectId(
        patientGroups,
        allPatients,
      );

      final savedPatientId = await _loadSelectedPatient();

      Set<String> expandedIds = <String>{};
      String? selectedPatientId;
      Patient? patientToPreserve;

      if (preserveOrder &&
          preservePatientId != null &&
          oldPosition != null &&
          oldPosition >= 0) {
        var matchingGroup = _deduplicationService.findPatientGroup(
          patientGroups_enhanced,
          preservePatientId,
        );

        if (matchingGroup == null) {
          final oldPatientGroup = state.patientGroups[preservePatientId];
          if (oldPatientGroup != null) {
            matchingGroup = _findMatchingGroupByOldPatient(
              patientGroups_enhanced,
              oldPatientGroup,
            );
          }
        }

        if (matchingGroup != null) {
          patientToPreserve = matchingGroup.representativePatient;
          selectedPatientId = patientToPreserve.id;
          expandedIds = {patientToPreserve.id};
        }
      }

      if (preserveOrder &&
          patientToPreserve != null &&
          oldPosition != null &&
          oldPosition >= 0) {
        final patient = patientToPreserve;
        final position = oldPosition;
        final newPatientIndex =
            uniquePatients.indexWhere((p) => p.id == patient.id);
        if (newPatientIndex != -1) {
          uniquePatients.removeAt(newPatientIndex);
          final insertIndex = position < uniquePatients.length
              ? position
              : uniquePatients.length;
          uniquePatients.insert(insertIndex, patient);
        }
      } else {
        if (savedPatientId != null &&
            uniquePatients.any((p) => p.id == savedPatientId)) {
          final savedPatient =
              uniquePatients.firstWhere((p) => p.id == savedPatientId);
          expandedIds = {savedPatient.id};
          selectedPatientId = savedPatient.id;

          if (uniquePatients.first.id != savedPatient.id) {
            uniquePatients.remove(savedPatient);
            uniquePatients.insert(0, savedPatient);
          }
        } else {
          expandedIds = uniquePatients.isNotEmpty
              ? {uniquePatients.first.id}
              : <String>{};
          if (uniquePatients.isNotEmpty) {
            selectedPatientId = uniquePatients.first.id;
          }
        }
      }

      emit(state.copyWith(
        status: const PatientStatus.success(),
        patients: uniquePatients,
        allPatientsAcrossSources: allPatients,
        patientGroups: patientGroups_enhanced,
        expandedPatientIds: expandedIds,
        selectedPatientId: selectedPatientId,
      ));

      if (selectedPatientId != null) {
        await _saveSelectedPatient(selectedPatientId);
      }
    } catch (e) {
      logger.e('Error in _loadPatients: $e');
      emit(state.copyWith(status: PatientStatus.failure(e)));
    }
  }

  Future<void> _onPatientsLoaded(
    PatientPatientsLoaded event,
    Emitter<PatientState> emit,
  ) async {
    await _loadPatients(emit,
        preserveOrder: event.preserveOrder,
        preservePatientId: event.preservePatientId);
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

    emit(state.copyWith(
      animationPhase: PatientAnimationPhase.collapsing,
      animatingPatientId: event.patientId,
    ));

    if (currentExpandedIds.isNotEmpty) {
      final collapsingPatientId = currentExpandedIds.first;

      emit(state.copyWith(
        collapsingPatientId: collapsingPatientId,
      ));

      await Future.delayed(const Duration(milliseconds: 560));

      currentExpandedIds.clear();
      emit(state.copyWith(
        expandedPatientIds: currentExpandedIds,
        collapsingPatientId: '',
      ));

      await Future.delayed(const Duration(milliseconds: 840));
    }

    emit(state.copyWith(
      animationPhase: PatientAnimationPhase.swapping,
      swappingFromPatientId: currentPatients[0].id,
      swappingToPatientId: event.patientId,
    ));

    await Future.delayed(const Duration(milliseconds: 140));

    currentPatients.remove(selectedPatient);
    currentPatients.insert(0, selectedPatient);

    await _saveSelectedPatient(selectedPatient.id);

    emit(state.copyWith(
      patients: currentPatients,
      selectedPatientId: selectedPatient.id,
      swappingFromPatientId: '',
      swappingToPatientId: '',
    ));

    await Future.delayed(const Duration(milliseconds: 560));

    currentExpandedIds.add(event.patientId);
    emit(state.copyWith(
      animationPhase: PatientAnimationPhase.expanding,
      expandedPatientIds: currentExpandedIds,
      expandingPatientId: event.patientId,
    ));

    await Future.delayed(const Duration(milliseconds: 840));

    emit(state.copyWith(
      expandingPatientId: '',
    ));

    await Future.delayed(const Duration(milliseconds: 140));

    emit(state.copyWith(
      animationPhase: PatientAnimationPhase.none,
      animatingPatientId: '',
      collapsingPatientId: '',
      expandingPatientId: '',
      swappingFromPatientId: '',
      swappingToPatientId: '',
    ));
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

    emit(state.copyWith(
      isEditingPatient: true,
      editingPatient: patient,
    ));
  }

  Future<void> _onEditCancelled(
    PatientEditCancelled event,
    Emitter<PatientState> emit,
  ) async {
    emit(state.copyWith(
      isEditingPatient: false,
      editingPatient: null,
    ));
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
        mrn: event.mrn,
        availableSources: availableSources,
      );

      await _loadPatients(
        emit,
        preserveOrder: true,
        preservePatientId: event.patientId,
      );

      final finalExpandedIds =
          wasExpanded ? state.expandedPatientIds : <String>{};

      final currentBloodType =
          await _patientEditService.getCurrentBloodType(currentPatient);
      if (currentBloodType != event.bloodType) {
        await _patientEditService.updateBloodTypeObservation(
          currentPatient,
          event.bloodType,
        );
      }

      emit(state.copyWith(
        isEditingPatient: false,
        editingPatient: null,
        expandedPatientIds: finalExpandedIds,
        animationPhase: PatientAnimationPhase.none,
        animatingPatientId: '',
        collapsingPatientId: '',
        expandingPatientId: '',
        swappingFromPatientId: '',
        swappingToPatientId: '',
      ));
    } catch (e) {
      logger.e('Error in _onEditSaved: $e');
      emit(state.copyWith(
        status: PatientStatus.failure(e),
        isEditingPatient: false,
        editingPatient: null,
      ));
    }
  }

  Future<void> _onSelectionChanged(
    PatientSelectionChanged event,
    Emitter<PatientState> emit,
  ) async {
    try {
      await _saveSelectedPatient(event.patientId);

      emit(state.copyWith(
        selectedPatientId: event.patientId,
        expandedPatientIds: {event.patientId},
      ));
    } catch (e) {
      logger.e('Error in _onSelectionChanged: $e');
      emit(state.copyWith(
        status: PatientStatus.failure(e),
      ));
    }
  }
}
