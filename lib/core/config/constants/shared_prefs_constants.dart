class SharedPrefsConstants {
  SharedPrefsConstants._();

  static const bearerToken = 'bearerToken';

  /// Set by the onboarding's last page. The splash page and the app lock
  /// read it.
  static const hasSeenOnboarding = 'hasSeenOnboarding';
  static const vitalsOrder = 'vitalsOrder';
  static const recordsOrder = 'recordsOrder';
  static const vitalsVisibility = 'vitalsVisibility';
  static const recordsVisibility = 'recordsVisibility';
  static const aiMaxTokens = 'aiMaxTokens';
  static const aiGpuLayers = 'aiGpuLayers';
  static const aiThreads = 'aiThreads';
  static const aiContextSize = 'aiContextSize';
  static const aiSelectedModel = 'aiSelectedModel';
  static const aiUseVision = 'aiUseVision';

  /// `ExtractionOutputMode` name: grammar, schema or schemaDraft.
  static const aiOutputMode = 'aiOutputMode';
  static const regionPreset = 'regionPreset';
  static const countryCode = 'countryCode';
  static const appLocale = 'appLocale';
  static const backupDirectory = 'backupDirectory';
  static const minimizeToTray = 'minimizeToTray';
  static const recordsViewMode = 'recordsViewMode';
  static const specialtiesOrder = 'specialtiesOrder';
  static const specialtiesVisibility = 'specialtiesVisibility';
  static const overviewViewMode = 'overviewViewMode';
}
