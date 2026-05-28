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
  Future<void> saveSpecialtiesOrder(List<String> specialtiesOrder);
  Future<List<String>?> getSpecialtiesOrder();
  Future<void> saveSpecialtiesVisibility(Map<String, bool> visibility);
  Future<Map<String, bool>?> getSpecialtiesVisibility();
  Future<void> saveOverviewViewMode(String mode);
  Future<String?> getOverviewViewMode();
}
