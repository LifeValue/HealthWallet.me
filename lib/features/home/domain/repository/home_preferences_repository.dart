abstract class HomePreferencesRepository {
  Future<void> saveVitalsOrder(List<String> vitalsOrder);
  Future<List<String>?> getVitalsOrder();
  Future<void> saveRecordsOrder(List<String> recordsOrder);
  Future<List<String>?> getRecordsOrder();
  Future<void> saveVitalsVisibility(Map<String, bool> visibility);
  Future<Map<String, bool>?> getVitalsVisibility();
  Future<void> saveRecordsVisibility(Map<String, bool> visibility);
  Future<Map<String, bool>?> getRecordsVisibility();
  Future<void> clearPreferences();
}
