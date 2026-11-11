import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/services/device_capability_service.dart'
    as core;
import 'package:health_wallet/features/processing/domain/services/device_capability_service.dart';

/// Every iPad that runs iPadOS 16.4 (the app's minimum) and the RAM of its
/// smallest configuration. Where a larger storage tier has more memory under
/// the same identifier (16 GB on the 1 and 2 TB M1, M2 and M4 iPad Pro) the
/// smaller amount is the one to plan for.
const _ipadRamMB = <String, int>{
  // iPad Pro 9.7-inch.
  'iPad6,3': 2048, 'iPad6,4': 2048,
  // iPad Pro 12.9-inch (1st generation).
  'iPad6,7': 4096, 'iPad6,8': 4096,
  // iPad (5th generation).
  'iPad6,11': 2048, 'iPad6,12': 2048,
  // iPad Pro 12.9-inch (2nd generation).
  'iPad7,1': 4096, 'iPad7,2': 4096,
  // iPad Pro 10.5-inch.
  'iPad7,3': 4096, 'iPad7,4': 4096,
  // iPad (6th generation).
  'iPad7,5': 2048, 'iPad7,6': 2048,
  // iPad (7th generation).
  'iPad7,11': 3072, 'iPad7,12': 3072,
  // iPad Pro 11-inch (1st generation); the 1 TB models have 6 GB.
  'iPad8,1': 4096, 'iPad8,2': 6144, 'iPad8,3': 4096, 'iPad8,4': 6144,
  // iPad Pro 12.9-inch (3rd generation); the 1 TB models have 6 GB.
  'iPad8,5': 4096, 'iPad8,6': 6144, 'iPad8,7': 4096, 'iPad8,8': 6144,
  // iPad Pro 11-inch (2nd generation) and 12.9-inch (4th generation).
  'iPad8,9': 6144, 'iPad8,10': 6144, 'iPad8,11': 6144, 'iPad8,12': 6144,
  // iPad mini (5th generation) and iPad Air (3rd generation).
  'iPad11,1': 3072, 'iPad11,2': 3072, 'iPad11,3': 3072, 'iPad11,4': 3072,
  // iPad (8th generation).
  'iPad11,6': 3072, 'iPad11,7': 3072,
  // iPad (9th generation).
  'iPad12,1': 3072, 'iPad12,2': 3072,
  // iPad Air (4th generation).
  'iPad13,1': 4096, 'iPad13,2': 4096,
  // iPad Pro 11-inch (3rd generation, M1).
  'iPad13,4': 8192, 'iPad13,5': 8192, 'iPad13,6': 8192, 'iPad13,7': 8192,
  // iPad Pro 12.9-inch (5th generation, M1).
  'iPad13,8': 8192, 'iPad13,9': 8192, 'iPad13,10': 8192, 'iPad13,11': 8192,
  // iPad Air (5th generation, M1).
  'iPad13,16': 8192, 'iPad13,17': 8192,
  // iPad (10th generation).
  'iPad13,18': 4096, 'iPad13,19': 4096,
  // iPad mini (6th generation).
  'iPad14,1': 4096, 'iPad14,2': 4096,
  // iPad Pro 11-inch (4th generation) and 12.9-inch (6th generation), M2.
  'iPad14,3': 8192, 'iPad14,4': 8192, 'iPad14,5': 8192, 'iPad14,6': 8192,
  // iPad Air 11-inch and 13-inch (M2).
  'iPad14,8': 8192, 'iPad14,9': 8192, 'iPad14,10': 8192, 'iPad14,11': 8192,
  // iPad Air 11-inch and 13-inch (M3).
  'iPad15,3': 8192, 'iPad15,4': 8192, 'iPad15,5': 8192, 'iPad15,6': 8192,
  // iPad (A16).
  'iPad15,7': 6144, 'iPad15,8': 6144,
  // iPad mini (A17 Pro).
  'iPad16,1': 8192, 'iPad16,2': 8192,
  // iPad Pro 11-inch and 13-inch (M4).
  'iPad16,3': 8192, 'iPad16,4': 8192, 'iPad16,5': 8192, 'iPad16,6': 8192,
  // iPad Air 11-inch and 13-inch (M4).
  'iPad16,8': 12288, 'iPad16,9': 12288, 'iPad16,10': 12288, 'iPad16,11': 12288,
};

void main() {
  group('iPad memory table', () {
    for (final MapEntry(key: machine, value: ramMB) in _ipadRamMB.entries) {
      test('$machine has $ramMB MB', () {
        expect(DeviceCapabilityService.estimateIosRam(machine), ramMB);
        expect(core.DeviceCapabilityService.estimateIosRam(machine), ramMB);
      });
    }

    test('an iPad missing from the table is taken to have 4 GB', () {
      for (final machine in ['iPad5,3', 'iPad13,3', 'iPad14,7', 'iPad16,7']) {
        expect(
          DeviceCapabilityService.estimateIosRam(machine),
          4096,
          reason: machine,
        );
      }
    });

    test('an iPad newer than the table is taken to have 8 GB', () {
      for (final machine in ['iPad17,1', 'iPad17,4', 'iPad18,2']) {
        expect(
          DeviceCapabilityService.estimateIosRam(machine),
          8192,
          reason: machine,
        );
      }
    });
  });

  group('what the iPad table allows', () {
    core.DeviceAiCapability capability(String machine) =>
        core.DeviceCapabilityService.classifyCapability(
          DeviceCapabilityService.estimateIosRam(machine),
          platform: 'ios',
        );

    bool advanced(String machine) =>
        core.DeviceCapabilityService.supportsAdvancedModelFor(
          DeviceCapabilityService.estimateIosRam(machine),
          platform: 'ios',
        );

    test('4 GB iPads read text only and are not offered Advanced', () {
      // iPad mini 6, iPad 10th generation, iPad Air 4.
      for (final machine in [
        'iPad14,1',
        'iPad14,2',
        'iPad13,18',
        'iPad13,19',
        'iPad13,1',
        'iPad13,2',
      ]) {
        expect(
          capability(machine),
          core.DeviceAiCapability.basicOnly,
          reason: machine,
        );
        expect(advanced(machine), isFalse, reason: machine);
      }
    });

    test('3 GB iPads get no Deep Scan', () {
      // iPad 9th and 8th generation, iPad mini 5, iPad Air 3.
      for (final machine in [
        'iPad12,1',
        'iPad12,2',
        'iPad11,6',
        'iPad11,1',
        'iPad11,3',
      ]) {
        expect(
          capability(machine),
          isNot(core.DeviceAiCapability.full),
          reason: machine,
        );
        expect(advanced(machine), isFalse, reason: machine);
      }
    });

    test('6 GB iPads get Deep Scan with Lite but not Advanced', () {
      for (final machine in ['iPad8,9', 'iPad8,12', 'iPad15,7', 'iPad8,2']) {
        expect(
          capability(machine),
          core.DeviceAiCapability.full,
          reason: machine,
        );
        expect(advanced(machine), isFalse, reason: machine);
      }
    });

    test('8 GB iPads are offered Advanced', () {
      // M1, M2 and M4 iPad Pro, M1 to M4 iPad Air, iPad mini A17 Pro.
      for (final machine in [
        'iPad13,4',
        'iPad13,8',
        'iPad13,16',
        'iPad13,17',
        'iPad14,3',
        'iPad14,8',
        'iPad15,3',
        'iPad16,1',
        'iPad16,3',
        'iPad16,10',
        'iPad17,1',
      ]) {
        expect(advanced(machine), isTrue, reason: machine);
      }
    });
  });
}
