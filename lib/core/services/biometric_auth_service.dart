import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';

class BiometricAuthService {
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
        localizedReason: 'Please authenticate to access your HealthWallet.me',
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
          final securityIntent = AndroidIntent(
            action: 'android.settings.SECURITY_SETTINGS',
          );
          await securityIntent.launch();
          return true;
        } catch (e) {
          final settingsIntent = AndroidIntent(
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
