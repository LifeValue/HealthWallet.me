import 'dart:async';
import 'dart:math' as math;

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/entities/overview_card.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';
import 'package:health_wallet/features/home/domain/entities/specialty_card.dart';
import 'package:health_wallet/features/home/domain/factory/patient_vitals_factory.dart';
import 'package:health_wallet/features/home/domain/repository/home_preferences_repository.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/home/presentation/bloc/handlers/home_data_handler.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/use_case/get_sources_use_case.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'home_bloc.freezed.dart';
part 'home_event.dart';
part 'home_state.dart';

@lazySingleton
class HomeBloc extends Bloc<HomeEvent, HomeState> with HomeDataHandler {
  @override
  final RecordsRepository recordsRepository;
  final GetSourcesUseCase _getSourcesUseCase;
  @override
  final HomePreferencesRepository homePreferences;
  final SyncRepository _syncRepository;
  final HolderSelection _selection;
  late final StreamSubscription<HolderScope> _scopeChanges;
  @override
  final PatientVitalFactory patientVitalFactory = PatientVitalFactory();
  final SpecialtyClassifier _specialtyClassifier;

  @override
  SpecialtyClassifier get specialtyClassifier => _specialtyClassifier;

  static const int _minVisibleVitalsCount = 4;

  HomeBloc(
    this._getSourcesUseCase,
    this.homePreferences,
    this.recordsRepository,
    this._syncRepository,
    this._selection,
    this._specialtyClassifier,
  ) : super(const HomeState()) {
    on<HomeInitialised>(_onInitialised, transformer: restartable());
    on<HomeSourceChanged>(_onSourceChanged, transformer: sequential());
    on<HomeScopeChanged>(_onScopeChanged, transformer: restartable());
    on<HomeRecordsFiltersChanged>(
      _onRecordsFiltersChanged,
      transformer: restartable(),
    );
    on<HomeVitalsFiltersChanged>(
      _onVitalsFiltersChanged,
      transformer: sequential(),
    );
    on<HomeEditModeChanged>(
      (e, emit) => emit(state.copyWith(editMode: e.editMode)),
      transformer: sequential(),
    );
    on<HomeRecordsReordered>(_onRecordsReordered, transformer: sequential());
    on<HomeVitalsReordered>(_onVitalsReordered, transformer: sequential());
    on<HomeVitalsExpansionToggled>(
      (e, emit) => emit(state.copyWith(vitalsExpanded: !state.vitalsExpanded)),
      transformer: sequential(),
    );
    on<HomeRefreshPreservingOrder>(
      _onRefreshPreservingOrder,
      transformer: restartable(),
    );
    on<HomeScanCompleted>(_onScanCompleted, transformer: sequential());
    on<HomeSourceLabelUpdated>(
      _onSourceLabelUpdated,
      transformer: sequential(),
    );
    on<HomeSourceDeleted>(_onSourceDeleted, transformer: sequential());
    on<HomeOverviewViewModeChanged>(
      _onOverviewViewModeChanged,
      transformer: sequential(),
    );
    on<HomeSpecialtiesReordered>(
      _onSpecialtiesReordered,
      transformer: sequential(),
    );
    on<HomeSpecialtiesFiltersChanged>(
      _onSpecialtiesFiltersChanged,
      transformer: sequential(),
    );
    _scopeChanges = _selection.changes.listen(
      (_) => add(const HomeScopeChanged()),
    );
  }

  @override
  Future<void> close() async {
    await _scopeChanges.cancel();
    return super.close();
  }

  bool hasData({
    required List<PatientVital> patientVitals,
    required List<OverviewCard> overviewCards,
    required List<IFhirResource> recentRecords,
  }) {
    final hasVitals = patientVitals.isNotEmpty;
    final hasOverview = overviewCards.isNotEmpty;
    final hasRecent = recentRecords.isNotEmpty;

    final result = hasVitals || hasOverview || hasRecent;
    return result;
  }

  Future<void> _onInitialised(
    HomeInitialised e,
    Emitter<HomeState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final savedViewMode = prefs.getString(
      SharedPrefsConstants.overviewViewMode,
    );
    if (savedViewMode != null) {
      final mode = OverviewViewMode.values.firstWhere(
        (m) => m.name == savedViewMode,
        orElse: () => OverviewViewMode.specialties,
      );
      emit(state.copyWith(overviewViewMode: mode));
    }

    if (_hasExistingVitalsData() && !_shouldForceRefresh()) {
      emit(state.copyWith());
    } else {
      await _reloadHomeData(emit);
    }
  }

  bool _hasExistingVitalsData() {
    return state.allAvailableVitals.isNotEmpty &&
        state.patientVitals.isNotEmpty &&
        state.status != const HomeStatus.loading();
  }

  bool _shouldForceRefresh() {
    final hasOnlyPlaceholders =
        state.patientVitals.isNotEmpty &&
        state.patientVitals.every((v) => v.value == 'N/A');
    final hasOnlyZeroCounts =
        state.overviewCards.isNotEmpty &&
        state.overviewCards.every((c) => c.count == '0');
    return hasOnlyPlaceholders || hasOnlyZeroCounts;
  }

  Future<void> _onRefreshPreservingOrder(
    HomeRefreshPreservingOrder e,
    Emitter<HomeState> emit,
  ) async {
    await _reloadHomeData(emit);
  }

  /// A scan shows all of the person's sources, so its records are in view.
  Future<void> _onScanCompleted(
    HomeScanCompleted e,
    Emitter<HomeState> emit,
  ) => _selection.filter(null);

  /// The new filter comes back as a [HomeScopeChanged].
  Future<void> _onSourceChanged(
    HomeSourceChanged e,
    Emitter<HomeState> emit,
  ) => _selection.filter(e.source);

  Future<void> _onScopeChanged(
    HomeScopeChanged e,
    Emitter<HomeState> emit,
  ) => _reloadHomeData(emit);

  Future<void> _onVitalsFiltersChanged(
    HomeVitalsFiltersChanged e,
    Emitter<HomeState> emit,
  ) async {
    final toSave = <String, bool>{
      for (final entry in e.filters.entries) entry.key.title: entry.value,
    };
    await homePreferences.saveVitalsVisibility(toSave);
    final filtered = _filterVitalsByVisibility(
      state.allAvailableVitals,
      e.filters,
    );
    emit(state.copyWith(selectedVitals: e.filters, patientVitals: filtered));
  }

  Future<void> _onVitalsReordered(
    HomeVitalsReordered e,
    Emitter<HomeState> emit,
  ) async {
    try {
      final master = List.of(state.allAvailableVitals);
      if (!_validateReorderIndices(e.oldIndex, e.newIndex, master.length)) {
        return;
      }

      final moved = master.removeAt(e.oldIndex);
      master.insert(e.newIndex, moved);
      await _handleAutoVisibility(moved, e.newIndex, emit);
      await homePreferences.saveVitalsOrder(
        master.map((v) => v.title).toList(),
      );
      final filtered = _filterVitalsByVisibility(master, state.selectedVitals);
      emit(state.copyWith(allAvailableVitals: master, patientVitals: filtered));
    } catch (err) {
      logger.e('Vitals reorder error: $err');
    }
  }

  Future<void> _onOverviewViewModeChanged(
    HomeOverviewViewModeChanged e,
    Emitter<HomeState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPrefsConstants.overviewViewMode, e.mode.name);
    emit(state.copyWith(overviewViewMode: e.mode));
  }

  Future<void> _onRecordsFiltersChanged(
    HomeRecordsFiltersChanged e,
    Emitter<HomeState> emit,
  ) async {
    final toSave = <String, bool>{
      for (final entry in e.filters.entries) entry.key.display: entry.value,
    };
    await homePreferences.saveRecordsVisibility(toSave);
    emit(state.copyWith(selectedRecordTypes: e.filters));
    await _reloadHomeData(emit);
  }

  Future<void> _onSpecialtiesFiltersChanged(
    HomeSpecialtiesFiltersChanged e,
    Emitter<HomeState> emit,
  ) async {
    final toSave = <String, bool>{
      for (final entry in e.filters.entries) entry.key.name: entry.value,
    };
    await homePreferences.saveSpecialtiesVisibility(toSave);
    emit(state.copyWith(selectedSpecialties: e.filters));
  }

  Future<void> _onSpecialtiesReordered(
    HomeSpecialtiesReordered e,
    Emitter<HomeState> emit,
  ) async {
    try {
      final cards = List.of(state.specialtyCards);
      if (!_validateReorderIndices(e.oldIndex, e.newIndex, cards.length)) {
        return;
      }

      final item = cards.removeAt(e.oldIndex);
      cards.insert(e.newIndex, item);
      await homePreferences.saveSpecialtiesOrder(
        cards.map((c) => c.specialty.name).toList(),
      );
      emit(state.copyWith(specialtyCards: cards));
    } catch (err) {
      logger.e('Specialties reorder error: $err');
    }
  }

  Future<void> _onRecordsReordered(
    HomeRecordsReordered e,
    Emitter<HomeState> emit,
  ) async {
    try {
      final cards = List.of(state.overviewCards);
      if (!_validateReorderIndices(e.oldIndex, e.newIndex, cards.length)) {
        return;
      }

      final item = cards.removeAt(e.oldIndex);
      cards.insert(e.newIndex, item);
      await homePreferences.saveRecordsOrder(
        cards.map((c) => c.category.display).toList(),
      );
      emit(state.copyWith(overviewCards: cards));
    } catch (err) {
      logger.e('Records reorder error: $err');
    }
  }

  List<PatientVital> _filterVitalsByVisibility(
    List<PatientVital> allVitals,
    Map<PatientVitalType, bool> visibilityMap,
  ) {
    return allVitals
        .where(
          (v) => visibilityMap.entries
              .where((entry) => entry.value)
              .any((entry) => entry.key.title == v.title),
        )
        .toList(growable: false);
  }

  bool _validateReorderIndices(int oldIndex, int newIndex, int length) {
    final ok =
        oldIndex >= 0 &&
        oldIndex < length &&
        newIndex >= 0 &&
        newIndex <= length;
    if (!ok) {
      logger.e('Invalid reorder indices: $oldIndex -> $newIndex of $length');
    }
    return ok;
  }

  Future<void> _handleAutoVisibility(
    PatientVital vital,
    int newIndex,
    Emitter<HomeState> emit,
  ) async {
    final currentVisibleCount = state.selectedVitals.entries
        .where((e) => e.value)
        .length;
    final effectiveVisibleArea = math.max(
      currentVisibleCount,
      _minVisibleVitalsCount,
    );

    if (newIndex < effectiveVisibleArea) {
      final vitalType = PatientVitalTypeX.fromTitle(vital.title);
      if (vitalType != null && !(state.selectedVitals[vitalType] ?? false)) {
        final updated = Map<PatientVitalType, bool>.from(state.selectedVitals);
        updated[vitalType] = true;
        await homePreferences.saveVitalsVisibility({
          for (final e in updated.entries) e.key.title: e.value,
        });
        emit(state.copyWith(selectedVitals: updated));
      }
    }
  }

  /// Loads what Home shows for the current selection.
  Future<void> _reloadHomeData(Emitter<HomeState> emit) async {
    final scope = _selection.scope;
    emit(
      state.copyWith(
        status: const HomeStatus.loading(),
        scope: scope,
        selectedSource: scope.sourceFilter ?? 'All',
      ),
    );
    try {
      final sourceId = scope.sourceFilter;
      final sourceIds = scope.sourceIds;

      final sources = await _getSourcesUseCase();
      final overview = await fetchOverviewCardsAndResources(
        sourceId,
        sourceIds,
      );
      final vitalsData = await processVitalsData(sourceId, sourceIds);
      final reorderedCards = await applyOverviewCardsOrder(
        overview.overviewCards,
      );
      final specialtyCards = await classifyIntoSpecialties(
        overview.allEnabledResources,
      );

      final savedSpecialtiesVisibility = await homePreferences
          .getSpecialtiesVisibility();
      final updatedSelectedSpecialties = Map<MedicalSpecialty, bool>.from(
        state.selectedSpecialties,
      );
      if (savedSpecialtiesVisibility != null) {
        updatedSelectedSpecialties.updateAll(
          (specialty, value) =>
              savedSpecialtiesVisibility[specialty.name] ?? value,
        );
      }

      final hasDataResult = hasData(
        patientVitals: vitalsData.patientVitals,
        overviewCards: reorderedCards,
        recentRecords: overview.allEnabledResources.take(3).toList(),
      );

      emit(
        state.copyWith(
          status: const HomeStatus.success(),
          sources: sources,
          patient: scope.patient,
          overviewCards: reorderedCards,
          recentRecords: overview.allEnabledResources.take(3).toList(),
          allAvailableVitals: vitalsData.allAvailableVitals,
          patientVitals: vitalsData.patientVitals,
          selectedVitals: vitalsData.selectedVitals,
          selectedRecordTypes: overview.selectedRecordTypes,
          hasDataLoaded: hasDataResult,
          specialtyCards: specialtyCards,
          selectedSpecialties: updatedSelectedSpecialties,
        ),
      );
    } catch (err, stackTrace) {
      logger.e('reloadHomeData error: $err');
      logger.e('reloadHomeData stack trace: $stackTrace');
      emit(
        state.copyWith(
          status: HomeStatus.failure('Failed to load home data: $err'),
          errorMessage: err.toString(),
        ),
      );
    }
  }

  Future<void> _onSourceLabelUpdated(
    HomeSourceLabelUpdated event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final updatedSources = state.sources.map((source) {
        if (source.id == event.sourceId) {
          return source.copyWith(labelSource: event.newLabel);
        }
        return source;
      }).toList();

      await _syncRepository.updateSourceLabel(event.sourceId, event.newLabel);

      emit(state.copyWith(sources: updatedSources));
    } catch (e) {
      logger.e('Error updating source label: $e');
    }
  }

  /// Deletes the source and reads the people again, which drops it from
  /// the selection and from the person's sources.
  Future<void> _onSourceDeleted(
    HomeSourceDeleted event,
    Emitter<HomeState> emit,
  ) async {
    try {
      await _syncRepository.deleteSource(event.sourceId);
      emit(
        state.copyWith(
          sources: state.sources.where((s) => s.id != event.sourceId).toList(),
        ),
      );
      await _selection.refresh();
    } catch (e) {
      logger.e('Error deleting source: $e');
    }
  }
}
