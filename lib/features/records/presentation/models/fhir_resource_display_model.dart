import 'package:intl/intl.dart';

/// Generic display model for any FHIR resource type
class FhirResourceDisplayModel {
  final String id;
  final String resourceType;
  final String
  primaryDisplay; // Main title (e.g., condition name, allergy substance)
  final String? secondaryDisplay; // Subtitle (e.g., status, severity)
  final String? date; // Relevant date for the resource
  final String? status; // Clinical status if applicable
  final String? category; // Category or classification
  final List<String> additionalInfo; // Extra information lines
  final Map<String, dynamic> rawResource;

  const FhirResourceDisplayModel({
    required this.id,
    required this.resourceType,
    required this.primaryDisplay,
    this.secondaryDisplay,
    this.date,
    this.status,
    this.category,
    this.additionalInfo = const [],
    required this.rawResource,
  });

  /// Create from display data built by DisplayModelBuilder
  factory FhirResourceDisplayModel.fromDisplayData(
    Map<String, dynamic> displayData,
  ) {
    return FhirResourceDisplayModel(
      id: displayData['id'] as String? ?? '',
      resourceType: displayData['resourceType'] as String? ?? 'Unknown',
      primaryDisplay:
          displayData['primaryDisplay'] as String? ?? 'Unknown Resource',
      secondaryDisplay: displayData['secondaryDisplay'] as String?,
      date: displayData['date'] as String?,
      status: displayData['status'] as String?,
      category: displayData['category'] as String?,
      additionalInfo:
          (displayData['additionalInfo'] as List<dynamic>?)?.cast<String>() ??
          [],
      rawResource: displayData['rawResource'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Formatted date for display (e.g., "March 15, 2024")
  String? get formattedDate {
    if (date == null) return null;
    try {
      final parsedDate = DateTime.parse(date!);
      return DateFormat.yMMMMd().format(parsedDate);
    } catch (_) {
      return date;
    }
  }

  /// Display name for the resource (used as primary display in UI)
  String get display => primaryDisplay;

  /// Whether this resource has a status
  bool get hasStatus => status != null && status!.isNotEmpty;

  /// Whether this resource has a category
  bool get hasCategory => category != null && category!.isNotEmpty;

  /// Whether this resource has additional information
  bool get hasAdditionalInfo => additionalInfo.isNotEmpty;

  /// Get a summary line for the resource
  String get summary {
    final parts = <String>[];
    if (hasCategory) parts.add(category!);
    if (hasStatus) parts.add(status!);
    if (date != null) parts.add(formattedDate ?? date!);
    return parts.join(' • ');
  }

  @override
  String toString() {
    return 'FhirResourceDisplayModel(resourceType: $resourceType, '
        'primaryDisplay: $primaryDisplay, status: $status)';
  }
}
