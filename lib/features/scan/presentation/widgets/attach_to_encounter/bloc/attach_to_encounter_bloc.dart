import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';
import 'package:injectable/injectable.dart';

part 'attach_to_encounter_event.dart';
part 'attach_to_encounter_state.dart';
part 'attach_to_encounter_bloc.freezed.dart';

@injectable
class AttachToEncounterBloc
    extends Bloc<AttachToEncounterEvent, AttachToEncounterState> {
  final RecordsRepository _recordsRepository;
  final PatientDeduplicationService _deduplicationService;

  AttachToEncounterBloc(
    this._recordsRepository,
    this._deduplicationService,
  ) : super(const AttachToEncounterState()) {
    on<AttachToEncounterStarted>(_onStarted);
    on<AttachToEncounterPatientChanged>(_onPatientChanged);
    on<AttachToEncounterSearchQueryChanged>(_onSearchQueryChanged);
    on<AttachToEncounterSelected>(_onEncounterSelected);
    on<AttachToEncounterNewEncounterCreated>(_onNewEncounterCreated);
  }

  Future<void> _onStarted(
    AttachToEncounterStarted event,
    Emitter<AttachToEncounterState> emit,
  ) async {
    emit(state.copyWith(status: AttachToEncounterStatus.loading));

    try {
      final allPatientsResources = await _recordsRepository.getResources(
        resourceTypes: [FhirType.Patient],
        limit: 100,
      );

      final allPatients = allPatientsResources.whereType<Patient>().toList();
      List<Patient> uniquePatients =
          _deduplicationService.getUniquePatients(allPatients);

      if (uniquePatients.isEmpty && event.newPatient == null) {
        emit(state.copyWith(
          status: AttachToEncounterStatus.success,
          patients: [],
        ));
        return;
      }

      if (event.newPatient != null) {
        uniquePatients = [
          event.newPatient!.toFhirResource() as Patient,
          ...uniquePatients
        ];
      }

      final selectedPatient = uniquePatients.first;

      emit(state.copyWith(
        patients: uniquePatients,
        selectedPatient: selectedPatient,
        newPatient: event.newPatient,
        newEncounter: event.newEncounter,
      ));

      await _loadEncounters(emit, selectedPatient);
    } catch (e) {
      logger.e('Error loading patients in AttachToEncounterBloc: $e');
      emit(state.copyWith(
        status: AttachToEncounterStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onPatientChanged(
    AttachToEncounterPatientChanged event,
    Emitter<AttachToEncounterState> emit,
  ) async {
    emit(state.copyWith(
      selectedPatient: event.patient,
      status: AttachToEncounterStatus.loading,
    ));
    await _loadEncounters(emit, event.patient);
  }

  Future<void> _loadEncounters(
    Emitter<AttachToEncounterState> emit,
    Patient patient,
  ) async {
    try {
      final sourceId = patient.sourceId;

      final resources = await _recordsRepository.getResources(
        resourceTypes: [FhirType.Encounter],
        sourceId: sourceId,
        limit: 100,
      );

      List<Encounter> encounters = resources.whereType<Encounter>().toList();

      if (state.newEncounter != null) {
        encounters = [
          state.newEncounter!.toFhirResource() as Encounter,
          ...encounters
        ];
      }

      emit(state.copyWith(
        status: AttachToEncounterStatus.success,
        encounters: encounters,
        filteredEncounters: _filterEncounters(encounters, state.searchQuery),
      ));
    } catch (e) {
      logger.e('Error loading encounters: $e');
      emit(state.copyWith(
        status: AttachToEncounterStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSearchQueryChanged(
    AttachToEncounterSearchQueryChanged event,
    Emitter<AttachToEncounterState> emit,
  ) async {
    final filtered = _filterEncounters(state.encounters, event.query);
    emit(state.copyWith(
      searchQuery: event.query,
      filteredEncounters: filtered,
    ));
  }

  Future<void> _onEncounterSelected(
    AttachToEncounterSelected event,
    Emitter<AttachToEncounterState> emit,
  ) async {
    emit(state.copyWith(selectedEncounter: event.encounter));
  }

  Future<void> _onNewEncounterCreated(
    AttachToEncounterNewEncounterCreated event,
    Emitter<AttachToEncounterState> emit,
  ) async {
    final newEncounter = event.newEncounter.toFhirResource() as Encounter;
    final updatedEncounters = [newEncounter, ...state.encounters];
    final filteredEncounters =
        _filterEncounters(updatedEncounters, state.searchQuery);

    emit(state.copyWith(
      newEncounter: event.newEncounter,
      encounters: updatedEncounters,
      filteredEncounters: filteredEncounters,
      selectedEncounter: newEncounter,
    ));
  }

  List<Encounter> _filterEncounters(List<Encounter> encounters, String query) {
    if (query.isEmpty) return encounters;
    final lowerQuery = query.toLowerCase();
    return encounters.where((encounter) {
      return encounter.title.toLowerCase().contains(lowerQuery) ||
          encounter.displayTitle.toLowerCase().contains(lowerQuery) ||
          encounter.id.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}
