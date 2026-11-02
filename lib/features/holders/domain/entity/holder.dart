import 'package:health_wallet/features/holders/domain/entity/holder_snapshot.dart';
import 'package:health_wallet/features/holders/domain/services/holder_linker.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';

/// A person in the wallet: the sources linked to them and the Patient rows
/// those sources hold.
class Holder {
  const Holder({
    required this.id,
    required this.representativePatient,
    required this.sourceIds,
    required this.allPatientInstances,
  });

  final String id;

  /// The row shown for the person: the holder's own wallet Patient when there
  /// is one.
  final Patient representativePatient;
  final List<String> sourceIds;
  final List<Patient> allPatientInstances;

  String get patientId => representativePatient.id;

  /// The demo data's patient, who is not someone the user knows.
  bool get isDemo => sourceIds.contains(HolderSource.demoId);

  bool existsInSource(String sourceId) => sourceIds.contains(sourceId);

  Patient? getPatientForSource(String sourceId) =>
      allPatientInstances.where((p) => p.sourceId == sourceId).firstOrNull;

  /// Whether [patient] is one of this person's rows.
  bool hasPatient(Patient patient) =>
      sourceIds.contains(patient.sourceId) ||
      allPatientInstances.any((p) => p.id == patient.id);
}

/// Someone to place, with the Patient row the user is shown.
class HolderAsk {
  const HolderAsk(this.question, this.patient);

  final HolderQuestion question;
  final Patient patient;
}

/// Everyone in the wallet, in the order their records came in, and who is
/// still to be placed.
class HolderDirectory {
  const HolderDirectory({this.holders = const [], this.questions = const []});

  final List<Holder> holders;
  final List<HolderAsk> questions;

  Holder? byId(String id) => holders.where((h) => h.id == id).firstOrNull;

  Holder? ofSource(String sourceId) =>
      holders.where((h) => h.existsInSource(sourceId)).firstOrNull;

  /// The holder [patient] belongs to: by its source, or, for a row id saved
  /// before holders existed, by the row.
  Holder? ofPatient(Patient patient) =>
      ofSource(patient.sourceId) ??
      holders.where((h) => h.hasPatient(patient)).firstOrNull;

  /// The holder with a Patient row of this id (or FHIR id), or this holder id.
  Holder? ofPatientId(String id) =>
      byId(id) ??
      holders
          .where(
            (h) => h.allPatientInstances.any(
              (p) => p.id == id || p.resourceId == id,
            ),
          )
          .firstOrNull;
}
