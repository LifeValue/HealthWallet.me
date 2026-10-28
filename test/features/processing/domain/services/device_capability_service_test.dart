import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/domain/services/device_capability_service.dart';

DeviceProfile _profile({
  int ramMB = 16384,
  GpuType gpuType = GpuType.appleSilicon,
  int cores = 8,
}) => DeviceProfile(
  ramMB: ramMB,
  logicalCores: cores,
  physicalCores: cores,
  gpuType: gpuType,
  isDesktop: true,
  platform: 'test',
);

void main() {
  group('estimateIosRam', () {
    test('maps iPhone generations to their RAM', () {
      expect(DeviceCapabilityService.estimateIosRam('iPhone18,1'), 8192);
      expect(DeviceCapabilityService.estimateIosRam('iPhone16,2'), 6144);
      expect(DeviceCapabilityService.estimateIosRam('iPhone13,1'), 4096);
    });

    test('tells the 6 GB iPhone 13 Pro models from the 4 GB ones', () {
      for (final minor in [2, 3, 7, 8]) {
        expect(
          DeviceCapabilityService.estimateIosRam('iPhone14,$minor'),
          6144,
        );
      }
      expect(DeviceCapabilityService.estimateIosRam('iPhone14,5'), 4096);
    });

    test('maps iPad generations and unknown machines', () {
      expect(DeviceCapabilityService.estimateIosRam('iPad16,1'), 16384);
      expect(DeviceCapabilityService.estimateIosRam('iPad14,1'), 8192);
      expect(DeviceCapabilityService.estimateIosRam('iPad11,1'), 6144);
      expect(DeviceCapabilityService.estimateIosRam('iPad6,1'), 4096);
      expect(DeviceCapabilityService.estimateIosRam('x86_64'), 4096);
    });
  });

  test('hasUsableGpu is true only for Apple silicon and discrete GPUs', () {
    expect(_profile(gpuType: GpuType.appleSilicon).hasUsableGpu, isTrue);
    expect(_profile(gpuType: GpuType.discrete).hasUsableGpu, isTrue);
    expect(_profile(gpuType: GpuType.integratedOnly).hasUsableGpu, isFalse);
    expect(_profile(gpuType: GpuType.none).hasUsableGpu, isFalse);
  });

  group('on the test host', () {
    test(
      'detectGpuType falls back to a known type when probing fails',
      () async {
        final gpu = await DeviceCapabilityService.detectGpuType();

        if (Platform.isMacOS) {
          expect(gpu, GpuType.appleSilicon);
        } else {
          // lspci or PowerShell may be missing; the probe then falls back.
          expect(gpu, isIn(GpuType.values));
        }
      },
    );

    test('buildProfile describes this machine', () async {
      final profile = await DeviceCapabilityService.buildProfile(ramMB: 8192);

      expect(profile.ramMB, 8192);
      expect(profile.logicalCores, Platform.numberOfProcessors);
      expect(profile.physicalCores, inInclusiveRange(1, profile.logicalCores));
      expect(profile.isDesktop, isTrue);
      expect(profile.platform, Platform.operatingSystem);
    });

    test('computeModelConfig gives more context to more RAM', () {
      final small = DeviceCapabilityService.computeModelConfig(
        withVision: false,
        profile: _profile(ramMB: 4096),
      );
      final large = DeviceCapabilityService.computeModelConfig(
        withVision: false,
        profile: _profile(ramMB: 32768),
      );

      expect(large.contextSize, greaterThanOrEqualTo(small.contextSize));
      expect(large.contextSize, 4096);
      expect(small.threads, inInclusiveRange(1, 8));
      expect(small.threadsBatch, inInclusiveRange(1, 8));
    });

    test('computeModelConfig offloads more layers with vision on a Mac', () {
      final text = DeviceCapabilityService.computeModelConfig(
        withVision: false,
        profile: _profile(),
      );
      final vision = DeviceCapabilityService.computeModelConfig(
        withVision: true,
        profile: _profile(),
      );

      expect(text.gpuLayers, 33);
      expect(vision.gpuLayers, 99);
    }, skip: !Platform.isMacOS);

    test('computeModelConfig uses no GPU layers without a usable GPU', () {
      final config = DeviceCapabilityService.computeModelConfig(
        withVision: true,
        profile: _profile(gpuType: GpuType.integratedOnly, ramMB: 16384),
      );

      expect(config.gpuLayers, 0);
      expect(config.contextSize, 2048);
    }, skip: !(Platform.isLinux || Platform.isWindows));
  }, skip: !(Platform.isMacOS || Platform.isLinux || Platform.isWindows));
}
