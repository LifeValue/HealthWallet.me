import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/domain/utils/extractors/fhir_common_extractor.dart';
import 'package:health_wallet/features/records/domain/utils/resource_field_mapper.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';

/// Localized labels for the FHIR status codes records carry. A status is
/// read from its code, so it shows in the app language and doesn't depend on
/// a display the source may leave out (`fhir_r4` never sets one for status
/// enums).
class FhirCodeLabels {
  FhirCodeLabels._();

  /// Statuses saying the record no longer stands as a current fact: a
  /// stopped medication, a refuted allergy, a vaccine not given. They are
  /// shown with a warning so they can't pass for current ones.
  static const Set<String> flaggedStatuses = {
    'entered-in-error',
    'not-done',
    'refuted',
    'inactive',
    'resolved',
    'remission',
    'stopped',
    'cancelled',
    'not-taken',
    'declined',
  };

  /// The label of a FHIR status [code], or null for a code not listed.
  static String? status(String? code, AppLocalizations l10n) => switch (code) {
    'active' => l10n.fhirStatusActive,
    'inactive' => l10n.fhirStatusInactive,
    'resolved' => l10n.fhirStatusResolved,
    'recurrence' => l10n.fhirStatusRecurrence,
    'relapse' => l10n.fhirStatusRelapse,
    'remission' => l10n.fhirStatusRemission,
    'unconfirmed' => l10n.fhirStatusUnconfirmed,
    'provisional' => l10n.fhirStatusProvisional,
    'differential' => l10n.fhirStatusDifferential,
    'confirmed' => l10n.fhirStatusConfirmed,
    'refuted' => l10n.fhirStatusRefuted,
    'entered-in-error' => l10n.fhirStatusEnteredInError,
    'on-hold' => l10n.fhirStatusOnHold,
    'cancelled' => l10n.fhirStatusCancelled,
    'completed' => l10n.fhirStatusCompleted,
    'stopped' => l10n.fhirStatusStopped,
    'draft' => l10n.fhirStatusDraft,
    'unknown' => l10n.fhirStatusUnknown,
    'intended' => l10n.fhirStatusIntended,
    'not-taken' => l10n.fhirStatusNotTaken,
    'in-progress' => l10n.fhirStatusInProgress,
    'not-done' => l10n.fhirStatusNotDone,
    'preparation' => l10n.fhirStatusPreparation,
    'declined' => l10n.fhirStatusDeclined,
    'registered' => l10n.fhirStatusRegistered,
    'preliminary' => l10n.fhirStatusPreliminary,
    'final' => l10n.fhirStatusFinal,
    'amended' => l10n.fhirStatusAmended,
    'corrected' => l10n.fhirStatusCorrected,
    _ => null,
  };

  static bool isFlagged(String? code) => flaggedStatuses.contains(code);

  /// A "prefix: status" line for a status [code], with a warning icon when
  /// the status is flagged. An unlisted code is shown as written.
  static RecordInfoLine? statusLine(
    String? code,
    AppLocalizations l10n, {
    required String prefix,
  }) {
    final label = status(code, l10n) ?? code;
    return isFlagged(code)
        ? ResourceFieldMapper.createWarningLine(label, prefix: prefix)
        : ResourceFieldMapper.createStatusLine(label, prefix: prefix);
  }

  /// The lines a record with a flagged status [code] starts with: the status
  /// and its [reason], so a vaccine not given or a result entered in error
  /// can't be read as a normal record on the card. Empty for other statuses,
  /// which stay where the record lists them.
  static List<RecordInfoLine> flaggedStatusLines(
    String? code,
    String? reason,
    AppLocalizations l10n,
  ) {
    if (!isFlagged(code)) return const [];
    return [
      ?statusLine(code, l10n, prefix: l10n.fieldStatus),
      ?ResourceFieldMapper.createStatusLine(
        reason,
        prefix: l10n.fieldStatusReason,
      ),
    ];
  }

  /// The code of the first coding in [concept] that [status] knows.
  static String? statusCodeOf(fhir_r4.CodeableConcept? concept) => concept
      ?.coding
      ?.map((coding) => coding.code?.valueString)
      .firstWhere(_statusCodes.contains, orElse: () => null);

  static const Set<String> _statusCodes = {
    ...flaggedStatuses,
    'active',
    'recurrence',
    'relapse',
    'unconfirmed',
    'provisional',
    'differential',
    'confirmed',
    'on-hold',
    'completed',
    'draft',
    'unknown',
    'intended',
    'in-progress',
    'preparation',
    'registered',
    'preliminary',
    'final',
    'amended',
    'corrected',
  };

  /// The label of a coded status ([concept]): a listed status code, else
  /// the concept's text, a coding display, or the first code.
  static String? statusConcept(
    fhir_r4.CodeableConcept? concept,
    AppLocalizations l10n,
  ) {
    if (concept == null) return null;
    final label = status(statusCodeOf(concept), l10n);
    if (label != null) return label;
    return FhirCommonExtractor.extractCodeableConceptText(concept) ??
        concept.coding
            ?.map((coding) => coding.code?.valueString)
            .nonNulls
            .firstOrNull;
  }

  /// A "prefix: status" line for a coded status, with a warning icon when
  /// the status is flagged.
  static RecordInfoLine? statusConceptLine(
    fhir_r4.CodeableConcept? concept,
    AppLocalizations l10n, {
    required String prefix,
  }) {
    final label = statusConcept(concept, l10n);
    return isFlagged(statusCodeOf(concept))
        ? ResourceFieldMapper.createWarningLine(label, prefix: prefix)
        : ResourceFieldMapper.createStatusLine(label, prefix: prefix);
  }
}
