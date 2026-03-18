part of 'home_bloc.dart';

@freezed
class HomeState with _$HomeState {
  const HomeState._();

  const factory HomeState({
    @Default(HomeStatus.initial()) HomeStatus status,
    @Default([]) List<PatientVital> patientVitals,
    @Default([]) List<PatientVital> allAvailableVitals,
    @Default([]) List<OverviewCard> overviewCards,
    @Default([]) List<IFhirResource> recentRecords,
    @Default([]) List<Source> sources,
    @Default(0) int selectedIndex,
    @Default('All') String selectedSource,
    @Default({
      HomeRecordsCategory.allergies: true,
      HomeRecordsCategory.medications: true,
      HomeRecordsCategory.healthIssues: true,
      HomeRecordsCategory.immunizations: true,
      HomeRecordsCategory.labResults: true,
      HomeRecordsCategory.procedures: true,
      HomeRecordsCategory.healthGoals: true,
      HomeRecordsCategory.careTeam: true,
      HomeRecordsCategory.clinicalNotes: true,
      HomeRecordsCategory.files: true,
      HomeRecordsCategory.facilities: true,
      HomeRecordsCategory.demographics: true,
      HomeRecordsCategory.healthInsurance: true,
    })
    Map<HomeRecordsCategory, bool> selectedRecordTypes,
    @Default({
      PatientVitalType.heartRate: true,
      PatientVitalType.bloodPressure: true,
      PatientVitalType.bloodOxygen: true,
      PatientVitalType.temperature: true,
      PatientVitalType.respiratoryRate: false,
      PatientVitalType.weight: false,
      PatientVitalType.height: false,
      PatientVitalType.bmi: false,
      PatientVitalType.bloodGlucose: false,
    })
    Map<PatientVitalType, bool> selectedVitals,
    Patient? patient,
    String? selectedPatientName,
    String? errorMessage,
    @Default(false) bool editMode,
    @Default(false) bool vitalsExpanded,
    @Default(false) bool hasDataLoaded,
  }) = _HomeState;

  bool get shouldShowPlaceholder {
    final hasVitalData = patientVitals
        .any((vital) => vital.value != 'N/A' && vital.observationId != null);
    final hasOverviewData = overviewCards.any((card) => card.count != '0');
    final hasRecent = recentRecords.isNotEmpty;
    return !(hasVitalData || hasOverviewData || hasRecent);
  }

  List<OverviewCard> get visibleOverviewCards =>
      overviewCards
          .where((card) => selectedRecordTypes[card.category] ?? false)
          .toList(growable: false);
}

@freezed
class HomeStatus with _$HomeStatus {
  const factory HomeStatus.initial() = _Initial;
  const factory HomeStatus.loading() = _Loading;
  const factory HomeStatus.success() = _Success;
  const factory HomeStatus.failure(Object error) = _Failure;
}
