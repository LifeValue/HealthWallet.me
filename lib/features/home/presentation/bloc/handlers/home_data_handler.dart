import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/home/domain/entities/overview_card.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';
import 'package:health_wallet/features/home/domain/factory/patient_vitals_factory.dart';
import 'package:health_wallet/features/home/domain/repository/home_preferences_repository.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_selection_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

mixin HomeDataHandler on Bloc<HomeEvent, HomeState> {
  RecordsRepository get recordsRepository;
  HomePreferencesRepository get homePreferences;
  PatientDeduplicationService get deduplicationService;
  PatientSelectionService get patientSelectionService;
  PatientVitalFactory get patientVitalFactory;

  static const String demoSourceId = 'demo_data';

  Future<List<String>?> getPatientSourceIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedPatientId = prefs.getString('selected_patient_id');

      if (selectedPatientId == null) {
        logger.w('No selected patient ID found');
        return null;
      }

      final allPatients = await recordsRepository.getResources(
        resourceTypes: [FhirType.Patient],
        limit: 100,
      );

      if (allPatients.isEmpty) return null;

      final patients = allPatients.whereType<Patient>().toList();

      final sourceIds = <String>{};
      for (final patient in patients) {
        if (patient.id == selectedPatientId && patient.sourceId.isNotEmpty) {
          sourceIds.add(patient.sourceId);
        }
      }

      if (sourceIds.isNotEmpty) return sourceIds.toList();

      final patientGroups = deduplicationService.deduplicatePatients(patients);
      final matchingGroup = deduplicationService.findPatientGroup(
        patientGroups,
        selectedPatientId,
      );

      if (matchingGroup != null) {
        return matchingGroup.sourceIds;
      }

      if (patientGroups.isNotEmpty) {
        final firstGroup = patientGroups.values.first;
        final newSelectedId = firstGroup.representativePatient.id;
        await prefs.setString('selected_patient_id', newSelectedId);
        return firstGroup.sourceIds;
      }

      return null;
    } catch (e) {
      logger.e('Error getting patient source IDs: $e');
      return null;
    }
  }

  Future<List<IFhirResource>> fetchResourcesFromAllSources(
      List<FhirType> resourceTypes, String? sourceId,
      [List<String>? patientSourceIds]) async {
    if (sourceId == demoSourceId) {
      final resources = await recordsRepository.getResources(
          resourceTypes: resourceTypes, sourceId: demoSourceId);
      return resources;
    }

    List<String>? finalPatientSourceIds = patientSourceIds;
    if ((sourceId == null || sourceId == 'All') &&
        finalPatientSourceIds == null) {
      finalPatientSourceIds = await getPatientSourceIds();
    }

    final resources = await recordsRepository.getResources(
        resourceTypes: resourceTypes,
        sourceId: sourceId,
        sourceIds: finalPatientSourceIds);

    return resources;
  }

  Future<
          ({
            List<OverviewCard> overviewCards,
            List<IFhirResource> allEnabledResources,
            Map<HomeRecordsCategory, bool> selectedRecordTypes
          })>
      fetchOverviewCardsAndResources(String? sourceId,
          [List<String>? patientSourceIds]) async {
    final overviewCards = <OverviewCard>[];
    final allEnabledResources = <IFhirResource>[];
    final savedRecordsVisibility =
        await homePreferences.getRecordsVisibility();
    final updatedSelectedRecordTypes =
        Map<HomeRecordsCategory, bool>.from(state.selectedRecordTypes);
    if (savedRecordsVisibility != null) {
      updatedSelectedRecordTypes.updateAll((category, value) =>
          savedRecordsVisibility[category.display] ?? value);
    }

    for (final category in updatedSelectedRecordTypes.keys) {
      if (updatedSelectedRecordTypes[category]!) {
        final resources = await fetchResourcesFromAllSources(
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

  Future<List<IFhirResource>> fetchPatientResources(String? sourceId,
      [List<String>? patientSourceIds, String? selectedPatientId]) async {
    final resources = await fetchResourcesFromAllSources(
        [FhirType.Patient], sourceId, patientSourceIds);

    final patients = resources.whereType<Patient>().toList();

    if (patients.isEmpty) {
      return [];
    }

    if (selectedPatientId != null && patients.length > 1) {
      final patientGroups = deduplicationService.deduplicatePatients(patients);
      final selectedPatient = patientSelectionService.getPatientForSource(
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

  Future<List<PatientVital>> fetchAndProcessVitals(String? sourceId,
      [List<String>? patientSourceIds]) async {
    final obs = await fetchResourcesFromAllSources(
        [FhirType.Observation], sourceId, patientSourceIds);
    final prefs = await SharedPreferences.getInstance();
    final region = RegionPreset.fromString(
      prefs.getString(SharedPrefsConstants.regionPreset),
    );
    return patientVitalFactory.buildFromResources(obs, region: region);
  }

  Future<
          ({
            List<PatientVital> allAvailableVitals,
            List<PatientVital> patientVitals,
            Map<PatientVitalType, bool> selectedVitals
          })>
      processVitalsData(String? sourceId,
          [List<String>? patientSourceIds]) async {
    final vitals = await fetchAndProcessVitals(sourceId, patientSourceIds);
    final saved = await homePreferences.getVitalsVisibility();
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
          mergeVitalsWithCurrentOrder(state.allAvailableVitals, vitals);
    } else {
      allAvailableVitals = await applyVitalSignsOrder(vitals);
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

  List<PatientVital> mergeVitalsWithCurrentOrder(
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

  Future<List<PatientVital>> applyVitalSignsOrder(
      List<PatientVital> vitals) async {
    if (vitals.isEmpty) return vitals;

    final savedOrder = await homePreferences.getVitalsOrder();
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

  Future<List<OverviewCard>> applyOverviewCardsOrder(
      List<OverviewCard> cards) async {
    final savedOrder = await homePreferences.getRecordsOrder();
    if (savedOrder == null || savedOrder.isEmpty) return cards;

    final map = {for (final c in cards) c.category.display: c};
    return [
      ...savedOrder.map((t) => map.remove(t)).whereType<OverviewCard>(),
      ...map.values,
    ];
  }
}
