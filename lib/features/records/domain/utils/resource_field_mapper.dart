import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:health_wallet/gen/assets.gen.dart';

/// Utility class for mapping FHIR resource fields to icons and creating RecordInfoLine objects.
/// Provides consistent icon usage and field formatting across all resource types.
class ResourceFieldMapper {
  ResourceFieldMapper._();

  // ============================================
  // Icon Getters for Common Field Types
  // ============================================

  /// Status/general information icon
  static SvgGenImage get statusIcon => Assets.icons.information;

  /// Date/calendar icon
  static SvgGenImage get dateIcon => Assets.icons.calendar;

  /// Time/clock icon
  static SvgGenImage get timeIcon => Assets.icons.timeClock;

  /// User/practitioner icon
  static SvgGenImage get userIcon => Assets.icons.user;

  /// Organization/hospital icon
  static SvgGenImage get organizationIcon => Assets.icons.hospital;

  /// Location icon (using hospital as fallback)
  static SvgGenImage get locationIcon => Assets.icons.hospital;

  /// Medication icon
  static SvgGenImage get medicationIcon => Assets.icons.medication;

  /// Notes/annotation icon
  static SvgGenImage get notesIcon => Assets.icons.catalogNotes;

  /// Procedure icon
  static SvgGenImage get procedureIcon => Assets.icons.briefcaseProcedures;

  /// Lab/test result icon
  static SvgGenImage get labIcon => Assets.icons.lab;

  /// Document icon
  static SvgGenImage get documentIcon => Assets.icons.document;

  /// Value/measurement icon
  static SvgGenImage get valueIcon => Assets.icons.drop;

  /// Category/classification icon
  static SvgGenImage get categoryIcon => Assets.icons.filter;

  /// Warning/alert icon
  static SvgGenImage get warningIcon => Assets.icons.warning;

  /// Shield/security icon
  static SvgGenImage get shieldIcon => Assets.icons.shield;

  /// Immunization/vaccine icon
  static SvgGenImage get immunizationIcon => Assets.icons.faceMask;

  /// Activity icon
  static SvgGenImage get activityIcon => Assets.icons.activity;

  /// Body site icon
  static SvgGenImage get bodySiteIcon => Assets.icons.stethoscope;

  /// Team/care team icon
  static SvgGenImage get teamIcon => Assets.icons.eventsTeam;

  /// Identification icon
  static SvgGenImage get identificationIcon => Assets.icons.identification;

  /// Timeline icon
  static SvgGenImage get timelineIcon => Assets.icons.timeline;

  /// Image/media icon
  static SvgGenImage get imageIcon => Assets.icons.image;

  /// Attachment icon
  static SvgGenImage get attachmentIcon => Assets.icons.attachment;

  // ============================================
  // Factory Methods for RecordInfoLine
  // ============================================

  /// Creates a status info line
  static RecordInfoLine? createStatusLine(String? status, {String? prefix}) {
    if (status == null || status.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $status' : status;
    return RecordInfoLine(icon: statusIcon, info: displayText);
  }

  /// Creates a date info line
  static RecordInfoLine? createDateLine(String? date, {String? prefix}) {
    if (date == null || date.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $date' : date;
    return RecordInfoLine(icon: dateIcon, info: displayText);
  }

  /// Creates a time info line
  static RecordInfoLine? createTimeLine(String? time, {String? prefix}) {
    if (time == null || time.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $time' : time;
    return RecordInfoLine(icon: timeIcon, info: displayText);
  }

  /// Creates a user/practitioner info line
  static RecordInfoLine? createUserLine(String? user, {String? prefix}) {
    if (user == null || user.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $user' : user;
    return RecordInfoLine(icon: userIcon, info: displayText);
  }

  /// Creates an organization info line
  static RecordInfoLine? createOrganizationLine(String? organization,
      {String? prefix}) {
    if (organization == null || organization.isEmpty) return null;
    final displayText =
        prefix != null ? '$prefix: $organization' : organization;
    return RecordInfoLine(icon: organizationIcon, info: displayText);
  }

  /// Creates a location info line
  static RecordInfoLine? createLocationLine(String? location,
      {String? prefix}) {
    if (location == null || location.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $location' : location;
    return RecordInfoLine(icon: locationIcon, info: displayText);
  }

  /// Creates a medication info line
  static RecordInfoLine? createMedicationLine(String? medication,
      {String? prefix}) {
    if (medication == null || medication.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $medication' : medication;
    return RecordInfoLine(icon: medicationIcon, info: displayText);
  }

  /// Creates a notes/annotation info line
  static RecordInfoLine? createNotesLine(String? notes, {String? prefix}) {
    if (notes == null || notes.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $notes' : notes;
    return RecordInfoLine(icon: notesIcon, info: displayText);
  }

  /// Creates a procedure info line
  static RecordInfoLine? createProcedureLine(String? procedure,
      {String? prefix}) {
    if (procedure == null || procedure.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $procedure' : procedure;
    return RecordInfoLine(icon: procedureIcon, info: displayText);
  }

  /// Creates a lab/result info line
  static RecordInfoLine? createLabLine(String? labResult, {String? prefix}) {
    if (labResult == null || labResult.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $labResult' : labResult;
    return RecordInfoLine(icon: labIcon, info: displayText);
  }

  /// Creates a value/measurement info line
  static RecordInfoLine? createValueLine(String? value, {String? prefix}) {
    if (value == null || value.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $value' : value;
    return RecordInfoLine(icon: valueIcon, info: displayText);
  }

  /// Creates a category info line
  static RecordInfoLine? createCategoryLine(String? category,
      {String? prefix}) {
    if (category == null || category.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $category' : category;
    return RecordInfoLine(icon: categoryIcon, info: displayText);
  }

  /// Creates a warning/severity info line
  static RecordInfoLine? createWarningLine(String? warning, {String? prefix}) {
    if (warning == null || warning.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $warning' : warning;
    return RecordInfoLine(icon: warningIcon, info: displayText);
  }

  /// Creates a body site info line
  static RecordInfoLine? createBodySiteLine(String? bodySite,
      {String? prefix}) {
    if (bodySite == null || bodySite.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $bodySite' : bodySite;
    return RecordInfoLine(icon: bodySiteIcon, info: displayText);
  }

  /// Creates a team/care team info line
  static RecordInfoLine? createTeamLine(String? team, {String? prefix}) {
    if (team == null || team.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $team' : team;
    return RecordInfoLine(icon: teamIcon, info: displayText);
  }

  /// Creates an immunization info line
  static RecordInfoLine? createImmunizationLine(String? immunization,
      {String? prefix}) {
    if (immunization == null || immunization.isEmpty) return null;
    final displayText =
        prefix != null ? '$prefix: $immunization' : immunization;
    return RecordInfoLine(icon: immunizationIcon, info: displayText);
  }

  /// Creates a document info line
  static RecordInfoLine? createDocumentLine(String? document,
      {String? prefix}) {
    if (document == null || document.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $document' : document;
    return RecordInfoLine(icon: documentIcon, info: displayText);
  }

  /// Creates an identification info line
  static RecordInfoLine? createIdentificationLine(String? identification,
      {String? prefix}) {
    if (identification == null || identification.isEmpty) return null;
    final displayText =
        prefix != null ? '$prefix: $identification' : identification;
    return RecordInfoLine(icon: identificationIcon, info: displayText);
  }

  /// Creates a timeline/period info line
  static RecordInfoLine? createTimelineLine(String? timeline,
      {String? prefix}) {
    if (timeline == null || timeline.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $timeline' : timeline;
    return RecordInfoLine(icon: timelineIcon, info: displayText);
  }

  /// Creates an activity info line
  static RecordInfoLine? createActivityLine(String? activity,
      {String? prefix}) {
    if (activity == null || activity.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $activity' : activity;
    return RecordInfoLine(icon: activityIcon, info: displayText);
  }

  /// Creates an image/media info line
  static RecordInfoLine? createImageLine(String? image, {String? prefix}) {
    if (image == null || image.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $image' : image;
    return RecordInfoLine(icon: imageIcon, info: displayText);
  }

  /// Creates an attachment info line
  static RecordInfoLine? createAttachmentLine(String? attachment,
      {String? prefix}) {
    if (attachment == null || attachment.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $attachment' : attachment;
    return RecordInfoLine(icon: attachmentIcon, info: displayText);
  }

  /// Creates a custom info line with a specified icon
  static RecordInfoLine? createCustomLine(
    SvgGenImage icon,
    String? value, {
    String? prefix,
  }) {
    if (value == null || value.isEmpty) return null;
    final displayText = prefix != null ? '$prefix: $value' : value;
    return RecordInfoLine(icon: icon, info: displayText);
  }

  // ============================================
  // Helper to add non-null lines to a list
  // ============================================

  /// Adds a line to the list if it's not null
  static void addIfNotNull(List<RecordInfoLine> list, RecordInfoLine? line) {
    if (line != null) {
      list.add(line);
    }
  }

  /// Creates a section header line (bold text with spacing)
  static RecordInfoLine createSectionHeader(String sectionTitle) {
    return RecordInfoLine(
      icon: Assets.icons.timeline,
      info: sectionTitle,
      isSection: true,
    );
  }
}
