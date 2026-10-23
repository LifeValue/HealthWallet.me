import 'package:intl/intl.dart';

/// Simple display model for Encounter UI presentation
class EncounterDisplayModel {
  final String id;
  final String patientDisplay;
  final String encounterType;
  final String? startDate;
  final String? endDate;
  final List<String> practitionerNames;
  final String organizationName;
  final List<String> locationNames;
  final Map<String, dynamic> rawEncounter;

  const EncounterDisplayModel({
    required this.id,
    required this.patientDisplay,
    required this.encounterType,
    this.startDate,
    this.endDate,
    required this.practitionerNames,
    required this.organizationName,
    required this.locationNames,
    required this.rawEncounter,
  });

  /// Create from display data built by DisplayModelBuilder
  factory EncounterDisplayModel.fromDisplayData(
    Map<String, dynamic> displayData,
  ) {
    return EncounterDisplayModel(
      id: displayData['id'] as String? ?? '',
      patientDisplay:
          displayData['patientDisplay'] as String? ?? 'Unknown Patient',
      encounterType: displayData['encounterType'] as String? ?? 'Encounter',
      startDate: displayData['startDate'] as String?,
      endDate: displayData['endDate'] as String?,
      practitionerNames:
          (displayData['practitionerNames'] as List<dynamic>?)
              ?.cast<String>() ??
          [],
      organizationName:
          displayData['organizationName'] as String? ?? 'Unknown Organization',
      locationNames:
          (displayData['locationNames'] as List<dynamic>?)?.cast<String>() ??
          [],
      rawEncounter: displayData['rawEncounter'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Display name for the encounter (used as primary display in UI)
  String get display => 'Encounter';

  /// Combined practitioner names for display
  String get practitionerDisplayText => practitionerNames.join(', ');

  /// Combined organization and location names for display
  String get organizationLocationDisplayText {
    final all = <String>[];
    if (organizationName.isNotEmpty) all.add(organizationName);
    all.addAll(locationNames);
    return all.join(', ');
  }

  /// Formatted start date (e.g., "March 15, 2025")
  String? get formattedStartDate {
    if (startDate == null) return null;
    try {
      final date = DateTime.parse(startDate!);
      return DateFormat('MMMM d, yyyy').format(date);
    } catch (_) {
      return startDate;
    }
  }

  /// Whether practitioners are available for display
  bool get hasPractitioners => practitionerNames.isNotEmpty;

  /// Whether organization/location is available for display
  bool get hasOrganizationLocation =>
      organizationName.isNotEmpty || locationNames.isNotEmpty;
}
