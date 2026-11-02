import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// Small secrets kept in the platform's protected store (Keychain, Android
/// Keystore, Windows DPAPI) instead of preferences, which go into device
/// backups in plain text.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

@LazySingleton(as: SecretStore)
class SecureSecretStore implements SecretStore {
  // This device only: not restored onto another phone from a backup, and
  // not synced through iCloud Keychain. On macOS the legacy keychain needs no
  // keychain-sharing entitlement, which would tie builds to a provisioning
  // profile.
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      usesDataProtectionKeychain: false,
    ),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
