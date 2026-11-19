import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/processing/data/model/structured_output/extraction_schemas.dart';

class CorrectionTemplateLoader {
  static final CorrectionTemplateLoader _instance =
      CorrectionTemplateLoader._();
  factory CorrectionTemplateLoader() => _instance;
  CorrectionTemplateLoader._();

  Map<String, List<Map<String, dynamic>>>? _cache;

  Future<void> _ensureLoaded() async {
    if (_cache != null) return;
    _cache = {};

    const templates = [
      'assets/correction_templates/ro/discharge_letter_female.json',
      'assets/correction_templates/ro/discharge_letter_male.json',
      'assets/correction_templates/ro/lab_report_female.json',
      'assets/correction_templates/ro/lab_report_male.json',
      'assets/correction_templates/ro/histopathology_report_female.json',
      'assets/correction_templates/ro/gynecology_exam_female.json',
    ];

    for (final path in templates) {
      try {
        final jsonStr = await rootBundle.loadString(path);
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final category = data['category'] as String? ?? 'visit';
        _cache!.putIfAbsent(category, () => []).add(data);
      } catch (e) {
        logger.w('Could not load the correction template $path', e);
      }
    }
  }

  Future<String?> getBestExample({
    String? documentCategory,
    String? ocrText,
  }) async {
    final template = await _bestTemplate(
      documentCategory: documentCategory,
      ocrText: ocrText,
    );
    if (template == null) return null;
    // Lab-report prompts offer no Condition, so neither does their example.
    return _formatExample(
      template,
      exclude: documentCategory == 'lab_report'
          ? const {'Condition'}
          : const {},
    );
  }

  /// The best template as the phase-2 schema object of [documentCategory]:
  /// its first 8 resources of a type that category has an array for.
  Future<String?> getBestExampleObject({
    String? documentCategory,
    String? ocrText,
  }) async {
    final template = await _bestTemplate(
      documentCategory: documentCategory,
      ocrText: ocrText,
    );
    if (template == null) return null;
    final types = {
      for (final s in ExtractionSchemas.sectionsFor(documentCategory))
        s.resourceType,
    };
    final resources = [
      for (final r in template['extraction'] as List<dynamic>)
        if (r is Map<String, dynamic> && types.contains(r['resourceType'])) r,
    ].take(8).toList();
    if (resources.isEmpty) return null;
    return jsonEncode(
      ExtractionSchemas.legacyToRemaining(resources, documentCategory),
    );
  }

  Future<Map<String, dynamic>?> _bestTemplate({
    String? documentCategory,
    String? ocrText,
  }) async {
    await _ensureLoaded();

    final category = documentCategory ?? 'visit';
    final candidates = _cache?[category];
    if (candidates == null || candidates.isEmpty) return null;

    Map<String, dynamic>? bestTemplate;
    int bestScore = -1;

    for (final template in candidates) {
      int score = 0;
      final templateOcr = (template['ocrExcerpt'] as String? ?? '')
          .toLowerCase();

      if (ocrText != null && ocrText.isNotEmpty) {
        final ocrLower = ocrText.toLowerCase();
        final detectedGender = _detectGender(ocrLower);
        if (detectedGender == template['gender']) score += 3;

        if (ocrLower.contains('buletin de analize') ||
            ocrLower.contains('hemoleucograma')) {
          if (templateOcr.contains('buletin de analize')) score += 2;
        }
        if (ocrLower.contains('anatomo-patologic') ||
            ocrLower.contains('histopatologic')) {
          if (templateOcr.contains('anatomo-patologic')) score += 2;
        }
        if (ocrLower.contains('bilet de iesire') ||
            ocrLower.contains('scrisoare medicala')) {
          if (templateOcr.contains('bilet de iesire')) score += 2;
        }
        if (ocrLower.contains('fisa de examinare') ||
            ocrLower.contains('ecografie')) {
          if (templateOcr.contains('fisa de examinare')) score += 2;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestTemplate = template;
      }
    }

    return bestTemplate ?? candidates.first;
  }

  String? _detectGender(String ocrLower) {
    const femaleSignals = [
      'pacienta',
      'sex: f',
      'sex:f',
      'prenume mama',
      'gender: female',
      'gender:female',
      'feminin',
      'weiblich',
      'female',
    ];
    const maleSignals = [
      'pacientul',
      'pacient in varsta',
      'sex: m',
      'sex:m',
      'gender: male',
      'gender:male',
      'masculin',
      'männlich',
      'male',
    ];

    int femaleScore = 0;
    int maleScore = 0;
    for (final signal in femaleSignals) {
      if (ocrLower.contains(signal)) femaleScore++;
    }
    for (final signal in maleSignals) {
      if (ocrLower.contains(signal)) maleScore++;
    }

    if (femaleScore > maleScore) return 'female';
    if (maleScore > femaleScore) return 'male';

    final cnpMatch = RegExp(r'\b([12])\d{12}\b').firstMatch(ocrLower);
    if (cnpMatch != null) {
      return cnpMatch.group(1) == '2' ? 'female' : 'male';
    }

    return null;
  }

  String _formatExample(
    Map<String, dynamic> template, {
    Set<String> exclude = const {},
  }) {
    final extraction = (template['extraction'] as List<dynamic>).where(
      (r) => !exclude.contains((r as Map<String, dynamic>)['resourceType']),
    );

    final condensed = extraction
        .take(8)
        .map((resource) {
          final r = resource as Map<String, dynamic>;
          final copy = Map<String, dynamic>.from(r);
          copy.remove('confidenceLevel');
          return jsonEncode(copy);
        })
        .join(',\n');

    return '[\n$condensed\n]';
  }
}
