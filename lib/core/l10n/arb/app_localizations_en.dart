// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'HealthWallet.me';

  @override
  String get homeTitle => 'Home';

  @override
  String get profileTitle => 'Profile';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get welcomeMessage => 'Welcome to HealthWallet.me!';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get onboardingNext => 'Next';

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
  String get onboardingBiometricText =>
      'You can lock your HealthWallet with biometric security like Face ID or a fingerprint scan.';

  @override
  String get homeHi => 'Hi, ';

  @override
  String get homeLastSynced => 'Last synced: ';

  @override
  String get homeNever => 'Never';

  @override
  String get homeVitalSigns => 'Vitals';

  @override
  String get homeOverview => 'Medical Records';

  @override
  String get homeSource => 'Source:';

  @override
  String get homeAll => 'All';

  @override
  String get homeRecentRecords => 'Recent Records';

  @override
  String get homeViewAll => 'View All';

  @override
  String get homeNA => 'N/A';

  @override
  String get bluetoothRequired =>
      'Please turn on Bluetooth to use Share Proximity';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get recordsTitle => 'Records';

  @override
  String get goToRecords => 'Go to Records';

  @override
  String get syncTitle => 'Sync';

  @override
  String get scanFastenQr => 'Scan Fasten Health QR';

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
  String get syncAgain => 'Sync Again';

  @override
  String get syncFailed => 'Sync failed: ';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get syncedAt => 'Synced at: ';

  @override
  String get pasteSyncData => 'Paste Sync Data';

  @override
  String get submit => 'Submit';

  @override
  String get hideManualEntry => 'Hide Manual Entry';

  @override
  String get enterDataManually => 'Enter data manually';

  @override
  String get medicalRecords => 'Medical Records';

  @override
  String get searchRecordsHint => 'Search records, doctors, locations...';

  @override
  String get detailsFor => 'Details for ';

  @override
  String get patientId => 'MRN: ';

  @override
  String get age => 'Age';

  @override
  String get sex => 'Sex';

  @override
  String get bloodType => 'Blood Type';

  @override
  String get lastSyncedProfile => 'Last synced: 2 hours ago';

  @override
  String get syncLatestRecords =>
      'Sync your latest medical records from your healthcare provider.';

  @override
  String get scanToSync => 'Scan to Sync';

  @override
  String get theme => 'Theme';

  @override
  String get pleaseAuthenticate => 'Please authenticate to continue';

  @override
  String get authenticate => 'Authenticate';

  @override
  String get bypass => 'Bypass';

  @override
  String get onboardingAuthTitle => 'Enable Biometric Authentication';

  @override
  String get onboardingAuthDescription =>
      'Add an extra layer of security to your account by enabling biometric authentication.';

  @override
  String get onboardingAuthEnable => 'Enable Now';

  @override
  String get onboardingAuthSkip => 'Skip for Now';

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
  String get scanCode => 'Scan code';

  @override
  String get or => 'or';

  @override
  String get manualSyncMessage => 'Raw QR Code';

  @override
  String get pasteSyncDataHint => 'Paste the raw QR code';

  @override
  String get connect => 'Connect';

  @override
  String get scanNewQRCode => 'Scan New QR Code';

  @override
  String get loadDemoData => 'Load Demo Data';

  @override
  String get syncData => 'Sync Data';

  @override
  String get noMedicalRecordsYet => 'No medical records yet';

  @override
  String noRecordTypeYet(Object recordType) {
    return 'No $recordType yet';
  }

  @override
  String get loadDemoDataMessage =>
      'Load demo data to explore the app or sync your real medical records';

  @override
  String syncDataMessage(Object recordType) {
    return 'Sync or update your data to view $recordType records';
  }

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
  String get noChangesDetected => 'No changes detected';

  @override
  String get pleaseSelectBirthDate => 'Please select a birth date';

  @override
  String get errorSavingPatientData => 'Error saving patient data';

  @override
  String get walletHolder => 'Wallet Holder';

  @override
  String get walletHolderDescription =>
      'This patient is the primary owner of this health wallet';

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
  String confirmDeleteFile(Object filename) {
    return 'Are you sure you want to delete \"$filename\"?';
  }

  @override
  String selectAtLeastOne(Object type) {
    return 'Select at least one $type to continue.';
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
  String chooseToDisplay(Object type) {
    return 'Choose the $type you want to see on your dashboard.';
  }

  @override
  String get displayName => 'Display name';

  @override
  String get bloodTypeAPositive => 'A positive';

  @override
  String get bloodTypeANegative => 'A negative';

  @override
  String get bloodTypeBPositive => 'B positive';

  @override
  String get bloodTypeBNegative => 'B negative';

  @override
  String get bloodTypeABPositive => 'AB positive';

  @override
  String get bloodTypeABNegative => 'AB negative';

  @override
  String get bloodTypeOPositive => 'O positive';

  @override
  String get bloodTypeONegative => 'O negative';

  @override
  String get serverError => 'Something went wrong on the server';

  @override
  String get serverTimeout => 'Server timeout';

  @override
  String get connectionError => 'Connection error';

  @override
  String get unknownSource => 'Unknown Source';

  @override
  String get synchronization => 'Synchronization';

  @override
  String get desktopSyncAndBackup => 'Data Sync & Backup';

  @override
  String get desktopSyncDescription =>
      'Sync & Backup your health records.\nHand over documents to be digitally processed on your desktop.';

  @override
  String get processOnDesktop => 'Process on Desktop';

  @override
  String get sendToDesktop => 'Send to Desktop';

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
  String get syncLatestMedicalRecords =>
      'Sync your latest medical records from your healthcare provider using a secure JWT token.';

  @override
  String get neverSynced => 'Never synced';

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
  String get showAll => 'Show All';

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
  String get clearAllFilters => 'Clear all';

  @override
  String get syncingData => 'Syncing data';

  @override
  String get syncingMessage => 'It might take a while. Please wait.';

  @override
  String get scanQRMessage =>
      'Scan a QR code from your HealthWallet.me desktop app or Fasten Health to sync your data.';

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
  String get recordsSavedMessage =>
      'Your health records have been saved successfully.';

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
  String get patientSetupTitle => 'Set Up Your Profile';

  @override
  String get patientSetupSubtitle =>
      'Personalize your health wallet with your information';

  @override
  String get onboardingSetupTitle => 'Set Up my Health Wallet';

  @override
  String get onboardingSetupBody =>
      'Create your personal health profile to get started with HealthWallet';

  @override
  String get onboardingDemoTitle => 'Try Demo Data';

  @override
  String get onboardingDemoBody =>
      'Explore the app with sample medical records to see how it works';

  @override
  String get onboardingSyncTitle2 => 'Sync Your Records';

  @override
  String get onboardingSyncBody =>
      'Connect to your healthcare providers to import your real medical records';

  @override
  String get givenName => 'Given Name';

  @override
  String get familyName => 'Family Name';

  @override
  String get skipForNow => 'Skip for now';

  @override
  String get setUpProfile => 'Set Up';

  @override
  String get useDefaults => 'Default';

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
  String get tokenPresetLowDescription =>
      'Best for small files and quick tasks.\nUses the least resources and processes fastest.';

  @override
  String get tokenPresetMedium => 'Medium';

  @override
  String get tokenPresetMediumDescription =>
      'Good for most use cases.\nBalances file size, processing time, and resource usage.';

  @override
  String get tokenPresetHigh => 'High';

  @override
  String get tokenPresetHighDescription =>
      'Best for large files and complex processing.\nUses more resources and battery, and takes longer to complete.';

  @override
  String get tokenPresetCustom => 'Custom';

  @override
  String get tokenPresetCustomDescription =>
      'Set custom amount of tokens you want to use.';

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
  String get emergencyContactHint => 'Phone number';

  @override
  String get searchCountry => 'Search country...';

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
  String get cannotDeleteLastPage => 'Cannot delete the last page';

  @override
  String get pageRotated => 'Page rotated';

  @override
  String get regionAndUnits => 'Language & Units';

  @override
  String get country => 'Country';

  @override
  String get patientModifiedNewWillBeCreated =>
      'Modified — a new patient will be created';

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
  String get modifyPatientTitle => 'Modify patient?';

  @override
  String get modifyPatientMessage =>
      'This will update the existing patient record with your changes.';

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
  String get downloadingVisionModel => 'Downloading vision model...';

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
  String shareExtensionDurationRequested(String duration) {
    return '$duration requested';
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
  String get desktopBackupLocation => 'Backup Location';

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
  String get desktopConnectToDesktop => 'Connect to Desktop';

  @override
  String get desktopCouldNotReconnect =>
      'Could not reconnect. Scan QR code to pair again.';

  @override
  String get desktopScanQrToPair =>
      'Scan the QR code on your desktop app to pair.';

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
}
