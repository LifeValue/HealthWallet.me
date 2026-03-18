import 'dart:io';

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

  static ({int gpuLayers, int threads, int contextSize}) computeModelConfig({
    required bool withVision,
    required int ramMB,
  }) {
    final cpuCores = Platform.numberOfProcessors;
    final threads = cpuCores.clamp(1, 4);

    int contextSize;
    int gpuLayers = 0;

    if (Platform.isIOS) {
      if (ramMB >= 8192) {
        contextSize = 4096;
        gpuLayers = withVision ? 4 : 0;
      } else if (ramMB >= 6144) {
        contextSize = 2048;
        gpuLayers = withVision ? 2 : 0;
      } else if (ramMB >= 4096) {
        contextSize = 1024;
        gpuLayers = withVision ? 1 : 0;
      } else {
        contextSize = 512;
      }
    } else {
      if (ramMB >= 12288) {
        contextSize = 4096;
      } else if (ramMB >= 8192) {
        contextSize = 2048;
      } else {
        contextSize = 512;
      }
    }

    return (gpuLayers: gpuLayers, threads: threads, contextSize: contextSize);
  }
}
