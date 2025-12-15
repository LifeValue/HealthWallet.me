import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:health_wallet/core/config/constants/app_constants.dart';
import 'package:health_wallet/core/config/env/env.dart';
import 'package:injectable/injectable.dart';

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
  ScanNetworkDataSourceImpl();

  InferenceModel? _model;
  InferenceChat? _chat;

  @override
  Future<bool> checkModelExistence() async {
    return await FlutterGemma.isModelInstalled(AppConstants.modelId);
  }

  @override
  Future<InferenceInstallation> downloadModel({
    required void Function(int) onProgress,
  }) {
    return FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
    )
        .fromNetwork(
          AppConstants.modelUrl,
          token: Env.huggingFaceToken,
        )
        .withProgress(onProgress)
        .install();
  }

  Future<void> _activateModel() async {
    // For some weird reason we need to do this before calling FlutterGemma.getActiveModel
    // If we don't we get a "No active inference model set" error
    if (await checkModelExistence()) {
      await downloadModel(onProgress: (_) {});
    }
  }

  @override
  Future<void> initModel() async {
    if (_model != null) return;

    await _activateModel();

    _model = await FlutterGemma.getActiveModel(
      maxTokens: 2048,
      preferredBackend: PreferredBackend.gpu,
    );
  }

  bool _isGenerating = false;
  bool _pendingDisposal = false;

  @override
  Future<void> disposeModel() async {
    _pendingDisposal = true;

    // If we are currently generating, we defer the disposal to the end of runPrompt
    // This is to avoid leaving the native side in a "zombie" state.
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

    _chat ??= await _model!.createChat();
    final chat = _chat!;

    _isGenerating = true;
    try {
      await chat.addQueryChunk(Message(text: prompt, isUser: true));
      final response = await chat.generateChatResponse();

      await chat.clearHistory();

      if (response is TextResponse) {
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
