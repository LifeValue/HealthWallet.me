/// The parts of a stored Patient row that say who it is, read straight from
/// its FHIR JSON so linking doesn't depend on the record entities.
class HolderPatient {
  const HolderPatient({
    required this.rowId,
    required this.resourceId,
    required this.sourceId,
    this.identifiers = const [],
    this.family = '',
    this.given = '',
    this.birthDate = '',
  });

  factory HolderPatient.fromRow({
    required String rowId,
    required String? resourceId,
    required String sourceId,
    required Map<String, dynamic> raw,
  }) {
    final names = (raw['name'] as List?)?.whereType<Map>().toList() ?? [];
    final name =
        names.where((n) => n['use'] == 'official').firstOrNull ??
        names.firstOrNull;
    return HolderPatient(
      rowId: rowId,
      resourceId: resourceId ?? rowId,
      sourceId: sourceId,
      identifiers: [
        for (final id in (raw['identifier'] as List?) ?? const [])
          if (id is Map && id['value'] is String)
            HolderIdentifier(
              system: id['system'] is String ? id['system'] as String : '',
              value: id['value'] as String,
              typeCodes: {
                for (final coding
                    in ((id['type'] as Map?)?['coding'] as List?) ?? const [])
                  if (coding is Map && coding['code'] is String)
                    coding['code'] as String,
              },
            ),
      ],
      family: name?['family'] is String ? name!['family'] as String : '',
      given: ((name?['given'] as List?) ?? const []).whereType<String>().join(
        ' ',
      ),
      birthDate: raw['birthDate'] is String ? raw['birthDate'] as String : '',
    );
  }

  /// The `fhir_resource` row id.
  final String rowId;

  /// The FHIR id, which other records reference as `Patient/<resourceId>`.
  final String resourceId;
  final String sourceId;
  final List<HolderIdentifier> identifiers;
  final String family;
  final String given;
  final String birthDate;

  /// The "Health Wallet Holder" created before the first sync or scan, still
  /// unnamed (see `DefaultPatientService`).
  bool get isPlaceholder =>
      rowId == placeholderRowId &&
      given == 'Health Wallet' &&
      family == 'Holder';

  static const placeholderRowId = 'default_patient';
}

class HolderIdentifier {
  const HolderIdentifier({
    required this.system,
    required this.value,
    this.typeCodes = const {},
  });

  final String system;
  final String value;

  /// The `type.coding` codes (v2-0203), e.g. `MR` or `SS`.
  final Set<String> typeCodes;
}
