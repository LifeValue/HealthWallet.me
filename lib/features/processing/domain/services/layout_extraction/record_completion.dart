import 'package:collection/collection.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/extractor_provenance.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/records/domain/entity/vision_prescription/vision_prescription.dart';

/// Completes a record already in the wallet from a document read again: only
/// fields the stored record leaves empty are filled, a value is never
/// changed. The one exception is the placeholder prescriber an extractor
/// wrote itself, which counts as empty.
abstract final class RecordCompletion {
  /// [stored] (a VisionPrescription's JSON) with the fields it lacks taken
  /// from [read], tagged with [provenance]; null when there is nothing to
  /// fill.
  static Map<String, dynamic>? visionPrescription(
    Map<String, dynamic> stored,
    Map<String, dynamic> read, {
    required String provenance,
  }) {
    final out = Map<String, dynamic>.from(stored);
    var filled = false;

    for (final key in const ['identifier', 'encounter']) {
      if (_isEmpty(out[key]) && !_isEmpty(read[key])) {
        out[key] = read[key];
        filled = true;
      }
    }

    if (_isPlaceholder(out['prescriber']) &&
        read['prescriber'] is Map &&
        !_isPlaceholder(read['prescriber'])) {
      out['prescriber'] = read['prescriber'];
      filled = true;
    }

    final extensions = [...?(out['extension'] as List?)];
    for (final ext in (read['extension'] as List?) ?? const []) {
      if (ext is! Map) continue;
      if (!extensions.any((e) => e is Map && e['url'] == ext['url'])) {
        extensions.add(ext);
        filled = true;
      }
    }
    if (extensions.isNotEmpty) out['extension'] = extensions;

    final lenses = [
      for (final lens in (out['lensSpecification'] as List?) ?? const [])
        if (lens is Map) Map<String, dynamic>.from(lens),
    ];
    for (final readLens in (read['lensSpecification'] as List?) ?? const []) {
      if (readLens is! Map) continue;
      final lens = lenses.firstWhereOrNull((l) => l['eye'] == readLens['eye']);
      if (lens == null) {
        lenses.add(Map<String, dynamic>.from(readLens));
        filled = true;
        continue;
      }
      for (final key in const ['sphere', 'cylinder', 'axis', 'add', 'prism']) {
        if (_isEmpty(lens[key]) && !_isEmpty(readLens[key])) {
          lens[key] = readLens[key];
          filled = true;
        }
      }
    }
    out['lensSpecification'] = lenses;

    if (!filled) return null;
    return ExtractorProvenance.mergeIntoJson(out, provenance);
  }

  /// [stored] (an Encounter's JSON) with the identifiers of [read] it lacks
  /// added, tagged with [read]'s provenance; null when it has them all.
  static Map<String, dynamic>? addIdentifiers(
    Map<String, dynamic> stored,
    MappingEncounter read,
  ) {
    final missing = read.identifiersMissingFrom(stored);
    if (missing.isEmpty) return null;
    return ExtractorProvenance.mergeIntoJson({
      ...stored,
      'identifier': [
        ...?(stored['identifier'] as List?),
        for (final identifier in missing) identifier.toFhir().toJson(),
      ],
    }, read.provenance);
  }

  static bool _isEmpty(Object? value) =>
      value == null ||
      (value is String && value.isEmpty) ||
      (value is List && value.isEmpty) ||
      (value is Map && value.isEmpty);

  static bool _isPlaceholder(Object? reference) =>
      reference is Map &&
      ((reference['extension'] as List?) ?? const []).any(
        (e) => e is Map && e['url'] == VisionPrescriptionFhir.placeholderUrl,
      );
}
