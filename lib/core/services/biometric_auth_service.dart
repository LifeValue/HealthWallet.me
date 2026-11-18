import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class BiometricAuthService {
  BiometricAuthService(this._strings);

  final AppStringsProvider _strings;
  final LocalAuthentication _auth = LocalAuthentication();

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  Future<bool> canAuthenticate() async {
    final canAuth =
        await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    return canAuth;
  }

  Future<bool> isBiometricAvailable() async {
    try {
      final availableBiometrics = await _auth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isDeviceSecure() async {
    try {
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      return isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: _strings.l10n.biometricAuthReason,
        options: const AuthenticationOptions(
          biometricOnly: false,
        ),
      );
      return didAuthenticate;
    } catch (e) {
      // Handle cases where biometrics are not available
      return false;
    }
  }

  Future<bool> openDeviceSettings() async {
    try {
      if (_isAndroid) {
        try {
          const securityIntent = AndroidIntent(
            action: 'android.settings.SECURITY_SETTINGS',
          );
          await securityIntent.launch();
          return true;
        } catch (e) {
          const settingsIntent = AndroidIntent(
            action: 'android.settings.SETTINGS',
          );
          await settingsIntent.launch();
          return true;
        }
      } else {
        final Uri settingsUri = Uri.parse('App-Prefs:');
        if (await canLaunchUrl(settingsUri)) {
          await launchUrl(settingsUri);
          return true;
        }
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
