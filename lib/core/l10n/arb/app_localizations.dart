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
  /// **'Get started'**
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
  /// **'is a simple, secure tool designed to help you organize your health records at ease, directly on your device. This policy explains our commitment to your privacy: we do not collect your data, and we do not track you. You are in complete control.'**
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
  /// **'This model requires more memory than your device has available. Use the Standard model instead.'**
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
