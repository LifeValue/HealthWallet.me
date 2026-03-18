import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:health_wallet/core/config/constants/app_constants.dart';
import 'package:health_wallet/features/scan/domain/services/scan_log_buffer.dart';
import 'package:image/image.dart' as img;
import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

mixin ScanInferenceHandler {
  LlamaEngine? get engine;
  set engine(LlamaEngine? value);
  bool get hasVisionProjector;
  set hasVisionProjector(bool value);
  String get ts;

  static const int maxImageDimension = 560;

  bool isGenerating = false;
  bool pendingDisposal = false;

  Future<void> disposeModel() async {
    pendingDisposal = true;

    if (isGenerating) {
      return;
    }

    await performActualDisposal();
  }

  Future<void> performActualDisposal() async {
    await engine?.dispose();
    engine = null;
    hasVisionProjector = false;
    pendingDisposal = false;
  }

  Future<String> resizeImageIfNeeded(String imagePath) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return imagePath;

    final w = decoded.width;
    final h = decoded.height;

    if (w <= maxImageDimension && h <= maxImageDimension) {
      return imagePath;
    }

    final scale = maxImageDimension / math.max(w, h);
    final newW = (w * scale).round();
    final newH = (h * scale).round();

    final resized = img.copyResize(decoded, width: newW, height: newH);
    final dir = await getTemporaryDirectory();
    final resizedPath =
        path.join(dir.path, 'resized_${path.basename(imagePath)}');
    await File(resizedPath).writeAsBytes(img.encodeJpg(resized, quality: 85));

    return resizedPath;
  }

  Future<String?> runVisionPromptImpl({
    required String prompt,
    required List<String> imagePaths,
    int? maxTokens,
  }) async {
    if (engine == null) {
      throw Exception('Model not initialized. Call initModel() first.');
    }

    final effectiveTokens = maxTokens ?? AppConstants.visionMaxTokens;
    ScanLogBuffer.instance
        .log('[$ts][ScanAI] --- VISION INFERENCE ---');
    ScanLogBuffer.instance.log(
        '[$ts][ScanAI] input: ${imagePaths.length} images, prompt ${prompt.length} chars, maxTokens=$effectiveTokens');

    final resizeSw = Stopwatch()..start();
    final resizedPaths = <String>[];
    for (final imgPath in imagePaths) {
      final originalSize =
          File(imgPath).existsSync() ? File(imgPath).lengthSync() : 0;
      final resized = await resizeImageIfNeeded(imgPath);
      final resizedSize =
          File(resized).existsSync() ? File(resized).lengthSync() : 0;
      final wasResized = resized != imgPath;
      ScanLogBuffer.instance.log(
          '[$ts][ScanAI] image: ${(resizedSize / 1024).toStringAsFixed(0)}KB${wasResized ? ' (resized from ${(originalSize / 1024).toStringAsFixed(0)}KB, max ${maxImageDimension}px)' : ' (${maxImageDimension}px limit ok)'}');
      resizedPaths.add(resized);
    }
    resizeSw.stop();
    if (resizeSw.elapsedMilliseconds > 100) {
      ScanLogBuffer.instance.log(
          '[$ts][ScanAI] image prep: ${(resizeSw.elapsedMilliseconds / 1000.0).toStringAsFixed(1)}s');
    }

    final content = <LlamaContentPart>[
      for (final imgPath in resizedPaths) LlamaImageContent(path: imgPath),
      LlamaTextContent(prompt),
    ];

    final messages = [
      LlamaChatMessage.fromText(
        role: LlamaChatRole.system,
        text:
            'You are a medical document data extractor. Output only valid JSON.',
      ),
      LlamaChatMessage.withContent(
        role: LlamaChatRole.user,
        content: content,
      ),
    ];

    isGenerating = true;
    final sw = Stopwatch()..start();
    Timer? heartbeat;
    try {
      final buffer = StringBuffer();
      int tokenCount = 0;
      ScanLogBuffer.instance.log(
          '[$ts][ScanAI] encoding image + prompt (native, no callbacks available)...');

      heartbeat = Timer.periodic(const Duration(seconds: 10), (_) {
        final elapsed =
            (sw.elapsedMilliseconds / 1000.0).toStringAsFixed(0);
        if (tokenCount == 0) {
          ScanLogBuffer.instance
              .log('[$ts][ScanAI] still encoding... ${elapsed}s elapsed');
        }
      });

      await for (final chunk in engine!.create(
        messages,
        params: GenerationParams(
          maxTokens: effectiveTokens,
          temp: 0.0,
          topK: 1,
          topP: 1.0,
        ),
        enableThinking: false,
      )) {
        final text = chunk.choices.first.delta.content;
        if (text != null) {
          buffer.write(text);
          tokenCount++;
          if (tokenCount == 1) {
            heartbeat?.cancel();
            final prefillSec =
                (sw.elapsedMilliseconds / 1000.0).toStringAsFixed(1);
            ScanLogBuffer.instance.log(
                '[$ts][ScanAI] image encoded + prefill done in ${prefillSec}s, generating JSON...');
            heartbeat = Timer.periodic(const Duration(seconds: 5), (_) {
              final elapsed =
                  (sw.elapsedMilliseconds / 1000.0).toStringAsFixed(0);
              final snippet = buffer.length > 60
                  ? '...${buffer.toString().substring(buffer.length - 60)}'
                  : buffer.toString();
              ScanLogBuffer.instance.log(
                  '[$ts][ScanAI] generating... $tokenCount tokens, ${elapsed}s | $snippet');
            });
          }
        }
      }

      heartbeat?.cancel();
      sw.stop();
      final totalSec = sw.elapsedMilliseconds / 1000.0;
      final tokPerSec = tokenCount > 0
          ? (tokenCount / totalSec).toStringAsFixed(1)
          : '0';
      ScanLogBuffer.instance.log(
          '[$ts][ScanAI] done: $tokenCount tokens in ${totalSec.toStringAsFixed(1)}s ($tokPerSec tok/s)');
      if (tokenCount >= effectiveTokens) {
        ScanLogBuffer.instance.log(
            '[$ts][ScanAI] WARNING: hit maxTokens limit ($effectiveTokens), output may be truncated');
      }
      final preview = buffer.length > 120
          ? '${buffer.toString().substring(0, 120)}...'
          : buffer.toString();
      ScanLogBuffer.instance.log('[$ts][ScanAI] response: $preview');
      return buffer.toString();
    } catch (e) {
      heartbeat?.cancel();
      sw.stop();
      ScanLogBuffer.instance.log(
          '[$ts][ScanAI] FAILED after ${(sw.elapsedMilliseconds / 1000.0).toStringAsFixed(1)}s: $e');
      rethrow;
    } finally {
      heartbeat?.cancel();
      isGenerating = false;
      if (pendingDisposal) {
        await performActualDisposal();
      }
    }
  }

  Future<String?> runTextPromptImpl({
    required String prompt,
    int? maxTokens,
  }) async {
    if (engine == null) {
      throw Exception('Model not initialized. Call initModel() first.');
    }

    final effectiveTokens = maxTokens ?? AppConstants.defaultMaxTokens;
    ScanLogBuffer.instance.log('[$ts][ScanAI] --- TEXT INFERENCE ---');
    ScanLogBuffer.instance.log(
        '[$ts][ScanAI] prompt ${prompt.length} chars, maxTokens=$effectiveTokens');

    final messages = [
      LlamaChatMessage.fromText(
        role: LlamaChatRole.system,
        text:
            'You are a medical document data extractor. Output only valid JSON.',
      ),
      LlamaChatMessage.fromText(
        role: LlamaChatRole.user,
        text: '$prompt\n\nJSON:\n',
      ),
    ];

    isGenerating = true;
    final sw = Stopwatch()..start();
    Timer? heartbeat;
    try {
      final buffer = StringBuffer();
      int tokenCount = 0;

      heartbeat = Timer.periodic(const Duration(seconds: 5), (_) {
        final elapsed =
            (sw.elapsedMilliseconds / 1000.0).toStringAsFixed(0);
        if (tokenCount == 0) {
          ScanLogBuffer.instance.log(
              '[$ts][ScanAI] text: processing prompt (no tokens generated yet)... ${elapsed}s elapsed');
        } else {
          final snippet = buffer.length > 60
              ? '...${buffer.toString().substring(buffer.length - 60)}'
              : buffer.toString();
          ScanLogBuffer.instance.log(
              '[$ts][ScanAI] text: generating... $tokenCount tokens, ${elapsed}s | $snippet');
        }
      });

      await for (final chunk in engine!.create(
        messages,
        params: GenerationParams(
          maxTokens: effectiveTokens,
          temp: 0.0,
          topK: 1,
          topP: 1.0,
        ),
        enableThinking: false,
      )) {
        final text = chunk.choices.first.delta.content;
        if (text != null) {
          buffer.write(text);
          tokenCount++;
          if (tokenCount == 1) {
            final prefillMs = sw.elapsedMilliseconds;
            ScanLogBuffer.instance.log(
                '[$ts][ScanAI] text: prefill done in ${(prefillMs / 1000.0).toStringAsFixed(1)}s, generating JSON...');
          }
        }
      }

      heartbeat.cancel();
      sw.stop();
      final totalSec = sw.elapsedMilliseconds / 1000.0;
      final tokPerSec = tokenCount > 0
          ? (tokenCount / totalSec).toStringAsFixed(1)
          : '0';
      ScanLogBuffer.instance.log(
          '[$ts][ScanAI] text done: $tokenCount tokens in ${totalSec.toStringAsFixed(1)}s ($tokPerSec tok/s)');
      if (tokenCount >= effectiveTokens) {
        ScanLogBuffer.instance.log(
            '[$ts][ScanAI] WARNING: hit maxTokens limit ($effectiveTokens), output may be truncated');
      }
      final preview = buffer.length > 120
          ? '${buffer.toString().substring(0, 120)}...'
          : buffer.toString();
      ScanLogBuffer.instance.log('[$ts][ScanAI] response: $preview');
      return buffer.toString();
    } catch (e) {
      heartbeat?.cancel();
      sw.stop();
      ScanLogBuffer.instance.log(
          '[$ts][ScanAI] text FAILED after ${(sw.elapsedMilliseconds / 1000.0).toStringAsFixed(1)}s: $e');
      rethrow;
    } finally {
      heartbeat?.cancel();
      isGenerating = false;
      if (pendingDisposal) {
        await performActualDisposal();
      }
    }
  }
}
