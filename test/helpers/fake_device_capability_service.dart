import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';

/// A device of the given [capability], [DeviceAiCapability.full] unless set,
/// that runs the Advanced model while [advancedModelSupported].
class FakeDeviceCapabilityService extends Fake
    implements DeviceCapabilityService {
  FakeDeviceCapabilityService([this.capability = DeviceAiCapability.full]);

  DeviceAiCapability capability;

  bool advancedModelSupported = true;

  @override
  Future<DeviceAiCapability> getCapability() async => capability;

  @override
  Future<bool> supportsAdvancedModel() async => advancedModelSupported;
}
