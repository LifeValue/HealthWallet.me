import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:health_wallet/core/config/constants/app_constants.dart';
import 'package:health_wallet/core/config/env/env.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

abstract class ScanNetworkDataSource {
  Future<InferenceInstallation> downloadModel({
    required void Function(int) onProgress,
  });

  Future<bool> checkModelExistence();

  Future<String?> runPrompt({
    required String prompt,
  });
}

@LazySingleton(as: ScanNetworkDataSource)
class ScanNetworkDataSourceImpl implements ScanNetworkDataSource {
  ScanNetworkDataSourceImpl(Dio dio)
      : _dio = dio
          ..interceptors.add(
            LogInterceptor(
              request: true,
              responseBody: true,
              requestBody: true,
              requestHeader: true,
            ),
          );

  final Dio _dio;

  @override
  Future<bool> checkModelExistence() async {
    final isInstalled =
        await FlutterGemma.isModelInstalled(AppConstants.modelId);

    if (isInstalled) {
      return true;
    }

    // Fallback: check physical file existence with size validation
    final filePath = await getFilePath(AppConstants.modelId);
    final file = File(filePath);

    // Check remote file size
    final headResponse = await _dio.head(
      AppConstants.modelUrl,
      options:
          Options(headers: {'Authorization': 'Bearer ${Env.huggingFaceToken}'}),
    );

    if (headResponse.statusCode == 200) {
      final contentLengthHeaders = headResponse.headers['content-length'];
      if (contentLengthHeaders != null && contentLengthHeaders.isNotEmpty) {
        final remoteFileSize = int.parse(contentLengthHeaders.first);
        if (file.existsSync() && await file.length() == remoteFileSize) {
          return true;
        }
      }
    }

    return false;
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

  /// Helper method to get the file path.
  Future<String> getFilePath(String fileName) async {
    // Use the same path correction logic as the unified system
    final directory = await getApplicationDocumentsDirectory();
    // Apply Android path correction for consistency with unified download system
    final correctedPath = directory.path.contains('/data/user/0/')
        ? directory.path.replaceFirst('/data/user/0/', '/data/data/')
        : directory.path;
    return '$correctedPath/$fileName';
  }

  Future<void> _activateModel() async {
    if (await checkModelExistence()) {
      await downloadModel(onProgress: (_) {});
    }
  }

  @override
  Future<String?> runPrompt({
    required String prompt,
  }) async {
    await _activateModel();

    final model = await FlutterGemma.getActiveModel(
      maxTokens: 4096,
      preferredBackend: PreferredBackend.gpu,
    );

    final chat = await model.createChat();

    await chat.addQueryChunk(Message(text: prompt, isUser: true));
    final response = await chat.generateChatResponse();

    if (response is TextResponse) {
      return response.token;
    }

    return response.toString();
  }
}
