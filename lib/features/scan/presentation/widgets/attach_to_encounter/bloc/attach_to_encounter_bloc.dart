import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/scan/domain/entity/staged_resource.dart';
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
    try {
      final allPatientsResources = await _recordsRepository.getResources(
        resourceTypes: [FhirType.Patient],
        limit: 100,
      );

      final allPatients = allPatientsResources.whereType<Patient>().toList();
      List<Patient> uniquePatients =
          _deduplicationService.getUniquePatients(allPatients);

      if (uniquePatients.isEmpty) {
        emit(state.copyWith(
          status: AttachToEncounterStatus.success,
          existingPatients: [],
        ));
        return;
      }

      dynamic selectedPatient = event.patient.draft ?? uniquePatients.first;

      if (event.patient.existing != null) {
        selectedPatient = uniquePatients
            .firstWhere((patient) => patient.id == event.patient.existing!.id);
      }

      emit(state.copyWith(
        existingPatients: uniquePatients,
        selectedPatient: selectedPatient,
        patient: event.patient.copyWith(
            draft: (selectedPatient is MappingPatient)
                ? selectedPatient
                : event.patient.draft,
            existing: (selectedPatient is Patient)
                ? selectedPatient
                : event.patient.existing,
            mode: (selectedPatient is MappingPatient)
                ? ImportMode.createNew
                : ImportMode.linkExisting),
        encounter: event.encounter,
      ));

      if (selectedPatient is Patient) {
        await _loadEncounters(emit, selectedPatient);
      }

      emit(state.copyWith(status: AttachToEncounterStatus.success));
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
    if (event.patient is MappingPatient) {
      emit(state.copyWith(
        patient: state.patient.copyWith(
          mode: ImportMode.createNew,
          existing: null,
        ),
        encounter: state.encounter.copyWith(existing: null),
        existingEncounters: [],
        selectedPatient: event.patient,
      ));
    }

    if (event.patient is Patient) {
      emit(state.copyWith(
        selectedPatient: event.patient,
        patient: state.patient.copyWith(
          existing: event.patient,
          mode: ImportMode.linkExisting,
        ),
        encounter: state.encounter.copyWith(existing: null),
        status: AttachToEncounterStatus.loading,
      ));
      await _loadEncounters(emit, event.patient);
    }
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

      emit(state.copyWith(
        status: AttachToEncounterStatus.success,
        existingEncounters: encounters,
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
    final filtered = _filterEncounters(state.existingEncounters, event.query);
    emit(state.copyWith(
      searchQuery: event.query,
      filteredEncounters: filtered,
    ));
  }

  Future<void> _onEncounterSelected(
    AttachToEncounterSelected event,
    Emitter<AttachToEncounterState> emit,
  ) async {
    if (event.encounter is MappingEncounter) {
      emit(state.copyWith(
        encounter: state.encounter.copyWith(
          existing: null,
          mode: ImportMode.createNew,
        ),
      ));
    }
    if (event.encounter is Encounter) {
      emit(state.copyWith(
        encounter: state.encounter.copyWith(
          existing: event.encounter,
          mode: ImportMode.linkExisting,
        ),
      ));
    }
  }

  Future<void> _onNewEncounterCreated(
    AttachToEncounterNewEncounterCreated event,
    Emitter<AttachToEncounterState> emit,
  ) async {
    emit(state.copyWith(
      encounter: state.encounter.copyWith(
        draft: event.encounter,
        mode: ImportMode.createNew,
      ),
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
