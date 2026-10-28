// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get onboardingWelcomeTitle => 'a Health Wallet for You!';

  @override
  String get onboardingWelcomeSubtitle =>
      '<link>HealthWallet.me</link> already connects to 100,000+ US healthcare providers, and we\'re expanding to new countries.';

  @override
  String get onboardingWelcomeDescription =>
      'Add records from any provider, import documents manually, or request support for your country.';

  @override
  String get onboardingRecordsTitle => 'Your Health, Always in Sync';

  @override
  String get onboardingRecordsSubtitle =>
      '<link>HealthWallet.me</link> gives you flexible ways to bring all your medical history together:';

  @override
  String get onboardingRecordsDescription =>
      '• Scan documents with your phone\'s camera\n• Upload PDFs, images, or lab files directly\n• Import records by sharing directly with <link>HealthWallet.me</link> from any app in your smartphone.\n• Scan the QR Code of Fasten Health OnPrem and get all your US healthcare systems records to your wallet.';

  @override
  String get onboardingRecordsContent =>
      '• Scan documents with your phone\'s camera\n• Upload PDFs, images, or lab files directly\n• Import records by sharing directly with <link>HealthWallet.me</link> from any app in your smartphone.\n• Scan the QR Code of <link>Fasten Health OnPrem</link> and get all your US healthcare systems records to your wallet.';

  @override
  String get onboardingRecordsBottom =>
      'Everything is organized securely on your device.';

  @override
  String get onboardingRequestIntegration => 'Request an integration';

  @override
  String get onboardingScanButton => 'Scan';

  @override
  String get onboardingSyncTitle => 'Security & Privacy';

  @override
  String get onboardingSyncSubtitle =>
      '<link>HealthWallet.me</link> is built with privacy at its core. Your medical data is encrypted and stored only on your phone, never on cloud servers.';

  @override
  String get onboardingSyncDescription =>
      'View your health history in airplane mode, abroad, or without internet, your records stay with you wherever you go. Add an extra layer of security by enabling biometric authentication.';

  @override
  String get homeHi => 'Hi, ';

  @override
  String get homeVitalSigns => 'Vitals';

  @override
  String get homeSource => 'Source:';

  @override
  String get homeNA => 'N/A';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get recordsTitle => 'Records';

  @override
  String get goToRecords => 'Go to Records';

  @override
  String get syncTitle => 'Sync';

  @override
  String get syncSuccessful => 'Sync successful!';

  @override
  String get syncDataLoadedSuccessfully =>
      'Your medical records have been synchronized. You will be redirected to the home page.';

  @override
  String get cancelSyncTitle => 'Cancel Sync?';

  @override
  String get cancelSyncMessage =>
      'Are you sure you want to cancel the synchronization? This will stop the current sync process.';

  @override
  String get yesCancel => 'Yes, Cancel';

  @override
  String get continueSync => 'Continue Sync';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get searchRecordsHint => 'Search records, doctors, locations...';

  @override
  String get patientId => 'MRN: ';

  @override
  String get age => 'Age';

  @override
  String get sex => 'Sex';

  @override
  String get bloodType => 'Blood Type';

  @override
  String get theme => 'Theme';

  @override
  String get authenticate => 'Authenticate';

  @override
  String get biometricAuthentication => 'Biometric Authentication';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get setupDeviceSecurity => 'Set Up Device Security';

  @override
  String get deviceSecurityMessage =>
      'Your device has no security setup. For your safety, please set up device security before using this app:';

  @override
  String get deviceSettingsStep1 => 'Go to your device Settings';

  @override
  String get deviceSettingsStep2 => 'Navigate to Security or Lock screen';

  @override
  String get deviceSettingsStep3 =>
      'Set up a screen lock (PIN, pattern, or password)';

  @override
  String get deviceSettingsStep4 =>
      'Optionally add fingerprint or face unlock for convenience';

  @override
  String get deviceSecurityReturnMessage =>
      'After setting up device security, return to this app and try again.';

  @override
  String get cancel => 'Cancel';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get settingsNotAvailable => 'Settings Not Available';

  @override
  String get settingsNotAvailableMessage =>
      'Could not open device settings automatically. Please manually:\n\n1. Open Settings\n2. Go to Security → Biometrics\n3. Add fingerprint or face unlock\n4. Return to this app and try again';

  @override
  String get ok => 'OK';

  @override
  String get or => 'or';

  @override
  String get connect => 'Connect';

  @override
  String get loadDemoData => 'Load Demo Data';

  @override
  String get noMedicalRecordsYet => 'No medical records yet';

  @override
  String get loadDemoDataMessage =>
      'Load demo data to explore the app or sync your real medical records';

  @override
  String get retry => 'Retry';

  @override
  String get pleaseEnterSourceName => 'Please enter a source name';

  @override
  String get selectBirthDate => 'Select birth date';

  @override
  String get years => 'years';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get preferNotToSay => 'Prefer not to say';

  @override
  String get errorUpdatingSourceLabel => 'Error updating source label';

  @override
  String get getStarted => 'Get Started';

  @override
  String get failedToUpdateDisplayName => 'Failed to update display name';

  @override
  String get actionCannotBeUndone => 'This action cannot be undone.';

  @override
  String get deleteSourceConfirmPrefix => 'This will permanently delete ';

  @override
  String get deleteSourceConfirmSuffix =>
      ' and all its records. To confirm, type the source name below.';

  @override
  String get deleteRecordConfirm =>
      'Are you sure you want to delete this record?';

  @override
  String get deleteNoteConfirm => 'Are you sure you want to delete this note?';

  @override
  String get deleteAttachmentConfirm =>
      'Are you sure you want to delete this attachment?';

  @override
  String deleteRecordsConfirm(int count) {
    return 'Are you sure you want to delete $count items?';
  }

  @override
  String get editSourceLabel => 'Edit source label';

  @override
  String get saveDetails => 'Save details';

  @override
  String get editDetails => 'Edit details';

  @override
  String get done => 'Done';

  @override
  String get page => 'Page';

  @override
  String get reorderPages => 'Reorder Pages';

  @override
  String get attachments => 'Attachments';

  @override
  String get noFilesAttached => 'This record has no files attached';

  @override
  String get attachFile => 'Attach file';

  @override
  String get overview => 'Overview';

  @override
  String get recentRecords => 'Recent records';

  @override
  String get displayName => 'Display name';

  @override
  String get unknownSource => 'Unknown Source';

  @override
  String get desktopSyncAndBackup => 'Data Sync & Backup';

  @override
  String get desktopSyncDescription =>
      'Sync & Backup your health records.\nHand over documents to be digitally processed on your desktop.';

  @override
  String get processOnDesktop => 'Process on Desktop';

  @override
  String get continueImporting => 'Continue Importing';

  @override
  String get noAiModel => 'No AI model';

  @override
  String get noAiModelOnDesktop =>
      'No AI model on Desktop. Please download the AI model on your desktop app first.';

  @override
  String get syncMedicalRecords => 'Sync Medical records';

  @override
  String get lastSynced => 'Last synced';

  @override
  String get tapToSelectPatient => 'Tap to select patient';

  @override
  String get preferences => 'Preferences';

  @override
  String get version => 'Version';

  @override
  String get on => 'ON';

  @override
  String get off => 'OFF';

  @override
  String get confirmDisableBiometric =>
      'Are you sure you would like to disable the Biometric Auth (FaceID / Passcode)?';

  @override
  String get disable => 'Disable';

  @override
  String get continueButton => 'Continue';

  @override
  String get enableBiometricAuth => 'Enable Biometric Auth (FaceID / Passcode)';

  @override
  String get disableBiometricAuth =>
      'Disable Biometric Auth (FaceID / Passcode)';

  @override
  String get patient => 'Patient';

  @override
  String get noPatientsFound => 'No patients found';

  @override
  String get id => 'ID';

  @override
  String get gender => 'Gender';

  @override
  String get loading => 'Loading...';

  @override
  String get source => 'Source';

  @override
  String get records => 'Records';

  @override
  String get vitals => 'Vitals';

  @override
  String get selectAll => 'Select all';

  @override
  String get clearAll => 'Clear all';

  @override
  String get save => 'Save';

  @override
  String get noRecordsFound => 'No records found';

  @override
  String get noRecords => 'No records';

  @override
  String get tryDifferentKeywords => 'Try searching with different keywords';

  @override
  String get syncingData => 'Syncing data';

  @override
  String get syncingMessage => 'It might take a while. Please wait.';

  @override
  String get viewAll => 'View all';

  @override
  String get vitalSigns => 'Vital Signs';

  @override
  String get longPressToReorder =>
      'Long press to move & reorder cards, or filter to select which ones appear on your dashboard.';

  @override
  String get finishProcessing => 'Finish Processing';

  @override
  String get finishProcessingMessage =>
      'Are you sure you want to finish this processing session?';

  @override
  String get finishProcessingWarning => 'This will clear the current session.';

  @override
  String get fieldCannotBeEmpty => 'This field cannot be empty';

  @override
  String get selectDate => 'Select date';

  @override
  String get attachToEncounter => 'Attach to Encounter';

  @override
  String get continueProcessing => 'Continue Processing';

  @override
  String get recordsSavedTitle => 'Successfully Saved';

  @override
  String get whatNextQuestion => 'What would you like to do next?';

  @override
  String get continueScanning => 'Continue Scanning';

  @override
  String get effectiveDate => 'Effective Date';

  @override
  String get privacyIntro => 'Your privacy is our highest priority.';

  @override
  String get privacyDescription =>
      'is a simple, secure tool designed to help you organize your health records with ease, directly on your device. This policy explains our commitment to your privacy: we do not collect your data, and we do not track you. You are in complete control.';

  @override
  String get corePrinciple =>
      'Our Core Principle: Your Data Stays on Your Device';

  @override
  String get whatInformationHandled => 'What Information is Handled?';

  @override
  String get informationWeDoNotCollect =>
      'Information We Do Not Collect or Access';

  @override
  String get informationYouManage => 'Information You Manage';

  @override
  String get importingDocuments => 'Importing Documents from Your Device';

  @override
  String get connectingFastenHealth => 'Connecting to FastenHealth OnPrem';

  @override
  String get howInformationUsed => 'How Your Information is Used';

  @override
  String get dataStorageSecurity => 'Data Storage, Security, and Sharing';

  @override
  String get childrensPrivacy => 'Children\'s Privacy';

  @override
  String get changesToPolicy => 'Changes to This Privacy Policy';

  @override
  String get contactUs => 'Contact Us';

  @override
  String get builtWithLove => 'Built with love by Life Value!';

  @override
  String get sourceName => 'Source name';

  @override
  String get provideCustomLabel => 'Provide a custom label for:';

  @override
  String get success => 'Success';

  @override
  String get demoDataLoadedSuccessfully =>
      'Demo data has been loaded successfully. You will be redirected to the home page.';

  @override
  String get documentScanTitle => 'Scan';

  @override
  String get fromPhoneTab => 'From Phone';

  @override
  String get onboardingAiModelTitle => 'Enable AI Model';

  @override
  String get onboardingAiModelDescription =>
      'Download a secure, on-device AI model to automatically analyze and organize your health records. Choose between two options depending on your needs and device capability. This is a one-time setup.\n\n**Your data stays private on your device.**';

  @override
  String get onboardingAiModelSubtitle => 'Unlock AI-powered scanning';

  @override
  String get aiModelReady => 'AI ready! You can start scanning.';

  @override
  String get aiModelDownloading => 'Downloading...';

  @override
  String get aiModelEnableDownload => 'Choose & Download';

  @override
  String get aiModelError => 'Couldn’t verify. Try again.';

  @override
  String get aiModelMissing => 'Not downloaded.';

  @override
  String get aiModelTitle => 'Load AI Model';

  @override
  String get aiModelUnlockTitle => 'Unlock AI-Powered Scanning';

  @override
  String get aiModelUnlockDescription =>
      'To automatically read and organize your medical documents, this feature uses a secure, on-device AI model.\n\n**Your data stays private on your device.**';

  @override
  String get aiModelDownloadInfo =>
      'To get started, choose and download one of two available AI options. This is a one-time setup.';

  @override
  String get setup => 'Setup';

  @override
  String get patientSetupSubtitle =>
      'Personalize your health wallet with your information';

  @override
  String get givenName => 'Given Name';

  @override
  String get familyName => 'Family Name';

  @override
  String get syncPlaceholderTutorialStep1 =>
      'Complete your profile to unlock full features.';

  @override
  String get syncPlaceholderTutorialStep2 =>
      'Not ready to import? Load demo data to see how the app looks in action.';

  @override
  String get syncPlaceholderTutorialStep3 =>
      'Keep your desktop and mobile wallet up to date.';

  @override
  String get tapToContinue => 'Tap to continue';

  @override
  String get homeOnboardingReorderMessage =>
      'Long press to reorder them according to your preference.';

  @override
  String get processing => 'Processing';

  @override
  String get sessionNotFound => 'Session not found!';

  @override
  String get preparingPreview => 'Preparing preview...';

  @override
  String get processingFailed => 'Processing failed';

  @override
  String get modelNotFoundError =>
      'Model file not found. Please download the AI model first.';

  @override
  String get modelCorruptedError =>
      'Model file is corrupted. Please re-download the AI model.';

  @override
  String get processingCancelled => 'Processing was cancelled';

  @override
  String get processingBasicDetails => 'Processing basic details...';

  @override
  String get processingPages => 'Processing pages...';

  @override
  String get extractingPatientInfo => 'Extracting patient and encounter info.';

  @override
  String get pleaseWait => 'It might take a while. Please wait.';

  @override
  String get focusMode => 'Focus Mode';

  @override
  String get onlyOneSessionAtTime =>
      'Only one processing session can run at a time';

  @override
  String get aiModelNotAvailable => 'Smart scanning is not available';

  @override
  String get addResources => 'Add resources';

  @override
  String get addResourcesTitle => 'Add Resources';

  @override
  String get chooseResourcesDescription =>
      'Choose the resources you want to add for processing.';

  @override
  String get add => 'Add';

  @override
  String get allergyIntolerance => 'Allergy Intolerance';

  @override
  String get condition => 'Condition';

  @override
  String get diagnosticReport => 'Diagnostic Report';

  @override
  String get medicationStatement => 'Medication Statement';

  @override
  String get observation => 'Observation';

  @override
  String get organization => 'Organization';

  @override
  String get practitioner => 'Practitioner';

  @override
  String get procedure => 'Procedure';

  @override
  String get tapToViewProgress => 'Tap anywhere to view progress';

  @override
  String screenWillDarkenInSeconds(int remainingSeconds) {
    return 'The screen will darken in $remainingSeconds seconds.';
  }

  @override
  String get screenWillDarkenInZeroSeconds =>
      'The screen will darken in 0 seconds.';

  @override
  String get whileDocumentsProcessed =>
      'While your documents are being processed:';

  @override
  String get doNotLockScreen => 'Do not lock the screen or exit the app.';

  @override
  String get plugInCharger => 'Plug in the charger.';

  @override
  String get exitFocusMode => 'Exit Focus Mode';

  @override
  String get chargerPluggedIn => 'Charger plugged in.';

  @override
  String get plugInChargerEllipsis => 'Plug in the charger...';

  @override
  String get processingFailedCapacity =>
      'The document is too large for the current AI context size.';

  @override
  String get processingFailedCapacitySuggestion =>
      'Tap the settings icon above and increase the Context Size to 2048 or higher, then retry.';

  @override
  String get increaseAiModelCapacity => 'Increase AI Capacity';

  @override
  String get goBack => 'Go Back';

  @override
  String get aiModelManage => 'Manage AI Options';

  @override
  String get aiModelNotSelected => 'No option selected';

  @override
  String get aiModelSelect => 'Select Option';

  @override
  String get aiSettings => 'AI Settings';

  @override
  String get aiSettingsDescription =>
      'Adjust AI performance for your device. Recommended values are pre-selected.';

  @override
  String get setAiTokensUsage => 'Set AI Tokens Usage';

  @override
  String get tokenUsageDescription =>
      'Control how much processing power the AI can use. Higher capacity allows larger files and more complex tasks, but uses more resources and takes longer.';

  @override
  String get gpuLayersLabel => 'GPU Layers';

  @override
  String get gpuLayersDescription =>
      'Offload model layers to GPU for faster image processing. More layers = faster but uses more memory. Set to 0 if the app crashes.';

  @override
  String get threadsLabel => 'CPU Threads';

  @override
  String get threadsDescription =>
      'Number of CPU threads for inference. More threads = faster but uses more battery.';

  @override
  String get recommended => 'Recommended';

  @override
  String get tokenPresetLow => 'Low';

  @override
  String get tokenPresetMedium => 'Medium';

  @override
  String get tokenPresetHigh => 'High';

  @override
  String get tokenPresetCustom => 'Custom';

  @override
  String get setTokens => 'Set';

  @override
  String get tokens => 'tokens';

  @override
  String get contextSizeLabel => 'Context Size';

  @override
  String get contextSizeDescription =>
      'Amount of text the AI can process at once. Larger context handles bigger documents but uses more memory.';

  @override
  String get useVisionLabel => 'Deep Scan';

  @override
  String get useVisionDescription =>
      'Reads images for deeper analysis (e.g. handwriting). Uses more memory and requires a more performant device.';

  @override
  String get aiModelNotAvailableForDevice => 'Not available for this phone';

  @override
  String get aiModelNotAvailableForDeviceDescription =>
      'Sorry, your device doesn\'t have enough memory to run the AI model. You can still use the app without smart scanning.';

  @override
  String get noInternetConnectionTitle => 'No Internet Connection';

  @override
  String get noInternetConnectionDescription =>
      'Please check your internet connection and try again.';

  @override
  String get processingStep2NotAvailableTitle =>
      'Deep Scan not available on this device';

  @override
  String get processingStep2NotEnoughRam =>
      'This device doesn\'t have enough memory for Deep Scan. Text-based processing is still available and works well for most documents.';

  @override
  String get emergencyContact => 'Emergency Phone Contact';

  @override
  String get rotatePage => 'Rotate';

  @override
  String get deletePage => 'Delete';

  @override
  String get deletePageConfirmTitle => 'Delete Page';

  @override
  String get deletePageConfirmMessage =>
      'This page will be removed from the document.';

  @override
  String get regionAndUnits => 'Language & Units';

  @override
  String get country => 'Country';

  @override
  String patientModifiedUpdating(String name) {
    return 'Modifying existing patient: $name';
  }

  @override
  String patientSavingModified(String name) {
    return 'Saving modified patient: $name';
  }

  @override
  String get dropModificationsTitle => 'Drop modifications?';

  @override
  String get dropModificationsMessage =>
      'Your changes to the patient fields will be discarded.';

  @override
  String get scanIdCard => 'Scan ID Card or Passport';

  @override
  String get scanIdCardDescription =>
      'Auto-fill from your document. Data stays on your device.';

  @override
  String get newLabel => 'New';

  @override
  String get newPatient => 'New patient';

  @override
  String patientChangedTo(String name) {
    return 'Changed to: $name';
  }

  @override
  String patientMatchFound(String name) {
    return 'Existing patient: $name';
  }

  @override
  String get language => 'Language';

  @override
  String get systemDefault => 'System Default';

  @override
  String get regionUS => 'US';

  @override
  String get regionEurope => 'Europe';

  @override
  String get regionUK => 'UK';

  @override
  String get medGemmaIncompatibleDevice =>
      'This model requires more memory than your device has available. Use the Lite model instead.';

  @override
  String get deepScanDownloadTitle => 'Download Vision Model';

  @override
  String deepScanDownloadMessage(int size) {
    return 'Deep Scan requires an additional download (~$size MB). Download now?';
  }

  @override
  String get shareUnknownDevice => 'Unknown Device';

  @override
  String get shareViewOnlyBanner =>
      'VIEW ONLY - Data will be deleted when you close the session or leave proximity area';

  @override
  String get shareViewOnlyBannerViewing =>
      'VIEW ONLY - Data will be deleted when you exit';

  @override
  String get shareInfoBannerMessage =>
      'Shared records are view-only. All data is automatically deleted when the session ends or the time limit expires.';

  @override
  String get shareTitle => 'Share';

  @override
  String get shareFindDevices => 'Find Devices';

  @override
  String get shareWaiting => 'Waiting...';

  @override
  String get shareConnectingTitle => 'Connecting';

  @override
  String get shareSending => 'Sending';

  @override
  String get shareReceiving => 'Receiving';

  @override
  String get shareSessionActive => 'Session Active';

  @override
  String get shareViewingRecords => 'Viewing Records';

  @override
  String get shareComplete => 'Complete';

  @override
  String get shareError => 'Error';

  @override
  String get sharePermissionsRequired => 'Permissions Required';

  @override
  String get shareHealthWalletDevice => 'HealthWallet Device';

  @override
  String get shareInvitationDeclined => 'Invitation Declined';

  @override
  String get shareSessionComplete => 'Session Complete';

  @override
  String get shareInvitationDeclinedMessage =>
      'The receiver declined your invitation to view the records.';

  @override
  String get shareSessionCompleteMessage =>
      'All shared data has been securely removed from this device';

  @override
  String get shareBackHome => 'Back Home';

  @override
  String get shareConnectionFailed => 'Connection Failed';

  @override
  String get shareUnableToConnect => 'Unable to connect. Please try again.';

  @override
  String get shareNoDataReceived => 'No data received';

  @override
  String get shareSearchRecords => 'Search records';

  @override
  String get shareNoRecordsMatchFilters => 'No records match the filters';

  @override
  String get shareNoRecordsAvailable => 'No records available';

  @override
  String get shareReceiverViewingRecords => 'Receiver is viewing records';

  @override
  String get shareSessionAutoExpire =>
      'Session will auto-expire when timer reaches zero';

  @override
  String get shareRecordsDelivered => 'Records delivered successfully';

  @override
  String get shareConnecting => 'Connecting...';

  @override
  String get shareConnectionInterrupted =>
      'Connection interrupted, reconnecting';

  @override
  String get shareSendingRecords => 'Sending records...';

  @override
  String get shareReceivingRecords => 'Receiving records...';

  @override
  String get shareConfirmExit => 'Confirm Exit';

  @override
  String get shareDeleteSharedRecords => 'Delete Shared Records?';

  @override
  String get shareDeleteWarning =>
      'The shared record will be permanently deleted from this device. Action cannot be undone';

  @override
  String get shareDeleteAndExit => 'Delete & Exit';

  @override
  String get shareIncomingTransfer => 'Incoming Transfer';

  @override
  String get shareViewOnlyWarning =>
      'Records will be view-only and automatically deleted when you exit';

  @override
  String get shareDecline => 'Decline';

  @override
  String get shareAccept => 'Accept';

  @override
  String get shareSearchingForDevices => 'Searching for nearby devices...';

  @override
  String get shareSearchForDevices => 'Search for devices...';

  @override
  String get shareNoDevicesFound => 'No Devices Found';

  @override
  String get shareConnectionIssue => 'Connection Issue';

  @override
  String get shareWifiDirectUnresponsive =>
      'WiFi Direct is unresponsive on this device.';

  @override
  String get shareWifiToggleHint =>
      'WiFi Direct unresponsive. Toggle WiFi off/on, then tap Retry.';

  @override
  String get shareDiscoveryHint =>
      'Make sure the other device has the HealthWallet.me app opened';

  @override
  String get shareProximityHint =>
      'The receiving device must have Share Proximity ON in Preferences to be discoverable.';

  @override
  String get shareNoRecordsMatchSelectedFilters =>
      'No records match the selected filters';

  @override
  String get shareNoRecordsForAppliedFilters =>
      'No records found for the applied filters';

  @override
  String get shareTryClearingFilters => 'Try clearing some filters';

  @override
  String get shareRecordsPageFiltersNoResults =>
      'The Records page filters returned no results';

  @override
  String get shareImportOrSyncRecords => 'Import or sync records to share them';

  @override
  String get shareSessionTime => 'Session time';

  @override
  String get shareSetAsDefault => 'Set as default';

  @override
  String get shareRecordsButton => 'Share Records';

  @override
  String get shareSelectRecordsToShare => 'Select records to share';

  @override
  String get shareEndSession => 'End Session';

  @override
  String get shareRequestTenMin => 'Request +10 min';

  @override
  String get shareWaitingForResponse => 'Waiting for response...';

  @override
  String get shareAddMoreTime => 'Add more time';

  @override
  String get shareSessionExpiresIn => 'Session expires in';

  @override
  String get shareExtensionRequestedTitle => 'Extension Requested';

  @override
  String get shareHoursLabel => 'hours';

  @override
  String get shareMinLabel => 'min';

  @override
  String shareSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String shareRecordCount(int recordCount) {
    return '$recordCount record(s)';
  }

  @override
  String shareSharedFrom(String source) {
    return 'shared from $source';
  }

  @override
  String shareFoundDevices(int count) {
    return 'Found $count device(s)';
  }

  @override
  String shareRetryingCount(int retryCount) {
    return 'Retrying ($retryCount/3)...';
  }

  @override
  String shareDeviceWantsToShare(String deviceName) {
    return '$deviceName wants to share records with you';
  }

  @override
  String shareExtensionsUsed(int used, int max) {
    return '$used/$max extensions used';
  }

  @override
  String shareDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h $minutes min';
  }

  @override
  String shareDurationHours(int hours) {
    return '${hours}h';
  }

  @override
  String shareDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String shareTimerHoursMinutesSeconds(int hours, int minutes, int seconds) {
    return '${hours}h ${minutes}min ${seconds}s';
  }

  @override
  String shareTimerMinutesSeconds(int minutes, int seconds) {
    return '${minutes}min ${seconds}s';
  }

  @override
  String shareTimerSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String shareMinuteCount(int minutes) {
    return '$minutes minute(s)';
  }

  @override
  String shareSecondsCount(int seconds) {
    return '$seconds seconds';
  }

  @override
  String shareExtensionRequestMessage(String peerRole, String duration) {
    return 'The $peerRole wants to extend the session by $duration';
  }

  @override
  String get desktopSyncNotYet => 'Not yet';

  @override
  String get desktopSyncTransfer => 'Transfer';

  @override
  String desktopSyncTransferValue(int sentRows, int receivedRows) {
    return '$sentRows sent, $receivedRows received';
  }

  @override
  String get desktopSyncPending => 'Pending';

  @override
  String desktopSyncPendingValue(int count) {
    return '$count changes';
  }

  @override
  String desktopSyncingTable(String tableName) {
    return 'Syncing $tableName...';
  }

  @override
  String get desktopSyncing => 'Syncing...';

  @override
  String get desktopSyncNow => 'Sync Now';

  @override
  String get desktopSyncError => 'Error';

  @override
  String get desktopSyncInSync => 'In Sync';

  @override
  String get desktopSyncReady => 'Ready';

  @override
  String get desktopSyncOffline => 'Offline';

  @override
  String get desktopTableHealthRecords => 'Health Records';

  @override
  String get desktopTableSources => 'Sources';

  @override
  String get desktopTableNotes => 'Notes';

  @override
  String get desktopTableSessions => 'Sessions';

  @override
  String get desktopConnection => 'Connection';

  @override
  String get desktopGeneratePairingQr => 'Generate Pairing QR';

  @override
  String get desktopScanFromMobile => 'Scan from mobile Sync page';

  @override
  String get desktopDevice => 'Device';

  @override
  String get desktopTransport => 'Transport';

  @override
  String get desktopIp => 'IP';

  @override
  String get desktopPort => 'Port';

  @override
  String get desktopNewPairing => 'New Pairing';

  @override
  String get desktopTransportTcp => 'TCP over WiFi';

  @override
  String get desktopTransportMpc => 'MultipeerConnectivity (Direct)';

  @override
  String desktopConnectedTo(String name) {
    return 'Connected to $name';
  }

  @override
  String get desktopConnected => 'Connected';

  @override
  String desktopReconnectingTo(String name) {
    return 'Reconnecting to $name...';
  }

  @override
  String get desktopReconnecting => 'Reconnecting...';

  @override
  String desktopDisconnectedFrom(String name) {
    return 'Disconnected from $name';
  }

  @override
  String get desktopDisconnected => 'Disconnected';

  @override
  String get desktopDisconnect => 'Disconnect';

  @override
  String get desktopReconnect => 'Reconnect';

  @override
  String get desktopVpnDetected =>
      'VPN detected. Disconnect VPN to sync with desktop.';

  @override
  String get desktopPairing => 'Pairing';

  @override
  String get desktopLabel => 'Desktop';

  @override
  String get desktopScanFromPhoneToPair => 'Scan from your phone to pair';

  @override
  String get desktopNewQrCode => 'New QR Code';

  @override
  String get desktopGenerateQrCode => 'Generate QR Code';

  @override
  String get desktopScanQrCode => 'Scan QR Code';

  @override
  String get desktopChooseWhereToSave => 'Choose where to save backups';

  @override
  String get desktopSelectBackupFolder =>
      'Select a folder on your computer to store backup files';

  @override
  String get desktopChooseLocation => 'Choose Location';

  @override
  String get desktopChooseBackupLocation => 'Choose Backup Location';

  @override
  String get desktopBackingUp => 'Backing up...';

  @override
  String get desktopCreateBackup => 'Create Backup';

  @override
  String get desktopSyncWithPhoneFirst => 'Sync with phone first';

  @override
  String get desktopNotConnected => '(not connected)';

  @override
  String get desktopStartBackup => 'Start Backup';

  @override
  String get desktopNoBackupsYet => 'No backups yet';

  @override
  String get desktopCreateFirstBackup =>
      'Create your first backup to keep your health data safe';

  @override
  String get desktopAllBackups => 'All backups';

  @override
  String get desktopDate => 'Date';

  @override
  String get desktopSize => 'Size';

  @override
  String get desktopChecksum => 'Checksum';

  @override
  String get desktopRestoreThisBackup => 'Restore this backup';

  @override
  String get desktopRestoreBackupTitle => 'Restore Backup?';

  @override
  String desktopRestoreBackupMessage(String name, int count) {
    return 'This will replace all current data on this device with \"$name\".\n\n$count records will be restored.\n\nYour data on the paired phone will not be affected.';
  }

  @override
  String get desktopRestore => 'Restore';

  @override
  String get desktopDeleteBackupTitle => 'Delete Backup?';

  @override
  String desktopDeleteBackupMessage(String name) {
    return 'Delete \"$name\"?\n\nThis cannot be undone.';
  }

  @override
  String get desktopDelete => 'Delete';

  @override
  String get desktopBackupFrom => 'Backup from';

  @override
  String get desktopBackup => 'Backup';

  @override
  String get desktopChange => 'Change';

  @override
  String get desktopProcessingHistory => 'Processing History';

  @override
  String get desktopScannedOnPhone => 'Scanned on Phone';

  @override
  String get desktopProcessedOnDesktop => 'Processed on Desktop';

  @override
  String get desktopImportedOnDesktop => 'Imported on Desktop';

  @override
  String get desktopSyncRecent => 'Recent';

  @override
  String get desktopUnknownDevice => 'Unknown device';

  @override
  String desktopSyncHistoryTransfer(int sentRows, int receivedRows) {
    return '$sentRows sent · $receivedRows received';
  }

  @override
  String get desktopNewDeviceConnecting => 'New Device Connecting';

  @override
  String desktopNewDeviceMessage(String address, String currentDevice) {
    return 'A new device ($address) wants to connect.\n\nThis will disconnect \"$currentDevice\".\n\nSwitch to the new device?';
  }

  @override
  String get desktopKeepCurrent => 'Keep Current';

  @override
  String get desktopSwitch => 'Switch';

  @override
  String get desktopCurrentDevice => 'current device';

  @override
  String get desktopHandoverPreparing => 'Preparing...';

  @override
  String get desktopHandoverSendingFiles => 'Sending files...';

  @override
  String get desktopHandoverProcessingOnDesktop => 'Processing on desktop...';

  @override
  String get desktopHandoverComplete => 'Complete!';

  @override
  String get desktopHandoverError => 'Error occurred';

  @override
  String get desktopHandoverSending => 'Sending...';

  @override
  String get desktopHandoverSendingToDesktop => 'Sending to Desktop';

  @override
  String desktopHandoverFileCount(int count) {
    return '$count files';
  }

  @override
  String get desktopHandoverSuccess => 'Handed over to Desktop';

  @override
  String get desktopClose => 'Close';

  @override
  String get desktopContinueImporting => 'Continue Importing';

  @override
  String get desktopHandoverToDesktop => 'Handover to Desktop';

  @override
  String get desktopHandoverProcessingMessage =>
      'Processing is in progress. Handover will cancel the current processing and send files to desktop.';

  @override
  String get desktopHandover => 'Handover';

  @override
  String get attachedDocuments => 'Attached Documents';

  @override
  String get cameraPermissionRequired => 'Camera Permission Required';

  @override
  String get cameraPermissionRequiredMessage =>
      'This app needs camera access to scan. Please grant permission to continue.';

  @override
  String get cameraPermissionDenied => 'Camera Permission Denied';

  @override
  String get cameraPermissionDeniedMessage =>
      'Camera permission has been permanently denied. Please enable it in Settings to use the scanner.';

  @override
  String get successTitle => 'Success!';

  @override
  String attachmentSuccessMessage(int count) {
    return 'Successfully attached $count documents to the encounter.';
  }

  @override
  String get encounterLabel => 'Encounter';

  @override
  String get viewRecords => 'View Records';

  @override
  String get errorTitle => 'Error';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get importDocument => 'Import Document';

  @override
  String get pickImageFromGallery => 'Pick Image from Gallery';

  @override
  String get scanDocument => 'Scan Document';

  @override
  String get deleteSession => 'Delete Session';

  @override
  String get deleteSessionConfirmation =>
      'Are you sure you want to delete this session?';

  @override
  String get delete => 'Delete';

  @override
  String get canceling => 'Canceling...';

  @override
  String get waitingForAiToFinish => 'Waiting for AI to finish...';

  @override
  String get logsCopied => 'Logs copied';

  @override
  String get download => 'Download';

  @override
  String get active => 'Active';

  @override
  String get tapToSelect => 'Tap to select';

  @override
  String deviceInfoChip(
    String platform,
    String ramGB,
    int cores,
    int estimatedMB,
  ) {
    return '$platform  •  ${ramGB}GB RAM  •  $cores cores  •  ~${estimatedMB}MB needed';
  }

  @override
  String get downloadContinuesInBackground =>
      'You can navigate away - download will continue in background.\nCheck notifications for progress.';

  @override
  String get continueWithoutAi =>
      'Continue without AI (download in background)';

  @override
  String get continueUsingApp => 'Continue using app';

  @override
  String get attachWithoutProcessing =>
      'I want to attach the document without processing';

  @override
  String get currentPatientAndSource => 'Current Patient & Source';

  @override
  String get createEncounter => 'Create Encounter';

  @override
  String get encounterName => 'Encounter name';

  @override
  String get enterEncounterName => 'Enter encounter name';

  @override
  String get pleaseEnterEncounterName => 'Please enter an encounter name';

  @override
  String get date => 'Date';

  @override
  String get create => 'Create';

  @override
  String get searchEncounters => 'Search encounters...';

  @override
  String get noEncountersFound => 'No encounters found';

  @override
  String get noEncountersFoundMessage =>
      'Create a new encounter first or select a different patient.';

  @override
  String get newEncounterPrefix => 'New encounter';

  @override
  String get scannedDocumentsTitle => 'Scanned Documents';

  @override
  String scannedDocumentsPagesTitle(String count) {
    return 'Scanned Documents ($count pages)';
  }

  @override
  String pdfFileTitle(String fileName) {
    return 'PDF: $fileName';
  }

  @override
  String get labelOrganizationName => 'Organization Name';

  @override
  String get labelAddress => 'Address';

  @override
  String get labelPhone => 'Phone';

  @override
  String get labelEncounterName => 'Encounter Name';

  @override
  String get labelStartDate => 'Start Date';

  @override
  String get labelFirstName => 'First name';

  @override
  String get labelFamilyName => 'Family name';

  @override
  String get labelDateOfBirth => 'Date of birth';

  @override
  String get labelGender => 'Gender';

  @override
  String get labelReportName => 'Report Name';

  @override
  String get labelConclusion => 'Conclusion';

  @override
  String get labelIssuedDate => 'Issued Date';

  @override
  String get labelPractitionerName => 'Practitioner Name';

  @override
  String get labelSpecialty => 'Specialty';

  @override
  String get labelIdentifier => 'Identifier';

  @override
  String get labelConditionName => 'Condition Name';

  @override
  String get labelOnsetDate => 'Onset Date';

  @override
  String get labelClinicalStatus => 'Clinical Status';

  @override
  String get labelSubstance => 'Substance';

  @override
  String get labelManifestation => 'Manifestation';

  @override
  String get labelCategory => 'Category';

  @override
  String get labelProcedureName => 'Procedure Name';

  @override
  String get labelPerformedDate => 'Performed Date';

  @override
  String get labelReason => 'Reason';

  @override
  String get labelMedicationName => 'Medication Name';

  @override
  String get labelDosage => 'Dosage';

  @override
  String get labelObservationName => 'Observation name';

  @override
  String get labelValue => 'Value';

  @override
  String get labelUnit => 'Unit';

  @override
  String get labelReferenceRange => 'Reference Range';

  @override
  String get permissionsRequired => 'Permissions Required';

  @override
  String recordsSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get noRecordsSelected => 'No records selected';

  @override
  String get select => 'Select';

  @override
  String get selectRecordsBeforeSharing => 'Select records\nbefore sharing';

  @override
  String get selectRecordToViewDetails => 'Select a record to view details';

  @override
  String get recordDetails => 'Record Details';

  @override
  String get viewDocument => 'View Document';

  @override
  String get encounterDetails => 'Encounter details';

  @override
  String get relatedResources => 'Related resources';

  @override
  String deletePlusRelated(int count) {
    return 'Delete + $count related';
  }

  @override
  String get fileNotAvailable => 'File not available on this device';

  @override
  String couldNotOpenFile(String message) {
    return 'Could not open file: $message';
  }

  @override
  String errorOpeningFile(String error) {
    return 'Error opening file: $error';
  }

  @override
  String get failedToLoadImage => 'Failed to load image';

  @override
  String errorLoadingPdf(String error) {
    return 'Error loading PDF: $error';
  }

  @override
  String errorOnPage(String page, String error) {
    return 'Error on page $page: $error';
  }

  @override
  String get notes => 'Notes';

  @override
  String get noNotesAttached => 'This record has no notes attached';

  @override
  String get addNote => 'Add note';

  @override
  String get editNote => 'Edit note';

  @override
  String get filters => 'Filters';

  @override
  String get timeRange => 'Time Range';

  @override
  String get applyFilters => 'Apply filters';

  @override
  String get recordType => 'Record type';

  @override
  String get specialty => 'Specialty';

  @override
  String get allSpecialties => 'All Specialties';

  @override
  String get selectedRange => 'Selected Range';

  @override
  String get noRangeSelected => 'No range selected';

  @override
  String get clearDateRange => 'Clear date range';

  @override
  String get start => 'Start';

  @override
  String get end => 'End';

  @override
  String fromDate(String date) {
    return 'From $date';
  }

  @override
  String untilDate(String date) {
    return 'Until $date';
  }

  @override
  String get day => 'Day';

  @override
  String get month => 'Month';

  @override
  String get year => 'Year';

  @override
  String get mediaInfo => 'Media Info';

  @override
  String get linkToEncounter => 'Link to Encounter';

  @override
  String get noPdfDataAvailable => 'No PDF data available';

  @override
  String get failedToLoadPdf => 'Failed to load PDF document';

  @override
  String get mediaInformation => 'Media Information';

  @override
  String get mediaInfoTitle => 'Title:';

  @override
  String get mediaInfoType => 'Type:';

  @override
  String get mediaInfoStatus => 'Status:';

  @override
  String get mediaInfoPatient => 'Patient:';

  @override
  String get mediaInfoEncounter => 'Encounter:';

  @override
  String get mediaInfoFileSize => 'File Size:';

  @override
  String get mediaInfoCreated => 'Created:';

  @override
  String get mediaInfoResourceId => 'Resource ID:';

  @override
  String get mediaInfoSource => 'Source:';

  @override
  String get close => 'Close';

  @override
  String get linkMediaToEncounterDescription =>
      'Link this media resource to an encounter:';

  @override
  String get encounterId => 'Encounter ID';

  @override
  String get encounterIdHint => 'e.g., encounter-123';

  @override
  String get mediaLinkedSuccess => 'Media linked to encounter successfully';

  @override
  String failedToLinkMedia(String error) {
    return 'Failed to link media: $error';
  }

  @override
  String get link => 'Link';

  @override
  String get connectionLabel => 'Connection';

  @override
  String get connectionStatusConnected => 'Connected';

  @override
  String get connectionStatusConnecting => 'Connecting...';

  @override
  String get connectionStatusDisconnected => 'Disconnected';

  @override
  String get connectionStatusNotPaired => 'Not paired';

  @override
  String get syncLabel => 'Sync';

  @override
  String get syncStatusSyncing => 'Syncing...';

  @override
  String get syncStatusNotSynced => 'Not synced';

  @override
  String get syncStatusInSync => 'In sync';

  @override
  String syncStatusPending(int count) {
    return '$count pending';
  }

  @override
  String get backupLabel => 'Backup';

  @override
  String get backupStatusWorking => 'Working...';

  @override
  String get backupStatusNoBackup => 'No backup';

  @override
  String get backupStatusBackingUp => 'Backing up...';

  @override
  String get backupStatusRestoring => 'Restoring...';

  @override
  String get backupStatusWaiting => 'Waiting...';

  @override
  String get backupStatusNotConnected => 'Not connected';

  @override
  String get exportIpsPdf => 'Export IPS (PDF)';

  @override
  String get addIpsToAppleWallet => 'Add IPS to Apple Wallet';

  @override
  String get addIpsToGoogleWallet => 'Add IPS to Google Wallet';

  @override
  String get sourcesTitle => 'Sources';

  @override
  String get emergencyMedicalId => 'Emergency Medical ID';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get allergiesLabel => 'Allergies';

  @override
  String get medicalConditionsLabel => 'Medical Conditions';

  @override
  String get medicationsLabel => 'Medications';

  @override
  String get conditionsLabel => 'Conditions';

  @override
  String get dateOfBirthLabel => 'Date of Birth';

  @override
  String get emergencyPhoneLabel => 'Emergency Phone';

  @override
  String get openingScanner => 'Opening scanner...';

  @override
  String get activeScanSessions => 'Active scan sessions:';

  @override
  String get noScansYet => 'No scans yet';

  @override
  String get scanOrImportToGetStarted =>
      'Scan or import documents to get started';

  @override
  String pageOfTotal(String current, String total) {
    return '$current of $total';
  }

  @override
  String get fileNotFound => 'File not found';

  @override
  String get fileIsEmpty => 'File is empty';

  @override
  String get importTitle => 'Import';

  @override
  String get activeImportSessions => 'Active import sessions:';

  @override
  String get dropToImport => 'Drop to import';

  @override
  String get dropFilesHereToImport => 'Drop files here to import';

  @override
  String get supportedFileFormats => 'PDF, JPG, PNG, TIFF';

  @override
  String get browseFiles => 'Browse Files';

  @override
  String get noImportsYet => 'No imports yet';

  @override
  String get importOrScanToGetStarted =>
      'Import or scan documents to get started';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get cancelDownloadTitle => 'Cancel Download';

  @override
  String get cancelDownloadMessage =>
      'Are you sure you want to cancel the AI Model download? You can restart it later.';

  @override
  String get processingDone => 'Processing done';

  @override
  String pairedWithDevice(String deviceName) {
    return 'Paired with $deviceName';
  }

  @override
  String get deviceSyncLabel => 'Device Sync';

  @override
  String get disconnectLabel => 'Disconnect';

  @override
  String get changeLabel => 'Change';

  @override
  String get minimizeToTray => 'Minimize to tray';

  @override
  String get changeSpecialty => 'Change Specialty';

  @override
  String get changeSpecialtyConfirm =>
      'Are you sure you want to change the specialty to';

  @override
  String get removeSpecialtyConfirm =>
      'Are you sure you want to remove the specialty from this record?';

  @override
  String get confirm => 'Confirm';

  @override
  String get currentRecord => 'Current record';

  @override
  String get vitalHeartRate => 'Heart Rate';

  @override
  String get vitalBloodPressure => 'Blood Pressure';

  @override
  String get vitalTemperature => 'Temperature';

  @override
  String get vitalBloodOxygen => 'Blood Oxygen';

  @override
  String get vitalRespiratoryRate => 'Respiratory Rate';

  @override
  String get vitalWeight => 'Weight';

  @override
  String get vitalHeight => 'Height';

  @override
  String get vitalBmi => 'BMI';

  @override
  String get vitalBloodGlucose => 'Blood Glucose';

  @override
  String get vitalSystolicBloodPressure => 'Systolic Blood Pressure';

  @override
  String get vitalDiastolicBloodPressure => 'Diastolic Blood Pressure';

  @override
  String get unitBeatsPerMinute => 'beats/min';

  @override
  String get unitBreathsPerMinute => 'breaths/min';

  @override
  String get unitPounds => 'pounds';

  @override
  String get unitInches => 'inches';

  @override
  String get unitKilograms => 'kilograms';

  @override
  String get unitCentimeters => 'centimeters';

  @override
  String get specialtyAllergology => 'Allergology';

  @override
  String get specialtyCardiology => 'Cardiology';

  @override
  String get specialtyDental => 'Dental';

  @override
  String get specialtyDermatology => 'Dermatology';

  @override
  String get specialtyEmergencyMedicine => 'Emergency Medicine';

  @override
  String get specialtyEndocrinology => 'Endocrinology';

  @override
  String get specialtyGastroenterology => 'Gastroenterology';

  @override
  String get specialtyGeneralCare => 'General Care';

  @override
  String get specialtyGynecology => 'Gynecology';

  @override
  String get specialtyNephrology => 'Nephrology';

  @override
  String get specialtyNeurology => 'Neurology';

  @override
  String get specialtyOncology => 'Oncology';

  @override
  String get specialtyOphthalmology => 'Ophthalmology';

  @override
  String get specialtyOrthopedics => 'Orthopedics';

  @override
  String get specialtyPsychiatry => 'Psychiatry';

  @override
  String get specialtyPulmonology => 'Pulmonology';

  @override
  String get specialtyRheumatology => 'Rheumatology';

  @override
  String get specialtyUrology => 'Urology';

  @override
  String get categoryAllergies => 'Allergies';

  @override
  String get categoryCareTeam => 'Care Team';

  @override
  String get categoryClinicalNotes => 'Clinical Notes';

  @override
  String get categoryFiles => 'Files';

  @override
  String get categoryLabResults => 'Lab Results';

  @override
  String get categoryHealthIssues => 'Health Issues';

  @override
  String get categoryFacilities => 'Facilities';

  @override
  String get categoryHealthGoals => 'Health Goals';

  @override
  String get categoryImmunizations => 'Immunizations';

  @override
  String get categoryMedications => 'Medications';

  @override
  String get categoryDemographics => 'Demographics';

  @override
  String get categoryProcedures => 'Procedures';

  @override
  String get categoryHealthInsurance => 'Health Insurance';

  @override
  String get fhirTypeAdverseEvent => 'Adverse Event';

  @override
  String get fhirTypeAllergyIntolerance => 'Allergy';

  @override
  String get fhirTypeBinary => 'Binary';

  @override
  String get fhirTypeCareTeam => 'Care Team';

  @override
  String get fhirTypeClaim => 'Claim';

  @override
  String get fhirTypeCondition => 'Condition';

  @override
  String get fhirTypeCoverage => 'Coverage';

  @override
  String get fhirTypeDiagnosticReport => 'Diagnostic Report';

  @override
  String get fhirTypeDocumentReference => 'Document';

  @override
  String get fhirTypeEncounter => 'Encounter';

  @override
  String get fhirTypeExplanationOfBenefit => 'Explanation of Benefit';

  @override
  String get fhirTypeGoal => 'Goal';

  @override
  String get fhirTypeImmunization => 'Immunization';

  @override
  String get fhirTypeLocation => 'Location';

  @override
  String get fhirTypeMedia => 'Media';

  @override
  String get fhirTypeMedication => 'Medication';

  @override
  String get fhirTypeMedicationAdministration => 'Medication Administration';

  @override
  String get fhirTypeMedicationDispense => 'Medication Dispense';

  @override
  String get fhirTypeMedicationRequest => 'Medication Request';

  @override
  String get fhirTypeMedicationStatement => 'Medication Statement';

  @override
  String get fhirTypeObservation => 'Observation';

  @override
  String get fhirTypeOrganization => 'Organization';

  @override
  String get fhirTypePatient => 'Patient';

  @override
  String get fhirTypePractitioner => 'Practitioner';

  @override
  String get fhirTypePractitionerRole => 'Practitioner Role';

  @override
  String get fhirTypeProcedure => 'Procedure';

  @override
  String get fhirTypeRelatedPerson => 'Related Person';

  @override
  String get fhirTypeServiceRequest => 'Service Request';

  @override
  String get fhirTypeSpecimen => 'Specimen';

  @override
  String get fhirTypeGeneralResource => 'Resource';

  @override
  String get processingOriginScan => 'Scan';

  @override
  String get processingOriginImport => 'Import';

  @override
  String get processingOriginHandover => 'Handover';

  @override
  String get processingStatusPending => 'Pending';

  @override
  String get processingStatusProcessingPatient => 'Processing Patient';

  @override
  String get processingStatusPatientExtracted => 'Patient Extracted';

  @override
  String get processingStatusProcessing => 'Processing';

  @override
  String get processingStatusDraft => 'Draft';

  @override
  String get processingStatusCancelled => 'Cancelled';

  @override
  String get showAll => 'Show All';

  @override
  String get showLess => 'Show Less';

  @override
  String get all => 'All';

  @override
  String get gotIt => 'Got it';

  @override
  String get homeSpecialties => 'Specialties';

  @override
  String get homeResources => 'Resources';

  @override
  String get homeDefaultUserName => 'User';

  @override
  String get selectSpecialty => 'Select Specialty';

  @override
  String get removeSpecialty => 'Remove Specialty';

  @override
  String get chooseRecordsForDashboard =>
      'Choose the records you want to see on your dashboard.';

  @override
  String get selectAtLeastOneRecordType =>
      'Select at least one record type to continue.';

  @override
  String get chooseVitalsForDashboard =>
      'Choose the vitals you want to see on your dashboard.';

  @override
  String get selectAtLeastOneVital =>
      'Select at least one vital sign to continue.';

  @override
  String get chooseSpecialtiesForDashboard =>
      'Choose the specialities you want to see on your dashboard.';

  @override
  String get selectAtLeastOneSpecialty =>
      'Select at least one specialty to continue.';

  @override
  String get selectAtLeastOneItem => 'Select at least one item to continue.';

  @override
  String get sourceSectionWallet => 'WALLET';

  @override
  String get sourceSectionEhr => 'EHR SOURCES';

  @override
  String get areYouSure => 'Are you sure?';

  @override
  String get resourceNotViewable => 'This resource is not a viewable file';

  @override
  String get noFilePathFound => 'No file path found';

  @override
  String get handoverPatientMatched => 'Handover patient matched';

  @override
  String get desktopDiscovering => 'Discovering...';

  @override
  String get desktopTransportWifi => 'WiFi';

  @override
  String get desktopTransportDirect => 'Direct';

  @override
  String get desktopDeviceSync => 'Device Sync';

  @override
  String get desktopBackupLocation => 'Location';

  @override
  String get desktopBackupHistory => 'History';

  @override
  String desktopPairedWith(String name) {
    return 'Paired with $name';
  }

  @override
  String get desktopMobileDevice => 'Mobile Device';

  @override
  String get desktopNotFoundScanAgain =>
      'Desktop not found. Try scanning QR again.';

  @override
  String get desktopPairingExpired =>
      'Could not connect. Scan QR code to pair again.';

  @override
  String desktopRemoteBackupName(String date) {
    return 'Remote $date';
  }

  @override
  String get desktopNoBackupLocation =>
      'No backup location set on desktop. Open the desktop app and choose a backup folder first.';

  @override
  String get desktopBackupFailed => 'Backup failed. Please try again.';

  @override
  String get desktopRestoreFailed => 'Restore failed. Please try again.';

  @override
  String get desktopBackupActionFailed =>
      'Could not update the backups. Please try again.';

  @override
  String get desktopSyncFailed =>
      'Sync failed. Check the connection and try again.';

  @override
  String get desktopHandoverTransfer => 'Transfer';

  @override
  String get desktopHandoverNoActive => 'No active handovers';

  @override
  String get desktopHandoverSendFromPhone => 'Send documents from your phone.';

  @override
  String desktopHandoverFilesProgress(String received, String total) {
    return '$received/$total files';
  }

  @override
  String get desktopHandoverTransferComplete => 'Transfer complete';

  @override
  String get desktopHandoverReceivingFiles => 'Receiving files...';

  @override
  String get desktopHandoverProcessingStatus => 'Processing...';

  @override
  String get desktopHandoverSendingResults => 'Sending results...';

  @override
  String get desktopHandoverDone => 'Complete';

  @override
  String get desktopHandoverStatusError => 'Error';

  @override
  String get desktopHandoverWaitingForResults => 'Waiting for results...';

  @override
  String get desktopHandoverNotAccepted =>
      'The desktop did not accept the documents.';

  @override
  String get desktopHandoverFileMissing =>
      'A document could not be found on this device.';

  @override
  String get desktopHandoverCancelled => 'Cancelled';

  @override
  String get desktopHandoverFailed => 'Processing failed. Please try again.';

  @override
  String get trayShowWindow => 'Show Window';

  @override
  String get trayHideWindow => 'Hide Window';

  @override
  String get trayNoDeviceConnected => 'No device connected';

  @override
  String traySyncStatus(String status) {
    return 'Sync: $status';
  }

  @override
  String get trayUpToDate => 'Up to date';

  @override
  String trayQuit(String appName) {
    return 'Quit $appName';
  }

  @override
  String get desktopFinishedProcessing => 'Desktop finished processing';

  @override
  String get biometricAuthReason =>
      'Please authenticate to access your HealthWallet.me';

  @override
  String sourceUploadedOn(String date) {
    return 'Uploaded $date';
  }

  @override
  String couldNotOpenPdf(String message) {
    return 'Could not open PDF: $message';
  }

  @override
  String errorOpeningPdf(String error) {
    return 'Error opening PDF: $error';
  }

  @override
  String get shareStatusReadyToShare => 'Ready to share';

  @override
  String get shareStatusWaitingForSender => 'Waiting for sender...';

  @override
  String get shareStatusPermissionsRequired => 'Permissions required';

  @override
  String get shareStatusEnablePermissionsInSettings =>
      'Please enable permissions in Settings';

  @override
  String get shareSelectAtLeastOneRecord => 'Please select at least one record';

  @override
  String get shareStatusLookingForDevices => 'Looking for nearby devices...';

  @override
  String get shareStatusTransferFailed => 'Transfer failed';

  @override
  String get shareStatusConfirmExit =>
      'Are you sure you want to exit? Data will be deleted.';

  @override
  String shareStatusViewingRecords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Viewing $count records',
      one: 'Viewing 1 record',
    );
    return '$_temp0';
  }

  @override
  String shareStatusViewingRecordsFrom(int count, String deviceName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Viewing $count records from $deviceName',
      one: 'Viewing 1 record from $deviceName',
    );
    return '$_temp0';
  }

  @override
  String get shareStatusDataDeleted => 'Data has been securely deleted';

  @override
  String get shareStatusSessionExpired => 'Session expired';

  @override
  String get shareStatusTerminatingSession => 'Terminating remote session...';

  @override
  String get shareStatusSessionTerminated => 'Session terminated';

  @override
  String get shareStatusRemoteSessionTerminated => 'Remote session terminated';

  @override
  String get shareStatusExtensionDeclined => 'Extension request was declined';

  @override
  String get shareStatusReceiverViewing =>
      'Receiver is viewing records - monitoring session';

  @override
  String get shareStatusReceiverDeclined => 'Receiver declined invitation';

  @override
  String shareStatusReceivingFrom(String deviceName) {
    return 'Receiving records from $deviceName...';
  }

  @override
  String get shareNoDataAvailable => 'No data available';

  @override
  String shareStatusDeviceWantsToShare(String deviceName) {
    return '$deviceName wants to share records';
  }

  @override
  String get shareStatusScanning => 'Scanning for devices...';

  @override
  String shareStatusFoundDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found $count devices',
      one: 'Found 1 device',
    );
    return '$_temp0';
  }

  @override
  String shareStatusConnectingTo(String deviceName) {
    return 'Connecting to $deviceName...';
  }

  @override
  String get shareStatusPreparingRecords => 'Preparing records...';

  @override
  String get shareErrorPrepareFiles => 'Failed to prepare files for sending';

  @override
  String shareStatusTransferring(int percent) {
    return 'Transferring $percent%';
  }

  @override
  String get shareStatusRecordsSentWaiting =>
      'Records sent - waiting for receiver to accept';

  @override
  String get shareStatusTransferCancelled => 'Transfer cancelled';

  @override
  String get shareStatusInvitationRejected => 'Invitation rejected';

  @override
  String get shareErrorParseData => 'Failed to parse received data';

  @override
  String get shareStatusProcessingReceived => 'Processing received records...';

  @override
  String get shareErrorParseFile => 'Failed to parse received file';

  @override
  String get shareIncomingHealthRecords => 'Incoming Health Records';

  @override
  String shareDeviceWantsToShareHealthRecords(String deviceName) {
    return '$deviceName wants to share health records with you';
  }

  @override
  String get sharePermissionExplanationIos =>
      'To share records with nearby devices, HealthWallet needs access to:\n\n• Bluetooth - to discover and connect to nearby devices\n\nThis allows you to securely share health records with other devices nearby.';

  @override
  String get sharePermissionExplanationAndroid =>
      'To share records with nearby devices, HealthWallet needs access to:\n\n• Bluetooth - to discover and connect to nearby devices\n• Location/Nearby Devices - required by Android to scan for Bluetooth and WiFi Direct devices\n\nYour location is never stored or transmitted.';

  @override
  String get sharePermissionsDeniedMessage =>
      'Please grant all permissions to share records with nearby devices.';

  @override
  String get sharePermissionsPermanentlyDeniedMessage =>
      'Some permissions were denied. Please enable them in Settings to use this feature.';

  @override
  String shareDurationRequested(String duration) {
    return '$duration requested';
  }

  @override
  String get noAttachments => 'No attachments';

  @override
  String get attachingFiles => 'Attaching files...';

  @override
  String get addAttachment => 'Add Attachment';

  @override
  String get noFileName => 'No file name';

  @override
  String attachmentFileOfTotal(int current, int total) {
    return '( $current of $total files )';
  }

  @override
  String get showDetails => 'Show Details';

  @override
  String get viewRelated => 'View Related';

  @override
  String get hideRelated => 'Hide Related';

  @override
  String get noRelatedResourcesFound => 'No related resources found';

  @override
  String get loadingRelatedResources => 'Loading related resources...';

  @override
  String get noRelatedResourcesForEncounter =>
      'No related resources found for this encounter';

  @override
  String get cannotAttachToDocumentReference =>
      'Cannot attach files to DocumentReference resources';

  @override
  String deleteRecordOfType(String type) {
    return 'Delete $type';
  }

  @override
  String get dateFilterEndBeforeStart => 'End date must be after start date';

  @override
  String dateFilterChip(String range) {
    return 'Date: $range';
  }

  @override
  String get aiModelCheckFailed =>
      'An error appeared while checking model existence';

  @override
  String get aiModelExistenceCheckFailed => 'Failed to check model existence';

  @override
  String aiModelDownloadingTitle(String modelName) {
    return 'Downloading $modelName';
  }

  @override
  String get aiModelDownloadStarting => 'Starting download...';

  @override
  String aiModelReadyTitle(String modelName) {
    return '$modelName Ready';
  }

  @override
  String aiModelDownloadedMessage(String modelName) {
    return '$modelName has been downloaded successfully.';
  }

  @override
  String get aiModelDownloadFailedTitle => 'Download Failed';

  @override
  String get aiModelDownloadFailedMessage =>
      'AI model download failed. Please check your connection and try again.';

  @override
  String get aiModelDownloadFailed => 'Download failed';

  @override
  String get aiModelDownloadCancelledTitle => 'Download Cancelled';

  @override
  String get aiModelDownloadInterruptedMessage =>
      'The download was interrupted. Please try again.';

  @override
  String get aiModelDownloadCancelledNotificationTitle =>
      'AI Model Download Cancelled';

  @override
  String get aiModelDownloadWasCancelled => 'AI model download was cancelled';

  @override
  String get aiModelDownloadCancelled => 'Download cancelled';

  @override
  String aiModelDownloadingPercent(String percent) {
    return 'Downloading... $percent%';
  }

  @override
  String get processingNoImagesGenerated =>
      'No images were generated from the scan. Please try scanning again.';

  @override
  String processingPatientMatched(String origin) {
    return '$origin patient matched';
  }

  @override
  String processingPatientInfoExtracted(String origin) {
    return '$origin patient info extracted';
  }

  @override
  String processingFinished(String origin) {
    return '$origin processing finished';
  }

  @override
  String scanFailedWithError(String error) {
    return 'Scan failed: $error';
  }

  @override
  String get noValidFilesFound => 'No valid files found';

  @override
  String failedToImportDocument(String error) {
    return 'Failed to import document: $error';
  }

  @override
  String get couldNotOpenLink => 'Could not open link. Please try again.';

  @override
  String get continueProcessingOnDesktop => 'Continue processing on Desktop';

  @override
  String get deleteResourcesTitle => 'Delete Resources';

  @override
  String get switchToDiagnosticReport => 'Switch to Diagnostic Report';

  @override
  String get switchToEncounter => 'Switch to Encounter';

  @override
  String get previewDocument => 'Preview document';

  @override
  String get summaryTitle => 'Summary';

  @override
  String pagesAvailableForProcessing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Total: $count pages available for processing',
      one: 'Total: $count page available for processing',
    );
    return '$_temp0';
  }

  @override
  String get betaBadge => 'Beta';

  @override
  String get pleaseSelectSpecialty => 'Please select a specialty';

  @override
  String get patientAndSourceInformation => 'Patient & Source Information';

  @override
  String get noPatientsAvailable => 'No patients available';

  @override
  String get selectPatient => 'Select patient';

  @override
  String get unknownPatient => 'Unknown Patient';

  @override
  String get documentPreview => 'Document Preview';

  @override
  String filePathLabel(String path) {
    return 'Path: $path';
  }

  @override
  String get confidenceMedium => 'Medium confidence';

  @override
  String get confidenceLow => 'Low confidence';

  @override
  String get dateFormatHintIso => 'YYYY-MM-DD';

  @override
  String retryStep(int step) {
    return 'Retry (Step $step)';
  }

  @override
  String failedToCreateEncounter(String error) {
    return 'Failed to create encounter: $error';
  }

  @override
  String failedToAttachDocuments(String error) {
    return 'Failed to attach documents: $error';
  }

  @override
  String get fieldAccessionNumber => 'Accession Number';

  @override
  String get fieldAchievementStatus => 'Achievement Status';

  @override
  String get fieldActuality => 'Actuality';

  @override
  String get fieldAdditionalInformation => 'Additional Information';

  @override
  String get fieldAddress => 'Address';

  @override
  String get fieldAddresses => 'Addresses';

  @override
  String get fieldAdministeredBy => 'Administered By';

  @override
  String get fieldAdmissionSource => 'Admission Source';

  @override
  String get fieldAlert => 'Alert';

  @override
  String get fieldAllergyDetails => 'Allergy Details';

  @override
  String get fieldAlsoKnownAs => 'Also Known As';

  @override
  String get fieldAsserter => 'Asserter';

  @override
  String get fieldAttachmentTitle => 'Attachment Title';

  @override
  String get fieldAuthenticatedBy => 'Authenticated By';

  @override
  String get fieldAuthor => 'Author';

  @override
  String get fieldAvailabilityExceptions => 'Availability Exceptions';

  @override
  String get fieldAvailabilityNotes => 'Availability Notes';

  @override
  String get fieldBasedOn => 'Based On';

  @override
  String get fieldBasicInformation => 'Basic Information';

  @override
  String get fieldBeneficiary => 'Beneficiary';

  @override
  String get fieldBillablePeriod => 'Billable Period';

  @override
  String get fieldBirthDate => 'Birth Date';

  @override
  String get fieldBirthPlace => 'Birth Place';

  @override
  String get fieldBirthSex => 'Birth Sex';

  @override
  String get fieldBodySite => 'Body Site';

  @override
  String get fieldCareTeam => 'Care Team';

  @override
  String get fieldCategory => 'Category';

  @override
  String get fieldClinicalNotes => 'Clinical Notes';

  @override
  String get fieldClinicalStatus => 'Clinical Status';

  @override
  String get fieldCollectedBy => 'Collected By';

  @override
  String get fieldCollectionDate => 'Collection Date';

  @override
  String get fieldCollectionDuration => 'Collection Duration';

  @override
  String get fieldCollectionInformation => 'Collection Information';

  @override
  String get fieldCollectionMethod => 'Collection Method';

  @override
  String get fieldCollectionPeriod => 'Collection Period';

  @override
  String get fieldComplicationDetails => 'Complication Details';

  @override
  String get fieldComplications => 'Complications';

  @override
  String get fieldConclusion => 'Conclusion';

  @override
  String get fieldConclusionCode => 'Conclusion Code';

  @override
  String get fieldCondition => 'Condition';

  @override
  String get fieldContactEmail => 'Contact Email';

  @override
  String get fieldContactInformation => 'Contact Information';

  @override
  String get fieldContactPerson => 'Contact Person';

  @override
  String get fieldContactPhone => 'Contact Phone';

  @override
  String get fieldContainerAdditive => 'Container Additive';

  @override
  String get fieldContainerCapacity => 'Container Capacity';

  @override
  String get fieldContainerType => 'Container Type';

  @override
  String get fieldContainers => 'Containers';

  @override
  String get fieldContentType => 'Content Type';

  @override
  String get fieldContext => 'Context';

  @override
  String get fieldContract => 'Contract';

  @override
  String get fieldCostSharing => 'Cost Sharing';

  @override
  String get fieldCourseOfTherapy => 'Course of Therapy';

  @override
  String get fieldCoverage => 'Coverage';

  @override
  String get fieldCoverageClass => 'Coverage Class';

  @override
  String get fieldCoverageDetails => 'Coverage Details';

  @override
  String get fieldCreated => 'Created';

  @override
  String get fieldCriticality => 'Criticality';

  @override
  String get fieldCustodian => 'Custodian';

  @override
  String get fieldDataAbsentReason => 'Data Absent Reason';

  @override
  String get fieldDateGiven => 'Date Given';

  @override
  String get fieldDatePerformed => 'Date Performed';

  @override
  String get fieldDaysSupply => 'Days Supply';

  @override
  String get fieldDependent => 'Dependent';

  @override
  String get fieldDerivedFrom => 'Derived From';

  @override
  String get fieldDescription => 'Description';

  @override
  String get fieldDetected => 'Detected';

  @override
  String get fieldDevice => 'Device';

  @override
  String get fieldDiagnoses => 'Diagnoses';

  @override
  String get fieldDietPreference => 'Diet Preference';

  @override
  String get fieldDimensions => 'Dimensions';

  @override
  String get fieldDischargeDisposition => 'Discharge Disposition';

  @override
  String get fieldDischargeTo => 'Discharge To';

  @override
  String get fieldDisposition => 'Disposition';

  @override
  String get fieldDocumentDetails => 'Document Details';

  @override
  String get fieldDocumentId => 'Document ID';

  @override
  String get fieldDocumentStatus => 'Document Status';

  @override
  String get fieldDosage => 'Dosage';

  @override
  String get fieldDose => 'Dose';

  @override
  String get fieldDoseQuantity => 'Dose Quantity';

  @override
  String get fieldDriversLicenseNumber => 'Driver\'s License Number';

  @override
  String get fieldDuration => 'Duration';

  @override
  String get fieldEducationProvided => 'Education Provided';

  @override
  String get fieldEffective => 'Effective';

  @override
  String get fieldEffectiveDates => 'Effective Dates';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldEmergency => 'Emergency';

  @override
  String get fieldEncounterType => 'Encounter Type';

  @override
  String get fieldEndpoints => 'Endpoints';

  @override
  String get fieldEpisodeOfCare => 'Episode of Care';

  @override
  String get fieldEthnicity => 'Ethnicity';

  @override
  String get fieldExpiration => 'Expiration';

  @override
  String get fieldExpirationDate => 'Expiration Date';

  @override
  String get fieldFacility => 'Facility';

  @override
  String get fieldFacilityDetails => 'Facility Details';

  @override
  String get fieldFacilityType => 'Facility Type';

  @override
  String get fieldFastingStatus => 'Fasting Status';

  @override
  String get fieldFax => 'Fax';

  @override
  String get fieldFocalDevice => 'Focal Device';

  @override
  String get fieldFollowUp => 'Follow-up';

  @override
  String get fieldForm => 'Form';

  @override
  String get fieldFormat => 'Format';

  @override
  String get fieldFundingSource => 'Funding Source';

  @override
  String get fieldGender => 'Gender';

  @override
  String get fieldGeneralPractitioner => 'General Practitioner';

  @override
  String get fieldGoal => 'Goal';

  @override
  String get fieldGoalDetails => 'Goal Details';

  @override
  String get fieldGpsCoordinates => 'GPS Coordinates';

  @override
  String get fieldGroupNumber => 'Group Number';

  @override
  String get fieldHandedOver => 'Handed Over';

  @override
  String get fieldHealthcareFacility => 'Healthcare Facility';

  @override
  String get fieldHealthcareService => 'Healthcare Service';

  @override
  String get fieldHours => 'Hours';

  @override
  String get fieldHowToTake => 'How to Take';

  @override
  String get fieldIdentifiers => 'Identifiers';

  @override
  String get fieldInformationSource => 'Information Source';

  @override
  String get fieldIngredients => 'Ingredients';

  @override
  String get fieldInstructions => 'Instructions';

  @override
  String get fieldInsuranceCompany => 'Insurance Company';

  @override
  String get fieldInsurer => 'Insurer';

  @override
  String get fieldIntent => 'Intent';

  @override
  String get fieldInterpreter => 'Interpreter';

  @override
  String get fieldItemsUsed => 'Items Used';

  @override
  String get fieldLanguage => 'Language';

  @override
  String get fieldLanguages => 'Languages';

  @override
  String get fieldLastOccurrence => 'Last Occurrence';

  @override
  String get fieldLifecycleStatus => 'Lifecycle Status';

  @override
  String get fieldLocation => 'Location';

  @override
  String get fieldLocationProvider => 'Location & Provider';

  @override
  String get fieldLotNumber => 'Lot Number';

  @override
  String get fieldManagingOrganization => 'Managing Organization';

  @override
  String get fieldManufacturer => 'Manufacturer';

  @override
  String get fieldMaritalStatus => 'Marital Status';

  @override
  String get fieldMedia => 'Media';

  @override
  String get fieldMedicalRecordNumber => 'Medical Record Number';

  @override
  String get fieldMedication => 'Medication';

  @override
  String get fieldMedicationDetails => 'Medication Details';

  @override
  String get fieldMemberId => 'Member ID';

  @override
  String get fieldMembers => 'Members';

  @override
  String get fieldMethod => 'Method';

  @override
  String get fieldModality => 'Modality';

  @override
  String get fieldMode => 'Mode';

  @override
  String get fieldMothersMaidenName => 'Mother\'s Maiden Name';

  @override
  String get fieldMultipleBirth => 'Multiple Birth';

  @override
  String get fieldNetwork => 'Network';

  @override
  String get fieldNextDose => 'Next Dose';

  @override
  String get fieldNotes => 'Notes';

  @override
  String get fieldOccurrence => 'Occurrence';

  @override
  String get fieldOnset => 'Onset';

  @override
  String get fieldOperationalStatus => 'Operational Status';

  @override
  String get fieldOperator => 'Operator';

  @override
  String get fieldOrder => 'Order';

  @override
  String get fieldOrderedBy => 'Ordered By';

  @override
  String get fieldOrganization => 'Organization';

  @override
  String get fieldOrganizationDetails => 'Organization Details';

  @override
  String get fieldOutcome => 'Outcome';

  @override
  String get fieldOutcomeMeasurements => 'Outcome Measurements';

  @override
  String get fieldPanelComponents => 'Panel Components';

  @override
  String get fieldParentSpecimen => 'Parent Specimen';

  @override
  String get fieldPartOf => 'Part Of';

  @override
  String get fieldPassportNumber => 'Passport Number';

  @override
  String get fieldPatient => 'Patient';

  @override
  String get fieldPerformedBy => 'Performed By';

  @override
  String get fieldPerformer => 'Performer';

  @override
  String get fieldPerformerType => 'Performer Type';

  @override
  String get fieldPeriod => 'Period';

  @override
  String get fieldPhone => 'Phone';

  @override
  String get fieldPhysicalType => 'Physical Type';

  @override
  String get fieldPlanName => 'Plan Name';

  @override
  String get fieldPlanType => 'Plan Type';

  @override
  String get fieldPolicyHolder => 'Policy Holder';

  @override
  String get fieldPracticeSetting => 'Practice Setting';

  @override
  String get fieldPractitioner => 'Practitioner';

  @override
  String get fieldPrepared => 'Prepared';

  @override
  String get fieldPrescribed => 'Prescribed';

  @override
  String get fieldPrescribedBy => 'Prescribed By';

  @override
  String get fieldPrimarySource => 'Primary Source';

  @override
  String get fieldPriority => 'Priority';

  @override
  String get fieldProcedureCode => 'Procedure Code';

  @override
  String get fieldProcedureDetails => 'Procedure Details';

  @override
  String get fieldProcessingStorage => 'Processing & Storage';

  @override
  String get fieldProfessionalInformation => 'Professional Information';

  @override
  String get fieldProgramEligibility => 'Program Eligibility';

  @override
  String get fieldProgressNotes => 'Progress Notes';

  @override
  String get fieldProvider => 'Provider';

  @override
  String get fieldQualification => 'Qualification';

  @override
  String get fieldQuantity => 'Quantity';

  @override
  String get fieldQuantityCollected => 'Quantity Collected';

  @override
  String get fieldRace => 'Race';

  @override
  String get fieldRangeAppliesTo => 'Range Applies To';

  @override
  String get fieldRangeNotes => 'Range Notes';

  @override
  String get fieldReAdmission => 'Re-admission';

  @override
  String get fieldReaction => 'Reaction';

  @override
  String get fieldReactions => 'Reactions';

  @override
  String get fieldReason => 'Reason';

  @override
  String get fieldReasonForVisit => 'Reason for Visit';

  @override
  String get fieldReceivedAtLab => 'Received at Lab';

  @override
  String get fieldRecorded => 'Recorded';

  @override
  String get fieldRecorder => 'Recorder';

  @override
  String get fieldReferenceRange => 'Reference Range';

  @override
  String get fieldRefills => 'Refills';

  @override
  String get fieldRelatedAppointment => 'Related Appointment';

  @override
  String get fieldRelatedCondition => 'Related Condition';

  @override
  String get fieldRelatedDocument => 'Related Document';

  @override
  String get fieldRelationship => 'Relationship';

  @override
  String get fieldRelationshipToSubscriber => 'Relationship to Subscriber';

  @override
  String get fieldReport => 'Report';

  @override
  String get fieldReportedBy => 'Reported By';

  @override
  String get fieldRequestedBy => 'Requested By';

  @override
  String get fieldRequester => 'Requester';

  @override
  String get fieldResolved => 'Resolved';

  @override
  String get fieldResult => 'Result';

  @override
  String get fieldResultDate => 'Result Date';

  @override
  String get fieldResults => 'Results';

  @override
  String get fieldRole => 'Role';

  @override
  String get fieldRoute => 'Route';

  @override
  String get fieldSecurityClassification => 'Security Classification';

  @override
  String get fieldSeries => 'Series';

  @override
  String get fieldSeriousness => 'Seriousness';

  @override
  String get fieldServicePeriod => 'Service Period';

  @override
  String get fieldServiceType => 'Service Type';

  @override
  String get fieldSetBy => 'Set By';

  @override
  String get fieldSeverity => 'Severity';

  @override
  String get fieldSite => 'Site';

  @override
  String get fieldSize => 'Size';

  @override
  String get fieldSpecialArrangements => 'Special Arrangements';

  @override
  String get fieldSpecialty => 'Specialty';

  @override
  String get fieldSpecimenDetails => 'Specimen Details';

  @override
  String get fieldSpecimenQuantity => 'Specimen Quantity';

  @override
  String get fieldSpecimenType => 'Specimen Type';

  @override
  String get fieldSpecimens => 'Specimens';

  @override
  String get fieldStage => 'Stage';

  @override
  String get fieldStartDate => 'Start Date';

  @override
  String get fieldStatus => 'Status';

  @override
  String get fieldStatusDate => 'Status Date';

  @override
  String get fieldStatusHistory => 'Status History';

  @override
  String get fieldStatusReason => 'Status Reason';

  @override
  String get fieldStrength => 'Strength';

  @override
  String get fieldSubpotent => 'Subpotent';

  @override
  String get fieldSubrogation => 'Subrogation';

  @override
  String get fieldSubscriber => 'Subscriber';

  @override
  String get fieldSubstitution => 'Substitution';

  @override
  String get fieldSupplies => 'Supplies';

  @override
  String get fieldTarget => 'Target';

  @override
  String get fieldTestDate => 'Test Date';

  @override
  String get fieldTimePeriod => 'Time Period';

  @override
  String get fieldTotal => 'Total';

  @override
  String get fieldType => 'Type';

  @override
  String get fieldUse => 'Use';

  @override
  String get fieldVaccinationDetails => 'Vaccination Details';

  @override
  String get fieldVaccine => 'Vaccine';

  @override
  String get fieldValue => 'Value';

  @override
  String get fieldVerification => 'Verification';

  @override
  String get fieldVerifiedBy => 'Verified By';

  @override
  String get fieldView => 'View';

  @override
  String get fieldVisitDetails => 'Visit Details';

  @override
  String get fieldVisitType => 'Visit Type';

  @override
  String get fieldWebsite => 'Website';

  @override
  String get fieldDateOfBirth => 'Date of Birth';

  @override
  String get fieldAge => 'Age';

  @override
  String get fieldLastUpdated => 'Last Updated';

  @override
  String get fieldAdditive => 'Additive';

  @override
  String get fieldTime => 'Time';

  @override
  String fieldProcessingNumber(int number) {
    return 'Processing $number';
  }

  @override
  String get inactive => 'Inactive';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String moreCount(int count) {
    return '$count more';
  }

  @override
  String qualificationIssuedBy(String qualification, String issuer) {
    return '$qualification (issued by $issuer)';
  }

  @override
  String qualificationValidPeriod(String qualification, String period) {
    return '$qualification - Valid: $period';
  }

  @override
  String sizeBytes(String size) {
    return '$size bytes';
  }

  @override
  String doseNumberOfTotal(String dose, String total) {
    return 'Dose $dose of $total';
  }

  @override
  String doseNumber(String dose) {
    return 'Dose $dose';
  }

  @override
  String get immunizationPrimarySourceYes => 'Yes (directly administered)';

  @override
  String get immunizationPrimarySourceNo =>
      'No (reported by patient or other source)';

  @override
  String get immunizationReactionReported => 'Reaction reported';

  @override
  String get immunizationNoReactions => 'No adverse reactions reported';

  @override
  String get immunizationSeriesComplete => 'Not scheduled (series complete)';

  @override
  String get immunizationSubpotent => 'Vaccine is subpotent';

  @override
  String documentPublished(String document, String date) {
    return '$document (published $date)';
  }

  @override
  String refillsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count refills remaining',
    );
    return '$_temp0';
  }

  @override
  String validUntil(String date) {
    return 'Valid until $date';
  }

  @override
  String validFrom(String date) {
    return 'Valid from $date';
  }

  @override
  String get substitutionAllowed => 'Generic substitution allowed';

  @override
  String get substitutionNotAllowed => 'Brand name required - no substitution';

  @override
  String get doNotPerformRequest => 'Do NOT perform this request';

  @override
  String get complicationsNone => 'None';

  @override
  String fastedFor(String duration) {
    return 'Fasted for $duration';
  }

  @override
  String containerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count container(s)',
    );
    return '$_temp0';
  }

  @override
  String get coverageOrderPrimary => 'Primary (1)';

  @override
  String get coverageOrderSecondary => 'Secondary (2)';

  @override
  String get coverageOrderTertiary => 'Tertiary (3)';

  @override
  String coverageOrderNumber(int order) {
    return 'Order $order';
  }

  @override
  String goalDueBy(String date) {
    return 'by $date';
  }

  @override
  String durationSeconds(String seconds) {
    return '$seconds seconds';
  }

  @override
  String ingredientCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ingredient(s)',
    );
    return '$_temp0';
  }

  @override
  String resultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count result(s)',
    );
    return '$_temp0';
  }

  @override
  String specimenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count specimen(s)',
    );
    return '$_temp0';
  }

  @override
  String imageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count image(s)',
    );
    return '$_temp0';
  }

  @override
  String ageYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '$count year',
    );
    return '$_temp0';
  }

  @override
  String get identifierPassport => 'Passport';

  @override
  String multipleBirthOrder(String order) {
    return 'Yes (Birth order: $order)';
  }

  @override
  String timeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '$count day ago',
    );
    return '$_temp0';
  }

  @override
  String timeAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '$count hour ago',
    );
    return '$_temp0';
  }

  @override
  String timeAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '$count minute ago',
    );
    return '$_temp0';
  }

  @override
  String get justNow => 'Just now';

  @override
  String get bloodTypeNotAvailable => 'Not Available';

  @override
  String get settingsStorage => 'Storage';

  @override
  String get settingsStorageDescription =>
      'Clear all records, preferences and cached data';

  @override
  String get settingsReset => 'Reset';

  @override
  String get resetDataWarning =>
      'This will permanently delete all your data including synced records, notes, attachments, and preferences.';

  @override
  String resetTypeToConfirm(String word) {
    return 'Type $word to confirm:';
  }

  @override
  String get deleting => 'Deleting...';

  @override
  String get aiModelDownloadContinuesInBackground =>
      'Download continues in background';

  @override
  String get aiModelAdvanced => 'Advanced';

  @override
  String get aiModelMedical => 'Medical';

  @override
  String aiModelDescriptionLite(double sizeGb) {
    final intl.NumberFormat sizeGbNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String sizeGbString = sizeGbNumberFormat.format(sizeGb);

    return 'Fast and lightweight (~$sizeGbString GB)';
  }

  @override
  String aiModelDescriptionAdvanced(double sizeGb) {
    final intl.NumberFormat sizeGbNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String sizeGbString = sizeGbNumberFormat.format(sizeGb);

    return 'Higher accuracy (~$sizeGbString GB)';
  }

  @override
  String aiModelDescriptionUltra(double sizeGb) {
    final intl.NumberFormat sizeGbNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String sizeGbString = sizeGbNumberFormat.format(sizeGb);

    return 'Best accuracy for desktop (~$sizeGbString GB)';
  }

  @override
  String aiModelDescriptionPreviousAdvanced(double sizeGb) {
    final intl.NumberFormat sizeGbNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String sizeGbString = sizeGbNumberFormat.format(sizeGb);

    return 'Previous Advanced model (~$sizeGbString GB)';
  }

  @override
  String get settingsEhrSync => 'EHR Sync';

  @override
  String get shareProximityTitle => 'Share Proximity';

  @override
  String get shareProximityDescription => 'Advertise to nearby devices';

  @override
  String get allow => 'Allow';

  @override
  String get settingsSendFeedback => 'Send us your feedback';

  @override
  String get toggleOn => 'ON';

  @override
  String get toggleOff => 'OFF';

  @override
  String get idScanVerifyDetails =>
      'Verify the details are correct. Retry scanning if needed.';

  @override
  String get idScanPartial =>
      'Some fields could not be read. Try a clearer photo.';

  @override
  String get idScanFailed =>
      'Could not read the document. Retake with better lighting.';

  @override
  String get genderOther => 'Other';

  @override
  String get genderUnknown => 'Unknown';

  @override
  String walletPassAge(int age) {
    return 'Age $age';
  }

  @override
  String privacyEffectiveDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Effective Date: $dateString';
  }

  @override
  String get privacyCorePrincipleBody =>
      'The most important thing to know is that we, the developers of **HealthWallet.me**, do not collect, store, or have access to any of your personal or health information. Our app operates entirely on your device.';

  @override
  String get privacyNoCloudProcessing =>
      '✅ No Cloud Processing: All calculations, data organization, and other functions happen locally on your phone or tablet.';

  @override
  String get privacyNoDeveloperAccess =>
      '✅ No Developer Access: We cannot see, access, or export your data. It is never sent to our servers.';

  @override
  String get privacyYouAreInControl =>
      '✅ You Are in Control: Your information is stored securely within the app\'s private storage on your device, which only you can access.';

  @override
  String get privacyDoNotCollectIntro =>
      'To be perfectly clear, our app is intentionally built to avoid accessing your personal data. We **do not** collect, store, link, or process any information that can be tied to you.';

  @override
  String get privacyPersonalIdentifiers =>
      'Personal Identifiers: We do not access or store your name, email address, phone number, contacts, or any other personal account information from your device.';

  @override
  String get privacyHealthInformation =>
      'Health Information: Any health records, medical conditions, medications, or other data you import remain yours alone. We cannot access them.';

  @override
  String get privacyNoCrossReferencing =>
      'No Cross-Referencing: The app operates in isolation. It **does not** scan, index, or cross-reference your health data with any other personal information on your phone (like your contacts list, name, or phone number). Its only job is to organize the records you provide to it.';

  @override
  String get privacyUsageAnalytics =>
      'Usage Analytics: We do not track how you use the app, which buttons you tap, or how long you spend on certain screens.';

  @override
  String get privacyYouManageIntro =>
      'The only data processed by the app is the health information **you choose to import** into it. This can be done in the following ways:';

  @override
  String get privacyImportingIntro =>
      'You can add health documents (such as PDFs of lab results or clinic summaries) directly into the app using standard mobile operating system features:';

  @override
  String get privacyScanning =>
      'Scanning: Using your device\'s camera to scan a physical document from within the app.';

  @override
  String get privacyShareActionSheet =>
      'Share Action Sheet: Selecting a file from another app (like your email, photos, or file manager) and \"sharing\" it directly to **HealthWallet.me**.';

  @override
  String get privacyLocalProcessing =>
      'Once a document is imported, the app processes it locally on your device in the background. It structures the information according to the **HL7 FHIR (Fast Healthcare Interoperability Resources)** standard to make it useful and organized. This entire process happens on your device; the document and the structured data never leave it.';

  @override
  String get privacyFastenIntro =>
      'Our app allows you to consolidate your health records by connecting to **FastenHealth OnPrem**, a transparent, open-source platform.';

  @override
  String get privacyFastenOpenSource =>
      'Open-Source and On-Premises: FastenHealth OnPrem is open-source software that you or a trusted entity controls. This provides an exceptional level of privacy.';

  @override
  String get privacyFastenDirectDownload =>
      'Direct-to-Device Download: When you authorize the connection, your health records are downloaded **directly from your FastenHealth OnPrem instance to your device**. Our app is only a conduit; your data never passes through our servers.';

  @override
  String get privacyUsageIntro =>
      'Since all your data resides on your device, it is only \"used\" by the app to help you organize and view your records. This includes:';

  @override
  String get privacyUsageProcessing =>
      'Processing and structuring imported or scanned documents.';

  @override
  String get privacyUsageDisplaying =>
      'Displaying your health records, lab results, and medication history to you.';

  @override
  String get privacyNoOtherUse =>
      'We do not use your information for advertising, research, or any other purpose.';

  @override
  String get privacyStorage =>
      'Storage: All your data is stored in the app\'s secure, sandboxed storage on your device. It is as secure as your device itself. We strongly recommend you protect your device with a passcode, Face ID, or other biometric security.';

  @override
  String get privacySharing =>
      'Sharing: We do not and cannot share your data with anyone because we don\'t have it. If you choose to export or share your data from the app, you are in complete control of where it goes.';

  @override
  String get privacyDeletion =>
      'Deletion: You can delete your information at any time from within the app. Deleting the app from your device will also permanently delete all data it has stored.';

  @override
  String get privacyChildrenBody =>
      'Our service is not directed to individuals under the age of 16, in accordance with the General Data Protection Regulation (GDPR) as applicable in Romania and across the EU. We do not knowingly collect personal information from children. If you become aware that a child has provided us with personal information, please contact us.';

  @override
  String get privacyChangesBody =>
      'We may update this policy from time to time. If we make any material changes, we will notify you through the app or by other means so you can review the changes before they take effect.';

  @override
  String get privacyContactBody =>
      'If you have any questions or concerns about this Privacy Policy, please contact us at:';

  @override
  String get syncQrScanInstructions =>
      'Scan a QR code from your **HealthWallet.me** desktop app or **Fasten Health** to sync your data.';

  @override
  String get syncSuccessMessage => 'Data was successfully synced!';

  @override
  String get syncErrorConnection =>
      'Connection failed. Please check your network and try again.';

  @override
  String get syncErrorEndpointNotFound =>
      'Sync endpoint not found. Please check server configuration.';

  @override
  String get syncErrorAuthentication =>
      'Authentication failed. Please check your token.';

  @override
  String get syncErrorInvalidFormat => 'Invalid sync data format';

  @override
  String syncErrorGeneric(String error) {
    return 'Data sync failed: $error';
  }

  @override
  String syncPlaceholderSubtitle(String recordType) {
    return 'Sync or update your data to view $recordType records';
  }

  @override
  String get appLockTitle => 'HealthWallet is locked';

  @override
  String get appLockMessage => 'Unlock to view your health records';

  @override
  String get appLockUnlock => 'Unlock';
}
