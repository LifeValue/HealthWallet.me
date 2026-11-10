import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_session.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/records/domain/entity/encounter/encounter.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';

part 'handover_protocol.freezed.dart';

/// The handover messages, carried as `data` frames on the paired link. Every
/// payload has `session_id`: the phone's processing session, which is also
/// the desktop's session for the same document.
abstract final class HandoverMessage {
  /// Phone → desktop: `v`, `files` (`name`, `size`), optional `phase1_data`.
  static const offer = 'handover.offer';

  /// Desktop → phone: ready for the files.
  static const accept = 'handover.accept';

  /// Desktop → phone: refused, with a `reason` ([HandoverFailure.wire]).
  static const reject = 'handover.reject';

  /// Phone → desktop: `index`, `offset`, `data` (base64, at most
  /// [HandoverProtocol.chunkBytes] bytes), in order.
  static const chunk = 'handover.chunk';

  /// Either way: the sender withdrew the document.
  static const cancel = 'handover.cancel';

  /// Desktop → phone: processing `progress`, 0 to 1. Not acknowledged.
  static const progress = 'handover.progress';

  /// Desktop → phone: the `draft` ([HandoverDraft]) to review.
  static const result = 'handover.result';

  /// Desktop → phone: processing failed, with a `reason`.
  static const failed = 'handover.failed';

  /// Either way: the records were saved on the sending device, so the other
  /// one drops its draft.
  static const saved = 'handover.saved';

  /// The answer to [cancel], [result], [failed] and [saved]: `type` names the
  /// message received. Until it arrives the message is sent again on every
  /// connection.
  static const ack = 'handover.ack';
}

abstract final class HandoverProtocol {
  /// Sent in the offer; a desktop that speaks another version rejects it.
  static const version = 2;

  /// Bytes of a file in one [HandoverMessage.chunk], far below the link's
  /// frame cap once base64-encoded.
  static const chunkBytes = 256 * 1024;

  /// The largest handover the desktop accepts, all files together.
  static const maxTotalBytes = 200 * 1024 * 1024;

  /// How long the phone waits for [HandoverMessage.accept].
  static const acceptTimeout = Duration(seconds: 30);

  /// How long the desktop waits for the next chunk before it gives up.
  static const idleTimeout = Duration(seconds: 60);

  /// How often messages still waiting for an acknowledgement are sent
  /// again while the link is up.
  static const outboxRetry = Duration(seconds: 30);
}

/// What the desktop read from a document, for the phone to review: the same
/// staging a processing session holds. Ids travel with it, so the records
/// are the same rows whichever device saves them.
@Freezed(fromJson: false, toJson: false)
abstract class HandoverDraft with _$HandoverDraft {
  const HandoverDraft._();

  const factory HandoverDraft({
    required StagedPatient patient,
    @Default(StagedEncounter()) StagedEncounter encounter,
    StagedDiagnosticReport? diagnosticReport,
    @Default([]) List<MappingResource> resources,
  }) = _HandoverDraft;

  factory HandoverDraft.of(ProcessingSession session) => HandoverDraft(
    patient: session.patient,
    encounter: session.encounter,
    diagnosticReport: session.diagnosticReport,
    resources: session.resources,
  );

  factory HandoverDraft.fromJson(Map<String, dynamic> json) => HandoverDraft(
    patient: stagedPatientFromJson(json['patient'] as Map<String, dynamic>),
    encounter: json['encounter'] is Map<String, dynamic>
        ? stagedEncounterFromJson(json['encounter'] as Map<String, dynamic>)
        : const StagedEncounter(),
    diagnosticReport: json['diagnosticReport'] is Map<String, dynamic>
        ? stagedDiagnosticReportFromJson(
            json['diagnosticReport'] as Map<String, dynamic>,
          )
        : null,
    resources: [
      for (final r in json['resources'] as List? ?? const [])
        MappingResource.fromJson(r as Map<String, dynamic>),
    ],
  );

  Map<String, dynamic> toJson() => {
    'patient': stagedPatientToJson(patient),
    'encounter': stagedEncounterToJson(encounter),
    if (diagnosticReport != null)
      'diagnosticReport': stagedDiagnosticReportToJson(diagnosticReport!),
    'resources': [for (final r in resources) r.toJson()],
  };
}
