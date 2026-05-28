import 'dart:convert';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/features/home/domain/repository/home_preferences_repository.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@Injectable(as: HomePreferencesRepository)
class HomeLocalDataSourceImpl implements HomePreferencesRepository {
  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  @override
  Future<void> saveVitalsOrder(List<String> vitalsOrder) async {
    final prefs = await _prefs;
    final jsonString = jsonEncode(vitalsOrder);
    await prefs.setString(SharedPrefsConstants.vitalsOrder, jsonString);
  }

  @override
  Future<List<String>?> getVitalsOrder() async {
    final prefs = await _prefs;
    final jsonString = prefs.getString(SharedPrefsConstants.vitalsOrder);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        return decoded.cast<String>();
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<void> saveRecordsOrder(List<String> recordsOrder) async {
    final prefs = await _prefs;
    final jsonString = jsonEncode(recordsOrder);
    await prefs.setString(SharedPrefsConstants.recordsOrder, jsonString);
  }

  @override
  Future<void> saveSpecialtiesOrder(List<String> specialtiesOrder) async {
    final prefs = await _prefs;
    final jsonString = jsonEncode(specialtiesOrder);
    await prefs.setString(SharedPrefsConstants.specialtiesOrder, jsonString);
  }

  @override
  Future<List<String>?> getSpecialtiesOrder() async {
    final prefs = await _prefs;
    final jsonString = prefs.getString(SharedPrefsConstants.specialtiesOrder);
    if (jsonString == null) return null;
    return List<String>.from(jsonDecode(jsonString));
  }

  @override
  Future<void> saveSpecialtiesVisibility(Map<String, bool> visibility) async {
    final prefs = await _prefs;
    final jsonString = jsonEncode(visibility);
    await prefs.setString(SharedPrefsConstants.specialtiesVisibility, jsonString);
  }

  @override
  Future<Map<String, bool>?> getSpecialtiesVisibility() async {
    final prefs = await _prefs;
    final jsonString = prefs.getString(SharedPrefsConstants.specialtiesVisibility);
    if (jsonString == null) return null;
    return Map<String, bool>.from(jsonDecode(jsonString));
  }

  @override
  Future<void> saveVitalsVisibility(Map<String, bool> visibility) async {
    final prefs = await _prefs;
    final jsonString = jsonEncode(visibility);
    await prefs.setString(SharedPrefsConstants.vitalsVisibility, jsonString);
  }

  @override
  Future<void> saveRecordsVisibility(Map<String, bool> visibility) async {
    final prefs = await _prefs;
    final jsonString = jsonEncode(visibility);
    await prefs.setString(SharedPrefsConstants.recordsVisibility, jsonString);
  }

  @override
  Future<Map<String, bool>?> getRecordsVisibility() async {
    final prefs = await _prefs;
    final jsonString = prefs.getString(SharedPrefsConstants.recordsVisibility);
    if (jsonString != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(jsonString);
        return decoded.map((k, v) => MapEntry(k, v == true));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<Map<String, bool>?> getVitalsVisibility() async {
    final prefs = await _prefs;
    final jsonString = prefs.getString(SharedPrefsConstants.vitalsVisibility);
    if (jsonString != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(jsonString);
        return decoded.map((k, v) => MapEntry(k, v == true));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<List<String>?> getRecordsOrder() async {
    final prefs = await _prefs;
    final jsonString = prefs.getString(SharedPrefsConstants.recordsOrder);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        return decoded.cast<String>();
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<void> clearPreferences() async {
    final prefs = await _prefs;
    await prefs.remove(SharedPrefsConstants.vitalsOrder);
    await prefs.remove(SharedPrefsConstants.recordsOrder);
    await prefs.remove(SharedPrefsConstants.vitalsVisibility);
    await prefs.remove(SharedPrefsConstants.recordsVisibility);
    await prefs.remove(SharedPrefsConstants.overviewViewMode);
  }

  @override
  Future<void> saveOverviewViewMode(String mode) async {
    final prefs = await _prefs;
    await prefs.setString(SharedPrefsConstants.overviewViewMode, mode);
  }

  @override
  Future<String?> getOverviewViewMode() async {
    final prefs = await _prefs;
    return prefs.getString(SharedPrefsConstants.overviewViewMode);
  }
}
