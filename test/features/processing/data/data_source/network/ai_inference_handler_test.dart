import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/app_constants.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_data_source.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_handler.dart';
import 'package:health_wallet/features/processing/data/model/generation_stats.dart';
import 'package:health_wallet/features/processing/domain/services/processing_log_buffer.dart';
import 'package:image/image.dart' as img;
import 'package:llamadart/llamadart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../share_records/share_test_helpers.dart';

/// One [LlamaEngine.create] call.
typedef _Create = ({
  List<LlamaChatMessage> messages,
  GenerationParams? params,
  Map<String, dynamic>? responseFormat,
  Map<String, dynamic>? chatTemplateKwargs,
});

/// A llama engine the test drives. Like llama.cpp it runs one generation at
/// a time, and a cancel ends the running one with the text sent so far.
class _FakeEngine extends Fake implements LlamaEngine {
  final calls = <_Create>[];

  /// Sent by each generation as soon as it starts.
  List<String> tokens = const [];
  String? finishReason;
  LlamaGenerationUsage? usage;

  /// Fails each generation after its tokens.
  Object? error;

  /// Keeps each generation open after its tokens, until [finish] or a cancel.
  bool hold = false;

  bool perfFails = false;
  var cancels = 0;
  var disposed = false;

  StreamController<LlamaCompletionChunk>? _running;

  bool get generating => _running != null;

  static LlamaCompletionChunk chunk({
    String? content,
    String? finishReason,
    LlamaGenerationUsage? usage,
  }) => LlamaCompletionChunk(
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
    usage: usage,
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
  }) {
    if (_running != null) {
      throw StateError('llama.cpp generation is already in progress');
    }
    calls.add((
      messages: messages,
      params: params,
      responseFormat: responseFormat,
      chatTemplateKwargs: chatTemplateKwargs,
    ));
    // ignore: close_sinks, closed by finish(), also on a cancel.
    final controller = StreamController<LlamaCompletionChunk>();
    _running = controller;
    for (final token in tokens) {
      controller.add(chunk(content: token));
    }
    if (error != null) controller.addError(error!);
    if (!hold) finish();
    return controller.stream;
  }

  void send(String token) => _running!.add(chunk(content: token));

  /// Ends the running generation with its final chunk.
  void finish() {
    final controller = _running;
    if (controller == null) return;
    _running = null;
    controller
      ..add(chunk(finishReason: finishReason, usage: usage))
      ..close();
  }

  @override
  void cancelGeneration() {
    cancels++;
    finish();
  }

  @override
  Future<void> dispose() async => disposed = true;

  @override
  Future<BackendPerfContextData?> getPerformanceContext() async {
    if (perfFails) throw StateError('no performance counters');
    return null;
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
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory logRoot;
  late ProcessingLogBuffer log;
  late _FakeEngine engine;
  late _Handler handler;

  final isDesktopHost =
      Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  // One folder for every test's log, deleted at the end: an append queued
  // inside fakeAsync never runs, so a test can't wait for its log to settle.
  setUpAll(() => logRoot = Directory.systemTemp.createTempSync('hw_ai_log_'));
  tearDownAll(() => logRoot.deleteSync(recursive: true));

  setUp(() {
    log = ProcessingLogBuffer.forTesting(
      enabled: true,
      directory: logRoot.createTempSync(),
    );
    ProcessingLogBuffer.debugOverrideInstance(log);
    engine = _FakeEngine();
    handler = _Handler()..engine = engine;
  });

  tearDown(() => ProcessingLogBuffer.debugOverrideInstance(null));

  Matcher logged(String part) => contains(contains(part));

  group('text prompt', () {
    test('sends the extractor instruction and the prompt, returns the whole '
        'answer and keeps its stats', () async {
      engine
        ..tokens = ['{"a":', '1}']
        ..finishReason = 'stop'
        ..usage = const LlamaGenerationUsage(
          promptTokens: 30,
          completionTokens: 2,
        );

      final answer = await handler.runTextPromptImpl(
        prompt: 'Read this',
        grammar: 'root ::= "x"',
        responseFormat: const {'type': 'json_object'},
      );

      expect(answer, '{"a":1}');
      final call = engine.calls.single;
      expect(call.messages.map((m) => m.role), [
        LlamaChatRole.system,
        LlamaChatRole.user,
      ]);
      expect(call.messages.last.content, 'Read this\n\nJSON:\n');
      expect(call.params!.maxTokens, AppConstants.defaultMaxTokens);
      expect(call.params!.grammar, 'root ::= "x"');
      expect(call.params!.temp, 0.0);
      expect(call.responseFormat, const {'type': 'json_object'});
      expect(call.chatTemplateKwargs, isNull);
      final stats = handler.lastGenerationStats!;
      expect(stats.mode, GenerationMode.text);
      expect(stats.promptTokens, 30);
      expect(stats.completionTokens, 2);
      expect(stats.finishReason, 'stop');
      expect(handler.isGenerating, isFalse);
      expect(log.getAll(), logged('text done: 2 tokens'));
    });

    test('with chat-template kwargs the prompt is the only message', () async {
      engine.tokens = ['{}'];

      await handler.runTextPromptImpl(
        prompt: 'the document',
        chatTemplateKwargs: const {'template': '{}'},
      );

      final call = engine.calls.single;
      expect(call.messages.single.role, LlamaChatRole.user);
      expect(call.messages.single.content, 'the document');
      expect(call.chatTemplateKwargs, const {'template': '{}'});
    });

    test('an answer that reaches maxTokens is logged as possibly cut off, '
        'with a shortened preview', () async {
      engine
        ..tokens = ['a' * 130, 'b']
        ..perfFails = true;

      final answer = await handler.runTextPromptImpl(
        prompt: 'p',
        maxTokens: 2,
      );

      expect(answer, '${'a' * 130}b');
      expect(engine.calls.single.params!.maxTokens, 2);
      expect(log.getAll(), logged('hit maxTokens limit (2)'));
      expect(log.getAll(), logged('response: ${'a' * 120}...'));
      // Without performance counters the stats are still kept.
      expect(handler.lastGenerationStats!.promptEvalMs, isNull);
    });

    test('a failed generation is logged and rethrown, and leaves no '
        'stats', () async {
      engine.error = StateError('decode failed');

      await expectLater(
        handler.runTextPromptImpl(prompt: 'p'),
        throwsA(isA<StateError>()),
      );

      expect(log.getAll(), logged('text FAILED after'));
      expect(handler.lastGenerationStats, isNull);
      expect(handler.isGenerating, isFalse);
    });

    test('logs the prompt while it is read, then the answer as it '
        'grows', () {
      fakeAsync((async) {
        engine.hold = true;
        String? answer;
        handler.runTextPromptImpl(prompt: 'p').then((a) => answer = a);
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 6));
        expect(log.getAll(), logged('no tokens generated yet'));

        engine.send('x' * 70);
        async.flushMicrotasks();
        expect(log.getAll(), logged('text: prefill done in'));
        async.elapse(const Duration(seconds: 5));
        expect(log.getAll(), logged('text: generating... 1 tokens'));
        expect(log.getAll(), logged('| ...${'x' * 60}'));

        engine.send('y');
        async.elapse(const Duration(seconds: 5));
        engine.finish();
        async.flushMicrotasks();
        expect(answer, '${'x' * 70}y');
      });
    });

    test('a short answer is logged whole while it grows', () {
      fakeAsync((async) {
        engine.hold = true;
        handler.runTextPromptImpl(prompt: 'p');
        async.flushMicrotasks();
        engine.send('short');
        async.elapse(const Duration(seconds: 5));

        // The stopwatch runs on the real clock: the seconds are not checked.
        expect(log.getAll(), logged('generating... 1 tokens, '));
        expect(log.getAll(), contains(endsWith('s | short')));
        engine.finish();
        async.flushMicrotasks();
      });
    });
  });

  group('vision prompt', () {
    late Directory root;

    setUp(() => root = mockPathProvider());

    String png(String name, int width, int height) {
      final file = File('${root.path}/$name')
        ..writeAsBytesSync(
          img.encodePng(img.Image(width: width, height: height)),
        );
      return file.path;
    }

    test('a large page is shrunk to the size limit, a missing one is '
        'skipped, and the pages go before the prompt', () async {
      final large = png(
        'large.png',
        AiInferenceHandler.maxImageDimension * 2,
        8,
      );
      final small = png('small.png', 10, 10);
      engine.tokens = ['[]'];

      final answer = await handler.runVisionPromptImpl(
        prompt: 'Read the page',
        imagePaths: [large, '${root.path}/missing.png', small],
        responseFormat: const {'type': 'json_object'},
      );

      expect(answer, '[]');
      final call = engine.calls.single;
      final parts = call.messages.last.parts;
      final images = parts.whereType<LlamaImageContent>().toList();
      expect(images, hasLength(2));
      final resized = images.first.path!;
      expect(
        resized,
        endsWith('${TempFileSweeper.resizedImagePrefix}large.png'),
      );
      final shrunk = img.decodeImage(File(resized).readAsBytesSync())!;
      expect(shrunk.width, AiInferenceHandler.maxImageDimension);
      expect(images.last.path, small);
      expect((parts.last as LlamaTextContent).text, 'Read the page');
      expect(call.messages.first.role, LlamaChatRole.system);
      expect(
        call.params!.maxTokens,
        isDesktopHost
            ? AppConstants.desktopVisionMaxTokens
            : AppConstants.visionMaxTokens,
      );
      expect(call.responseFormat, const {'type': 'json_object'});
      expect(handler.lastGenerationStats!.mode, GenerationMode.vision);
      expect(log.getAll(), logged('image skipped (not found): missing.png'));
      expect(log.getAll(), logged('resized from'));
      expect(log.getAll(), logged('limit ok'));
    });

    test('an answer that reaches maxTokens is logged as possibly cut '
        'off', () async {
      engine.tokens = ['a' * 130, 'b'];

      final answer = await handler.runVisionPromptImpl(
        prompt: 'p',
        imagePaths: const [],
        maxTokens: 2,
        grammar: 'root ::= "x"',
      );

      expect(answer, '${'a' * 130}b');
      expect(engine.calls.single.params!.grammar, 'root ::= "x"');
      expect(log.getAll(), logged('hit maxTokens limit (2)'));
      expect(log.getAll(), logged('response: ${'a' * 120}...'));
    });

    test('a failed generation is logged and rethrown', () async {
      engine.error = StateError('image encode failed');

      await expectLater(
        handler.runVisionPromptImpl(prompt: 'p', imagePaths: const []),
        throwsA(isA<StateError>()),
      );

      expect(log.getAll(), logged('FAILED after'));
      expect(handler.isGenerating, isFalse);
    });

    test('logs the encoding while it lasts, then the answer as it '
        'grows', () {
      fakeAsync((async) {
        engine.hold = true;
        String? answer;
        handler
            .runVisionPromptImpl(prompt: 'p', imagePaths: const [])
            .then((a) => answer = a);
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 11));
        expect(log.getAll(), logged('still encoding... '));

        engine.send('x' * 70);
        async.flushMicrotasks();
        expect(log.getAll(), logged('image encoded + prefill done'));
        async.elapse(const Duration(seconds: 5));
        expect(log.getAll(), logged('generating... 1 tokens'));
        expect(log.getAll(), logged('| ...${'x' * 60}'));

        engine.send('y');
        async.flushMicrotasks();
        engine.finish();
        async.flushMicrotasks();
        expect(answer, '${'x' * 70}y');
      });
    });

    test('a short answer is logged whole while it grows', () {
      fakeAsync((async) {
        engine.hold = true;
        handler.runVisionPromptImpl(prompt: 'p', imagePaths: const []);
        async.flushMicrotasks();
        engine.send('short');
        async.elapse(const Duration(seconds: 5));

        // The stopwatch runs on the real clock: the seconds are not checked.
        expect(log.getAll(), logged('generating... 1 tokens, '));
        expect(log.getAll(), contains(endsWith('s | short')));
        engine.finish();
        async.flushMicrotasks();
      });
    });

    test('a page that is missing, not an image or small enough is used as '
        'it is', () async {
      final notAnImage = File('${root.path}/note.png')
        ..writeAsStringSync('not an image');
      final small = png('small.png', 10, 10);

      for (final path in [
        '${root.path}/missing.png',
        notAnImage.path,
        small,
      ]) {
        expect(await handler.resizeImageIfNeeded(path), path);
      }
    });
  });

  group('one generation at a time', () {
    test('cancelGeneration stops the running generation, which returns what '
        'it generated so far', () async {
      engine.hold = true;
      final answer = handler.runTextPromptImpl(prompt: 'p');
      await pumpEventQueue();
      engine.send('{"partial":');
      await pumpEventQueue();

      handler.cancelGeneration();

      expect(engine.cancels, 1);
      expect(await answer, '{"partial":');
      expect(log.getAll(), logged('cancelling the running generation'));
    });

    test('cancelGeneration with nothing running leaves the engine '
        'alone', () {
      handler.cancelGeneration();

      expect(engine.cancels, 0);
    });

    test('disposeModel during a generation waits for it to end, then '
        'disposes the engine', () async {
      engine.hold = true;
      final answer = handler.runTextPromptImpl(prompt: 'p');
      await pumpEventQueue();

      var disposed = false;
      final dispose = handler.disposeModel().then((_) => disposed = true);
      await pumpEventQueue();
      expect(disposed, isFalse);
      expect(engine.disposed, isFalse);

      engine.finish();
      await answer;
      await dispose;
      expect(engine.disposed, isTrue);
      expect(handler.engine, isNull);
      expect(handler.pendingDisposal, isFalse);
    });

    test('a prompt sent during another generation waits for it instead of '
        'failing', () async {
      engine
        ..hold = true
        ..tokens = ['first'];
      final first = handler.runTextPromptImpl(prompt: 'one');
      await pumpEventQueue();

      final second = handler.runVisionPromptImpl(
        prompt: 'two',
        imagePaths: const [],
      );
      await pumpEventQueue();
      expect(engine.calls, hasLength(1));

      engine.hold = false;
      engine.finish();
      expect(await first, 'first');
      expect(await second, 'first');
      expect(engine.calls, hasLength(2));
    });

    test('a prompt that waited while the engine was disposed fails as not '
        'loaded', () async {
      engine.hold = true;
      final first = handler.runTextPromptImpl(prompt: 'one');
      await pumpEventQueue();
      final dispose = handler.disposeModel();
      final second = handler.runTextPromptImpl(prompt: 'two');
      await pumpEventQueue();

      engine.finish();
      await first;
      await dispose;
      await expectLater(
        second,
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Model not initialized'),
          ),
        ),
      );
      expect(engine.calls, hasLength(1));
    });

    test('waitForGeneration returns at once when nothing runs', () async {
      await handler.waitForGeneration().timeout(const Duration(seconds: 1));
    });
  });

  group('data source', () {
    late Directory docs;
    late AiInferenceDataSourceImpl dataSource;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      docs = Directory.systemTemp.createTempSync('hw_ai_handler_docs_');
      addTearDown(() => docs.deleteSync(recursive: true));
      dataSource = AiInferenceDataSourceImpl(
        await SharedPreferences.getInstance(),
        useDio: true,
        documentsDirectory: () async => docs,
      )..engine = engine;
    });

    test('cancelGeneration reaches the running generation', () async {
      engine.hold = true;
      final answer = dataSource.runTextPrompt(prompt: 'p');
      await pumpEventQueue();

      dataSource.cancelGeneration();

      expect(engine.cancels, 1);
      expect(await answer, '');
    });

    test('initModel waits for a running generation, then keeps the loaded '
        'engine', () async {
      engine.hold = true;
      final answer = dataSource.runTextPrompt(prompt: 'p');
      await pumpEventQueue();

      var loaded = false;
      // No model file: a new load would throw.
      final load = dataSource.initModel().then((_) => loaded = true);
      await pumpEventQueue();
      expect(loaded, isFalse);

      engine.finish();
      await answer;
      await load;
      expect(dataSource.engine, same(engine));
      expect(engine.disposed, isFalse);
    });
  });
}
