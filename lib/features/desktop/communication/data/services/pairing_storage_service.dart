import 'dart:convert';

import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/data/services/secret_store.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// The pairing with the other device. The keys live in [SecretStore]; the
/// rest (names, last address, the paired phone) in preferences. [load] must
/// run before [loadPairing].
@lazySingleton
class PairingStorageService {
  static const _pairingKey = 'device_pairing';
  static const _secretKey = 'desktop_pairing_key';
  static const _pendingSecretKey = 'desktop_pairing_pending_key';

  /// Shared with the LWW sync, which tags rows with the same id.
  static const _localDeviceIdKey = 'lww_local_device_id';

  final SharedPreferences _prefs;
  final SecretStore _secrets;
  DevicePairing? _pairing;
  bool _loaded = false;

  PairingStorageService(this._prefs, this._secrets);

  /// Reads the pairing, moving a key that an older version kept in
  /// preferences into the secret store.
  Future<DevicePairing?> load() async {
    final raw = _prefs.getString(_pairingKey);
    _loaded = true;
    if (raw == null) return _pairing = null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final legacyKey = json['pairingKey'] as String?;
      final legacyPending = json['pendingKey'] as String?;
      final key = legacyKey ?? await _secrets.read(_secretKey);
      if (key == null) {
        // The secret store was wiped or this is a restored backup: the
        // pairing can't be used any more.
        logger.w('[Pairing] key missing; the devices need to pair again');
        await _prefs.remove(_pairingKey);
        return _pairing = null;
      }
      final pending = legacyPending ?? await _secrets.read(_pendingSecretKey);
      final pairing = DevicePairing.fromJson({
        ...json,
        'pairingKey': key,
        'pendingKey': pending,
      });
      if (legacyKey != null) await savePairing(pairing);
      return _pairing = pairing;
    } catch (e) {
      logger.e('[Pairing] unreadable pairing, starting over', e);
      await _prefs.remove(_pairingKey);
      return _pairing = null;
    }
  }

  DevicePairing? loadPairing() {
    assert(_loaded, 'PairingStorageService.load() first');
    return _pairing;
  }

  bool get hasPairing => _pairing != null;

  Future<void> savePairing(DevicePairing pairing) async {
    final json = pairing.toJson()
      ..remove('pairingKey')
      ..remove('pendingKey');
    try {
      await _secrets.write(_secretKey, pairing.pairingKey);
      final pending = pairing.pendingKey;
      if (pending == null) {
        await _secrets.delete(_pendingSecretKey);
      } else {
        await _secrets.write(_pendingSecretKey, pending);
      }
    } catch (e) {
      // Without a working secret store the keys stay in preferences, so the
      // devices still connect.
      logger.e(
        '[Pairing] secret store unavailable; key kept in preferences',
        e,
      );
      json['pairingKey'] = pairing.pairingKey;
      json['pendingKey'] = pairing.pendingKey;
    }
    await _prefs.setString(_pairingKey, jsonEncode(json));
    _pairing = pairing;
    _loaded = true;
  }

  Future<void> clearPairing() async {
    await _prefs.remove(_pairingKey);
    try {
      await _secrets.delete(_secretKey);
      await _secrets.delete(_pendingSecretKey);
    } catch (e) {
      logger.w('[Pairing] secret store unavailable while clearing', e);
    }
    _pairing = null;
  }

  /// This device's id, the same one the LWW sync uses.
  Future<String> localDeviceId() async {
    var id = _prefs.getString(_localDeviceIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await _prefs.setString(_localDeviceIdKey, id);
    }
    return id;
  }

  Future<void> updateLastConnection({
    required String ip,
    required int port,
  }) async {
    final current = _pairing;
    if (current == null) return;
    if (current.lastIp == ip && current.lastPort == port) return;
    await savePairing(current.copyWith(lastIp: ip, lastPort: port));
  }
}
