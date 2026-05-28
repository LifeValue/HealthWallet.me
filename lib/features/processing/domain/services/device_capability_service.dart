import 'dart:io';

enum GpuType { appleSilicon, discrete, integratedOnly, none }

class DeviceProfile {
  final int ramMB;
  final int logicalCores;
  final int physicalCores;
  final GpuType gpuType;
  final bool isDesktop;
  final String platform;

  const DeviceProfile({
    required this.ramMB,
    required this.logicalCores,
    required this.physicalCores,
    required this.gpuType,
    required this.isDesktop,
    required this.platform,
  });

  bool get hasUsableGpu =>
      gpuType == GpuType.appleSilicon || gpuType == GpuType.discrete;
}

class DeviceCapabilityService {
  static int estimateIosRam(String machine) {
    final iphone = RegExp(r'iPhone(\d+),(\d+)').firstMatch(machine);
    if (iphone != null) {
      final major = int.tryParse(iphone.group(1)!) ?? 0;
      final minor = int.tryParse(iphone.group(2)!) ?? 0;
      if (major >= 17) return 8192;
      if (major >= 15) return 6144;
      if (major == 14) {
        if (minor == 2 || minor == 3 || minor == 7 || minor == 8) return 6144;
        return 4096;
      }
      return 4096;
    }

    final ipad = RegExp(r'iPad(\d+),').firstMatch(machine);
    if (ipad != null) {
      final major = int.tryParse(ipad.group(1)!) ?? 0;
      if (major >= 16) return 16384;
      if (major >= 13) return 8192;
      if (major >= 8) return 6144;
      return 4096;
    }

    return 4096;
  }

  static Future<GpuType> detectGpuType() async {
    if (Platform.isMacOS || Platform.isIOS) return GpuType.appleSilicon;

    if (Platform.isWindows) {
      try {
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          '(Get-CimInstance Win32_VideoController).Name -join "|"',
        ]);
        if (result.exitCode == 0) {
          final names = result.stdout.toString().toLowerCase();
          if (names.contains('nvidia') ||
              names.contains('radeon') ||
              names.contains('arc a')) {
            return GpuType.discrete;
          }
          if (names.contains('intel') || names.contains('microsoft basic')) {
            return GpuType.integratedOnly;
          }
        }
      } catch (_) {}
      return GpuType.integratedOnly;
    }

    if (Platform.isLinux) {
      try {
        final result = await Process.run('lspci', []);
        if (result.exitCode == 0) {
          final output = result.stdout.toString().toLowerCase();
          if (output.contains('nvidia') || output.contains('radeon')) {
            return GpuType.discrete;
          }
          if (output.contains('intel') || output.contains('vga')) {
            return GpuType.integratedOnly;
          }
        }
      } catch (_) {}
      return GpuType.integratedOnly;
    }

    if (Platform.isAndroid) return GpuType.none;

    return GpuType.none;
  }

  static int _estimatePhysicalCores(int logicalCores) {
    if (Platform.isMacOS || Platform.isIOS) return logicalCores;
    return (logicalCores / 2).ceil().clamp(1, logicalCores);
  }

  static ({
    int gpuLayers,
    int threads,
    int threadsBatch,
    int contextSize,
  }) computeModelConfig({
    required bool withVision,
    required DeviceProfile profile,
  }) {
    final physCores = profile.physicalCores;
    final logCores = profile.logicalCores;

    int contextSize;
    int gpuLayers = 0;
    int threads;
    int threadsBatch;

    if (Platform.isIOS) {
      threadsBatch = logCores.clamp(1, 4);
      threads = physCores.clamp(1, 4);

      if (profile.ramMB >= 8192) {
        contextSize = 4096;
        gpuLayers = withVision ? 4 : 0;
      } else if (profile.ramMB >= 6144) {
        contextSize = 2048;
        gpuLayers = withVision ? 2 : 0;
      } else if (profile.ramMB >= 4096) {
        contextSize = 1024;
        gpuLayers = withVision ? 1 : 0;
      } else {
        contextSize = 512;
      }
    } else if (Platform.isMacOS) {
      threadsBatch = logCores.clamp(1, 8);
      threads = physCores.clamp(1, 8);

      if (profile.ramMB >= 16384) {
        contextSize = 4096;
        gpuLayers = withVision ? 99 : 33;
      } else if (profile.ramMB >= 8192) {
        contextSize = 4096;
        gpuLayers = withVision ? 33 : 16;
      } else {
        contextSize = 2048;
        gpuLayers = withVision ? 4 : 0;
      }
    } else if (Platform.isWindows || Platform.isLinux) {
      threadsBatch = logCores.clamp(1, 8);
      threads = physCores.clamp(1, 8);

      if (profile.hasUsableGpu) {
        if (profile.ramMB >= 32768) {
          contextSize = 4096;
          gpuLayers = withVision ? 99 : 33;
        } else if (profile.ramMB >= 16384) {
          contextSize = 4096;
          gpuLayers = withVision ? 33 : 16;
        } else if (profile.ramMB >= 8192) {
          contextSize = 2048;
          gpuLayers = withVision ? 8 : 4;
        } else {
          contextSize = 2048;
          gpuLayers = 0;
        }
      } else {
        gpuLayers = 0;
        if (profile.ramMB >= 32768) {
          contextSize = 4096;
        } else if (profile.ramMB >= 16384) {
          contextSize = 2048;
        } else if (profile.ramMB >= 8192) {
          contextSize = 2048;
        } else {
          contextSize = 1024;
        }
      }
    } else {
      threadsBatch = logCores.clamp(1, 4);
      threads = physCores.clamp(1, 4);

      if (profile.ramMB >= 12288) {
        contextSize = 4096;
      } else if (profile.ramMB >= 8192) {
        contextSize = 2048;
      } else {
        contextSize = 512;
      }
    }

    return (
      gpuLayers: gpuLayers,
      threads: threads,
      threadsBatch: threadsBatch,
      contextSize: contextSize,
    );
  }

  static Future<DeviceProfile> buildProfile({required int ramMB}) async {
    final logicalCores = Platform.numberOfProcessors;
    final physicalCores = _estimatePhysicalCores(logicalCores);
    final gpuType = await detectGpuType();
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    return DeviceProfile(
      ramMB: ramMB,
      logicalCores: logicalCores,
      physicalCores: physicalCores,
      gpuType: gpuType,
      isDesktop: isDesktop,
      platform: Platform.operatingSystem,
    );
  }
}
