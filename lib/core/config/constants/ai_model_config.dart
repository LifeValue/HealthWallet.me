import 'dart:io';

import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/features/processing/domain/services/device_capability_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [qwen35x2b], [nuExtract2], [qwen35x4b], [nuExtract3] and [medGemma15] are
/// benchmark candidates: [AiModelConfig.availableVariants] leaves them out, so
/// only the extraction benchmark selects them (through the aiSelectedModel pref).
/// How prompts reach the model. NuExtract's chat templates take the extraction
/// template (and, for NuExtract3, instructions) as chat-template kwargs and
/// put the user message in their document slot; without a template NuExtract3
/// switches to document-to-Markdown.
enum PromptFamily { standard, nuExtract2, nuExtract3 }

enum AiModelVariant { medGemma, qwen, qwen7b, qwen35x2b, nuExtract2, qwen35x4b, nuExtract3, medGemma15 }

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
  final PromptFamily promptFamily;

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
    this.promptFamily = PromptFamily.standard,
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

  static const qwen35x2b = AiModelConfig._(
    variant: AiModelVariant.qwen35x2b,
    displayName: 'Qwen3.5 2B',
    description: 'Benchmark candidate (~1.9 GB)',
    modelUrl: 'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf',
    modelId: 'Qwen3.5-2B-Q4_K_M.gguf',
    mmprojUrl: 'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/mmproj-F16.gguf',
    mmprojId: 'mmproj-Qwen3.5-2B-F16.gguf',
    modelSizeMB: 1222,
    mmprojSizeMB: 637,
    skipDeviceCheck: false,
  );

  static const nuExtract2 = AiModelConfig._(
    variant: AiModelVariant.nuExtract2,
    displayName: 'NuExtract 2.0 2B',
    description: 'Benchmark candidate (~2.3 GB)',
    modelUrl: 'https://huggingface.co/numind/NuExtract-2.0-2B-GGUF/resolve/main/NuExtract-2.0-2B-Q4_K_M.gguf',
    modelId: 'NuExtract-2.0-2B-Q4_K_M.gguf',
    mmprojUrl: 'https://huggingface.co/numind/NuExtract-2.0-2B-GGUF/resolve/main/mmproj-BF16.gguf',
    mmprojId: 'mmproj-NuExtract-2.0-2B-BF16.gguf',
    modelSizeMB: 940,
    mmprojSizeMB: 1273,
    skipDeviceCheck: false,
    promptFamily: PromptFamily.nuExtract2,
  );

  static const qwen35x4b = AiModelConfig._(
    variant: AiModelVariant.qwen35x4b,
    displayName: 'Qwen3.5 4B',
    description: 'Benchmark candidate (~3.4 GB)',
    modelUrl: 'https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q4_K_M.gguf',
    modelId: 'Qwen3.5-4B-Q4_K_M.gguf',
    mmprojUrl: 'https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/mmproj-F16.gguf',
    mmprojId: 'mmproj-Qwen3.5-4B-F16.gguf',
    modelSizeMB: 2614,
    mmprojSizeMB: 641,
    skipDeviceCheck: true,
  );

  static const nuExtract3 = AiModelConfig._(
    variant: AiModelVariant.nuExtract3,
    displayName: 'NuExtract3 4B',
    description: 'Benchmark candidate (~3.5 GB)',
    modelUrl: 'https://huggingface.co/numind/NuExtract3-GGUF/resolve/main/NuExtract3-Q4_K_M.gguf',
    modelId: 'NuExtract3-Q4_K_M.gguf',
    mmprojUrl: 'https://huggingface.co/numind/NuExtract3-GGUF/resolve/main/mmproj-NuExtract3-BF16.gguf',
    mmprojId: 'mmproj-NuExtract3-BF16.gguf',
    modelSizeMB: 2654,
    mmprojSizeMB: 645,
    skipDeviceCheck: true,
    promptFamily: PromptFamily.nuExtract3,
  );

  static const medGemma15 = AiModelConfig._(
    variant: AiModelVariant.medGemma15,
    displayName: 'MedGemma 1.5',
    description: 'Benchmark candidate (~3.3 GB)',
    modelUrl: 'https://huggingface.co/unsloth/medgemma-1.5-4b-it-GGUF/resolve/main/medgemma-1.5-4b-it-Q4_K_M.gguf',
    modelId: 'medgemma-1.5-4b-it-Q4_K_M.gguf',
    mmprojUrl: 'https://huggingface.co/unsloth/medgemma-1.5-4b-it-GGUF/resolve/main/mmproj-F16.gguf',
    mmprojId: 'mmproj-medgemma-1.5-4b-it-F16.gguf',
    modelSizeMB: 2490,
    mmprojSizeMB: 851,
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
    for (final variant in AiModelVariant.values) {
      if (variant.name == name) return fromVariant(variant);
    }
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
      case AiModelVariant.qwen35x2b:
        return qwen35x2b;
      case AiModelVariant.nuExtract2:
        return nuExtract2;
      case AiModelVariant.qwen35x4b:
        return qwen35x4b;
      case AiModelVariant.nuExtract3:
        return nuExtract3;
      case AiModelVariant.medGemma15:
        return medGemma15;
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
