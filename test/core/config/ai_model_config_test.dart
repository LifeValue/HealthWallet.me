import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _candidates = [
  AiModelVariant.qwen35x2b,
  AiModelVariant.nuExtract2,
  AiModelVariant.qwen35x4b,
  AiModelVariant.nuExtract3,
  AiModelVariant.medGemma15,
];

void main() {
  test('benchmark candidates are not offered to users', () {
    final offered = AiModelConfig.availableVariants.map((c) => c.variant);
    expect(offered, isNot(contains(anyOf(_candidates))));
  });

  test('every variant resolves from the selected-model pref', () async {
    for (final variant in AiModelVariant.values) {
      SharedPreferences.setMockInitialValues({SharedPrefsConstants.aiSelectedModel: variant.name});
      final prefs = await SharedPreferences.getInstance();
      expect(AiModelConfig.getActive(prefs).variant, variant);
    }
  });

  test('model and projector files of different variants never share a name', () {
    final ids = AiModelVariant.values
        .map(AiModelConfig.fromVariant)
        .expand((c) => [c.modelId, c.mmprojId])
        .toList();
    expect(ids.toSet().length, ids.length);
  });
}
