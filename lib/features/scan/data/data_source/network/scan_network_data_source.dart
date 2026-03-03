import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:health_wallet/core/config/constants/app_constants.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/config/env/env.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class ScanNetworkDataSource {
  Future<InferenceInstallation> downloadModel({
    required void Function(int) onProgress,
  });

  Future<bool> checkModelExistence();

  Future<String?> runPrompt({
    required String prompt,
  });

  Future<void> initModel();

  Future<void> disposeModel();
}

@LazySingleton(as: ScanNetworkDataSource)
class ScanNetworkDataSourceImpl implements ScanNetworkDataSource {
  final SharedPreferences _prefs;

  ScanNetworkDataSourceImpl(this._prefs);

  InferenceModel? _model;
  InferenceChat? _chat;

  @override
  Future<bool> checkModelExistence() async {
    return await FlutterGemma.isModelInstalled(AppConstants.modelId);
  }

  Future<void> _configureDownloaderForLargeFile() async {
    if (!Platform.isAndroid) return;

    FileDownloader().configureNotificationForGroup(
      'smart_downloads',
      running: const TaskNotification(
        'Downloading AI Model',
        'Progress: {progress}',
      ),
      complete: const TaskNotification(
        'AI Model Downloaded',
        'Ready to use',
      ),
      error: const TaskNotification(
        'Download Failed',
        'Tap to retry',
      ),
      progressBar: true,
    );

    await FileDownloader().configure(
      androidConfig: [
        (Config.runInForeground, Config.always),
      ],
    );
  }

  @override
  Future<InferenceInstallation> downloadModel({
    required void Function(int) onProgress,
  }) async {
    await _configureDownloaderForLargeFile();

    return FlutterGemma.installModel(
      modelType: ModelType.qwen,
    )
        .fromNetwork(
          AppConstants.modelUrl,
          token: Env.huggingFaceToken,
          foreground: true,
        )
        .withProgress(onProgress)
        .install();
  }

  Future<void> _activateModel() async {
    if (await checkModelExistence()) {
      await downloadModel(onProgress: (_) {});
    }
  }

  @override
  Future<void> initModel() async {
    if (_model != null) return;

    await _activateModel();

    _model = await FlutterGemma.getActiveModel(
      maxTokens: AppConstants.modelKvCacheSize,
      preferredBackend: PreferredBackend.cpu,
    );
  }

  bool _isGenerating = false;
  bool _pendingDisposal = false;

  @override
  Future<void> disposeModel() async {
    _pendingDisposal = true;

    if (_isGenerating) {
      return;
    }

    await _performActualDisposal();
  }

  Future<void> _performActualDisposal() async {
    await _chat?.session.close();
    _chat = null;
    await _model?.close();
    _model = null;
    _pendingDisposal = false;
  }

  @override
  Future<String?> runPrompt({
    required String prompt,
  }) async {
    if (_model == null) {
      throw Exception('Model not initialized. Call initModel() first.');
    }

    debugPrint('[ScanAI] runPrompt called, prompt length: ${prompt.length}');
    _chat ??= await _model!.createChat(
      topK: 40,
      temperature: 0.2,
      modelType: ModelType.qwen,
    );
    final chat = _chat!;

    const maxTokens = AppConstants.modelKvCacheSize;
    debugPrint('[ScanAI] checking token count, maxTokens: $maxTokens');
    final inputTokens = await chat.session.sizeInTokens(prompt);
    debugPrint('[ScanAI] inputTokens: $inputTokens, maxTokens: $maxTokens');
    if (inputTokens >= maxTokens) {
      debugPrint('[ScanAI] CAPACITY ERROR: input exceeds max tokens');
      throw Exception(
        'Input is too long for the model to process: '
        'input_size($inputTokens) was not less than maxTokens($maxTokens)',
      );
    }

    debugPrint('[ScanAI] sending prompt to model...');
    _isGenerating = true;
    try {
      final wrappedPrompt = '$prompt\n\nJSON:\n';
      await chat.addQueryChunk(Message(text: wrappedPrompt, isUser: true));
      debugPrint('[ScanAI] query chunk added, generating response...');
      final response = await chat.generateChatResponse();
      debugPrint('[ScanAI] response received: ${response.runtimeType}');

      await chat.clearHistory();

      if (response is TextResponse) {
        debugPrint('[ScanAI] text response length: ${response.token.length}');
        debugPrint('[ScanAI] text response content: ${response.token}');
        return response.token;
      }
      return response.toString();
    } finally {
      _isGenerating = false;
      if (_pendingDisposal) {
        await _performActualDisposal();
      }
    }
  }
}
