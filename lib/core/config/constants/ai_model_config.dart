import 'dart:io';

import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/features/processing/domain/services/device_capability_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiModelVariant { medGemma, qwen, qwen7b }

class AiModelConfig {
  final AiModelVariant variant;
  final String displayName;
  final String description;
  final String modelUrl;
  final String modelId;
  final String mmprojUrl;
  final String mmprojId;
  final int modelSizeMB;
  final int mmprojSizeMB;
  final bool skipDeviceCheck;

  const AiModelConfig._({
    required this.variant,
    required this.displayName,
    required this.description,
    required this.modelUrl,
    required this.modelId,
    required this.mmprojUrl,
    required this.mmprojId,
    required this.modelSizeMB,
    required this.mmprojSizeMB,
    required this.skipDeviceCheck,
  });

  static const medGemma = AiModelConfig._(
    variant: AiModelVariant.medGemma,
    displayName: 'Medical',
    description: 'Medical-trained, higher accuracy (~2.5 GB)',
    modelUrl:
        'https://huggingface.co/SandLogicTechnologies/MedGemma-4B-IT-GGUF/resolve/main/medgemma-4b-it_Q4_K_M.gguf',
    modelId: 'medgemma-4b-it_Q4_K_M.gguf',
    mmprojUrl:
        'https://huggingface.co/SandLogicTechnologies/MedGemma-4B-IT-GGUF/resolve/main/mmproj-medgemma-4b-it-F16.gguf',
    mmprojId: 'mmproj-medgemma-4b-it-F16.gguf',
    modelSizeMB: 2490,
    mmprojSizeMB: 851,
    skipDeviceCheck: true,
  );

  static const qwen = AiModelConfig._(
    variant: AiModelVariant.qwen,
    displayName: 'Lite',
    description: 'Fast and lightweight (~1.1 GB)',
    modelUrl:
        'https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF/resolve/main/Qwen3VL-2B-Instruct-Q4_K_M.gguf',
    modelId: 'Qwen3VL-2B-Instruct-Q4_K_M.gguf',
    mmprojUrl:
        'https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF/resolve/main/mmproj-Qwen3VL-2B-Instruct-F16.gguf',
    mmprojId: 'mmproj-Qwen3VL-2B-Instruct-F16.gguf',
    modelSizeMB: 1056,
    mmprojSizeMB: 445,
    skipDeviceCheck: false,
  );

  static const qwen7b = AiModelConfig._(
    variant: AiModelVariant.qwen7b,
    displayName: 'Ultra',
    description: 'Best accuracy for desktop (~5 GB)',
    modelUrl:
        'https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct-GGUF/resolve/main/Qwen3VL-8B-Instruct-Q4_K_M.gguf',
    modelId: 'Qwen3VL-8B-Instruct-Q4_K_M.gguf',
    mmprojUrl:
        'https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct-GGUF/resolve/main/mmproj-Qwen3VL-8B-Instruct-F16.gguf',
    mmprojId: 'mmproj-Qwen3VL-8B-Instruct-F16.gguf',
    modelSizeMB: 4560,
    mmprojSizeMB: 815,
    skipDeviceCheck: true,
  );

  static List<AiModelConfig> get availableVariants {
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      return [qwen, medGemma, qwen7b];
    }
    return [qwen, medGemma];
  }

  static AiModelConfig getActive(SharedPreferences prefs,
      {DeviceProfile? profile}) {
    final name = prefs.getString(SharedPrefsConstants.aiSelectedModel);
    if (name == AiModelVariant.medGemma.name) return medGemma;
    if (name == AiModelVariant.qwen.name) return qwen;
    if (name == AiModelVariant.qwen7b.name) return qwen7b;
    if (profile != null) return fromVariant(recommendedVariant(profile));
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) return qwen7b;
    return qwen;
  }

  static AiModelConfig fromVariant(AiModelVariant variant) {
    switch (variant) {
      case AiModelVariant.medGemma:
        return medGemma;
      case AiModelVariant.qwen:
        return qwen;
      case AiModelVariant.qwen7b:
        return qwen7b;
    }
  }

  static AiModelVariant recommendedVariant(DeviceProfile profile) {
    if (!profile.isDesktop) {
      if (profile.ramMB >= 6144) return AiModelVariant.medGemma;
      return AiModelVariant.qwen;
    }

    if (profile.gpuType == GpuType.appleSilicon) {
      if (profile.ramMB >= 16384) return AiModelVariant.qwen7b;
      return AiModelVariant.medGemma;
    }

    if (profile.hasUsableGpu && profile.ramMB >= 16384) {
      return AiModelVariant.qwen7b;
    }

    if (profile.physicalCores >= 4 && profile.ramMB >= 16384) {
      return AiModelVariant.medGemma;
    }

    return AiModelVariant.qwen;
  }
}
