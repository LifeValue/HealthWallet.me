import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_ro.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'arb/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('de'),
    Locale('ro'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'HealthWallet.me'**
  String get appTitle;

  /// The title of the home screen
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// The title of the profile screen
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// The title of the settings screen
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// The welcome message shown to users
  ///
  /// In en, this message translates to:
  /// **'Welcome to HealthWallet.me!'**
  String get welcomeMessage;

  /// No description provided for @onboardingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'a Health Wallet for You!'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'<link>HealthWallet.me</link> already connects to 100,000+ US healthcare providers, and we\'re expanding to new countries.'**
  String get onboardingWelcomeSubtitle;

  /// No description provided for @onboardingWelcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Add records from any provider, import documents manually, or request support for your country.'**
  String get onboardingWelcomeDescription;

  /// No description provided for @onboardingRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Health, Always in Sync'**
  String get onboardingRecordsTitle;

  /// No description provided for @onboardingRecordsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'<link>HealthWallet.me</link> gives you flexible ways to bring all your medical history together:'**
  String get onboardingRecordsSubtitle;

  /// No description provided for @onboardingRecordsDescription.
  ///
  /// In en, this message translates to:
  /// **'• Scan documents with your phone\'s camera\n• Upload PDFs, images, or lab files directly\n• Import records by sharing directly with <link>HealthWallet.me</link> from any app in your smartphone.\n• Scan the QR Code of Fasten Health OnPrem and get all your US healthcare systems records to your wallet.'**
  String get onboardingRecordsDescription;

  /// No description provided for @onboardingRecordsContent.
  ///
  /// In en, this message translates to:
  /// **'• Scan documents with your phone\'s camera\n• Upload PDFs, images, or lab files directly\n• Import records by sharing directly with <link>HealthWallet.me</link> from any app in your smartphone.\n• Scan the QR Code of <link>Fasten Health OnPrem</link> and get all your US healthcare systems records to your wallet.'**
  String get onboardingRecordsContent;

  /// No description provided for @onboardingRecordsBottom.
  ///
  /// In en, this message translates to:
  /// **'Everything is organized securely on your device.'**
  String get onboardingRecordsBottom;

  /// No description provided for @onboardingRequestIntegration.
  ///
  /// In en, this message translates to:
  /// **'Request an integration'**
  String get onboardingRequestIntegration;

  /// No description provided for @onboardingScanButton.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get onboardingScanButton;

  /// No description provided for @onboardingSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Security & Privacy'**
  String get onboardingSyncTitle;

  /// No description provided for @onboardingSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'<link>HealthWallet.me</link> is built with privacy at its core. Your medical data is encrypted and stored only on your phone, never on cloud servers.'**
  String get onboardingSyncSubtitle;

  /// No description provided for @onboardingSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'View your health history in airplane mode, abroad, or without internet, your records stay with you wherever you go. Add an extra layer of security by enabling biometric authentication.'**
  String get onboardingSyncDescription;

  /// No description provided for @onboardingBiometricText.
  ///
  /// In en, this message translates to:
  /// **'You can lock your HealthWallet with biometric security like Face ID or a fingerprint scan.'**
  String get onboardingBiometricText;

  /// No description provided for @homeHi.
  ///
  /// In en, this message translates to:
  /// **'Hi, '**
  String get homeHi;

  /// No description provided for @homeLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced: '**
  String get homeLastSynced;

  /// No description provided for @homeNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get homeNever;

  /// No description provided for @homeVitalSigns.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get homeVitalSigns;

  /// No description provided for @homeOverview.
  ///
  /// In en, this message translates to:
  /// **'Medical Records'**
  String get homeOverview;

  /// No description provided for @homeSource.
  ///
  /// In en, this message translates to:
  /// **'Source:'**
  String get homeSource;

  /// No description provided for @homeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get homeAll;

  /// No description provided for @homeRecentRecords.
  ///
  /// In en, this message translates to:
  /// **'Recent Records'**
  String get homeRecentRecords;

  /// No description provided for @homeViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get homeViewAll;

  /// No description provided for @homeNA.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get homeNA;

  /// No description provided for @bluetoothRequired.
  ///
  /// In en, this message translates to:
  /// **'Please turn on Bluetooth to use Share Proximity'**
  String get bluetoothRequired;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @recordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get recordsTitle;

  /// No description provided for @goToRecords.
  ///
  /// In en, this message translates to:
  /// **'Go to Records'**
  String get goToRecords;

  /// No description provided for @syncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncTitle;

  /// No description provided for @syncSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Sync successful!'**
  String get syncSuccessful;

  /// No description provided for @syncDataLoadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Your medical records have been synchronized. You will be redirected to the home page.'**
  String get syncDataLoadedSuccessfully;

  /// No description provided for @cancelSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Sync?'**
  String get cancelSyncTitle;

  /// No description provided for @cancelSyncMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel the synchronization? This will stop the current sync process.'**
  String get cancelSyncMessage;

  /// No description provided for @yesCancel.
  ///
  /// In en, this message translates to:
  /// **'Yes, Cancel'**
  String get yesCancel;

  /// No description provided for @continueSync.
  ///
  /// In en, this message translates to:
  /// **'Continue Sync'**
  String get continueSync;

  /// No description provided for @syncAgain.
  ///
  /// In en, this message translates to:
  /// **'Sync Again'**
  String get syncAgain;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: '**
  String get syncFailed;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @syncedAt.
  ///
  /// In en, this message translates to:
  /// **'Synced at: '**
  String get syncedAt;

  /// No description provided for @pasteSyncData.
  ///
  /// In en, this message translates to:
  /// **'Paste Sync Data'**
  String get pasteSyncData;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @hideManualEntry.
  ///
  /// In en, this message translates to:
  /// **'Hide Manual Entry'**
  String get hideManualEntry;

  /// No description provided for @enterDataManually.
  ///
  /// In en, this message translates to:
  /// **'Enter data manually'**
  String get enterDataManually;

  /// No description provided for @medicalRecords.
  ///
  /// In en, this message translates to:
  /// **'Medical Records'**
  String get medicalRecords;

  /// No description provided for @searchRecordsHint.
  ///
  /// In en, this message translates to:
  /// **'Search records, doctors, locations...'**
  String get searchRecordsHint;

  /// No description provided for @detailsFor.
  ///
  /// In en, this message translates to:
  /// **'Details for '**
  String get detailsFor;

  /// No description provided for @patientId.
  ///
  /// In en, this message translates to:
  /// **'MRN: '**
  String get patientId;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @sex.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get sex;

  /// No description provided for @bloodType.
  ///
  /// In en, this message translates to:
  /// **'Blood Type'**
  String get bloodType;

  /// No description provided for @lastSyncedProfile.
  ///
  /// In en, this message translates to:
  /// **'Last synced: 2 hours ago'**
  String get lastSyncedProfile;

  /// No description provided for @syncLatestRecords.
  ///
  /// In en, this message translates to:
  /// **'Sync your latest medical records from your healthcare provider.'**
  String get syncLatestRecords;

  /// No description provided for @scanToSync.
  ///
  /// In en, this message translates to:
  /// **'Scan to Sync'**
  String get scanToSync;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @pleaseAuthenticate.
  ///
  /// In en, this message translates to:
  /// **'Please authenticate to continue'**
  String get pleaseAuthenticate;

  /// No description provided for @authenticate.
  ///
  /// In en, this message translates to:
  /// **'Authenticate'**
  String get authenticate;

  /// No description provided for @bypass.
  ///
  /// In en, this message translates to:
  /// **'Bypass'**
  String get bypass;

  /// No description provided for @onboardingAuthTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Biometric Authentication'**
  String get onboardingAuthTitle;

  /// No description provided for @onboardingAuthDescription.
  ///
  /// In en, this message translates to:
  /// **'Add an extra layer of security to your account by enabling biometric authentication.'**
  String get onboardingAuthDescription;

  /// No description provided for @onboardingAuthEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Now'**
  String get onboardingAuthEnable;

  /// No description provided for @onboardingAuthSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for Now'**
  String get onboardingAuthSkip;

  /// No description provided for @biometricAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Biometric Authentication'**
  String get biometricAuthentication;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @setupDeviceSecurity.
  ///
  /// In en, this message translates to:
  /// **'Set Up Device Security'**
  String get setupDeviceSecurity;

  /// No description provided for @deviceSecurityMessage.
  ///
  /// In en, this message translates to:
  /// **'Your device has no security setup. For your safety, please set up device security before using this app:'**
  String get deviceSecurityMessage;

  /// No description provided for @deviceSettingsStep1.
  ///
  /// In en, this message translates to:
  /// **'Go to your device Settings'**
  String get deviceSettingsStep1;

  /// No description provided for @deviceSettingsStep2.
  ///
  /// In en, this message translates to:
  /// **'Navigate to Security or Lock screen'**
  String get deviceSettingsStep2;

  /// No description provided for @deviceSettingsStep3.
  ///
  /// In en, this message translates to:
  /// **'Set up a screen lock (PIN, pattern, or password)'**
  String get deviceSettingsStep3;

  /// No description provided for @deviceSettingsStep4.
  ///
  /// In en, this message translates to:
  /// **'Optionally add fingerprint or face unlock for convenience'**
  String get deviceSettingsStep4;

  /// No description provided for @deviceSecurityReturnMessage.
  ///
  /// In en, this message translates to:
  /// **'After setting up device security, return to this app and try again.'**
  String get deviceSecurityReturnMessage;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @settingsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Settings Not Available'**
  String get settingsNotAvailable;

  /// No description provided for @settingsNotAvailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not open device settings automatically. Please manually:\n\n1. Open Settings\n2. Go to Security → Biometrics\n3. Add fingerprint or face unlock\n4. Return to this app and try again'**
  String get settingsNotAvailableMessage;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @scanCode.
  ///
  /// In en, this message translates to:
  /// **'Scan code'**
  String get scanCode;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @manualSyncMessage.
  ///
  /// In en, this message translates to:
  /// **'Raw QR Code'**
  String get manualSyncMessage;

  /// No description provided for @pasteSyncDataHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the raw QR code'**
  String get pasteSyncDataHint;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @scanNewQRCode.
  ///
  /// In en, this message translates to:
  /// **'Scan New QR Code'**
  String get scanNewQRCode;

  /// No description provided for @loadDemoData.
  ///
  /// In en, this message translates to:
  /// **'Load Demo Data'**
  String get loadDemoData;

  /// No description provided for @syncData.
  ///
  /// In en, this message translates to:
  /// **'Sync Data'**
  String get syncData;

  /// No description provided for @noMedicalRecordsYet.
  ///
  /// In en, this message translates to:
  /// **'No medical records yet'**
  String get noMedicalRecordsYet;

  /// No description provided for @noRecordTypeYet.
  ///
  /// In en, this message translates to:
  /// **'No {recordType} yet'**
  String noRecordTypeYet(Object recordType);

  /// No description provided for @loadDemoDataMessage.
  ///
  /// In en, this message translates to:
  /// **'Load demo data to explore the app or sync your real medical records'**
  String get loadDemoDataMessage;

  /// No description provided for @syncDataMessage.
  ///
  /// In en, this message translates to:
  /// **'Sync or update your data to view {recordType} records'**
  String syncDataMessage(Object recordType);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @pleaseEnterSourceName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a source name'**
  String get pleaseEnterSourceName;

  /// No description provided for @selectBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Select birth date'**
  String get selectBirthDate;

  /// No description provided for @years.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get years;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @preferNotToSay.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get preferNotToSay;

  /// No description provided for @errorUpdatingSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Error updating source label'**
  String get errorUpdatingSourceLabel;

  /// No description provided for @noChangesDetected.
  ///
  /// In en, this message translates to:
  /// **'No changes detected'**
  String get noChangesDetected;

  /// No description provided for @pleaseSelectBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Please select a birth date'**
  String get pleaseSelectBirthDate;

  /// No description provided for @errorSavingPatientData.
  ///
  /// In en, this message translates to:
  /// **'Error saving patient data'**
  String get errorSavingPatientData;

  /// No description provided for @walletHolder.
  ///
  /// In en, this message translates to:
  /// **'Wallet Holder'**
  String get walletHolder;

  /// No description provided for @walletHolderDescription.
  ///
  /// In en, this message translates to:
  /// **'This patient is the primary owner of this health wallet'**
  String get walletHolderDescription;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @failedToUpdateDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Failed to update display name'**
  String get failedToUpdateDisplayName;

  /// No description provided for @actionCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get actionCannotBeUndone;

  /// No description provided for @deleteRecordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this record?'**
  String get deleteRecordConfirm;

  /// No description provided for @deleteNoteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this note?'**
  String get deleteNoteConfirm;

  /// No description provided for @deleteAttachmentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this attachment?'**
  String get deleteAttachmentConfirm;

  /// No description provided for @deleteRecordsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} items?'**
  String deleteRecordsConfirm(int count);

  /// No description provided for @confirmDeleteFile.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{filename}\"?'**
  String confirmDeleteFile(Object filename);

  /// No description provided for @selectAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Select at least one {type} to continue.'**
  String selectAtLeastOne(Object type);

  /// No description provided for @editSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit source label'**
  String get editSourceLabel;

  /// No description provided for @saveDetails.
  ///
  /// In en, this message translates to:
  /// **'Save details'**
  String get saveDetails;

  /// No description provided for @editDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get editDetails;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @page.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get page;

  /// No description provided for @reorderPages.
  ///
  /// In en, this message translates to:
  /// **'Reorder Pages'**
  String get reorderPages;

  /// No description provided for @attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachments;

  /// No description provided for @noFilesAttached.
  ///
  /// In en, this message translates to:
  /// **'This record has no files attached'**
  String get noFilesAttached;

  /// No description provided for @attachFile.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get attachFile;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @recentRecords.
  ///
  /// In en, this message translates to:
  /// **'Recent records'**
  String get recentRecords;

  /// No description provided for @chooseToDisplay.
  ///
  /// In en, this message translates to:
  /// **'Choose the {type} you want to see on your dashboard.'**
  String chooseToDisplay(Object type);

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @bloodTypeAPositive.
  ///
  /// In en, this message translates to:
  /// **'A positive'**
  String get bloodTypeAPositive;

  /// No description provided for @bloodTypeANegative.
  ///
  /// In en, this message translates to:
  /// **'A negative'**
  String get bloodTypeANegative;

  /// No description provided for @bloodTypeBPositive.
  ///
  /// In en, this message translates to:
  /// **'B positive'**
  String get bloodTypeBPositive;

  /// No description provided for @bloodTypeBNegative.
  ///
  /// In en, this message translates to:
  /// **'B negative'**
  String get bloodTypeBNegative;

  /// No description provided for @bloodTypeABPositive.
  ///
  /// In en, this message translates to:
  /// **'AB positive'**
  String get bloodTypeABPositive;

  /// No description provided for @bloodTypeABNegative.
  ///
  /// In en, this message translates to:
  /// **'AB negative'**
  String get bloodTypeABNegative;

  /// No description provided for @bloodTypeOPositive.
  ///
  /// In en, this message translates to:
  /// **'O positive'**
  String get bloodTypeOPositive;

  /// No description provided for @bloodTypeONegative.
  ///
  /// In en, this message translates to:
  /// **'O negative'**
  String get bloodTypeONegative;

  /// No description provided for @serverError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on the server'**
  String get serverError;

  /// No description provided for @serverTimeout.
  ///
  /// In en, this message translates to:
  /// **'Server timeout'**
  String get serverTimeout;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get connectionError;

  /// No description provided for @unknownSource.
  ///
  /// In en, this message translates to:
  /// **'Unknown Source'**
  String get unknownSource;

  /// No description provided for @synchronization.
  ///
  /// In en, this message translates to:
  /// **'Synchronization'**
  String get synchronization;

  /// No description provided for @desktopSyncAndBackup.
  ///
  /// In en, this message translates to:
  /// **'Desktop Sync & Backup'**
  String get desktopSyncAndBackup;

  /// No description provided for @desktopSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Sync & Backup your health records.\nHand over documents to be digitally processed on your desktop.'**
  String get desktopSyncDescription;

  /// No description provided for @processOnDesktop.
  ///
  /// In en, this message translates to:
  /// **'Process on Desktop'**
  String get processOnDesktop;

  /// No description provided for @sendToDesktop.
  ///
  /// In en, this message translates to:
  /// **'Send to Desktop'**
  String get sendToDesktop;

  /// No description provided for @continueImporting.
  ///
  /// In en, this message translates to:
  /// **'Continue Importing'**
  String get continueImporting;

  /// No description provided for @noAiModelOnDesktop.
  ///
  /// In en, this message translates to:
  /// **'No AI model on Desktop. Please download the AI model on your desktop app first.'**
  String get noAiModelOnDesktop;

  /// No description provided for @syncMedicalRecords.
  ///
  /// In en, this message translates to:
  /// **'Sync Medical records'**
  String get syncMedicalRecords;

  /// No description provided for @syncLatestMedicalRecords.
  ///
  /// In en, this message translates to:
  /// **'Sync your latest medical records from your healthcare provider using a secure JWT token.'**
  String get syncLatestMedicalRecords;

  /// No description provided for @neverSynced.
  ///
  /// In en, this message translates to:
  /// **'Never synced'**
  String get neverSynced;

  /// No description provided for @lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced'**
  String get lastSynced;

  /// No description provided for @tapToSelectPatient.
  ///
  /// In en, this message translates to:
  /// **'Tap to select patient'**
  String get tapToSelectPatient;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get off;

  /// No description provided for @confirmDisableBiometric.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you would like to disable the Biometric Auth (FaceID / Passcode)?'**
  String get confirmDisableBiometric;

  /// No description provided for @disable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disable;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @enableBiometricAuth.
  ///
  /// In en, this message translates to:
  /// **'Enable Biometric Auth (FaceID / Passcode)'**
  String get enableBiometricAuth;

  /// No description provided for @disableBiometricAuth.
  ///
  /// In en, this message translates to:
  /// **'Disable Biometric Auth (FaceID / Passcode)'**
  String get disableBiometricAuth;

  /// No description provided for @patient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get patient;

  /// No description provided for @noPatientsFound.
  ///
  /// In en, this message translates to:
  /// **'No patients found'**
  String get noPatientsFound;

  /// No description provided for @id.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get id;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show All'**
  String get showAll;

  /// No description provided for @records.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get records;

  /// No description provided for @vitals.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get vitals;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @noRecordsFound.
  ///
  /// In en, this message translates to:
  /// **'No records found'**
  String get noRecordsFound;

  /// No description provided for @noRecords.
  ///
  /// In en, this message translates to:
  /// **'No records'**
  String get noRecords;

  /// No description provided for @tryDifferentKeywords.
  ///
  /// In en, this message translates to:
  /// **'Try searching with different keywords'**
  String get tryDifferentKeywords;

  /// No description provided for @clearAllFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAllFilters;

  /// No description provided for @syncingData.
  ///
  /// In en, this message translates to:
  /// **'Syncing data'**
  String get syncingData;

  /// No description provided for @syncingMessage.
  ///
  /// In en, this message translates to:
  /// **'It might take a while. Please wait.'**
  String get syncingMessage;

  /// No description provided for @scanQRMessage.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code from your Fasten Health server to create a new sync connection.'**
  String get scanQRMessage;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @vitalSigns.
  ///
  /// In en, this message translates to:
  /// **'Vital Signs'**
  String get vitalSigns;

  /// No description provided for @longPressToReorder.
  ///
  /// In en, this message translates to:
  /// **'Long press to move & reorder cards, or filter to select which ones appear on your dashboard.'**
  String get longPressToReorder;

  /// No description provided for @finishProcessing.
  ///
  /// In en, this message translates to:
  /// **'Finish Processing'**
  String get finishProcessing;

  /// No description provided for @finishProcessingMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to finish this processing session?'**
  String get finishProcessingMessage;

  /// No description provided for @finishProcessingWarning.
  ///
  /// In en, this message translates to:
  /// **'This will clear the current session.'**
  String get finishProcessingWarning;

  /// No description provided for @fieldCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'This field cannot be empty'**
  String get fieldCannotBeEmpty;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// No description provided for @attachToEncounter.
  ///
  /// In en, this message translates to:
  /// **'Attach to Encounter'**
  String get attachToEncounter;

  /// No description provided for @continueProcessing.
  ///
  /// In en, this message translates to:
  /// **'Continue Processing'**
  String get continueProcessing;

  /// No description provided for @recordsSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Successfully Saved'**
  String get recordsSavedTitle;

  /// No description provided for @recordsSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your health records have been saved successfully.'**
  String get recordsSavedMessage;

  /// No description provided for @whatNextQuestion.
  ///
  /// In en, this message translates to:
  /// **'What would you like to do next?'**
  String get whatNextQuestion;

  /// No description provided for @continueScanning.
  ///
  /// In en, this message translates to:
  /// **'Continue Scanning'**
  String get continueScanning;

  /// No description provided for @effectiveDate.
  ///
  /// In en, this message translates to:
  /// **'Effective Date'**
  String get effectiveDate;

  /// No description provided for @privacyIntro.
  ///
  /// In en, this message translates to:
  /// **'Your privacy is our highest priority.'**
  String get privacyIntro;

  /// No description provided for @privacyDescription.
  ///
  /// In en, this message translates to:
  /// **'is a simple, secure tool designed to help you organize your health records with ease, directly on your device. This policy explains our commitment to your privacy: we do not collect your data, and we do not track you. You are in complete control.'**
  String get privacyDescription;

  /// No description provided for @corePrinciple.
  ///
  /// In en, this message translates to:
  /// **'Our Core Principle: Your Data Stays on Your Device'**
  String get corePrinciple;

  /// No description provided for @whatInformationHandled.
  ///
  /// In en, this message translates to:
  /// **'What Information is Handled?'**
  String get whatInformationHandled;

  /// No description provided for @informationWeDoNotCollect.
  ///
  /// In en, this message translates to:
  /// **'Information We Do Not Collect or Access'**
  String get informationWeDoNotCollect;

  /// No description provided for @informationYouManage.
  ///
  /// In en, this message translates to:
  /// **'Information You Manage'**
  String get informationYouManage;

  /// No description provided for @importingDocuments.
  ///
  /// In en, this message translates to:
  /// **'Importing Documents from Your Device'**
  String get importingDocuments;

  /// No description provided for @connectingFastenHealth.
  ///
  /// In en, this message translates to:
  /// **'Connecting to FastenHealth OnPrem'**
  String get connectingFastenHealth;

  /// No description provided for @howInformationUsed.
  ///
  /// In en, this message translates to:
  /// **'How Your Information is Used'**
  String get howInformationUsed;

  /// No description provided for @dataStorageSecurity.
  ///
  /// In en, this message translates to:
  /// **'Data Storage, Security, and Sharing'**
  String get dataStorageSecurity;

  /// No description provided for @childrensPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Children\'s Privacy'**
  String get childrensPrivacy;

  /// No description provided for @changesToPolicy.
  ///
  /// In en, this message translates to:
  /// **'Changes to This Privacy Policy'**
  String get changesToPolicy;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @builtWithLove.
  ///
  /// In en, this message translates to:
  /// **'Built with love by Life Value!'**
  String get builtWithLove;

  /// No description provided for @sourceName.
  ///
  /// In en, this message translates to:
  /// **'Source name'**
  String get sourceName;

  /// No description provided for @provideCustomLabel.
  ///
  /// In en, this message translates to:
  /// **'Provide a custom label for:'**
  String get provideCustomLabel;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @demoDataLoadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Demo data has been loaded successfully. You will be redirected to the home page.'**
  String get demoDataLoadedSuccessfully;

  /// No description provided for @documentScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get documentScanTitle;

  /// No description provided for @fromPhoneTab.
  ///
  /// In en, this message translates to:
  /// **'From Phone'**
  String get fromPhoneTab;

  /// No description provided for @onboardingAiModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable AI Model'**
  String get onboardingAiModelTitle;

  /// No description provided for @onboardingAiModelDescription.
  ///
  /// In en, this message translates to:
  /// **'Download a secure, on-device AI model to automatically analyze and organize your health records. Choose between two options depending on your needs and device capability. This is a one-time setup.\n\n**Your data stays private on your device.**'**
  String get onboardingAiModelDescription;

  /// No description provided for @onboardingAiModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock AI-powered scanning'**
  String get onboardingAiModelSubtitle;

  /// No description provided for @aiModelReady.
  ///
  /// In en, this message translates to:
  /// **'AI ready! You can start scanning.'**
  String get aiModelReady;

  /// No description provided for @aiModelDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get aiModelDownloading;

  /// No description provided for @aiModelEnableDownload.
  ///
  /// In en, this message translates to:
  /// **'Choose & Download'**
  String get aiModelEnableDownload;

  /// No description provided for @aiModelError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t verify. Try again.'**
  String get aiModelError;

  /// No description provided for @aiModelMissing.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded.'**
  String get aiModelMissing;

  /// No description provided for @aiModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Load AI Model'**
  String get aiModelTitle;

  /// No description provided for @aiModelUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock AI-Powered Scanning'**
  String get aiModelUnlockTitle;

  /// No description provided for @aiModelUnlockDescription.
  ///
  /// In en, this message translates to:
  /// **'To automatically read and organize your medical documents, this feature uses a secure, on-device AI model.\n\n**Your data stays private on your device.**'**
  String get aiModelUnlockDescription;

  /// No description provided for @aiModelDownloadInfo.
  ///
  /// In en, this message translates to:
  /// **'To get started, choose and download one of two available AI options. This is a one-time setup.'**
  String get aiModelDownloadInfo;

  /// No description provided for @setup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get setup;

  /// No description provided for @patientSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Up Your Profile'**
  String get patientSetupTitle;

  /// No description provided for @patientSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Personalize your health wallet with your information'**
  String get patientSetupSubtitle;

  /// No description provided for @onboardingSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Up my Health Wallet'**
  String get onboardingSetupTitle;

  /// No description provided for @onboardingSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Create your personal health profile to get started with HealthWallet'**
  String get onboardingSetupBody;

  /// No description provided for @onboardingDemoTitle.
  ///
  /// In en, this message translates to:
  /// **'Try Demo Data'**
  String get onboardingDemoTitle;

  /// No description provided for @onboardingDemoBody.
  ///
  /// In en, this message translates to:
  /// **'Explore the app with sample medical records to see how it works'**
  String get onboardingDemoBody;

  /// No description provided for @onboardingSyncTitle2.
  ///
  /// In en, this message translates to:
  /// **'Sync Your Records'**
  String get onboardingSyncTitle2;

  /// No description provided for @onboardingSyncBody.
  ///
  /// In en, this message translates to:
  /// **'Connect to your healthcare providers to import your real medical records'**
  String get onboardingSyncBody;

  /// No description provided for @givenName.
  ///
  /// In en, this message translates to:
  /// **'Given Name'**
  String get givenName;

  /// No description provided for @familyName.
  ///
  /// In en, this message translates to:
  /// **'Family Name'**
  String get familyName;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @setUpProfile.
  ///
  /// In en, this message translates to:
  /// **'Set Up'**
  String get setUpProfile;

  /// No description provided for @useDefaults.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get useDefaults;

  /// No description provided for @syncPlaceholderTutorialStep1.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile to unlock full features.'**
  String get syncPlaceholderTutorialStep1;

  /// No description provided for @syncPlaceholderTutorialStep2.
  ///
  /// In en, this message translates to:
  /// **'Not ready to import? Load demo data to see how the app looks in action.'**
  String get syncPlaceholderTutorialStep2;

  /// No description provided for @syncPlaceholderTutorialStep3.
  ///
  /// In en, this message translates to:
  /// **'Keep your desktop and mobile wallet up to date.'**
  String get syncPlaceholderTutorialStep3;

  /// No description provided for @tapToContinue.
  ///
  /// In en, this message translates to:
  /// **'Tap to continue'**
  String get tapToContinue;

  /// No description provided for @homeOnboardingReorderMessage.
  ///
  /// In en, this message translates to:
  /// **'Long press to reorder them according to your preference.'**
  String get homeOnboardingReorderMessage;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processing;

  /// No description provided for @sessionNotFound.
  ///
  /// In en, this message translates to:
  /// **'Session not found!'**
  String get sessionNotFound;

  /// No description provided for @preparingPreview.
  ///
  /// In en, this message translates to:
  /// **'Preparing preview...'**
  String get preparingPreview;

  /// No description provided for @processingFailed.
  ///
  /// In en, this message translates to:
  /// **'Processing failed'**
  String get processingFailed;

  /// No description provided for @modelNotFoundError.
  ///
  /// In en, this message translates to:
  /// **'Model file not found. Please download the AI model first.'**
  String get modelNotFoundError;

  /// No description provided for @modelCorruptedError.
  ///
  /// In en, this message translates to:
  /// **'Model file is corrupted. Please re-download the AI model.'**
  String get modelCorruptedError;

  /// No description provided for @processingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Processing was cancelled'**
  String get processingCancelled;

  /// No description provided for @processingBasicDetails.
  ///
  /// In en, this message translates to:
  /// **'Processing basic details...'**
  String get processingBasicDetails;

  /// No description provided for @processingPages.
  ///
  /// In en, this message translates to:
  /// **'Processing pages...'**
  String get processingPages;

  /// No description provided for @extractingPatientInfo.
  ///
  /// In en, this message translates to:
  /// **'Extracting patient and encounter info.'**
  String get extractingPatientInfo;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'It might take a while. Please wait.'**
  String get pleaseWait;

  /// No description provided for @focusMode.
  ///
  /// In en, this message translates to:
  /// **'Focus Mode'**
  String get focusMode;

  /// No description provided for @onlyOneSessionAtTime.
  ///
  /// In en, this message translates to:
  /// **'Only one processing session can run at a time'**
  String get onlyOneSessionAtTime;

  /// No description provided for @aiModelNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Smart scanning is not available'**
  String get aiModelNotAvailable;

  /// No description provided for @addResources.
  ///
  /// In en, this message translates to:
  /// **'Add resources'**
  String get addResources;

  /// No description provided for @addResourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Resources'**
  String get addResourcesTitle;

  /// No description provided for @chooseResourcesDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the resources you want to add for processing.'**
  String get chooseResourcesDescription;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @allergyIntolerance.
  ///
  /// In en, this message translates to:
  /// **'Allergy Intolerance'**
  String get allergyIntolerance;

  /// No description provided for @condition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get condition;

  /// No description provided for @diagnosticReport.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic Report'**
  String get diagnosticReport;

  /// No description provided for @medicationStatement.
  ///
  /// In en, this message translates to:
  /// **'Medication Statement'**
  String get medicationStatement;

  /// No description provided for @observation.
  ///
  /// In en, this message translates to:
  /// **'Observation'**
  String get observation;

  /// No description provided for @organization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get organization;

  /// No description provided for @practitioner.
  ///
  /// In en, this message translates to:
  /// **'Practitioner'**
  String get practitioner;

  /// No description provided for @procedure.
  ///
  /// In en, this message translates to:
  /// **'Procedure'**
  String get procedure;

  /// No description provided for @tapToViewProgress.
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to view progress'**
  String get tapToViewProgress;

  /// No description provided for @screenWillDarkenInSeconds.
  ///
  /// In en, this message translates to:
  /// **'The screen will darken in {remainingSeconds} seconds.'**
  String screenWillDarkenInSeconds(int remainingSeconds);

  /// No description provided for @screenWillDarkenInZeroSeconds.
  ///
  /// In en, this message translates to:
  /// **'The screen will darken in 0 seconds.'**
  String get screenWillDarkenInZeroSeconds;

  /// No description provided for @whileDocumentsProcessed.
  ///
  /// In en, this message translates to:
  /// **'While your documents are being processed:'**
  String get whileDocumentsProcessed;

  /// No description provided for @doNotLockScreen.
  ///
  /// In en, this message translates to:
  /// **'Do not lock the screen or exit the app.'**
  String get doNotLockScreen;

  /// No description provided for @plugInCharger.
  ///
  /// In en, this message translates to:
  /// **'Plug in the charger.'**
  String get plugInCharger;

  /// No description provided for @exitFocusMode.
  ///
  /// In en, this message translates to:
  /// **'Exit Focus Mode'**
  String get exitFocusMode;

  /// No description provided for @chargerPluggedIn.
  ///
  /// In en, this message translates to:
  /// **'Charger plugged in.'**
  String get chargerPluggedIn;

  /// No description provided for @plugInChargerEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Plug in the charger...'**
  String get plugInChargerEllipsis;

  /// No description provided for @processingFailedCapacity.
  ///
  /// In en, this message translates to:
  /// **'The document is too large for the current AI context size.'**
  String get processingFailedCapacity;

  /// No description provided for @processingFailedCapacitySuggestion.
  ///
  /// In en, this message translates to:
  /// **'Tap the settings icon above and increase the Context Size to 2048 or higher, then retry.'**
  String get processingFailedCapacitySuggestion;

  /// No description provided for @increaseAiModelCapacity.
  ///
  /// In en, this message translates to:
  /// **'Increase AI Capacity'**
  String get increaseAiModelCapacity;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @aiModelManage.
  ///
  /// In en, this message translates to:
  /// **'Manage AI Options'**
  String get aiModelManage;

  /// No description provided for @aiModelNotSelected.
  ///
  /// In en, this message translates to:
  /// **'No option selected'**
  String get aiModelNotSelected;

  /// No description provided for @aiModelSelect.
  ///
  /// In en, this message translates to:
  /// **'Select Option'**
  String get aiModelSelect;

  /// No description provided for @aiSettings.
  ///
  /// In en, this message translates to:
  /// **'AI Settings'**
  String get aiSettings;

  /// No description provided for @aiSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Adjust AI performance for your device. Recommended values are pre-selected.'**
  String get aiSettingsDescription;

  /// No description provided for @setAiTokensUsage.
  ///
  /// In en, this message translates to:
  /// **'Set AI Tokens Usage'**
  String get setAiTokensUsage;

  /// No description provided for @tokenUsageDescription.
  ///
  /// In en, this message translates to:
  /// **'Control how much processing power the AI can use. Higher capacity allows larger files and more complex tasks, but uses more resources and takes longer.'**
  String get tokenUsageDescription;

  /// No description provided for @gpuLayersLabel.
  ///
  /// In en, this message translates to:
  /// **'GPU Layers'**
  String get gpuLayersLabel;

  /// No description provided for @gpuLayersDescription.
  ///
  /// In en, this message translates to:
  /// **'Offload model layers to GPU for faster image processing. More layers = faster but uses more memory. Set to 0 if the app crashes.'**
  String get gpuLayersDescription;

  /// No description provided for @threadsLabel.
  ///
  /// In en, this message translates to:
  /// **'CPU Threads'**
  String get threadsLabel;

  /// No description provided for @threadsDescription.
  ///
  /// In en, this message translates to:
  /// **'Number of CPU threads for inference. More threads = faster but uses more battery.'**
  String get threadsDescription;

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommended;

  /// No description provided for @tokenPresetLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get tokenPresetLow;

  /// No description provided for @tokenPresetLowDescription.
  ///
  /// In en, this message translates to:
  /// **'Best for small files and quick tasks.\nUses the least resources and processes fastest.'**
  String get tokenPresetLowDescription;

  /// No description provided for @tokenPresetMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get tokenPresetMedium;

  /// No description provided for @tokenPresetMediumDescription.
  ///
  /// In en, this message translates to:
  /// **'Good for most use cases.\nBalances file size, processing time, and resource usage.'**
  String get tokenPresetMediumDescription;

  /// No description provided for @tokenPresetHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get tokenPresetHigh;

  /// No description provided for @tokenPresetHighDescription.
  ///
  /// In en, this message translates to:
  /// **'Best for large files and complex processing.\nUses more resources and battery, and takes longer to complete.'**
  String get tokenPresetHighDescription;

  /// No description provided for @tokenPresetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get tokenPresetCustom;

  /// No description provided for @tokenPresetCustomDescription.
  ///
  /// In en, this message translates to:
  /// **'Set custom amount of tokens you want to use.'**
  String get tokenPresetCustomDescription;

  /// No description provided for @setTokens.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get setTokens;

  /// No description provided for @tokens.
  ///
  /// In en, this message translates to:
  /// **'tokens'**
  String get tokens;

  /// No description provided for @contextSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Context Size'**
  String get contextSizeLabel;

  /// No description provided for @contextSizeDescription.
  ///
  /// In en, this message translates to:
  /// **'Amount of text the AI can process at once. Larger context handles bigger documents but uses more memory.'**
  String get contextSizeDescription;

  /// No description provided for @useVisionLabel.
  ///
  /// In en, this message translates to:
  /// **'Deep Scan'**
  String get useVisionLabel;

  /// No description provided for @useVisionDescription.
  ///
  /// In en, this message translates to:
  /// **'Reads images for deeper analysis (e.g. handwriting). Uses more memory and requires a more performant device.'**
  String get useVisionDescription;

  /// No description provided for @aiModelNotAvailableForDevice.
  ///
  /// In en, this message translates to:
  /// **'Not available for this phone'**
  String get aiModelNotAvailableForDevice;

  /// No description provided for @aiModelNotAvailableForDeviceDescription.
  ///
  /// In en, this message translates to:
  /// **'Sorry, your device doesn\'t have enough memory to run the AI model. You can still use the app without smart scanning.'**
  String get aiModelNotAvailableForDeviceDescription;

  /// No description provided for @noInternetConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'No Internet Connection'**
  String get noInternetConnectionTitle;

  /// No description provided for @noInternetConnectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Please check your internet connection and try again.'**
  String get noInternetConnectionDescription;

  /// No description provided for @processingStep2NotAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Deep Scan not available on this device'**
  String get processingStep2NotAvailableTitle;

  /// No description provided for @processingStep2NotEnoughRam.
  ///
  /// In en, this message translates to:
  /// **'This device doesn\'t have enough memory for Deep Scan. Text-based processing is still available and works well for most documents.'**
  String get processingStep2NotEnoughRam;

  /// No description provided for @emergencyContact.
  ///
  /// In en, this message translates to:
  /// **'Emergency Phone Contact'**
  String get emergencyContact;

  /// No description provided for @emergencyContactHint.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get emergencyContactHint;

  /// No description provided for @searchCountry.
  ///
  /// In en, this message translates to:
  /// **'Search country...'**
  String get searchCountry;

  /// No description provided for @rotatePage.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get rotatePage;

  /// No description provided for @deletePage.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deletePage;

  /// No description provided for @deletePageConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Page'**
  String get deletePageConfirmTitle;

  /// No description provided for @deletePageConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This page will be removed from the document.'**
  String get deletePageConfirmMessage;

  /// No description provided for @cannotDeleteLastPage.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete the last page'**
  String get cannotDeleteLastPage;

  /// No description provided for @pageRotated.
  ///
  /// In en, this message translates to:
  /// **'Page rotated'**
  String get pageRotated;

  /// No description provided for @regionAndUnits.
  ///
  /// In en, this message translates to:
  /// **'Language & Units'**
  String get regionAndUnits;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @patientModifiedNewWillBeCreated.
  ///
  /// In en, this message translates to:
  /// **'Modified — a new patient will be created'**
  String get patientModifiedNewWillBeCreated;

  /// No description provided for @patientModifiedUpdating.
  ///
  /// In en, this message translates to:
  /// **'Modifying existing patient: {name}'**
  String patientModifiedUpdating(String name);

  /// No description provided for @patientSavingModified.
  ///
  /// In en, this message translates to:
  /// **'Saving modified patient: {name}'**
  String patientSavingModified(String name);

  /// No description provided for @dropModificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Drop modifications?'**
  String get dropModificationsTitle;

  /// No description provided for @dropModificationsMessage.
  ///
  /// In en, this message translates to:
  /// **'Your changes to the patient fields will be discarded.'**
  String get dropModificationsMessage;

  /// No description provided for @modifyPatientTitle.
  ///
  /// In en, this message translates to:
  /// **'Modify patient?'**
  String get modifyPatientTitle;

  /// No description provided for @modifyPatientMessage.
  ///
  /// In en, this message translates to:
  /// **'This will update the existing patient record with your changes.'**
  String get modifyPatientMessage;

  /// No description provided for @scanIdCard.
  ///
  /// In en, this message translates to:
  /// **'Scan ID Card or Passport'**
  String get scanIdCard;

  /// No description provided for @scanIdCardDescription.
  ///
  /// In en, this message translates to:
  /// **'Auto-fill from your document. Data stays on your device.'**
  String get scanIdCardDescription;

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// No description provided for @newPatient.
  ///
  /// In en, this message translates to:
  /// **'New patient'**
  String get newPatient;

  /// No description provided for @patientChangedTo.
  ///
  /// In en, this message translates to:
  /// **'Changed to: {name}'**
  String patientChangedTo(String name);

  /// No description provided for @patientMatchFound.
  ///
  /// In en, this message translates to:
  /// **'Existing patient: {name}'**
  String patientMatchFound(String name);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @regionUS.
  ///
  /// In en, this message translates to:
  /// **'US'**
  String get regionUS;

  /// No description provided for @regionEurope.
  ///
  /// In en, this message translates to:
  /// **'Europe'**
  String get regionEurope;

  /// No description provided for @regionUK.
  ///
  /// In en, this message translates to:
  /// **'UK'**
  String get regionUK;

  /// No description provided for @medGemmaIncompatibleDevice.
  ///
  /// In en, this message translates to:
  /// **'This model requires more memory than your device has available. Use the Lite model instead.'**
  String get medGemmaIncompatibleDevice;

  /// No description provided for @deepScanDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Download Vision Model'**
  String get deepScanDownloadTitle;

  /// No description provided for @deepScanDownloadMessage.
  ///
  /// In en, this message translates to:
  /// **'Deep Scan requires an additional download (~{size} MB). Download now?'**
  String deepScanDownloadMessage(int size);

  /// No description provided for @downloadingVisionModel.
  ///
  /// In en, this message translates to:
  /// **'Downloading vision model...'**
  String get downloadingVisionModel;

  /// No description provided for @shareUnknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown Device'**
  String get shareUnknownDevice;

  /// No description provided for @shareViewOnlyBanner.
  ///
  /// In en, this message translates to:
  /// **'VIEW ONLY - Data will be deleted when you close the session or leave proximity area'**
  String get shareViewOnlyBanner;

  /// No description provided for @shareViewOnlyBannerViewing.
  ///
  /// In en, this message translates to:
  /// **'VIEW ONLY - Data will be deleted when you exit'**
  String get shareViewOnlyBannerViewing;

  /// No description provided for @shareInfoBannerMessage.
  ///
  /// In en, this message translates to:
  /// **'Shared records are view-only. All data is automatically deleted when the session ends or the time limit expires.'**
  String get shareInfoBannerMessage;

  /// No description provided for @shareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareTitle;

  /// No description provided for @shareFindDevices.
  ///
  /// In en, this message translates to:
  /// **'Find Devices'**
  String get shareFindDevices;

  /// No description provided for @shareWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting...'**
  String get shareWaiting;

  /// No description provided for @shareConnectingTitle.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get shareConnectingTitle;

  /// No description provided for @shareSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get shareSending;

  /// No description provided for @shareReceiving.
  ///
  /// In en, this message translates to:
  /// **'Receiving'**
  String get shareReceiving;

  /// No description provided for @shareSessionActive.
  ///
  /// In en, this message translates to:
  /// **'Session Active'**
  String get shareSessionActive;

  /// No description provided for @shareViewingRecords.
  ///
  /// In en, this message translates to:
  /// **'Viewing Records'**
  String get shareViewingRecords;

  /// No description provided for @shareComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get shareComplete;

  /// No description provided for @shareError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get shareError;

  /// No description provided for @sharePermissionsRequired.
  ///
  /// In en, this message translates to:
  /// **'Permissions Required'**
  String get sharePermissionsRequired;

  /// No description provided for @shareHealthWalletDevice.
  ///
  /// In en, this message translates to:
  /// **'HealthWallet Device'**
  String get shareHealthWalletDevice;

  /// No description provided for @shareInvitationDeclined.
  ///
  /// In en, this message translates to:
  /// **'Invitation Declined'**
  String get shareInvitationDeclined;

  /// No description provided for @shareSessionComplete.
  ///
  /// In en, this message translates to:
  /// **'Session Complete'**
  String get shareSessionComplete;

  /// No description provided for @shareInvitationDeclinedMessage.
  ///
  /// In en, this message translates to:
  /// **'The receiver declined your invitation to view the records.'**
  String get shareInvitationDeclinedMessage;

  /// No description provided for @shareSessionCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'All shared data has been securely removed from this device'**
  String get shareSessionCompleteMessage;

  /// No description provided for @shareBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back Home'**
  String get shareBackHome;

  /// No description provided for @shareConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection Failed'**
  String get shareConnectionFailed;

  /// No description provided for @shareUnableToConnect.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect. Please try again.'**
  String get shareUnableToConnect;

  /// No description provided for @shareNoDataReceived.
  ///
  /// In en, this message translates to:
  /// **'No data received'**
  String get shareNoDataReceived;

  /// No description provided for @shareSearchRecords.
  ///
  /// In en, this message translates to:
  /// **'Search records'**
  String get shareSearchRecords;

  /// No description provided for @shareNoRecordsMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No records match the filters'**
  String get shareNoRecordsMatchFilters;

  /// No description provided for @shareNoRecordsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No records available'**
  String get shareNoRecordsAvailable;

  /// No description provided for @shareReceiverViewingRecords.
  ///
  /// In en, this message translates to:
  /// **'Receiver is viewing records'**
  String get shareReceiverViewingRecords;

  /// No description provided for @shareSessionAutoExpire.
  ///
  /// In en, this message translates to:
  /// **'Session will auto-expire when timer reaches zero'**
  String get shareSessionAutoExpire;

  /// No description provided for @shareRecordsDelivered.
  ///
  /// In en, this message translates to:
  /// **'Records delivered successfully'**
  String get shareRecordsDelivered;

  /// No description provided for @shareConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get shareConnecting;

  /// No description provided for @shareConnectionInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Connection interrupted, reconnecting'**
  String get shareConnectionInterrupted;

  /// No description provided for @shareSendingRecords.
  ///
  /// In en, this message translates to:
  /// **'Sending records...'**
  String get shareSendingRecords;

  /// No description provided for @shareReceivingRecords.
  ///
  /// In en, this message translates to:
  /// **'Receiving records...'**
  String get shareReceivingRecords;

  /// No description provided for @shareConfirmExit.
  ///
  /// In en, this message translates to:
  /// **'Confirm Exit'**
  String get shareConfirmExit;

  /// No description provided for @shareDeleteSharedRecords.
  ///
  /// In en, this message translates to:
  /// **'Delete Shared Records?'**
  String get shareDeleteSharedRecords;

  /// No description provided for @shareDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'The shared record will be permanently deleted from this device. Action cannot be undone'**
  String get shareDeleteWarning;

  /// No description provided for @shareDeleteAndExit.
  ///
  /// In en, this message translates to:
  /// **'Delete & Exit'**
  String get shareDeleteAndExit;

  /// No description provided for @shareIncomingTransfer.
  ///
  /// In en, this message translates to:
  /// **'Incoming Transfer'**
  String get shareIncomingTransfer;

  /// No description provided for @shareViewOnlyWarning.
  ///
  /// In en, this message translates to:
  /// **'Records will be view-only and automatically deleted when you exit'**
  String get shareViewOnlyWarning;

  /// No description provided for @shareDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get shareDecline;

  /// No description provided for @shareAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get shareAccept;

  /// No description provided for @shareSearchingForDevices.
  ///
  /// In en, this message translates to:
  /// **'Searching for nearby devices...'**
  String get shareSearchingForDevices;

  /// No description provided for @shareSearchForDevices.
  ///
  /// In en, this message translates to:
  /// **'Search for devices...'**
  String get shareSearchForDevices;

  /// No description provided for @shareNoDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No Devices Found'**
  String get shareNoDevicesFound;

  /// No description provided for @shareConnectionIssue.
  ///
  /// In en, this message translates to:
  /// **'Connection Issue'**
  String get shareConnectionIssue;

  /// No description provided for @shareWifiDirectUnresponsive.
  ///
  /// In en, this message translates to:
  /// **'WiFi Direct is unresponsive on this device.'**
  String get shareWifiDirectUnresponsive;

  /// No description provided for @shareWifiToggleHint.
  ///
  /// In en, this message translates to:
  /// **'WiFi Direct unresponsive. Toggle WiFi off/on, then tap Retry.'**
  String get shareWifiToggleHint;

  /// No description provided for @shareDiscoveryHint.
  ///
  /// In en, this message translates to:
  /// **'Make sure the other device has the HealthWallet.me app opened'**
  String get shareDiscoveryHint;

  /// No description provided for @shareProximityHint.
  ///
  /// In en, this message translates to:
  /// **'The receiving device must have Share Proximity ON in Preferences to be discoverable.'**
  String get shareProximityHint;

  /// No description provided for @shareNoRecordsMatchSelectedFilters.
  ///
  /// In en, this message translates to:
  /// **'No records match the selected filters'**
  String get shareNoRecordsMatchSelectedFilters;

  /// No description provided for @shareNoRecordsForAppliedFilters.
  ///
  /// In en, this message translates to:
  /// **'No records found for the applied filters'**
  String get shareNoRecordsForAppliedFilters;

  /// No description provided for @shareTryClearingFilters.
  ///
  /// In en, this message translates to:
  /// **'Try clearing some filters'**
  String get shareTryClearingFilters;

  /// No description provided for @shareRecordsPageFiltersNoResults.
  ///
  /// In en, this message translates to:
  /// **'The Records page filters returned no results'**
  String get shareRecordsPageFiltersNoResults;

  /// No description provided for @shareImportOrSyncRecords.
  ///
  /// In en, this message translates to:
  /// **'Import or sync records to share them'**
  String get shareImportOrSyncRecords;

  /// No description provided for @shareSessionTime.
  ///
  /// In en, this message translates to:
  /// **'Session time'**
  String get shareSessionTime;

  /// No description provided for @shareSetAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get shareSetAsDefault;

  /// No description provided for @shareRecordsButton.
  ///
  /// In en, this message translates to:
  /// **'Share Records'**
  String get shareRecordsButton;

  /// No description provided for @shareSelectRecordsToShare.
  ///
  /// In en, this message translates to:
  /// **'Select records to share'**
  String get shareSelectRecordsToShare;

  /// No description provided for @shareEndSession.
  ///
  /// In en, this message translates to:
  /// **'End Session'**
  String get shareEndSession;

  /// No description provided for @shareRequestTenMin.
  ///
  /// In en, this message translates to:
  /// **'Request +10 min'**
  String get shareRequestTenMin;

  /// No description provided for @shareWaitingForResponse.
  ///
  /// In en, this message translates to:
  /// **'Waiting for response...'**
  String get shareWaitingForResponse;

  /// No description provided for @shareAddMoreTime.
  ///
  /// In en, this message translates to:
  /// **'Add more time'**
  String get shareAddMoreTime;

  /// No description provided for @shareSessionExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'Session expires in'**
  String get shareSessionExpiresIn;

  /// No description provided for @shareExtensionRequestedTitle.
  ///
  /// In en, this message translates to:
  /// **'Extension Requested'**
  String get shareExtensionRequestedTitle;

  /// No description provided for @shareHoursLabel.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get shareHoursLabel;

  /// No description provided for @shareMinLabel.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get shareMinLabel;

  /// No description provided for @shareSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String shareSelectedCount(int count);

  /// No description provided for @shareRecordCount.
  ///
  /// In en, this message translates to:
  /// **'{recordCount} record(s)'**
  String shareRecordCount(int recordCount);

  /// No description provided for @shareSharedFrom.
  ///
  /// In en, this message translates to:
  /// **'shared from {source}'**
  String shareSharedFrom(String source);

  /// No description provided for @shareFoundDevices.
  ///
  /// In en, this message translates to:
  /// **'Found {count} device(s)'**
  String shareFoundDevices(int count);

  /// No description provided for @shareRetryingCount.
  ///
  /// In en, this message translates to:
  /// **'Retrying ({retryCount}/3)...'**
  String shareRetryingCount(int retryCount);

  /// No description provided for @shareDeviceWantsToShare.
  ///
  /// In en, this message translates to:
  /// **'{deviceName} wants to share records with you'**
  String shareDeviceWantsToShare(String deviceName);

  /// No description provided for @shareExtensionsUsed.
  ///
  /// In en, this message translates to:
  /// **'{used}/{max} extensions used'**
  String shareExtensionsUsed(int used, int max);

  /// No description provided for @shareDurationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes} min'**
  String shareDurationHoursMinutes(int hours, int minutes);

  /// No description provided for @shareDurationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String shareDurationHours(int hours);

  /// No description provided for @shareDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String shareDurationMinutes(int minutes);

  /// No description provided for @shareTimerHoursMinutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}min {seconds}s'**
  String shareTimerHoursMinutesSeconds(int hours, int minutes, int seconds);

  /// No description provided for @shareTimerMinutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{minutes}min {seconds}s'**
  String shareTimerMinutesSeconds(int minutes, int seconds);

  /// No description provided for @shareTimerSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String shareTimerSeconds(int seconds);

  /// No description provided for @shareMinuteCount.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minute(s)'**
  String shareMinuteCount(int minutes);

  /// No description provided for @shareSecondsCount.
  ///
  /// In en, this message translates to:
  /// **'{seconds} seconds'**
  String shareSecondsCount(int seconds);

  /// No description provided for @shareExtensionRequestMessage.
  ///
  /// In en, this message translates to:
  /// **'The {peerRole} wants to extend the session by {duration}'**
  String shareExtensionRequestMessage(String peerRole, String duration);

  /// No description provided for @shareExtensionDurationRequested.
  ///
  /// In en, this message translates to:
  /// **'{duration} requested'**
  String shareExtensionDurationRequested(String duration);

  /// No description provided for @desktopSyncNotYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get desktopSyncNotYet;

  /// No description provided for @desktopSyncTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get desktopSyncTransfer;

  /// No description provided for @desktopSyncTransferValue.
  ///
  /// In en, this message translates to:
  /// **'{sentRows} sent, {receivedRows} received'**
  String desktopSyncTransferValue(int sentRows, int receivedRows);

  /// No description provided for @desktopSyncPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get desktopSyncPending;

  /// No description provided for @desktopSyncPendingValue.
  ///
  /// In en, this message translates to:
  /// **'{count} changes'**
  String desktopSyncPendingValue(int count);

  /// No description provided for @desktopSyncingTable.
  ///
  /// In en, this message translates to:
  /// **'Syncing {tableName}...'**
  String desktopSyncingTable(String tableName);

  /// No description provided for @desktopSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get desktopSyncing;

  /// No description provided for @desktopSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get desktopSyncNow;

  /// No description provided for @desktopSyncError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get desktopSyncError;

  /// No description provided for @desktopSyncInSync.
  ///
  /// In en, this message translates to:
  /// **'In Sync'**
  String get desktopSyncInSync;

  /// No description provided for @desktopSyncReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get desktopSyncReady;

  /// No description provided for @desktopSyncOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get desktopSyncOffline;

  /// No description provided for @desktopTableHealthRecords.
  ///
  /// In en, this message translates to:
  /// **'Health Records'**
  String get desktopTableHealthRecords;

  /// No description provided for @desktopTableSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get desktopTableSources;

  /// No description provided for @desktopTableNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get desktopTableNotes;

  /// No description provided for @desktopTableSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get desktopTableSessions;

  /// No description provided for @desktopConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get desktopConnection;

  /// No description provided for @desktopGeneratePairingQr.
  ///
  /// In en, this message translates to:
  /// **'Generate Pairing QR'**
  String get desktopGeneratePairingQr;

  /// No description provided for @desktopScanFromMobile.
  ///
  /// In en, this message translates to:
  /// **'Scan from mobile Sync page'**
  String get desktopScanFromMobile;

  /// No description provided for @desktopDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get desktopDevice;

  /// No description provided for @desktopTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get desktopTransport;

  /// No description provided for @desktopIp.
  ///
  /// In en, this message translates to:
  /// **'IP'**
  String get desktopIp;

  /// No description provided for @desktopPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get desktopPort;

  /// No description provided for @desktopNewPairing.
  ///
  /// In en, this message translates to:
  /// **'New Pairing'**
  String get desktopNewPairing;

  /// No description provided for @desktopTransportTcp.
  ///
  /// In en, this message translates to:
  /// **'TCP over WiFi'**
  String get desktopTransportTcp;

  /// No description provided for @desktopTransportMpc.
  ///
  /// In en, this message translates to:
  /// **'MultipeerConnectivity (Direct)'**
  String get desktopTransportMpc;

  /// No description provided for @desktopConnectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected to {name}'**
  String desktopConnectedTo(String name);

  /// No description provided for @desktopConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get desktopConnected;

  /// No description provided for @desktopReconnectingTo.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting to {name}...'**
  String desktopReconnectingTo(String name);

  /// No description provided for @desktopReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get desktopReconnecting;

  /// No description provided for @desktopDisconnectedFrom.
  ///
  /// In en, this message translates to:
  /// **'Disconnected from {name}'**
  String desktopDisconnectedFrom(String name);

  /// No description provided for @desktopDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get desktopDisconnected;

  /// No description provided for @desktopDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get desktopDisconnect;

  /// No description provided for @desktopReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get desktopReconnect;

  /// No description provided for @desktopVpnDetected.
  ///
  /// In en, this message translates to:
  /// **'VPN detected. Disconnect VPN to sync with desktop.'**
  String get desktopVpnDetected;

  /// No description provided for @desktopPairing.
  ///
  /// In en, this message translates to:
  /// **'Pairing'**
  String get desktopPairing;

  /// No description provided for @desktopLabel.
  ///
  /// In en, this message translates to:
  /// **'Desktop'**
  String get desktopLabel;

  /// No description provided for @desktopScanFromPhoneToPair.
  ///
  /// In en, this message translates to:
  /// **'Scan from your phone to pair'**
  String get desktopScanFromPhoneToPair;

  /// No description provided for @desktopNewQrCode.
  ///
  /// In en, this message translates to:
  /// **'New QR Code'**
  String get desktopNewQrCode;

  /// No description provided for @desktopGenerateQrCode.
  ///
  /// In en, this message translates to:
  /// **'Generate QR Code'**
  String get desktopGenerateQrCode;

  /// No description provided for @desktopScanQrCode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get desktopScanQrCode;

  /// No description provided for @desktopChooseWhereToSave.
  ///
  /// In en, this message translates to:
  /// **'Choose where to save backups'**
  String get desktopChooseWhereToSave;

  /// No description provided for @desktopSelectBackupFolder.
  ///
  /// In en, this message translates to:
  /// **'Select a folder on your computer to store backup files'**
  String get desktopSelectBackupFolder;

  /// No description provided for @desktopChooseLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose Location'**
  String get desktopChooseLocation;

  /// No description provided for @desktopChooseBackupLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose Backup Location'**
  String get desktopChooseBackupLocation;

  /// No description provided for @desktopBackingUp.
  ///
  /// In en, this message translates to:
  /// **'Backing up...'**
  String get desktopBackingUp;

  /// No description provided for @desktopCreateBackup.
  ///
  /// In en, this message translates to:
  /// **'Create Backup'**
  String get desktopCreateBackup;

  /// No description provided for @desktopSyncWithPhoneFirst.
  ///
  /// In en, this message translates to:
  /// **'Sync with phone first'**
  String get desktopSyncWithPhoneFirst;

  /// No description provided for @desktopNotConnected.
  ///
  /// In en, this message translates to:
  /// **'(not connected)'**
  String get desktopNotConnected;

  /// No description provided for @desktopStartBackup.
  ///
  /// In en, this message translates to:
  /// **'Start Backup'**
  String get desktopStartBackup;

  /// No description provided for @desktopNoBackupsYet.
  ///
  /// In en, this message translates to:
  /// **'No backups yet'**
  String get desktopNoBackupsYet;

  /// No description provided for @desktopCreateFirstBackup.
  ///
  /// In en, this message translates to:
  /// **'Create your first backup to keep your health data safe'**
  String get desktopCreateFirstBackup;

  /// No description provided for @desktopAllBackups.
  ///
  /// In en, this message translates to:
  /// **'All backups'**
  String get desktopAllBackups;

  /// No description provided for @desktopDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get desktopDate;

  /// No description provided for @desktopSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get desktopSize;

  /// No description provided for @desktopChecksum.
  ///
  /// In en, this message translates to:
  /// **'Checksum'**
  String get desktopChecksum;

  /// No description provided for @desktopRestoreThisBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore this backup'**
  String get desktopRestoreThisBackup;

  /// No description provided for @desktopRestoreBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore Backup?'**
  String get desktopRestoreBackupTitle;

  /// No description provided for @desktopRestoreBackupMessage.
  ///
  /// In en, this message translates to:
  /// **'This will replace all current data on this device with \"{name}\".\n\n{count} records will be restored.\n\nYour data on the paired phone will not be affected.'**
  String desktopRestoreBackupMessage(String name, int count);

  /// No description provided for @desktopRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get desktopRestore;

  /// No description provided for @desktopDeleteBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Backup?'**
  String get desktopDeleteBackupTitle;

  /// No description provided for @desktopDeleteBackupMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?\n\nThis cannot be undone.'**
  String desktopDeleteBackupMessage(String name);

  /// No description provided for @desktopDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get desktopDelete;

  /// No description provided for @desktopBackupFrom.
  ///
  /// In en, this message translates to:
  /// **'Backup from'**
  String get desktopBackupFrom;

  /// No description provided for @desktopBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get desktopBackup;

  /// No description provided for @desktopChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get desktopChange;

  /// No description provided for @desktopProcessingHistory.
  ///
  /// In en, this message translates to:
  /// **'Processing History'**
  String get desktopProcessingHistory;

  /// No description provided for @desktopScannedOnPhone.
  ///
  /// In en, this message translates to:
  /// **'Scanned on Phone'**
  String get desktopScannedOnPhone;

  /// No description provided for @desktopProcessedOnDesktop.
  ///
  /// In en, this message translates to:
  /// **'Processed on Desktop'**
  String get desktopProcessedOnDesktop;

  /// No description provided for @desktopImportedOnDesktop.
  ///
  /// In en, this message translates to:
  /// **'Imported on Desktop'**
  String get desktopImportedOnDesktop;

  /// No description provided for @desktopSyncRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get desktopSyncRecent;

  /// No description provided for @desktopUnknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown device'**
  String get desktopUnknownDevice;

  /// No description provided for @desktopSyncHistoryTransfer.
  ///
  /// In en, this message translates to:
  /// **'{sentRows} sent · {receivedRows} received'**
  String desktopSyncHistoryTransfer(int sentRows, int receivedRows);

  /// No description provided for @desktopNewDeviceConnecting.
  ///
  /// In en, this message translates to:
  /// **'New Device Connecting'**
  String get desktopNewDeviceConnecting;

  /// No description provided for @desktopNewDeviceMessage.
  ///
  /// In en, this message translates to:
  /// **'A new device ({address}) wants to connect.\n\nThis will disconnect \"{currentDevice}\".\n\nSwitch to the new device?'**
  String desktopNewDeviceMessage(String address, String currentDevice);

  /// No description provided for @desktopKeepCurrent.
  ///
  /// In en, this message translates to:
  /// **'Keep Current'**
  String get desktopKeepCurrent;

  /// No description provided for @desktopSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get desktopSwitch;

  /// No description provided for @desktopCurrentDevice.
  ///
  /// In en, this message translates to:
  /// **'current device'**
  String get desktopCurrentDevice;

  /// No description provided for @desktopHandoverPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get desktopHandoverPreparing;

  /// No description provided for @desktopHandoverSendingFiles.
  ///
  /// In en, this message translates to:
  /// **'Sending files...'**
  String get desktopHandoverSendingFiles;

  /// No description provided for @desktopHandoverProcessingOnDesktop.
  ///
  /// In en, this message translates to:
  /// **'Processing on desktop...'**
  String get desktopHandoverProcessingOnDesktop;

  /// No description provided for @desktopHandoverComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete!'**
  String get desktopHandoverComplete;

  /// No description provided for @desktopHandoverError.
  ///
  /// In en, this message translates to:
  /// **'Error occurred'**
  String get desktopHandoverError;

  /// No description provided for @desktopHandoverSending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get desktopHandoverSending;

  /// No description provided for @desktopHandoverSendingToDesktop.
  ///
  /// In en, this message translates to:
  /// **'Sending to Desktop'**
  String get desktopHandoverSendingToDesktop;

  /// No description provided for @desktopHandoverFileCount.
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String desktopHandoverFileCount(int count);

  /// No description provided for @desktopHandoverSuccess.
  ///
  /// In en, this message translates to:
  /// **'Handed over to Desktop'**
  String get desktopHandoverSuccess;

  /// No description provided for @desktopClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get desktopClose;

  /// No description provided for @desktopContinueImporting.
  ///
  /// In en, this message translates to:
  /// **'Continue Importing'**
  String get desktopContinueImporting;

  /// No description provided for @desktopConnectToDesktop.
  ///
  /// In en, this message translates to:
  /// **'Connect to Desktop'**
  String get desktopConnectToDesktop;

  /// No description provided for @desktopCouldNotReconnect.
  ///
  /// In en, this message translates to:
  /// **'Could not reconnect. Scan QR code to pair again.'**
  String get desktopCouldNotReconnect;

  /// No description provided for @desktopScanQrToPair.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code on your desktop app to pair.'**
  String get desktopScanQrToPair;

  /// No description provided for @desktopHandoverToDesktop.
  ///
  /// In en, this message translates to:
  /// **'Handover to Desktop'**
  String get desktopHandoverToDesktop;

  /// No description provided for @desktopHandoverProcessingMessage.
  ///
  /// In en, this message translates to:
  /// **'Processing is in progress. Handover will cancel the current processing and send files to desktop.'**
  String get desktopHandoverProcessingMessage;

  /// No description provided for @desktopHandover.
  ///
  /// In en, this message translates to:
  /// **'Handover'**
  String get desktopHandover;

  /// No description provided for @attachedDocuments.
  ///
  /// In en, this message translates to:
  /// **'Attached Documents'**
  String get attachedDocuments;

  /// No description provided for @cameraPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera Permission Required'**
  String get cameraPermissionRequired;

  /// No description provided for @cameraPermissionRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'This app needs camera access to scan. Please grant permission to continue.'**
  String get cameraPermissionRequiredMessage;

  /// No description provided for @cameraPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera Permission Denied'**
  String get cameraPermissionDenied;

  /// No description provided for @cameraPermissionDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Camera permission has been permanently denied. Please enable it in Settings to use the scanner.'**
  String get cameraPermissionDeniedMessage;

  /// No description provided for @successTitle.
  ///
  /// In en, this message translates to:
  /// **'Success!'**
  String get successTitle;

  /// No description provided for @attachmentSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Successfully attached {count} documents to the encounter.'**
  String attachmentSuccessMessage(int count);

  /// No description provided for @encounterLabel.
  ///
  /// In en, this message translates to:
  /// **'Encounter'**
  String get encounterLabel;

  /// No description provided for @viewRecords.
  ///
  /// In en, this message translates to:
  /// **'View Records'**
  String get viewRecords;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorTitle;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @importDocument.
  ///
  /// In en, this message translates to:
  /// **'Import Document'**
  String get importDocument;

  /// No description provided for @pickImageFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Pick Image from Gallery'**
  String get pickImageFromGallery;

  /// No description provided for @scanDocument.
  ///
  /// In en, this message translates to:
  /// **'Scan Document'**
  String get scanDocument;

  /// No description provided for @deleteSession.
  ///
  /// In en, this message translates to:
  /// **'Delete Session'**
  String get deleteSession;

  /// No description provided for @deleteSessionConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this session?'**
  String get deleteSessionConfirmation;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @canceling.
  ///
  /// In en, this message translates to:
  /// **'Canceling...'**
  String get canceling;

  /// No description provided for @waitingForAiToFinish.
  ///
  /// In en, this message translates to:
  /// **'Waiting for AI to finish...'**
  String get waitingForAiToFinish;

  /// No description provided for @logsCopied.
  ///
  /// In en, this message translates to:
  /// **'Logs copied'**
  String get logsCopied;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @tapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap to select'**
  String get tapToSelect;

  /// No description provided for @deviceInfoChip.
  ///
  /// In en, this message translates to:
  /// **'{platform}  •  {ramGB}GB RAM  •  {cores} cores  •  ~{estimatedMB}MB needed'**
  String deviceInfoChip(
    String platform,
    String ramGB,
    int cores,
    int estimatedMB,
  );

  /// No description provided for @downloadContinuesInBackground.
  ///
  /// In en, this message translates to:
  /// **'You can navigate away - download will continue in background.\nCheck notifications for progress.'**
  String get downloadContinuesInBackground;

  /// No description provided for @continueWithoutAi.
  ///
  /// In en, this message translates to:
  /// **'Continue without AI (download in background)'**
  String get continueWithoutAi;

  /// No description provided for @continueUsingApp.
  ///
  /// In en, this message translates to:
  /// **'Continue using app'**
  String get continueUsingApp;

  /// No description provided for @attachWithoutProcessing.
  ///
  /// In en, this message translates to:
  /// **'I want to attach the document without processing'**
  String get attachWithoutProcessing;

  /// No description provided for @currentPatientAndSource.
  ///
  /// In en, this message translates to:
  /// **'Current Patient & Source'**
  String get currentPatientAndSource;

  /// No description provided for @createEncounter.
  ///
  /// In en, this message translates to:
  /// **'Create Encounter'**
  String get createEncounter;

  /// No description provided for @encounterName.
  ///
  /// In en, this message translates to:
  /// **'Encounter name'**
  String get encounterName;

  /// No description provided for @enterEncounterName.
  ///
  /// In en, this message translates to:
  /// **'Enter encounter name'**
  String get enterEncounterName;

  /// No description provided for @pleaseEnterEncounterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter an encounter name'**
  String get pleaseEnterEncounterName;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @searchEncounters.
  ///
  /// In en, this message translates to:
  /// **'Search encounters...'**
  String get searchEncounters;

  /// No description provided for @noEncountersFound.
  ///
  /// In en, this message translates to:
  /// **'No encounters found'**
  String get noEncountersFound;

  /// No description provided for @noEncountersFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Create a new encounter first or select a different patient.'**
  String get noEncountersFoundMessage;

  /// No description provided for @newEncounterPrefix.
  ///
  /// In en, this message translates to:
  /// **'New encounter'**
  String get newEncounterPrefix;

  /// No description provided for @scannedDocumentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Scanned Documents'**
  String get scannedDocumentsTitle;

  /// No description provided for @scannedDocumentsPagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Scanned Documents ({count} pages)'**
  String scannedDocumentsPagesTitle(String count);

  /// No description provided for @pdfFileTitle.
  ///
  /// In en, this message translates to:
  /// **'PDF: {fileName}'**
  String pdfFileTitle(String fileName);

  /// No description provided for @labelOrganizationName.
  ///
  /// In en, this message translates to:
  /// **'Organization Name'**
  String get labelOrganizationName;

  /// No description provided for @labelAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get labelAddress;

  /// No description provided for @labelPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get labelPhone;

  /// No description provided for @labelEncounterName.
  ///
  /// In en, this message translates to:
  /// **'Encounter Name'**
  String get labelEncounterName;

  /// No description provided for @labelStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get labelStartDate;

  /// No description provided for @labelFirstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get labelFirstName;

  /// No description provided for @labelFamilyName.
  ///
  /// In en, this message translates to:
  /// **'Family name'**
  String get labelFamilyName;

  /// No description provided for @labelDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get labelDateOfBirth;

  /// No description provided for @labelGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get labelGender;

  /// No description provided for @labelReportName.
  ///
  /// In en, this message translates to:
  /// **'Report Name'**
  String get labelReportName;

  /// No description provided for @labelConclusion.
  ///
  /// In en, this message translates to:
  /// **'Conclusion'**
  String get labelConclusion;

  /// No description provided for @labelIssuedDate.
  ///
  /// In en, this message translates to:
  /// **'Issued Date'**
  String get labelIssuedDate;

  /// No description provided for @labelPractitionerName.
  ///
  /// In en, this message translates to:
  /// **'Practitioner Name'**
  String get labelPractitionerName;

  /// No description provided for @labelSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get labelSpecialty;

  /// No description provided for @labelIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Identifier'**
  String get labelIdentifier;

  /// No description provided for @labelConditionName.
  ///
  /// In en, this message translates to:
  /// **'Condition Name'**
  String get labelConditionName;

  /// No description provided for @labelOnsetDate.
  ///
  /// In en, this message translates to:
  /// **'Onset Date'**
  String get labelOnsetDate;

  /// No description provided for @labelClinicalStatus.
  ///
  /// In en, this message translates to:
  /// **'Clinical Status'**
  String get labelClinicalStatus;

  /// No description provided for @labelSubstance.
  ///
  /// In en, this message translates to:
  /// **'Substance'**
  String get labelSubstance;

  /// No description provided for @labelManifestation.
  ///
  /// In en, this message translates to:
  /// **'Manifestation'**
  String get labelManifestation;

  /// No description provided for @labelCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get labelCategory;

  /// No description provided for @labelProcedureName.
  ///
  /// In en, this message translates to:
  /// **'Procedure Name'**
  String get labelProcedureName;

  /// No description provided for @labelPerformedDate.
  ///
  /// In en, this message translates to:
  /// **'Performed Date'**
  String get labelPerformedDate;

  /// No description provided for @labelReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get labelReason;

  /// No description provided for @labelMedicationName.
  ///
  /// In en, this message translates to:
  /// **'Medication Name'**
  String get labelMedicationName;

  /// No description provided for @labelDosage.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get labelDosage;

  /// No description provided for @labelObservationName.
  ///
  /// In en, this message translates to:
  /// **'Observation name'**
  String get labelObservationName;

  /// No description provided for @labelValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get labelValue;

  /// No description provided for @labelUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get labelUnit;

  /// No description provided for @labelReferenceRange.
  ///
  /// In en, this message translates to:
  /// **'Reference Range'**
  String get labelReferenceRange;

  /// No description provided for @permissionsRequired.
  ///
  /// In en, this message translates to:
  /// **'Permissions Required'**
  String get permissionsRequired;

  /// No description provided for @recordsSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String recordsSelectedCount(int count);

  /// No description provided for @noRecordsSelected.
  ///
  /// In en, this message translates to:
  /// **'No records selected'**
  String get noRecordsSelected;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @selectRecordsBeforeSharing.
  ///
  /// In en, this message translates to:
  /// **'Select records\nbefore sharing'**
  String get selectRecordsBeforeSharing;

  /// No description provided for @recordDetails.
  ///
  /// In en, this message translates to:
  /// **'Record Details'**
  String get recordDetails;

  /// No description provided for @viewDocument.
  ///
  /// In en, this message translates to:
  /// **'View Document'**
  String get viewDocument;

  /// No description provided for @encounterDetails.
  ///
  /// In en, this message translates to:
  /// **'Encounter details'**
  String get encounterDetails;

  /// No description provided for @relatedResources.
  ///
  /// In en, this message translates to:
  /// **'Related resources'**
  String get relatedResources;

  /// No description provided for @deletePlusRelated.
  ///
  /// In en, this message translates to:
  /// **'Delete + {count} related'**
  String deletePlusRelated(int count);

  /// No description provided for @fileNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'File not available on this device'**
  String get fileNotAvailable;

  /// No description provided for @couldNotOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Could not open file: {message}'**
  String couldNotOpenFile(String message);

  /// No description provided for @errorOpeningFile.
  ///
  /// In en, this message translates to:
  /// **'Error opening file: {error}'**
  String errorOpeningFile(String error);

  /// No description provided for @failedToLoadImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get failedToLoadImage;

  /// No description provided for @errorLoadingPdf.
  ///
  /// In en, this message translates to:
  /// **'Error loading PDF: {error}'**
  String errorLoadingPdf(String error);

  /// No description provided for @errorOnPage.
  ///
  /// In en, this message translates to:
  /// **'Error on page {page}: {error}'**
  String errorOnPage(String page, String error);

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @noNotesAttached.
  ///
  /// In en, this message translates to:
  /// **'This record has no notes attached'**
  String get noNotesAttached;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addNote;

  /// No description provided for @editNote.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get editNote;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @timeRange.
  ///
  /// In en, this message translates to:
  /// **'Time Range'**
  String get timeRange;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get applyFilters;

  /// No description provided for @recordType.
  ///
  /// In en, this message translates to:
  /// **'Record type'**
  String get recordType;

  /// No description provided for @selectedRange.
  ///
  /// In en, this message translates to:
  /// **'Selected Range'**
  String get selectedRange;

  /// No description provided for @noRangeSelected.
  ///
  /// In en, this message translates to:
  /// **'No range selected'**
  String get noRangeSelected;

  /// No description provided for @clearDateRange.
  ///
  /// In en, this message translates to:
  /// **'Clear date range'**
  String get clearDateRange;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @fromDate.
  ///
  /// In en, this message translates to:
  /// **'From {date}'**
  String fromDate(String date);

  /// No description provided for @untilDate.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String untilDate(String date);

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @mediaInfo.
  ///
  /// In en, this message translates to:
  /// **'Media Info'**
  String get mediaInfo;

  /// No description provided for @linkToEncounter.
  ///
  /// In en, this message translates to:
  /// **'Link to Encounter'**
  String get linkToEncounter;

  /// No description provided for @noPdfDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No PDF data available'**
  String get noPdfDataAvailable;

  /// No description provided for @failedToLoadPdf.
  ///
  /// In en, this message translates to:
  /// **'Failed to load PDF document'**
  String get failedToLoadPdf;

  /// No description provided for @mediaInformation.
  ///
  /// In en, this message translates to:
  /// **'Media Information'**
  String get mediaInformation;

  /// No description provided for @mediaInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Title:'**
  String get mediaInfoTitle;

  /// No description provided for @mediaInfoType.
  ///
  /// In en, this message translates to:
  /// **'Type:'**
  String get mediaInfoType;

  /// No description provided for @mediaInfoStatus.
  ///
  /// In en, this message translates to:
  /// **'Status:'**
  String get mediaInfoStatus;

  /// No description provided for @mediaInfoPatient.
  ///
  /// In en, this message translates to:
  /// **'Patient:'**
  String get mediaInfoPatient;

  /// No description provided for @mediaInfoEncounter.
  ///
  /// In en, this message translates to:
  /// **'Encounter:'**
  String get mediaInfoEncounter;

  /// No description provided for @mediaInfoFileSize.
  ///
  /// In en, this message translates to:
  /// **'File Size:'**
  String get mediaInfoFileSize;

  /// No description provided for @mediaInfoCreated.
  ///
  /// In en, this message translates to:
  /// **'Created:'**
  String get mediaInfoCreated;

  /// No description provided for @mediaInfoResourceId.
  ///
  /// In en, this message translates to:
  /// **'Resource ID:'**
  String get mediaInfoResourceId;

  /// No description provided for @mediaInfoSource.
  ///
  /// In en, this message translates to:
  /// **'Source:'**
  String get mediaInfoSource;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @linkMediaToEncounterDescription.
  ///
  /// In en, this message translates to:
  /// **'Link this media resource to an encounter:'**
  String get linkMediaToEncounterDescription;

  /// No description provided for @encounterId.
  ///
  /// In en, this message translates to:
  /// **'Encounter ID'**
  String get encounterId;

  /// No description provided for @encounterIdHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., encounter-123'**
  String get encounterIdHint;

  /// No description provided for @mediaLinkedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Media linked to encounter successfully'**
  String get mediaLinkedSuccess;

  /// No description provided for @failedToLinkMedia.
  ///
  /// In en, this message translates to:
  /// **'Failed to link media: {error}'**
  String failedToLinkMedia(String error);

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @connectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connectionLabel;

  /// No description provided for @connectionStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectionStatusConnected;

  /// No description provided for @connectionStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connectionStatusConnecting;

  /// No description provided for @connectionStatusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get connectionStatusDisconnected;

  /// No description provided for @connectionStatusNotPaired.
  ///
  /// In en, this message translates to:
  /// **'Not paired'**
  String get connectionStatusNotPaired;

  /// No description provided for @syncLabel.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncLabel;

  /// No description provided for @syncStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncStatusSyncing;

  /// No description provided for @syncStatusNotSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced'**
  String get syncStatusNotSynced;

  /// No description provided for @syncStatusInSync.
  ///
  /// In en, this message translates to:
  /// **'In sync'**
  String get syncStatusInSync;

  /// No description provided for @syncStatusPending.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String syncStatusPending(int count);

  /// No description provided for @backupLabel.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupLabel;

  /// No description provided for @backupStatusWorking.
  ///
  /// In en, this message translates to:
  /// **'Working...'**
  String get backupStatusWorking;

  /// No description provided for @backupStatusNoBackup.
  ///
  /// In en, this message translates to:
  /// **'No backup'**
  String get backupStatusNoBackup;

  /// No description provided for @backupStatusBackingUp.
  ///
  /// In en, this message translates to:
  /// **'Backing up...'**
  String get backupStatusBackingUp;

  /// No description provided for @backupStatusRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring...'**
  String get backupStatusRestoring;

  /// No description provided for @backupStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting...'**
  String get backupStatusWaiting;

  /// No description provided for @backupStatusNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get backupStatusNotConnected;

  /// No description provided for @exportIpsPdf.
  ///
  /// In en, this message translates to:
  /// **'Export IPS (PDF)'**
  String get exportIpsPdf;

  /// No description provided for @addIpsToAppleWallet.
  ///
  /// In en, this message translates to:
  /// **'Add IPS to Apple Wallet'**
  String get addIpsToAppleWallet;

  /// No description provided for @addIpsToGoogleWallet.
  ///
  /// In en, this message translates to:
  /// **'Add IPS to Google Wallet'**
  String get addIpsToGoogleWallet;

  /// No description provided for @sourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sourcesTitle;

  /// No description provided for @emergencyMedicalId.
  ///
  /// In en, this message translates to:
  /// **'Emergency Medical ID'**
  String get emergencyMedicalId;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @allergiesLabel.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get allergiesLabel;

  /// No description provided for @medicalConditionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Medical Conditions'**
  String get medicalConditionsLabel;

  /// No description provided for @medicationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medicationsLabel;

  /// No description provided for @conditionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get conditionsLabel;

  /// No description provided for @dateOfBirthLabel.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirthLabel;

  /// No description provided for @emergencyPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Emergency Phone'**
  String get emergencyPhoneLabel;

  /// No description provided for @openingScanner.
  ///
  /// In en, this message translates to:
  /// **'Opening scanner...'**
  String get openingScanner;

  /// No description provided for @activeScanSessions.
  ///
  /// In en, this message translates to:
  /// **'Active scan sessions:'**
  String get activeScanSessions;

  /// No description provided for @noScansYet.
  ///
  /// In en, this message translates to:
  /// **'No scans yet'**
  String get noScansYet;

  /// No description provided for @scanOrImportToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Scan or import documents to get started'**
  String get scanOrImportToGetStarted;

  /// No description provided for @pageOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String pageOfTotal(String current, String total);

  /// No description provided for @fileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get fileNotFound;

  /// No description provided for @fileIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'File is empty'**
  String get fileIsEmpty;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importTitle;

  /// No description provided for @activeImportSessions.
  ///
  /// In en, this message translates to:
  /// **'Active import sessions:'**
  String get activeImportSessions;

  /// No description provided for @dropToImport.
  ///
  /// In en, this message translates to:
  /// **'Drop to import'**
  String get dropToImport;

  /// No description provided for @dropFilesHereToImport.
  ///
  /// In en, this message translates to:
  /// **'Drop files here to import'**
  String get dropFilesHereToImport;

  /// No description provided for @supportedFileFormats.
  ///
  /// In en, this message translates to:
  /// **'PDF, JPG, PNG, TIFF'**
  String get supportedFileFormats;

  /// No description provided for @browseFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse Files'**
  String get browseFiles;

  /// No description provided for @noImportsYet.
  ///
  /// In en, this message translates to:
  /// **'No imports yet'**
  String get noImportsYet;

  /// No description provided for @importOrScanToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Import or scan documents to get started'**
  String get importOrScanToGetStarted;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get noNotifications;

  /// No description provided for @cancelDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Download'**
  String get cancelDownloadTitle;

  /// No description provided for @cancelDownloadMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel the AI Model download? You can restart it later.'**
  String get cancelDownloadMessage;

  /// No description provided for @processingDone.
  ///
  /// In en, this message translates to:
  /// **'Processing done'**
  String get processingDone;

  /// No description provided for @pairedWithDevice.
  ///
  /// In en, this message translates to:
  /// **'Paired with {deviceName}'**
  String pairedWithDevice(String deviceName);

  /// No description provided for @deviceSyncLabel.
  ///
  /// In en, this message translates to:
  /// **'Device Sync'**
  String get deviceSyncLabel;

  /// No description provided for @disconnectLabel.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnectLabel;

  /// No description provided for @changeLabel.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeLabel;

  /// No description provided for @minimizeToTray.
  ///
  /// In en, this message translates to:
  /// **'Minimize to tray'**
  String get minimizeToTray;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'ro'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'ro':
      return AppLocalizationsRo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
