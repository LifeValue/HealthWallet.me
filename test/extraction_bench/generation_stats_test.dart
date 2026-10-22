import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_handler.dart';
import 'package:health_wallet/features/processing/data/model/generation_stats.dart';
import 'package:llamadart/llamadart.dart';

class _Handler with AiInferenceHandler {
  @override
  LlamaEngine? engine;
  @override
  bool hasVisionProjector = false;
  @override
  String get ts => '00:00:00.000';
}

void main() {
  test('buildGenerationStats converts usage durations to ms and keeps token counts', () async {
    final stats = await _Handler().buildGenerationStats(
      GenerationMode.vision,
      const LlamaGenerationUsage(
        promptTokens: 812,
        completionTokens: 143,
        timeToFirstToken: Duration(microseconds: 1500),
        duration: Duration(milliseconds: 4210, microseconds: 700),
      ),
    );
    expect(stats.mode, GenerationMode.vision);
    expect(stats.promptTokens, 812);
    expect(stats.completionTokens, 143);
    expect(stats.timeToFirstTokenMs, 1.5);
    expect(stats.durationMs, 4210.7);
    // No engine, so no performance context.
    expect(stats.promptEvalMs, isNull);
  });

  test('buildGenerationStats without usage leaves every value null', () async {
    final stats = await _Handler().buildGenerationStats(GenerationMode.text, null);
    expect(stats, const GenerationStats(mode: GenerationMode.text));
  });

  test('lastGenerationStats is reset when a call starts', () async {
    final handler = _Handler()..lastGenerationStats = const GenerationStats(mode: GenerationMode.text);
    await expectLater(handler.runTextPromptImpl(prompt: 'p'), throwsException);
    expect(handler.lastGenerationStats, isNull);
  });
}
