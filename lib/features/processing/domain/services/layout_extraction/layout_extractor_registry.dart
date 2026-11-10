import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extractor.dart';
import 'package:health_wallet/features/processing/domain/services/processing_log_buffer.dart';

/// The layout extractors, in registration order. Adding a layout is one
/// entry in the list `register_module.dart` builds; nothing else changes.
class LayoutExtractorRegistry {
  LayoutExtractorRegistry(List<LayoutExtractor> extractors)
    : extractors = List.unmodifiable(extractors);

  /// The lowest score that hands a document to an extractor.
  static const threshold = 0.5;

  final List<LayoutExtractor> extractors;

  /// The extractor scoring highest on [ocrText], at least [threshold]; on a
  /// tie the one registered first. Null when none is sure enough, and the AI
  /// pipeline reads the document.
  LayoutExtractor? best(String ocrText) {
    LayoutExtractor? best;
    var bestScore = threshold;
    for (final extractor in extractors) {
      final score = extractor.score(ocrText);
      ProcessingLogBuffer.instance.log(
        '[${_ts()}][ScanAI] layout ${extractor.id}@${extractor.version} '
        'score ${score.toStringAsFixed(2)}',
      );
      if (score > bestScore || (best == null && score >= threshold)) {
        best = extractor;
        bestScore = score;
      }
    }
    return best;
  }

  static String _ts() => DateTime.now().toIso8601String().substring(11, 23);
}
