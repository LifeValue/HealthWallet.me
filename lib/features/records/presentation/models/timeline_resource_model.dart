import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/records/presentation/models/encounter_display_model.dart';
import 'package:health_wallet/features/records/presentation/models/fhir_resource_display_model.dart';
import 'package:intl/intl.dart';

part 'timeline_resource_model.freezed.dart';

/// Unified model for timeline resources that can be either encounters or standalone resources
@freezed
abstract class TimelineResourceModel with _$TimelineResourceModel {
  const factory TimelineResourceModel({
    required String id,
    required String resourceType,
    required String primaryDisplay,
    String? secondaryDisplay,
    String? date,
    String? status,
    String? category,
    required bool isEncounter,
    required bool isStandalone,
    EncounterDisplayModel? encounterModel,
    FhirResourceDisplayModel? resourceModel,
    required Map<String, dynamic> rawResource,
  }) = _TimelineResourceModel;

  /// Create from encounter display model
  factory TimelineResourceModel.fromEncounter(EncounterDisplayModel encounter) {
    return TimelineResourceModel(
      id: encounter.id,
      resourceType: 'Encounter',
      primaryDisplay: encounter.encounterType,
      secondaryDisplay: encounter.patientDisplay,
      date: encounter.startDate,
      status: null, // Encounters don't have a status field in the current model
      category: encounter.encounterType,
      isEncounter: true,
      isStandalone: false,
      encounterModel: encounter,
      resourceModel: null,
      rawResource: encounter.rawEncounter,
    );
  }

  /// Create from standalone resource display model
  factory TimelineResourceModel.fromStandaloneResource(
      FhirResourceDisplayModel resource) {
    return TimelineResourceModel(
      id: resource.id,
      resourceType: resource.resourceType,
      primaryDisplay: resource.primaryDisplay,
      secondaryDisplay: resource.secondaryDisplay,
      date: resource.date,
      status: resource.status,
      category: resource.category,
      isEncounter: false,
      isStandalone: true,
      encounterModel: null,
      resourceModel: resource,
      rawResource: resource.rawResource,
    );
  }
}

/// Extension methods for TimelineResourceModel
extension TimelineResourceModelExtensions on TimelineResourceModel {
  /// Get the formatted date for display
  String? get formattedDate {
    if (date == null) return null;
    try {
      final dateTime = DateTime.parse(date!);
      return DateFormat.yMMMMd().format(dateTime);
    } catch (_) {
      return date;
    }
  }

  /// Get the timestamp for sorting
  DateTime? get timestamp {
    if (date == null) return null;
    try {
      return DateTime.parse(date!);
    } catch (_) {
      return null;
    }
  }
}
