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
  /// The RAM of an iPhone or iPad from its model identifier (iOS does not
  /// report it). The only table in the app: every capability check reads it.
  static int estimateIosRam(String machine) {
    final iphone = RegExp(r'iPhone(\d+),(\d+)').firstMatch(machine);
    if (iphone != null) {
      final major = int.tryParse(iphone.group(1)!) ?? 0;
      final minor = int.tryParse(iphone.group(2)!) ?? 0;
      // iPhone 15 Pro (16,x) and every model after it.
      if (major >= 16) return 8192;
      // iPhone 14 Pro, 15 and 15 Plus.
      if (major == 15) return 6144;
      // iPhone 13 Pro and Pro Max, 14 and 14 Plus; 13, 13 mini and SE are 4 GB.
      if (major == 14) {
        if (minor == 2 || minor == 3 || minor == 7 || minor == 8) return 6144;
        return 4096;
      }
      // iPhone 12 Pro and Pro Max; 12 and 12 mini are 4 GB.
      if (major == 13 && (minor == 3 || minor == 4)) return 6144;
      return 4096;
    }

    final ipad = RegExp(r'iPad(\d+),(\d+)').firstMatch(machine);
    if (ipad != null) {
      final major = int.tryParse(ipad.group(1)!) ?? 0;
      final known = _ipadRamMB[machine.substring(ipad.start, ipad.end)];
      if (known != null) return known;
      // Every iPad after the table runs Apple Intelligence, which needs 8 GB.
      if (major > _lastIpadMajor) return 8192;
      return 4096;
    }

    return 4096;
  }

  /// The highest identifier generation in [_ipadRamMB].
  static const _lastIpadMajor = 16;

  /// Every iPad that runs iPadOS 16.4, the app's minimum, with the RAM of its
  /// smallest configuration: the 1 and 2 TB M1, M2 and M4 iPad Pro have 16 GB
  /// under the same identifiers. Apple publishes the memory of the M1 and
  /// later iPad Pro and of the iPad Air M4; the others are the widely
  /// reported amounts, as Apple does not list them.
  static const _ipadRamMB = <String, int>{
    // iPad Pro 9.7-inch; iPad Pro 12.9-inch (1st generation).
    'iPad6,3': 2048, 'iPad6,4': 2048, 'iPad6,7': 4096, 'iPad6,8': 4096,
    // iPad (5th generation).
    'iPad6,11': 2048, 'iPad6,12': 2048,
    // iPad Pro 12.9-inch (2nd generation); iPad Pro 10.5-inch.
    'iPad7,1': 4096, 'iPad7,2': 4096, 'iPad7,3': 4096, 'iPad7,4': 4096,
    // iPad (6th generation); iPad (7th generation).
    'iPad7,5': 2048, 'iPad7,6': 2048, 'iPad7,11': 3072, 'iPad7,12': 3072,
    // iPad Pro 11-inch (1st generation); 8,2 and 8,4 are the 1 TB models.
    'iPad8,1': 4096, 'iPad8,2': 6144, 'iPad8,3': 4096, 'iPad8,4': 6144,
    // iPad Pro 12.9-inch (3rd generation); 8,6 and 8,8 are the 1 TB models.
    'iPad8,5': 4096, 'iPad8,6': 6144, 'iPad8,7': 4096, 'iPad8,8': 6144,
    // iPad Pro 11-inch (2nd generation); iPad Pro 12.9-inch (4th generation).
    'iPad8,9': 6144, 'iPad8,10': 6144, 'iPad8,11': 6144, 'iPad8,12': 6144,
    // iPad mini (5th generation); iPad Air (3rd generation).
    'iPad11,1': 3072, 'iPad11,2': 3072, 'iPad11,3': 3072, 'iPad11,4': 3072,
    // iPad (8th generation); iPad (9th generation).
    'iPad11,6': 3072, 'iPad11,7': 3072, 'iPad12,1': 3072, 'iPad12,2': 3072,
    // iPad Air (4th generation).
    'iPad13,1': 4096, 'iPad13,2': 4096,
    // iPad Pro 11-inch (3rd generation, M1).
    'iPad13,4': 8192, 'iPad13,5': 8192, 'iPad13,6': 8192, 'iPad13,7': 8192,
    // iPad Pro 12.9-inch (5th generation, M1).
    'iPad13,8': 8192, 'iPad13,9': 8192, 'iPad13,10': 8192, 'iPad13,11': 8192,
    // iPad Air (5th generation, M1); iPad (10th generation).
    'iPad13,16': 8192, 'iPad13,17': 8192, 'iPad13,18': 4096, 'iPad13,19': 4096,
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
    'iPad16,8': 12288, 'iPad16,9': 12288, 'iPad16,10': 12288,
    'iPad16,11': 12288,
  };

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
      } catch (_) {
        // A failed GPU probe falls through to the integrated-GPU default.
      }
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
      } catch (_) {
        // A failed GPU probe falls through to the integrated-GPU default.
      }
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
  })
  computeModelConfig({
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

      // Every layer on Metal, text and vision: the GPU shares memory with the
      // CPU, and on an iPhone 17 full offload cut time to first token from
      // 19 s to 0.8 s (extraction benchmark, tool/extraction_bench).
      if (profile.ramMB >= 8192) {
        contextSize = 4096;
        gpuLayers = 99;
      } else if (profile.ramMB >= 6144) {
        contextSize = 2048;
        gpuLayers = 99;
      } else if (profile.ramMB >= 4096) {
        contextSize = 1024;
        gpuLayers = 99;
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
