import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiModelVariant { medGemma, qwen }

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
    displayName: 'Advanced Medical',
    description: 'Higher accuracy, larger download (~2.5 GB)',
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
    displayName: 'Standard',
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

  static AiModelConfig getActive(SharedPreferences prefs) {
    final name = prefs.getString(SharedPrefsConstants.aiSelectedModel);
    if (name == AiModelVariant.medGemma.name) return medGemma;
    if (name == AiModelVariant.qwen.name) return qwen;
    return qwen;
  }

  static AiModelConfig fromVariant(AiModelVariant variant) {
    switch (variant) {
      case AiModelVariant.medGemma:
        return medGemma;
      case AiModelVariant.qwen:
        return qwen;
    }
  }
}
