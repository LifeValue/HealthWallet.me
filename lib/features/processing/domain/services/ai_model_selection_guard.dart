import 'package:collection/collection.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the selected AI model one this device can run. A model chosen before
/// the device's limits changed (the Advanced model on a 6 GB iPhone) would
/// stop every scan with "not enough memory".
@lazySingleton
class AiModelSelectionGuard {
  AiModelSelectionGuard(this._deviceCapabilityService, this._prefs);

  final DeviceCapabilityService _deviceCapabilityService;
  final SharedPreferences _prefs;

  /// Selects the Lite model in place of one the device can't run, and
  /// returns whether it did. Where Lite runs, [takeSwitchNotice] then says
  /// which model was replaced. The replaced model's files stay on the device
  /// until the user deletes them; a missing Lite model is offered for
  /// download like any other.
  Future<bool> replaceUnsupportedModel() async {
    final name = _prefs.getString(SharedPrefsConstants.aiSelectedModel);
    final selected = AiModelVariant.values.firstWhereOrNull(
      (variant) => variant.name == name,
    );
    if (selected == null) return false;
    if (!AiModelConfig.fromVariant(selected).needsAdvancedSupport) {
      return false;
    }
    if (await _deviceCapabilityService.supportsAdvancedModel()) return false;

    await _prefs.setString(
      SharedPrefsConstants.aiSelectedModel,
      AiModelVariant.qwen.name,
    );
    // Where no model runs, the AI page already says so.
    if (await _deviceCapabilityService.getCapability() !=
        DeviceAiCapability.unsupported) {
      await _prefs.setString(
        SharedPrefsConstants.aiModelSwitchNotice,
        selected.name,
      );
    }
    return true;
  }

  /// The model [replaceUnsupportedModel] replaced, once: the notice is
  /// cleared as it is read.
  AiModelVariant? takeSwitchNotice() {
    final name = _prefs.getString(SharedPrefsConstants.aiModelSwitchNotice);
    if (name == null) return null;
    _prefs.remove(SharedPrefsConstants.aiModelSwitchNotice);
    return AiModelVariant.values.firstWhereOrNull(
      (variant) => variant.name == name,
    );
  }
}
