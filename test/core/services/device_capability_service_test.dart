import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';

import '../../helpers/log_capture.dart';

void main() {
  final logs = captureLogs();

  group('estimateIosRam', () {
    test('maps iPhone generations to their RAM', () {
      expect(DeviceCapabilityService.estimateIosRam('iPhone17,1'), 8192);
      expect(DeviceCapabilityService.estimateIosRam('iPhone15,2'), 6144);
      expect(DeviceCapabilityService.estimateIosRam('iPhone12,1'), 4096);
    });

    test('maps iPad generations to their RAM', () {
      expect(DeviceCapabilityService.estimateIosRam('iPad16,3'), 16384);
      expect(DeviceCapabilityService.estimateIosRam('iPad13,4'), 8192);
      expect(DeviceCapabilityService.estimateIosRam('iPad8,1'), 6144);
      expect(DeviceCapabilityService.estimateIosRam('iPad7,5'), 4096);
    });

    test('falls back to 4096 MB for an unknown machine', () {
      expect(DeviceCapabilityService.estimateIosRam('arm64'), 4096);
    });
  });

  group('on a desktop host', () {
    test('reads the RAM once and caches it', () async {
      final service = DeviceCapabilityService();

      final first = await service.getDeviceRamMB();
      final second = await service.getDeviceRamMB();

      expect(first, greaterThan(0));
      expect(second, first);
      expect(logs, isEmpty);
    });

    test('reports full AI capability and a desktop profile', () async {
      final service = DeviceCapabilityService();

      expect(await service.getCapability(), DeviceAiCapability.full);
      expect(await service.getCapability(), DeviceAiCapability.full);

      final profile = await service.getProfile();
      expect(profile.isDesktop, isTrue);
      expect(profile.ramMB, await service.getDeviceRamMB());
      expect(identical(await service.getProfile(), profile), isTrue);
    });
  }, skip: !(Platform.isMacOS || Platform.isLinux || Platform.isWindows));

  test('readAndroidRamMB returns null when /proc/meminfo is missing', () async {
    final ram = await DeviceCapabilityService.readAndroidRamMB();

    if (File('/proc/meminfo').existsSync()) {
      expect(ram, greaterThan(0));
    } else {
      expect(ram, isNull);
    }
  });
}
