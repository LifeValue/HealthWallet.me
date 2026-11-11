import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/features/processing/domain/services/device_capability_service.dart'
    as processing;

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
      expect(DeviceCapabilityService.estimateIosRam('iPad16,3'), 8192);
      expect(DeviceCapabilityService.estimateIosRam('iPad13,4'), 8192);
      expect(DeviceCapabilityService.estimateIosRam('iPad8,1'), 4096);
      expect(DeviceCapabilityService.estimateIosRam('iPad7,5'), 2048);
    });

    test('falls back to 4096 MB for an unknown machine', () {
      expect(DeviceCapabilityService.estimateIosRam('arm64'), 4096);
    });

    test('knows the 6 GB iPhone 13 Pro Max from the 4 GB iPhone 13', () {
      expect(DeviceCapabilityService.estimateIosRam('iPhone14,3'), 6144);
      expect(DeviceCapabilityService.estimateIosRam('iPhone14,2'), 6144);
      expect(DeviceCapabilityService.estimateIosRam('iPhone14,5'), 4096);
    });

    test('reads the same table as the AI pipeline', () {
      for (final machine in [
        'iPhone13,4',
        'iPhone14,3',
        'iPhone14,6',
        'iPhone15,4',
        'iPhone16,1',
        'iPhone18,3',
        'iPad13,4',
        'arm64',
      ]) {
        expect(
          DeviceCapabilityService.estimateIosRam(machine),
          processing.DeviceCapabilityService.estimateIosRam(machine),
          reason: machine,
        );
      }
    });
  });

  group('classifyCapability', () {
    DeviceAiCapability iPhone(String machine) =>
        DeviceCapabilityService.classifyCapability(
          DeviceCapabilityService.estimateIosRam(machine),
          platform: 'ios',
        );

    test('gives a 6 GB iPhone Deep Scan', () {
      expect(iPhone('iPhone14,3'), DeviceAiCapability.full);
      expect(iPhone('iPhone15,2'), DeviceAiCapability.full);
    });

    test('gives a 4 GB iPhone text processing only', () {
      expect(iPhone('iPhone14,5'), DeviceAiCapability.basicOnly);
      expect(iPhone('iPhone12,1'), DeviceAiCapability.basicOnly);
    });

    test('gives an iPhone under 4 GB no AI', () {
      expect(
        DeviceCapabilityService.classifyCapability(3072, platform: 'ios'),
        DeviceAiCapability.unsupported,
      );
    });

    test('asks an Android phone for 10 GB, and 11 GB for Deep Scan', () {
      DeviceAiCapability android(int ramMB) =>
          DeviceCapabilityService.classifyCapability(
            ramMB,
            platform: 'android',
          );

      expect(android(8192), DeviceAiCapability.unsupported);
      expect(android(10240), DeviceAiCapability.basicOnly);
      expect(android(11264), DeviceAiCapability.full);
    });

    test('lets a desktop run everything', () {
      for (final platform in ['macos', 'windows', 'linux']) {
        expect(
          DeviceCapabilityService.classifyCapability(2048, platform: platform),
          DeviceAiCapability.full,
        );
      }
    });
  });

  group('supportsAdvancedModelFor', () {
    bool iPhone(String machine) =>
        DeviceCapabilityService.supportsAdvancedModelFor(
          DeviceCapabilityService.estimateIosRam(machine),
          platform: 'ios',
        );

    test('offers the Advanced model on an iPhone with 8 GB', () {
      expect(iPhone('iPhone16,1'), isTrue);
      expect(iPhone('iPhone17,1'), isTrue);
    });

    test('keeps the Advanced model from a 6 GB iPhone', () {
      expect(iPhone('iPhone14,3'), isFalse);
      expect(iPhone('iPhone15,4'), isFalse);
    });

    test('keeps the Advanced model from a phone without Deep Scan', () {
      expect(iPhone('iPhone14,5'), isFalse);
      expect(
        DeviceCapabilityService.supportsAdvancedModelFor(
          10240,
          platform: 'android',
        ),
        isFalse,
      );
    });

    test('offers it to an Android phone with Deep Scan and to a desktop', () {
      expect(
        DeviceCapabilityService.supportsAdvancedModelFor(
          11264,
          platform: 'android',
        ),
        isTrue,
      );
      expect(
        DeviceCapabilityService.supportsAdvancedModelFor(
          4096,
          platform: 'macos',
        ),
        isTrue,
      );
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

    test('offers the Advanced model', () async {
      expect(await DeviceCapabilityService().supportsAdvancedModel(), isTrue);
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
