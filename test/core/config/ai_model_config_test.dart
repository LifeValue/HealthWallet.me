import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/features/processing/domain/services/device_capability_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _candidates = [
  AiModelVariant.qwen35x2b,
  AiModelVariant.nuExtract2,
  AiModelVariant.nuExtract3,
  AiModelVariant.medGemma15,
];

DeviceProfile _phone(int ramMB) => DeviceProfile(
  ramMB: ramMB,
  logicalCores: 6,
  physicalCores: 6,
  gpuType: GpuType.appleSilicon,
  isDesktop: false,
  platform: 'ios',
);

void main() {
  test('benchmark candidates are not offered to users', () {
    final offered = AiModelConfig.availableVariants.map((c) => c.variant);
    expect(offered, isNot(contains(anyOf(_candidates))));
  });

  test('Advanced is Qwen3.5-4B; MedGemma is listed only where its files already are', () {
    final offered = AiModelConfig.availableVariants.map((c) => c.variant);
    expect(
      offered,
      containsAllInOrder([AiModelVariant.qwen, AiModelVariant.qwen35x4b]),
    );
    expect(offered, isNot(contains(AiModelVariant.medGemma)));

    List<AiModelVariant> listed(Set<AiModelVariant> downloaded) =>
        AiModelConfig.listedVariants(downloaded.contains)
            .map((c) => c.variant)
            .toList();
    expect(listed({}), isNot(contains(AiModelVariant.medGemma)));
    expect(listed({AiModelVariant.medGemma}), [
      ...offered,
      AiModelVariant.medGemma,
    ]);
  });

  test('a 6 GB+ phone is recommended Qwen3.5-4B, a smaller one Lite', () {
    expect(
      AiModelConfig.recommendedVariant(_phone(8192)),
      AiModelVariant.qwen35x4b,
    );
    expect(AiModelConfig.recommendedVariant(_phone(4096)), AiModelVariant.qwen);
  });

  test('every variant resolves from the selected-model pref', () async {
    for (final variant in AiModelVariant.values) {
      SharedPreferences.setMockInitialValues({
        SharedPrefsConstants.aiSelectedModel: variant.name,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(AiModelConfig.getActive(prefs).variant, variant);
    }
  });

  test(
    'model and projector files of different variants never share a name',
    () {
      final ids = AiModelVariant.values
          .map(AiModelConfig.fromVariant)
          .expand((c) => [c.modelId, c.mmprojId])
          .toList();
      expect(ids.toSet().length, ids.length);
    },
  );
}
