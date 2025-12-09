import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:health_wallet/features/home/data/data_source/local/home_local_data_source.dart';
import 'package:health_wallet/features/home/domain/entities/overview_card.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';
import 'package:health_wallet/features/home/domain/factory/patient_vitals_factory.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/use_case/get_sources_use_case.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_selection_service.dart';

part 'home_bloc.freezed.dart';
part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final RecordsRepository _recordsRepository;
  final GetSourcesUseCase _getSourcesUseCase;
  final HomeLocalDataSource _homeLocalDataSource;
  final SyncRepository _syncRepository;
  final PatientDeduplicationService _deduplicationService;
  final PatientSelectionService _patientSelectionService;
  final PatientVitalFactory _patientVitalFactory = PatientVitalFactory();

  static const int _minVisibleVitalsCount = 4;
  static const String _demoSourceId = 'demo_data';

  HomeBloc(
    this._getSourcesUseCase,
    this._homeLocalDataSource,
    this._recordsRepository,
    this._syncRepository,
    this._deduplicationService,
    this._patientSelectionService,
  ) : super(const HomeState()) {
    on<HomeInitialised>(_onInitialised);
    on<HomeSourceChanged>(_onSourceChanged);
    on<HomeRecordsFiltersChanged>(_onRecordsFiltersChanged);
    on<HomeVitalsFiltersChanged>(_onVitalsFiltersChanged);
    on<HomeEditModeChanged>(
        (e, emit) => emit(state.copyWith(editMode: e.editMode)));
    on<HomeRecordsReordered>(_onRecordsReordered);
    on<HomeVitalsReordered>(_onVitalsReordered);
    on<HomeVitalsExpansionToggled>((e, emit) =>
        emit(state.copyWith(vitalsExpanded: !state.vitalsExpanded)));
    on<HomeRefreshPreservingOrder>(_onRefreshPreservingOrder);
    on<HomeSourceLabelUpdated>(_onSourceLabelUpdated);
    on<HomeSourceDeleted>(_onSourceDeleted);
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
      HomeInitialised e, Emitter<HomeState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final savedSource = prefs.getString('home_selected_source_id');

    if (savedSource != null) {
      emit(state.copyWith(selectedSource: savedSource));
    } else {
      emit(state.copyWith(selectedSource: 'All'));
    }

    if (_hasExistingVitalsData() && !_shouldForceRefresh()) {
      emit(state.copyWith());
    } else {
      await _reloadHomeData(emit, force: true, overrideSourceId: savedSource);
    }
  }

  bool _hasExistingVitalsData() {
    return state.allAvailableVitals.isNotEmpty &&
        state.patientVitals.isNotEmpty &&
        state.status != const HomeStatus.loading();
  }

  bool _shouldForceRefresh() {
    final hasOnlyPlaceholders = state.patientVitals.isNotEmpty &&
        state.patientVitals.every((v) => v.value == 'N/A');
    final hasOnlyZeroCounts = state.overviewCards.isNotEmpty &&
        state.overviewCards.every((c) => c.count == '0');
    return hasOnlyPlaceholders || hasOnlyZeroCounts;
  }

  Future<void> _onRefreshPreservingOrder(
      HomeRefreshPreservingOrder e, Emitter<HomeState> emit) async {
    await _reloadHomeData(emit,
        force: true, overrideSourceId: state.selectedSource);
  }

  Future<void> _onSourceChanged(
      HomeSourceChanged e, Emitter<HomeState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('home_selected_source_id', e.source);

    emit(state.copyWith(selectedSource: e.source));
    await _reloadHomeData(emit,
        force: true,
        overrideSourceId: e.source,
        patientSourceIds: e.patientSourceIds);
  }

  Future<void> _onVitalsFiltersChanged(
      HomeVitalsFiltersChanged e, Emitter<HomeState> emit) async {
    final toSave = <String, bool>{
      for (final entry in e.filters.entries) entry.key.title: entry.value
    };
    await _homeLocalDataSource.saveVitalsVisibility(toSave);
    final filtered =
        _filterVitalsByVisibility(state.allAvailableVitals, e.filters);
    emit(state.copyWith(selectedVitals: e.filters, patientVitals: filtered));
  }

  Future<void> _onVitalsReordered(
      HomeVitalsReordered e, Emitter<HomeState> emit) async {
    try {
      final master = List.of(state.allAvailableVitals);
      if (!_validateReorderIndices(e.oldIndex, e.newIndex, master.length))
        return;

      final moved = master.removeAt(e.oldIndex);
      master.insert(e.newIndex, moved);
      await _handleAutoVisibility(moved, e.newIndex, emit);
      await _homeLocalDataSource
          .saveVitalsOrder(master.map((v) => v.title).toList());
      final filtered = _filterVitalsByVisibility(master, state.selectedVitals);
      emit(state.copyWith(allAvailableVitals: master, patientVitals: filtered));
    } catch (err) {
      logger.e('Vitals reorder error: $err');
    }
  }

  Future<void> _onRecordsFiltersChanged(
      HomeRecordsFiltersChanged e, Emitter<HomeState> emit) async {
    final toSave = <String, bool>{
      for (final entry in e.filters.entries) entry.key.display: entry.value
    };
    await _homeLocalDataSource.saveRecordsVisibility(toSave);
    emit(state.copyWith(selectedRecordTypes: e.filters));
    await _reloadHomeData(emit,
        force: false,
        overrideSourceId:
            state.selectedSource != 'All' ? state.selectedSource : null);
  }

  Future<void> _onRecordsReordered(
      HomeRecordsReordered e, Emitter<HomeState> emit) async {
    try {
      final cards = List.of(state.overviewCards);
      if (!_validateReorderIndices(e.oldIndex, e.newIndex, cards.length))
        return;

      final item = cards.removeAt(e.oldIndex);
      cards.insert(e.newIndex, item);
      await _homeLocalDataSource
          .saveRecordsOrder(cards.map((c) => c.category.display).toList());
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
        .where((v) => visibilityMap.entries
            .where((entry) => entry.value)
            .any((entry) => entry.key.title == v.title))
        .toList(growable: false);
  }

  bool _validateReorderIndices(int oldIndex, int newIndex, int length) {
    final ok = oldIndex >= 0 &&
        oldIndex < length &&
        newIndex >= 0 &&
        newIndex <= length;
    if (!ok) {
      logger.e('Invalid reorder indices: $oldIndex -> $newIndex of $length');
    }
    return ok;
  }

  Future<void> _handleAutoVisibility(
      PatientVital vital, int newIndex, Emitter<HomeState> emit) async {
    final currentVisibleCount =
        state.selectedVitals.entries.where((e) => e.value).length;
    final effectiveVisibleArea =
        math.max(currentVisibleCount, _minVisibleVitalsCount);

    if (newIndex < effectiveVisibleArea) {
      final vitalType = PatientVitalTypeX.fromTitle(vital.title);
      if (vitalType != null && !(state.selectedVitals[vitalType] ?? false)) {
        final updated = Map<PatientVitalType, bool>.from(state.selectedVitals);
        updated[vitalType] = true;
        await _homeLocalDataSource.saveVitalsVisibility({
          for (final e in updated.entries) e.key.title: e.value,
        });
        emit(state.copyWith(selectedVitals: updated));
      }
    }
  }

  Future<List<Source>> _fetchSources(String? patientSourceId) async {
    return await _getSourcesUseCase();
  }

  Future<List<String>?> _getPatientSourceIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedPatientId = prefs.getString('selected_patient_id');

      if (selectedPatientId == null) {
        logger.w('No selected patient ID found');
        return null;
      }

      final allPatients = await _recordsRepository.getResources(
        resourceTypes: [FhirType.Patient],
        limit: 100,
      );

      if (allPatients.isEmpty) return null;

      final sourceIds = <String>{};
      for (final patient in allPatients) {
        if (patient.id == selectedPatientId && patient.sourceId.isNotEmpty) {
          sourceIds.add(patient.sourceId);
        }
      }

      return sourceIds.isNotEmpty ? sourceIds.toList() : null;
    } catch (e) {
      logger.e('Error getting patient source IDs: $e');
      return null;
    }
  }

  Future<
          ({
            List<OverviewCard> overviewCards,
            List<IFhirResource> allEnabledResources,
            Map<HomeRecordsCategory, bool> selectedRecordTypes
          })>
      _fetchOverviewCardsAndResources(String? sourceId,
          [List<String>? patientSourceIds]) async {
    final overviewCards = <OverviewCard>[];
    final allEnabledResources = <IFhirResource>[];
    final savedRecordsVisibility =
        await _homeLocalDataSource.getRecordsVisibility();
    final updatedSelectedRecordTypes =
        Map<HomeRecordsCategory, bool>.from(state.selectedRecordTypes);
    if (savedRecordsVisibility != null) {
      updatedSelectedRecordTypes.updateAll((category, value) =>
          savedRecordsVisibility[category.display] ?? value);
    }

    for (final category in updatedSelectedRecordTypes.keys) {
      if (updatedSelectedRecordTypes[category]!) {
        final resources = await _fetchResourcesFromAllSources(
            category.resourceTypes, sourceId, patientSourceIds);
        overviewCards.add(OverviewCard(
            category: category, count: resources.length.toString()));
        allEnabledResources.addAll(resources);
      } else {
        overviewCards.add(OverviewCard(category: category, count: '0'));
      }
    }

    return (
      overviewCards: overviewCards,
      allEnabledResources: allEnabledResources,
      selectedRecordTypes: updatedSelectedRecordTypes,
    );
  }

  Future<List<IFhirResource>> _fetchResourcesFromAllSources(
      List<FhirType> resourceTypes, String? sourceId,
      [List<String>? patientSourceIds]) async {
    if (sourceId == _demoSourceId) {
      final resources = await _recordsRepository.getResources(
          resourceTypes: resourceTypes, sourceId: _demoSourceId);
      return resources;
    }

    List<String>? finalPatientSourceIds = patientSourceIds;
    if ((sourceId == null || sourceId == 'All') &&
        finalPatientSourceIds == null) {
      finalPatientSourceIds = await _getPatientSourceIds();
    }

    final resources = await _recordsRepository.getResources(
        resourceTypes: resourceTypes,
        sourceId: sourceId,
        sourceIds: finalPatientSourceIds);

    return resources;
  }

  Future<List<IFhirResource>> _fetchPatientResources(String? sourceId,
      [List<String>? patientSourceIds, String? selectedPatientId]) async {
    final resources = await _fetchResourcesFromAllSources(
        [FhirType.Patient], sourceId, patientSourceIds);

    final patients = resources.whereType<Patient>().toList();

    if (patients.isEmpty) {
      return [];
    }

    if (selectedPatientId != null && patients.length > 1) {
      final patientGroups = _deduplicationService.deduplicatePatients(patients);
      final selectedPatient = _patientSelectionService.getPatientForSource(
        patients: patients,
        sourceId: sourceId,
        selectedPatientId: selectedPatientId,
        patientGroups: patientGroups,
      );
      if (selectedPatient != null) {
        return [selectedPatient];
      }
    }

    return patients;
  }

  Future<List<PatientVital>> _fetchAndProcessVitals(String? sourceId,
      [List<String>? patientSourceIds]) async {
    final obs = await _fetchResourcesFromAllSources(
        [FhirType.Observation], sourceId, patientSourceIds);
    return _patientVitalFactory.buildFromResources(obs);
  }

  Future<
          ({
            List<PatientVital> allAvailableVitals,
            List<PatientVital> patientVitals,
            Map<PatientVitalType, bool> selectedVitals
          })>
      _processVitalsData(String? sourceId,
          [List<String>? patientSourceIds]) async {
    final vitals = await _fetchAndProcessVitals(sourceId, patientSourceIds);
    final saved = await _homeLocalDataSource.getVitalsVisibility();
    final selectedMap = Map<String, bool>.from(saved ??
        {for (final e in state.selectedVitals.entries) e.key.title: e.value});

    final hasData = vitals.any((v) => v.observationId != null);

    for (final vital in vitals) {
      selectedMap.putIfAbsent(
        vital.title,
        () => hasData && vital.observationId != null
            ? true
            : (state.selectedVitals[PatientVitalTypeX.fromTitle(vital.title) ??
                    PatientVitalType.heartRate] ??
                false),
      );
    }

    List<PatientVital> allAvailableVitals;
    if (state.allAvailableVitals.isNotEmpty) {
      allAvailableVitals =
          _mergeVitalsWithCurrentOrder(state.allAvailableVitals, vitals);
    } else {
      allAvailableVitals = await _applyVitalSignsOrder(vitals);
    }

    final filtered = allAvailableVitals
        .where((v) => selectedMap[v.title] ?? false)
        .toList(growable: false);

    final selectedVitals = Map<PatientVitalType, bool>.fromEntries(
      selectedMap.entries.map(
        (e) => MapEntry(
            PatientVitalTypeX.fromTitle(e.key) ?? PatientVitalType.heartRate,
            e.value),
      ),
    );

    return (
      allAvailableVitals: allAvailableVitals,
      patientVitals: filtered,
      selectedVitals: selectedVitals
    );
  }

  List<PatientVital> _mergeVitalsWithCurrentOrder(
    List<PatientVital> currentOrder,
    List<PatientVital> freshVitals,
  ) {
    final merged = <PatientVital>[];
    final currentMap = {for (final v in currentOrder) v.title: v};
    final freshMap = {for (final v in freshVitals) v.title: v};

    for (final v in currentOrder) {
      merged.add(freshMap[v.title] ?? v);
    }
    for (final v in freshVitals) {
      if (!currentMap.containsKey(v.title)) merged.add(v);
    }
    return merged;
  }

  Future<List<PatientVital>> _applyVitalSignsOrder(
      List<PatientVital> vitals) async {
    if (vitals.isEmpty) return vitals;

    final savedOrder = await _homeLocalDataSource.getVitalsOrder();
    if (savedOrder != null && savedOrder.isNotEmpty) {
      final map = {for (final v in vitals) v.title: v};
      final ordered = <PatientVital>[
        ...savedOrder.map((t) => map.remove(t)).whereType<PatientVital>(),
        ...map.values,
      ];
      return ordered;
    }

    const pinnedTop = <String>[
      'Heart Rate',
      'Blood Pressure',
      'Temperature',
      'Blood Oxygen'
    ];
    final mapNoSaved = {for (final v in vitals) v.title: v};
    final ordered = <PatientVital>[
      for (final t in pinnedTop)
        if (mapNoSaved.containsKey(t)) mapNoSaved.remove(t)!,
      ...mapNoSaved.values,
    ];
    return ordered;
  }

  Future<List<OverviewCard>> _applyOverviewCardsOrder(
      List<OverviewCard> cards) async {
    final savedOrder = await _homeLocalDataSource.getRecordsOrder();
    if (savedOrder == null || savedOrder.isEmpty) return cards;

    final map = {for (final c in cards) c.category.display: c};
    return [
      ...savedOrder.map((t) => map.remove(t)).whereType<OverviewCard>(),
      ...map.values,
    ];
  }

  Future<void> _reloadHomeData(
    Emitter<HomeState> emit, {
    bool force = false,
    String? overrideSourceId,
    List<String>? patientSourceIds,
  }) async {
    emit(state.copyWith(status: const HomeStatus.loading()));
    try {
      final sourceId = _resolveSourceId(overrideSourceId);

      final prefs = await SharedPreferences.getInstance();
      final selectedPatientId = prefs.getString('selected_patient_id');

      final sources = await _fetchSources(sourceId);
      final overview =
          await _fetchOverviewCardsAndResources(sourceId, patientSourceIds);
      final patientResources = await _fetchPatientResources(
          sourceId, patientSourceIds, selectedPatientId);
      final vitalsData = await _processVitalsData(sourceId, patientSourceIds);
      final reorderedCards =
          await _applyOverviewCardsOrder(overview.overviewCards);

      final hasData = this.hasData(
        patientVitals: vitalsData.patientVitals,
        overviewCards: reorderedCards,
        recentRecords: overview.allEnabledResources.take(3).toList(),
      );

      final currentSelectedSource = state.selectedSource.isNotEmpty
          ? state.selectedSource
          : (sourceId ?? 'All');

      emit(state.copyWith(
        status: const HomeStatus.success(),
        sources: sources,
        selectedSource: currentSelectedSource,
        patient: patientResources.isNotEmpty
            ? patientResources.first as Patient
            : null,
        overviewCards: reorderedCards,
        recentRecords: overview.allEnabledResources.take(3).toList(),
        allAvailableVitals: vitalsData.allAvailableVitals,
        patientVitals: vitalsData.patientVitals,
        selectedVitals: vitalsData.selectedVitals,
        selectedRecordTypes: overview.selectedRecordTypes,
        hasDataLoaded: hasData,
      ));
    } catch (err, stackTrace) {
      logger.e('reloadHomeData error: $err');
      logger.e('reloadHomeData stack trace: $stackTrace');
      emit(state.copyWith(
        status: HomeStatus.failure('Failed to load home data: $err'),
        errorMessage: err.toString(),
      ));
    }
  }

  String? _resolveSourceId(String? input) {
    if (input == null || input == 'All') return null;
    if (input == _demoSourceId) return _demoSourceId;
    if (input == 'wallet') return 'wallet';
    return input;
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

      await _updateSourceLabel(event.sourceId, event.newLabel);

      emit(state.copyWith(sources: updatedSources));
    } catch (e) {
      logger.e('Error updating source label: $e');
    }
  }

  Future<void> _updateSourceLabel(String sourceId, String newLabel) async {
    try {
      await _syncRepository.updateSourceLabel(sourceId, newLabel);
    } catch (e) {
      logger.e('Error updating source label: $e');
      rethrow;
    }
  }

  Future<void> _onSourceDeleted(
    HomeSourceDeleted event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final deletedSource = state.sources.firstWhere(
        (source) => source.id == event.sourceId,
        orElse: () => throw Exception('Source not found: ${event.sourceId}'),
      );
      final isWalletSource = deletedSource.platformType == 'wallet' ||
          deletedSource.id == 'wallet';

      await _syncRepository.deleteSource(event.sourceId);

      final updatedSources =
          state.sources.where((source) => source.id != event.sourceId).toList();

      String? newSelectedSource = state.selectedSource;

      if (state.selectedSource == event.sourceId) {
        if (isWalletSource) {
          newSelectedSource = 'All';
        } else {
          newSelectedSource = 'All';
        }
      }

      emit(state.copyWith(
        sources: updatedSources,
        selectedSource: newSelectedSource,
      ));

      await _reloadHomeData(emit,
          force: true,
          overrideSourceId: newSelectedSource,
          patientSourceIds: event.patientSourceIds);
    } catch (e) {
      logger.e('Error deleting source: $e');
    }
  }
}
