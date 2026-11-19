import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/features/processing/domain/services/ai_model_selection_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fake_device_capability_service.dart';

void main() {
  late FakeDeviceCapabilityService device;

  setUp(() {
    device = FakeDeviceCapabilityService()..advancedModelSupported = false;
  });

  Future<SharedPreferences> prefsSelecting(AiModelVariant? variant) async {
    SharedPreferences.setMockInitialValues({
      if (variant != null) SharedPrefsConstants.aiSelectedModel: variant.name,
    });
    return SharedPreferences.getInstance();
  }

  AiModelVariant selected(SharedPreferences prefs) =>
      AiModelConfig.getActive(prefs).variant;

  group('a selected model the device cannot run', () {
    test('Advanced is replaced by Lite and the user is told once', () async {
      final prefs = await prefsSelecting(AiModelVariant.qwen35x4b);
      final guard = AiModelSelectionGuard(device, prefs);

      expect(await guard.replaceUnsupportedModel(), isTrue);

      expect(selected(prefs), AiModelVariant.qwen);
      expect(guard.takeSwitchNotice(), AiModelVariant.qwen35x4b);
      expect(guard.takeSwitchNotice(), isNull);
    });

    test('the retired Medical model is replaced as well', () async {
      final prefs = await prefsSelecting(AiModelVariant.medGemma);
      final guard = AiModelSelectionGuard(device, prefs);

      expect(await guard.replaceUnsupportedModel(), isTrue);

      expect(selected(prefs), AiModelVariant.qwen);
      expect(guard.takeSwitchNotice(), AiModelVariant.medGemma);
    });

    test('the notice survives a restart until it is shown', () async {
      final prefs = await prefsSelecting(AiModelVariant.qwen35x4b);
      await AiModelSelectionGuard(device, prefs).replaceUnsupportedModel();

      final afterRestart = AiModelSelectionGuard(device, prefs);
      expect(await afterRestart.replaceUnsupportedModel(), isFalse);
      expect(afterRestart.takeSwitchNotice(), AiModelVariant.qwen35x4b);
      expect(AiModelSelectionGuard(device, prefs).takeSwitchNotice(), isNull);
    });

    test('a device that runs no model switches without a notice', () async {
      device.capability = DeviceAiCapability.unsupported;
      final prefs = await prefsSelecting(AiModelVariant.qwen35x4b);
      final guard = AiModelSelectionGuard(device, prefs);

      expect(await guard.replaceUnsupportedModel(), isTrue);

      expect(selected(prefs), AiModelVariant.qwen);
      expect(guard.takeSwitchNotice(), isNull);
    });
  });

  group('a selection the device can run', () {
    test('Advanced stays where the device runs it', () async {
      device.advancedModelSupported = true;
      final prefs = await prefsSelecting(AiModelVariant.qwen35x4b);
      final guard = AiModelSelectionGuard(device, prefs);

      expect(await guard.replaceUnsupportedModel(), isFalse);

      expect(selected(prefs), AiModelVariant.qwen35x4b);
      expect(guard.takeSwitchNotice(), isNull);
    });

    test('Lite stays', () async {
      final prefs = await prefsSelecting(AiModelVariant.qwen);
      final guard = AiModelSelectionGuard(device, prefs);

      expect(await guard.replaceUnsupportedModel(), isFalse);

      expect(selected(prefs), AiModelVariant.qwen);
      expect(guard.takeSwitchNotice(), isNull);
    });

    test('no selection stays unset', () async {
      final prefs = await prefsSelecting(null);
      final guard = AiModelSelectionGuard(device, prefs);

      expect(await guard.replaceUnsupportedModel(), isFalse);

      expect(prefs.getString(SharedPrefsConstants.aiSelectedModel), isNull);
      expect(guard.takeSwitchNotice(), isNull);
    });
  });
}
