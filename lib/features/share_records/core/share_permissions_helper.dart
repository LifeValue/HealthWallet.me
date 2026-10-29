import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';

class SharePermissionsHelper {
  static Future<PermissionResult> requestSharePermissions() async {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return const PermissionGranted();
    }

    if (Platform.isIOS) {
      final bluetoothStatus = await Permission.bluetooth.status;

      if (bluetoothStatus.isGranted) {
        return const PermissionGranted();
      }

      if (bluetoothStatus.isPermanentlyDenied) {
        return const PermissionPermanentlyDenied([Permission.bluetooth]);
      }

      final result = await Permission.bluetooth.request();
      if (result.isGranted) {
        return const PermissionGranted();
      }
      if (result.isPermanentlyDenied) {
        return const PermissionPermanentlyDenied([Permission.bluetooth]);
      }
      return const PermissionDenied([Permission.bluetooth]);
    }

    final allPermissions = await _androidPermissions();

    final notGranted = <Permission>[];
    for (final permission in allPermissions) {
      final status = await permission.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        notGranted.add(permission);
      }
    }

    if (notGranted.isEmpty) {
      return const PermissionGranted();
    }

    final statuses = await notGranted.request();

    final denied = <Permission>[];
    final permanentlyDenied = <Permission>[];

    for (final entry in statuses.entries) {
      if (entry.value.isDenied) {
        denied.add(entry.key);
      } else if (entry.value.isPermanentlyDenied) {
        permanentlyDenied.add(entry.key);
      }
    }

    if (permanentlyDenied.isNotEmpty) {
      return PermissionPermanentlyDenied(permanentlyDenied);
    }

    if (denied.isNotEmpty) {
      return PermissionDenied(denied);
    }

    return const PermissionGranted();
  }

  static Future<bool> hasRequiredPermissions() async {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return true;
    }

    if (Platform.isIOS) {
      final bluetoothStatus = await Permission.bluetooth.status;
      return bluetoothStatus.isGranted;
    }

    final permissions = await _androidPermissions();

    for (final permission in permissions) {
      final status = await permission.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        return false;
      }
    }

    return true;
  }

  /// NEARBY_WIFI_DEVICES only exists from Android 13 (API 33). Below that,
  /// permission_handler finds nothing to check and reports it as denied
  /// forever, so asking for it would keep Share Proximity locked.
  static Future<List<Permission>> _androidPermissions() async {
    final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    return [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      if (sdkInt >= 33) Permission.nearbyWifiDevices,
      Permission.locationWhenInUse,
    ];
  }

  static Future<bool> openSettings() async {
    return openAppSettings();
  }

  static String getPermissionExplanation(AppLocalizations l10n) {
    if (Platform.isIOS) return l10n.sharePermissionExplanationIos;
    return l10n.sharePermissionExplanationAndroid;
  }
}

sealed class PermissionResult {
  const PermissionResult();
}

class PermissionGranted extends PermissionResult {
  const PermissionGranted();
}

class PermissionDenied extends PermissionResult {
  final List<Permission> permissions;
  const PermissionDenied(this.permissions);

  String message(AppLocalizations l10n) => l10n.sharePermissionsDeniedMessage;
}

class PermissionPermanentlyDenied extends PermissionResult {
  final List<Permission> permissions;
  const PermissionPermanentlyDenied(this.permissions);

  String message(AppLocalizations l10n) =>
      l10n.sharePermissionsPermanentlyDeniedMessage;
}
