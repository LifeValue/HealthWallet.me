import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
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
    _cachedCapability = _classifyCapability(ramMB);
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
    } catch (_) {}
    _deviceRamMB ??= 4096;
    return _deviceRamMB!;
  }

  static const int _minRamIosMB = 4096;
  static const int _minRamAndroidMB = 10240;
  static const int _minRamForVisionIosMB = 6144;
  static const int _minRamForVisionAndroidMB = 11264;

  DeviceAiCapability _classifyCapability(int ramMB) {
    if (Platform.isIOS) {
      if (ramMB < _minRamIosMB) return DeviceAiCapability.unsupported;
      if (ramMB < _minRamForVisionIosMB) return DeviceAiCapability.basicOnly;
      return DeviceAiCapability.full;
    }
    if (Platform.isAndroid) {
      if (ramMB < _minRamAndroidMB) return DeviceAiCapability.unsupported;
      if (ramMB < _minRamForVisionAndroidMB) return DeviceAiCapability.basicOnly;
      return DeviceAiCapability.full;
    }
    return DeviceAiCapability.full;
  }

  static Future<int?> readAndroidRamMB() async {
    try {
      final memInfo = await File('/proc/meminfo').readAsString();
      final match = RegExp(r'MemTotal:\s+(\d+)').firstMatch(memInfo);
      if (match != null) return int.parse(match.group(1)!) ~/ 1024;
    } catch (_) {}
    return null;
  }

  static int estimateIosRam(String machine) {
    final iphone = RegExp(r'iPhone(\d+),').firstMatch(machine);
    if (iphone != null) {
      final major = int.tryParse(iphone.group(1)!) ?? 0;
      if (major >= 17) return 8192;
      if (major >= 15) return 6144;
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

  static Future<int?> _readMacOsRamMB() async {
    try {
      final result = await Process.run('sysctl', ['-n', 'hw.memsize']);
      if (result.exitCode == 0) {
        final bytes = int.tryParse(result.stdout.toString().trim());
        if (bytes != null) return bytes ~/ (1024 * 1024);
      }
    } catch (_) {}
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
    } catch (_) {}
    return null;
  }

  static Future<int?> _readLinuxRamMB() async {
    try {
      final memInfo = await File('/proc/meminfo').readAsString();
      final match = RegExp(r'MemTotal:\s+(\d+)').firstMatch(memInfo);
      if (match != null) return int.parse(match.group(1)!) ~/ 1024;
    } catch (_) {}
    return null;
  }
}
