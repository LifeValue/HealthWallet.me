import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/processing/domain/services/device_capability_service.dart'
    as processing;
import 'package:injectable/injectable.dart';

enum DeviceAiCapability { unsupported, basicOnly, full }

@lazySingleton
class DeviceCapabilityService {
  DeviceAiCapability? _cachedCapability;
  int? _deviceRamMB;
  processing.DeviceProfile? _cachedProfile;

  Future<DeviceAiCapability> getCapability() async {
    if (_cachedCapability != null) return _cachedCapability!;
    final ramMB = await getDeviceRamMB();
    _cachedCapability = classifyCapability(
      ramMB,
      platform: Platform.operatingSystem,
    );
    return _cachedCapability!;
  }

  Future<processing.DeviceProfile> getProfile() async {
    if (_cachedProfile != null) return _cachedProfile!;
    final ramMB = await getDeviceRamMB();
    _cachedProfile = await processing.DeviceCapabilityService.buildProfile(
      ramMB: ramMB,
    );
    return _cachedProfile!;
  }

  Future<int> getDeviceRamMB() async {
    if (_deviceRamMB != null) return _deviceRamMB!;
    try {
      if (Platform.isIOS) {
        final deviceInfo = DeviceInfoPlugin();
        final ios = await deviceInfo.iosInfo;
        _deviceRamMB = estimateIosRam(ios.utsname.machine);
      } else if (Platform.isAndroid) {
        _deviceRamMB = await readAndroidRamMB();
        if (_deviceRamMB == null) {
          final deviceInfo = DeviceInfoPlugin();
          final android = await deviceInfo.androidInfo;
          _deviceRamMB = android.isLowRamDevice ? 2048 : 4096;
        }
      } else if (Platform.isMacOS) {
        _deviceRamMB = await _readMacOsRamMB();
      } else if (Platform.isWindows) {
        _deviceRamMB = await _readWindowsRamMB();
      } else if (Platform.isLinux) {
        _deviceRamMB = await _readLinuxRamMB();
      }
    } catch (e) {
      logger.w('Could not read the device RAM; assuming 4096 MB', e);
    }
    _deviceRamMB ??= 4096;
    return _deviceRamMB!;
  }

  static const int _minRamIosMB = 4096;
  static const int _minRamAndroidMB = 10240;
  static const int _minRamForVisionIosMB = 6144;
  static const int _minRamForVisionAndroidMB = 11264;

  /// The Advanced model needs about 3.6 GB for text and 4.3 GB with Deep
  /// Scan, more than iOS lets one app use on a 6 GB iPhone.
  static const int _minRamForAdvancedIosMB = 8192;

  /// Whether the Advanced model is offered: on a device with
  /// [DeviceAiCapability.full], and on an iPhone or iPad only from 8 GB.
  Future<bool> supportsAdvancedModel() async => supportsAdvancedModelFor(
    await getDeviceRamMB(),
    platform: Platform.operatingSystem,
  );

  /// What [ramMB] of memory allows on [platform] (as
  /// [Platform.operatingSystem] names it); desktops can run every model.
  static DeviceAiCapability classifyCapability(
    int ramMB, {
    required String platform,
  }) {
    if (platform == 'ios') {
      if (ramMB < _minRamIosMB) return DeviceAiCapability.unsupported;
      if (ramMB < _minRamForVisionIosMB) return DeviceAiCapability.basicOnly;
      return DeviceAiCapability.full;
    }
    if (platform == 'android') {
      if (ramMB < _minRamAndroidMB) return DeviceAiCapability.unsupported;
      if (ramMB < _minRamForVisionAndroidMB) {
        return DeviceAiCapability.basicOnly;
      }
      return DeviceAiCapability.full;
    }
    return DeviceAiCapability.full;
  }

  /// [supportsAdvancedModel] for [ramMB] of memory on [platform].
  static bool supportsAdvancedModelFor(int ramMB, {required String platform}) {
    if (classifyCapability(ramMB, platform: platform) !=
        DeviceAiCapability.full) {
      return false;
    }
    return platform != 'ios' || ramMB >= _minRamForAdvancedIosMB;
  }

  static Future<int?> readAndroidRamMB() async {
    try {
      final memInfo = await File('/proc/meminfo').readAsString();
      final match = RegExp(r'MemTotal:\s+(\d+)').firstMatch(memInfo);
      if (match != null) return int.parse(match.group(1)!) ~/ 1024;
    } catch (_) {
      // A failed RAM probe returns null; the caller falls back to an estimate.
    }
    return null;
  }

  /// The RAM of an iPhone or iPad from its model identifier, from the one
  /// table the AI pipeline also reads.
  static int estimateIosRam(String machine) =>
      processing.DeviceCapabilityService.estimateIosRam(machine);

  static Future<int?> _readMacOsRamMB() async {
    try {
      final result = await Process.run('sysctl', ['-n', 'hw.memsize']);
      if (result.exitCode == 0) {
        final bytes = int.tryParse(result.stdout.toString().trim());
        if (bytes != null) return bytes ~/ (1024 * 1024);
      }
    } catch (_) {
      // A failed RAM probe returns null; the caller falls back to an estimate.
    }
    return null;
  }

  static Future<int?> _readWindowsRamMB() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        '(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory',
      ]);
      if (result.exitCode == 0) {
        final bytes = int.tryParse(result.stdout.toString().trim());
        if (bytes != null) return bytes ~/ (1024 * 1024);
      }
    } catch (_) {
      // A failed RAM probe returns null; the caller falls back to an estimate.
    }
    return null;
  }

  static Future<int?> _readLinuxRamMB() async {
    try {
      final memInfo = await File('/proc/meminfo').readAsString();
      final match = RegExp(r'MemTotal:\s+(\d+)').firstMatch(memInfo);
      if (match != null) return int.parse(match.group(1)!) ~/ 1024;
    } catch (_) {
      // A failed RAM probe returns null; the caller falls back to an estimate.
    }
    return null;
  }
}
