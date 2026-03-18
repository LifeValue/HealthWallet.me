import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health_wallet/features/backup/data/models/device_pairing.dart';

@lazySingleton
class PairingStorageService {
  static const _pairingKey = 'device_pairing';
  static const _localDeviceIdKey = 'local_device_id';

  final SharedPreferences _prefs;

  PairingStorageService(this._prefs);

  Future<void> savePairing(DevicePairing pairing) async {
    final json = jsonEncode(pairing.toJson());
    await _prefs.setString(_pairingKey, json);
  }

  DevicePairing? loadPairing() {
    final json = _prefs.getString(_pairingKey);
    if (json == null) return null;
    return DevicePairing.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> clearPairing() async {
    await _prefs.remove(_pairingKey);
  }

  bool get hasPairing => _prefs.containsKey(_pairingKey);

  Future<void> saveLocalDeviceId(String deviceId) async {
    await _prefs.setString(_localDeviceIdKey, deviceId);
  }

  String? get localDeviceId => _prefs.getString(_localDeviceIdKey);

  Future<void> updateLastConnection({
    required String ip,
    required int port,
  }) async {
    final current = loadPairing();
    if (current == null) return;
    final updated = current.copyWith(lastIp: ip, lastPort: port);
    await savePairing(updated);
  }
}
