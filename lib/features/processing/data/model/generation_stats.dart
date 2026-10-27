import 'package:freezed_annotation/freezed_annotation.dart';

part 'generation_stats.freezed.dart';
part 'generation_stats.g.dart';

enum GenerationMode { vision, text }

/// Token counts and timings of one `runVisionPrompt` / `runTextPrompt` call,
/// taken from the final chunk's `usage` and the engine's performance context.
/// A value the backend does not report stays null.
@freezed
abstract class GenerationStats with _$GenerationStats {
  const factory GenerationStats({
    required GenerationMode mode,
    int? promptTokens,
    int? completionTokens,
    double? timeToFirstTokenMs,
    double? promptEvalMs,
    double? durationMs,

    /// The final chunk's `finishReason`: `stop` when the model ended its
    /// output, `length` when it hit maxTokens or a full context (truncated).
    String? finishReason,
  }) = _GenerationStats;

  factory GenerationStats.fromJson(Map<String, dynamic> json) =>
      _$GenerationStatsFromJson(json);
}
