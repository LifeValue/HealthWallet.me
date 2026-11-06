import 'package:health_wallet/features/holders/domain/services/holder_matcher.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/extractor_provenance.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_identifier.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_organization.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_practitioner.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:uuid/uuid.dart';

/// Reads documents of one known layout (a clinic system that always prints
/// the same form) from their OCR text, exactly and without AI. Implementations
/// are deterministic: same text, same result, no network.
abstract class LayoutExtractor {
  /// Stable name of the layout, e.g. `clearvis.io`; part of the provenance
  /// tag and of the visit key system.
  String get id;

  /// Bumped whenever the output for the same text changes.
  int get version;

  /// How sure this extractor is that [ocrText] is its layout, 0 to 1; cheap.
  /// The registry hands the text to the best one scoring at least
  /// [LayoutExtractorRegistry.threshold].
  double score(String ocrText);

  /// The records the document holds, or null when a required field (the
  /// date, the patient's name) can't be read: the AI pipeline then runs.
  LayoutExtraction? extract(String ocrText);
}

/// What an extractor read, as staged resources for the review. The visit
/// [encounter] carries the visit key ([LayoutKeys.visitKey]), which both
/// documents of one visit share.
class LayoutExtraction {
  const LayoutExtraction({
    required this.extractorId,
    required this.version,
    required this.clinicKey,
    required this.patient,
    required this.organization,
    required this.encounter,
    this.practitioner,
    this.resources = const [],
  });

  final String extractorId;
  final int version;

  /// Names the clinic in identifier systems: the same in every document of
  /// that clinic.
  final String clinicKey;
  final MappingPatient patient;
  final MappingOrganization organization;
  final MappingPractitioner? practitioner;
  final MappingEncounter encounter;

  /// The document's own records, e.g. one VisionPrescription per
  /// prescription.
  final List<MappingResource> resources;

  String get provenance => ExtractorProvenance.code(extractorId, version);

  MappingIdentifier? get visitKey => encounter.visitKey;
}

/// The identifier systems and stable ids extractors share, so every layout
/// keys clinics, visits and supporting records the same way.
abstract final class LayoutKeys {
  /// The system of a clinic's own patient number: two clinics' `PA-00001`
  /// are two people.
  static String clinicPatientSystem(String clinicKey) =>
      '${HolderMatcher.clinicSystemPrefix}$clinicKey/patient';

  /// The system of the serials a clinic prints on its documents.
  static String clinicDocumentSystem(String clinicKey) =>
      '${HolderMatcher.clinicSystemPrefix}$clinicKey/document';

  /// Whether [system] is a clinic-scoped system ([clinicPatientSystem]).
  static bool isClinicScoped(String system) =>
      system.startsWith(HolderMatcher.clinicSystemPrefix);

  /// The visit key `<clinicKey>|<patientNumber>|<date>` under
  /// `http://healthwallet.me/visit/<extractorId>`.
  static MappingIdentifier visitKey({
    required String extractorId,
    required String clinicKey,
    required String patientNumber,
    required String date,
  }) => MappingIdentifier(
    system: '${MappingEncounter.visitKeySystemPrefix}$extractorId',
    value: '$clinicKey|$patientNumber|$date',
  );

  /// An id that is the same every time the same [parts] are read, so a
  /// supporting record (the clinic, the examiner) read again is recognised.
  static String stableId(String extractorId, List<String> parts) =>
      const Uuid().v5(
        Namespace.url.value,
        'http://healthwallet.me/extractor/$extractorId/${parts.join('|')}',
      );

  /// Lower case ASCII letters and digits joined by dashes:
  /// "Optică Centru 1" is `optica-centru-1`.
  static String slug(String text) {
    final folded = foldDiacritics(text.toLowerCase());
    return folded
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// [text] without the diacritics OCR drops or keeps at random.
  static String foldDiacritics(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final c = String.fromCharCode(rune);
      buffer.write(_diacritics[c] ?? c);
    }
    return buffer.toString();
  }

  static const _diacritics = {
    'ă': 'a',
    'â': 'a',
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'î': 'i',
    'í': 'i',
    'ï': 'i',
    'ș': 's',
    'ş': 's',
    'ț': 't',
    'ţ': 't',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'ó': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
    'Ă': 'A',
    'Â': 'A',
    'Î': 'I',
    'Ș': 'S',
    'Ş': 'S',
    'Ț': 'T',
    'Ţ': 'T',
  };
}
