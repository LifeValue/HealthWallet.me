import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_handler.dart';
import 'package:health_wallet/features/processing/data/model/generation_stats.dart';
import 'package:llamadart/llamadart.dart';

/// Records the `responseFormat` of each `create` and streams one content
/// chunk, then a final chunk that stopped at the token limit.
class _FakeEngine extends Fake implements LlamaEngine {
  final responseFormats = <Map<String, dynamic>?>[];
  final grammars = <String?>[];

  LlamaCompletionChunk _chunk({String? content, String? finishReason}) => LlamaCompletionChunk(
        id: 'c',
        object: 'chat.completion.chunk',
        created: 0,
        model: 'fake',
        choices: [
          LlamaCompletionChunkChoice(
            index: 0,
            delta: LlamaCompletionChunkDelta(content: content),
            finishReason: finishReason,
          ),
        ],
      );

  @override
  Stream<LlamaCompletionChunk> create(
    List<LlamaChatMessage> messages, {
    GenerationParams? params,
    List<ToolDefinition>? tools,
    ToolChoice? toolChoice,
    bool parallelToolCalls = false,
    bool enableThinking = true,
    Map<String, dynamic>? responseFormat,
    String? sourceLangCode,
    String? targetLangCode,
    Map<String, dynamic>? chatTemplateKwargs,
    DateTime? templateNow,
  }) async* {
    responseFormats.add(responseFormat);
    grammars.add(params?.grammar);
    yield _chunk(content: '{"a":');
    yield _chunk(finishReason: 'length');
  }
}

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
    expect(stats.finishReason, isNull);
  });

  test('buildGenerationStats keeps the finish reason', () async {
    final stats = await _Handler().buildGenerationStats(GenerationMode.text, null, finishReason: 'length');
    expect(stats.finishReason, 'length');
    expect(GenerationStats.fromJson(stats.toJson()).finishReason, 'length');
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

  test('both run methods pass responseFormat to engine.create and keep the finish reason', () async {
    final engine = _FakeEngine();
    final handler = _Handler()..engine = engine;
    const format = {
      'type': 'json_schema',
      'json_schema': {'schema': {'type': 'object'}},
    };

    expect(await handler.runTextPromptImpl(prompt: 'p', responseFormat: format), '{"a":');
    expect(handler.lastGenerationStats!.finishReason, 'length');
    expect(handler.lastGenerationStats!.mode, GenerationMode.text);

    expect(await handler.runVisionPromptImpl(prompt: 'p', imagePaths: const [], responseFormat: format), '{"a":');
    expect(handler.lastGenerationStats!.finishReason, 'length');
    expect(handler.lastGenerationStats!.mode, GenerationMode.vision);

    await handler.runTextPromptImpl(prompt: 'p', grammar: 'root ::= "x"');
    expect(engine.responseFormats, [format, format, null]);
    expect(engine.grammars, [null, null, 'root ::= "x"']);
  });
}
