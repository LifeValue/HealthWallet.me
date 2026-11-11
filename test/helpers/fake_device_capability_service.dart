import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';

/// A device of the given [capability], [DeviceAiCapability.full] unless set.
class FakeDeviceCapabilityService extends Fake
    implements DeviceCapabilityService {
  FakeDeviceCapabilityService([this.capability = DeviceAiCapability.full]);

  DeviceAiCapability capability;

  @override
  Future<DeviceAiCapability> getCapability() async => capability;
}
