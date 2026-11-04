import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;

/// The `meta.tag` that says which layout extractor read a record:
/// system [system], code `<extractor id>@<version>`.
abstract final class ExtractorProvenance {
  static const system = 'http://healthwallet.me/extractor';

  /// The tag code of [extractorId] at [version].
  static String code(String extractorId, int version) =>
      '$extractorId@$version';

  /// [meta] with the provenance tag [code] added to its tags (the specialty
  /// tag among them); [meta] unchanged when [code] is empty.
  static fhir_r4.FhirMeta? merge(fhir_r4.FhirMeta? meta, String code) {
    if (code.isEmpty) return meta;
    final tags = [...?meta?.tag];
    if (tags.any((t) => t.system?.valueString == system)) return meta;
    tags.add(
      fhir_r4.Coding(
        system: fhir_r4.FhirUri(system),
        code: fhir_r4.FhirCode(code),
      ),
    );
    return (meta ?? const fhir_r4.FhirMeta()).copyWith(tag: tags);
  }

  /// [raw] (a stored resource's JSON) with the provenance tag [code] added
  /// to `meta.tag`, keeping every tag it has.
  static Map<String, dynamic> mergeIntoJson(
    Map<String, dynamic> raw,
    String code,
  ) {
    if (code.isEmpty) return raw;
    final meta = Map<String, dynamic>.from(raw['meta'] as Map? ?? const {});
    final tags = [...?(meta['tag'] as List?)];
    if (tags.any((t) => t is Map && t['system'] == system)) return raw;
    tags.add({'system': system, 'code': code});
    return {
      ...raw,
      'meta': {...meta, 'tag': tags},
    };
  }
}
