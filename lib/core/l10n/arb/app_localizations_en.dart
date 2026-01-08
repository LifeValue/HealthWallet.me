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
  String get dashboardTitle => 'Dashboard';

  @override
  String get recordsTitle => 'Records';

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
  String get getStarted => 'Get started';

  @override
  String get failedToUpdateDisplayName => 'Failed to update display name';

  @override
  String get actionCannotBeUndone => 'This action cannot be undone.';

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
      'Scan the QR code from your Fasten Health server to create a new sync connection.';

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
  String get effectiveDate => 'Effective Date';

  @override
  String get privacyIntro => 'Your privacy is our highest priority.';

  @override
  String get privacyDescription =>
      'is a simple, secure tool designed to help you organize your health records at ease, directly on your device. This policy explains our commitment to your privacy: we do not collect your data, and we do not track you. You are in complete control.';

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
  String get onboardingAiModelTitle => 'Enable AI Model';

  @override
  String get onboardingAiModelDescription =>
      'Download a secure, on-device AI model (~1.5 GB) to automatically analyze and organize your health records, your data stays private on your device. This is a one-time setup.';

  @override
  String get onboardingAiModelSubtitle => 'Unlock AI-powered scanning';

  @override
  String get aiModelReady => 'AI model ready! You can start scanning.';

  @override
  String get aiModelDownloading => 'Downloading AI model...';

  @override
  String get aiModelEnableDownload => 'Enable & Download';

  @override
  String get aiModelError => 'Couldn’t verify model. Try again.';

  @override
  String get aiModelMissing => 'Not downloaded.';

  @override
  String get aiModelTitle => 'Load AI Model';

  @override
  String get aiModelUnlockTitle => 'Unlock AI-Powered Scanning';

  @override
  String get aiModelUnlockDescription =>
      'To automatically read and organize your medical documents, this feature uses a secure, on-device AI model. This keeps your data completely private.';

  @override
  String get aiModelDownloadInfo =>
      'To get started, we need to download the AI component (approx. 1.5 GB). This is a one-time setup.';

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
  String get aiModelNotAvailable => 'AI model is not available';

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
}
