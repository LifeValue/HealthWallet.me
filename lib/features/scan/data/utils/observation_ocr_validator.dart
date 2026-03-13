import 'package:health_wallet/features/scan/domain/services/scan_log_buffer.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_observation.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:uuid/uuid.dart';

class _OcrObservation {
  final String name;
  final String value;
  final String unit;
  final String range;

  _OcrObservation({
    required this.name,
    required this.value,
    this.unit = '',
    this.range = '',
  });
}

class ObservationOcrValidator {
  static String get _ts => DateTime.now().toIso8601String().substring(11, 23);

  static final _linePattern = RegExp(
    r'^(.+?)\s+'
    r'(\d+[.,]\d+|\d+)'
    r'\s+'
    r'([A-Za-z%^/µμ0-9.*² ]+?)'
    r'\s+'
    r'([\d<>=.,]+\s*[-–]\s*[\d<>=.,]+|[<>]=?\s*[\d.,]+|>=?\s*[\d.,]+)'
    r'\s*$',
  );

  static final _linePatternNoRange = RegExp(
    r'^(.+?)\s+'
    r'(\d+[.,]\d+|\d+)'
    r'\s+'
    r'([A-Za-z%^/µμ0-9.*² ]+?)'
    r'\s*$',
  );

  static List<MappingResource> validate(
    List<MappingResource> resources,
    String ocrText,
  ) {
    if (ocrText.trim().isEmpty) return resources;

    final ocrObs = _parseOcrObservations(ocrText);
    if (ocrObs.isEmpty) return resources;

    final observations =
        resources.whereType<MappingObservation>().toList();
    if (observations.isEmpty) return resources;

    final others =
        resources.where((r) => r is! MappingObservation).toList();

    final corrected = <MappingObservation>[];
    final matchedOcrIndices = <int>{};
    int corrections = 0;

    for (final obs in observations) {
      final matchIndex = _findBestOcrMatch(
        obs.observationName.value,
        ocrObs,
        matchedOcrIndices,
      );

      if (matchIndex != null) {
        matchedOcrIndices.add(matchIndex);
        final ocrMatch = ocrObs[matchIndex];

        final normalizedAi = obs.value.value.replaceAll(',', '.').trim();
        final normalizedOcr = ocrMatch.value.replaceAll(',', '.').trim();

        if (normalizedAi != normalizedOcr) {
          corrections++;
          ScanLogBuffer.instance.log(
            '[$_ts][OcrValidator] CORRECTED "${obs.observationName.value}": '
            '"${obs.value.value}" -> "${ocrMatch.value}"',
          );
          corrected.add(MappingObservation(
            id: obs.id,
            observationName: obs.observationName,
            value: MappedProperty(
              value: ocrMatch.value,
              confidenceLevel: 1,
            ),
            unit: obs.unit.value.isNotEmpty
                ? obs.unit
                : MappedProperty(
                    value: ocrMatch.unit,
                    confidenceLevel: 0.8,
                  ),
            referenceRange: obs.referenceRange.value.isNotEmpty
                ? obs.referenceRange
                : MappedProperty(
                    value: ocrMatch.range,
                    confidenceLevel: 0.8,
                  ),
          ));
        } else {
          corrected.add(obs);
        }
      } else {
        corrected.add(obs);
      }
    }

    int added = 0;
    for (int i = 0; i < ocrObs.length; i++) {
      if (matchedOcrIndices.contains(i)) continue;

      final ocrMatch = ocrObs[i];
      final alreadyExtracted = observations.any(
        (o) => _namesMatch(o.observationName.value, ocrMatch.name),
      );
      if (alreadyExtracted) continue;

      added++;
      ScanLogBuffer.instance.log(
        '[$_ts][OcrValidator] ADDED missing "${ocrMatch.name}": '
        '${ocrMatch.value} ${ocrMatch.unit}',
      );
      corrected.add(MappingObservation(
        id: const Uuid().v4(),
        observationName: MappedProperty(
          value: ocrMatch.name,
          confidenceLevel: 0.7,
        ),
        value: MappedProperty(
          value: ocrMatch.value,
          confidenceLevel: 0.7,
        ),
        unit: MappedProperty(
          value: ocrMatch.unit,
          confidenceLevel: 0.7,
        ),
        referenceRange: MappedProperty(
          value: ocrMatch.range,
          confidenceLevel: 0.7,
        ),
      ));
    }

    if (corrections > 0 || added > 0) {
      ScanLogBuffer.instance.log(
        '[$_ts][OcrValidator] summary: $corrections corrected, $added added '
        '(${ocrObs.length} OCR obs, ${observations.length} AI obs)',
      );
    }

    return [...others, ...corrected];
  }

  static List<_OcrObservation> _parseOcrObservations(String ocrText) {
    final observations = <_OcrObservation>[];
    final lines = ocrText.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (_isHeaderLine(trimmed)) continue;

      final match = _linePattern.firstMatch(trimmed);
      if (match != null) {
        final name = _cleanName(match.group(1)!);
        if (name.isEmpty || _isExcludedName(name)) continue;

        observations.add(_OcrObservation(
          name: name,
          value: match.group(2)!.replaceAll(',', '.'),
          unit: match.group(3)!.trim(),
          range: match.group(4)!.trim(),
        ));
        continue;
      }

      final matchNoRange = _linePatternNoRange.firstMatch(trimmed);
      if (matchNoRange != null) {
        final name = _cleanName(matchNoRange.group(1)!);
        if (name.isEmpty || _isExcludedName(name)) continue;

        observations.add(_OcrObservation(
          name: name,
          value: matchNoRange.group(2)!.replaceAll(',', '.'),
          unit: matchNoRange.group(3)!.trim(),
        ));
      }
    }

    return observations;
  }

  static String _cleanName(String raw) {
    return raw
        .replaceAll(RegExp(r'[*#]+$'), '')
        .replaceAll(RegExp(r'^\s*[-•]\s*'), '')
        .trim();
  }

  static bool _isHeaderLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('interval biologic') ||
        lower.contains('interval de referinta') ||
        lower.contains('valori de referinta') ||
        lower.startsWith('test ') ||
        lower.startsWith('analiza ') ||
        lower == 'rezultat' ||
        lower == 'um' ||
        lower.contains('printed at') ||
        lower.contains('mrn:') ||
        lower.contains('mrn :') ||
        RegExp(r'^page\s+\d').hasMatch(lower);
  }

  static bool _isExcludedName(String name) {
    final lower = name.toLowerCase();
    if (RegExp(r'^\d+\s*ani?$').hasMatch(lower)) return true;
    if (RegExp(r'^sr\s*en\b|^iso\b|^en\s*iso\b').hasMatch(lower)) return true;
    if (RegExp(r'^\d+\s*(lun|zil|an)').hasMatch(lower)) return true;
    return lower.contains('departament') ||
        lower.contains('urgenta') ||
        lower.contains('varsta') ||
        lower.contains('salon') ||
        lower.contains('cod prezentare') ||
        lower.contains('cod set') ||
        lower.contains('acreditare') ||
        lower.startsWith('nr.') ||
        lower.startsWith('data ') ||
        lower.startsWith('medic') ||
        lower.startsWith('recoltat') ||
        lower.startsWith('eliberat') ||
        lower.startsWith('pacient') ||
        lower.startsWith('sectia') ||
        lower.startsWith('pat ');
  }

  static int? _findBestOcrMatch(
    String aiName,
    List<_OcrObservation> ocrObs,
    Set<int> alreadyMatched,
  ) {
    final normalizedAi = _normalize(aiName);
    if (normalizedAi.isEmpty) return null;

    int? bestIndex;
    double bestScore = 0;

    for (int i = 0; i < ocrObs.length; i++) {
      if (alreadyMatched.contains(i)) continue;

      final normalizedOcr = _normalize(ocrObs[i].name);
      final score = _similarity(normalizedAi, normalizedOcr);
      if (score > bestScore && score >= 0.6) {
        bestScore = score;
        bestIndex = i;
      }
    }

    return bestIndex;
  }

  static bool _namesMatch(String a, String b) {
    return _similarity(_normalize(a), _normalize(b)) >= 0.6;
  }

  static String _normalize(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[()#*]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    if (a.contains(b) || b.contains(a)) {
      final shorter = a.length < b.length ? a : b;
      final longer = a.length < b.length ? b : a;
      return shorter.length / longer.length;
    }

    final wordsA = a.split(' ').toSet();
    final wordsB = b.split(' ').toSet();
    final intersection = wordsA.intersection(wordsB);
    final union = wordsA.union(wordsB);
    if (union.isEmpty) return 0.0;
    return intersection.length / union.length;
  }
}
