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

  /// The model the selection was moved away from because the device can't
  /// run it, until the user has been told.
  static const aiModelSwitchNotice = 'aiModelSwitchNotice';
  static const aiUseVision = 'aiUseVision';

  /// Set once the AI settings that earlier versions saved by mistake have
  /// been removed, so a value the user saves later is never removed.
  static const aiMistakenSettingsReset = 'aiMistakenSettingsReset';

  /// `ExtractionOutputMode` name: grammar, schema or schemaDraft.
  static const aiOutputMode = 'aiOutputMode';
  static const regionPreset = 'regionPreset';
  static const countryCode = 'countryCode';
  static const appLocale = 'appLocale';
  static const backupDirectory = 'backupDirectory';

  /// macOS security-scoped bookmark for [backupDirectory], so the sandboxed
  /// app can open the folder again after a restart.
  static const backupDirectoryBookmark = 'backupDirectoryBookmark';

  /// Whole days a "Before restore" safety copy is kept on this desktop. Not
  /// synced and not stored in the backup folder.
  static const safetyCopyRetentionDays = 'safetyCopyRetentionDays';
  static const minimizeToTray = 'minimizeToTray';
  static const recordsViewMode = 'recordsViewMode';
  static const specialtiesOrder = 'specialtiesOrder';
  static const specialtiesVisibility = 'specialtiesVisibility';
  static const overviewViewMode = 'overviewViewMode';
}
