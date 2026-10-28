import 'dart:io';

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

    final bluetoothPermissions = <Permission>[
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
    ];

    final networkPermissions = <Permission>[
      Permission.nearbyWifiDevices,
      Permission.locationWhenInUse,
    ];

    final allPermissions = [...bluetoothPermissions, ...networkPermissions];

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

    final permissions = <Permission>[
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.nearbyWifiDevices,
      Permission.locationWhenInUse,
    ];

    for (final permission in permissions) {
      final status = await permission.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        return false;
      }
    }

    return true;
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
