import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
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
      final uniquePatients =
          _deduplicationService.getUniquePatients(allPatients);

      if (uniquePatients.isEmpty) {
        emit(state.copyWith(
          status: AttachToEncounterStatus.success,
          patients: [],
        ));
        return;
      }

      final selectedPatientId = uniquePatients.first.id;

      emit(state.copyWith(
        patients: uniquePatients,
        selectedPatientId: selectedPatientId,
      ));

      await _loadEncounters(emit, selectedPatientId);
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
      selectedPatientId: event.patientId,
      status: AttachToEncounterStatus.loading,
    ));
    await _loadEncounters(emit, event.patientId);
  }

  Future<void> _loadEncounters(
    Emitter<AttachToEncounterState> emit,
    String patientId,
  ) async {
    try {
      final patient = state.patients.firstWhere((p) => p.id == patientId);
      final sourceId = patient.sourceId;

      final resources = await _recordsRepository.getResources(
        resourceTypes: [FhirType.Encounter],
        sourceId: sourceId,
        limit: 100,
      );

      final encounters = resources.whereType<Encounter>().toList();

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