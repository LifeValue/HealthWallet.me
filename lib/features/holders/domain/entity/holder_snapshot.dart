import 'package:health_wallet/features/holders/domain/entity/holder_patient.dart';

/// What linking reads: the live sources, the Patient rows, and for each
/// source without a Patient row, the patients its records refer to.
class HolderSnapshot {
  const HolderSnapshot({
    required this.sources,
    this.patients = const [],
    this.references = const {},
  });

  final List<HolderSource> sources;
  final List<HolderPatient> patients;

  /// Source id → the `Patient/<id>` references of its records.
  final Map<String, Set<String>> references;
}

class HolderSource {
  const HolderSource(this.id, {this.holderId});

  final String id;
  final String? holderId;

  static const walletPrefix = 'wallet-';
  static const demoId = 'demo_data';

  bool get isDemo => id == demoId;

  /// The id in `wallet-<id>`: the Patient row (or its FHIR id) the wallet
  /// source was made for.
  String? get walletPatientId =>
      id.startsWith(walletPrefix) ? id.substring(walletPrefix.length) : null;
}
