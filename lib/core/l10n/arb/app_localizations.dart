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

  /// No description provided for @homeHi.
  ///
  /// In en, this message translates to:
  /// **'Hi, '**
  String get homeHi;

  /// No description provided for @homeVitalSigns.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get homeVitalSigns;

  /// No description provided for @homeSource.
  ///
  /// In en, this message translates to:
  /// **'Source:'**
  String get homeSource;

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

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @searchRecordsHint.
  ///
  /// In en, this message translates to:
  /// **'Search records, doctors, locations...'**
  String get searchRecordsHint;

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

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @authenticate.
  ///
  /// In en, this message translates to:
  /// **'Authenticate'**
  String get authenticate;

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

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @loadDemoData.
  ///
  /// In en, this message translates to:
  /// **'Load Demo Data'**
  String get loadDemoData;

  /// No description provided for @noMedicalRecordsYet.
  ///
  /// In en, this message translates to:
  /// **'No medical records yet'**
  String get noMedicalRecordsYet;

  /// No description provided for @loadDemoDataMessage.
  ///
  /// In en, this message translates to:
  /// **'Load demo data to explore the app or sync your real medical records'**
  String get loadDemoDataMessage;

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

  /// No description provided for @deleteSourceConfirmPrefix.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete '**
  String get deleteSourceConfirmPrefix;

  /// No description provided for @deleteSourceConfirmSuffix.
  ///
  /// In en, this message translates to:
  /// **' and all its records. To confirm, type the source name below.'**
  String get deleteSourceConfirmSuffix;

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

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @unknownSource.
  ///
  /// In en, this message translates to:
  /// **'Unknown Source'**
  String get unknownSource;

  /// No description provided for @desktopSyncAndBackup.
  ///
  /// In en, this message translates to:
  /// **'Data Sync & Backup'**
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

  /// No description provided for @continueImporting.
  ///
  /// In en, this message translates to:
  /// **'Continue Importing'**
  String get continueImporting;

  /// No description provided for @noAiModel.
  ///
  /// In en, this message translates to:
  /// **'No AI model'**
  String get noAiModel;

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

  /// No description provided for @patientSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Personalize your health wallet with your information'**
  String get patientSetupSubtitle;

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

  /// No description provided for @tokenPresetMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get tokenPresetMedium;

  /// No description provided for @tokenPresetHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get tokenPresetHigh;

  /// No description provided for @tokenPresetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get tokenPresetCustom;

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

  /// No description provided for @selectRecordToViewDetails.
  ///
  /// In en, this message translates to:
  /// **'Select a record to view details'**
  String get selectRecordToViewDetails;

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

  /// No description provided for @specialty.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get specialty;

  /// No description provided for @allSpecialties.
  ///
  /// In en, this message translates to:
  /// **'All Specialties'**
  String get allSpecialties;

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

  /// No description provided for @ipsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export your health summary. Please try again.'**
  String get ipsExportFailed;

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

  /// No description provided for @changeSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Change Specialty'**
  String get changeSpecialty;

  /// No description provided for @changeSpecialtyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to change the specialty to'**
  String get changeSpecialtyConfirm;

  /// No description provided for @removeSpecialtyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove the specialty from this record?'**
  String get removeSpecialtyConfirm;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @currentRecord.
  ///
  /// In en, this message translates to:
  /// **'Current record'**
  String get currentRecord;

  /// No description provided for @vitalHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get vitalHeartRate;

  /// No description provided for @vitalBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Blood Pressure'**
  String get vitalBloodPressure;

  /// No description provided for @vitalTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get vitalTemperature;

  /// No description provided for @vitalBloodOxygen.
  ///
  /// In en, this message translates to:
  /// **'Blood Oxygen'**
  String get vitalBloodOxygen;

  /// No description provided for @vitalRespiratoryRate.
  ///
  /// In en, this message translates to:
  /// **'Respiratory Rate'**
  String get vitalRespiratoryRate;

  /// No description provided for @vitalWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get vitalWeight;

  /// No description provided for @vitalHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get vitalHeight;

  /// No description provided for @vitalBmi.
  ///
  /// In en, this message translates to:
  /// **'BMI'**
  String get vitalBmi;

  /// No description provided for @vitalBloodGlucose.
  ///
  /// In en, this message translates to:
  /// **'Blood Glucose'**
  String get vitalBloodGlucose;

  /// No description provided for @vitalSystolicBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Systolic Blood Pressure'**
  String get vitalSystolicBloodPressure;

  /// No description provided for @vitalDiastolicBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Diastolic Blood Pressure'**
  String get vitalDiastolicBloodPressure;

  /// No description provided for @unitBeatsPerMinute.
  ///
  /// In en, this message translates to:
  /// **'beats/min'**
  String get unitBeatsPerMinute;

  /// No description provided for @unitBreathsPerMinute.
  ///
  /// In en, this message translates to:
  /// **'breaths/min'**
  String get unitBreathsPerMinute;

  /// No description provided for @unitPounds.
  ///
  /// In en, this message translates to:
  /// **'pounds'**
  String get unitPounds;

  /// No description provided for @unitInches.
  ///
  /// In en, this message translates to:
  /// **'inches'**
  String get unitInches;

  /// No description provided for @unitKilograms.
  ///
  /// In en, this message translates to:
  /// **'kilograms'**
  String get unitKilograms;

  /// No description provided for @unitCentimeters.
  ///
  /// In en, this message translates to:
  /// **'centimeters'**
  String get unitCentimeters;

  /// No description provided for @specialtyAllergology.
  ///
  /// In en, this message translates to:
  /// **'Allergology'**
  String get specialtyAllergology;

  /// No description provided for @specialtyCardiology.
  ///
  /// In en, this message translates to:
  /// **'Cardiology'**
  String get specialtyCardiology;

  /// No description provided for @specialtyDental.
  ///
  /// In en, this message translates to:
  /// **'Dental'**
  String get specialtyDental;

  /// No description provided for @specialtyDermatology.
  ///
  /// In en, this message translates to:
  /// **'Dermatology'**
  String get specialtyDermatology;

  /// No description provided for @specialtyEmergencyMedicine.
  ///
  /// In en, this message translates to:
  /// **'Emergency Medicine'**
  String get specialtyEmergencyMedicine;

  /// No description provided for @specialtyEndocrinology.
  ///
  /// In en, this message translates to:
  /// **'Endocrinology'**
  String get specialtyEndocrinology;

  /// No description provided for @specialtyGastroenterology.
  ///
  /// In en, this message translates to:
  /// **'Gastroenterology'**
  String get specialtyGastroenterology;

  /// No description provided for @specialtyGeneralCare.
  ///
  /// In en, this message translates to:
  /// **'General Care'**
  String get specialtyGeneralCare;

  /// No description provided for @specialtyGynecology.
  ///
  /// In en, this message translates to:
  /// **'Gynecology'**
  String get specialtyGynecology;

  /// No description provided for @specialtyNephrology.
  ///
  /// In en, this message translates to:
  /// **'Nephrology'**
  String get specialtyNephrology;

  /// No description provided for @specialtyNeurology.
  ///
  /// In en, this message translates to:
  /// **'Neurology'**
  String get specialtyNeurology;

  /// No description provided for @specialtyOncology.
  ///
  /// In en, this message translates to:
  /// **'Oncology'**
  String get specialtyOncology;

  /// No description provided for @specialtyOphthalmology.
  ///
  /// In en, this message translates to:
  /// **'Ophthalmology'**
  String get specialtyOphthalmology;

  /// No description provided for @specialtyOrthopedics.
  ///
  /// In en, this message translates to:
  /// **'Orthopedics'**
  String get specialtyOrthopedics;

  /// No description provided for @specialtyPsychiatry.
  ///
  /// In en, this message translates to:
  /// **'Psychiatry'**
  String get specialtyPsychiatry;

  /// No description provided for @specialtyPulmonology.
  ///
  /// In en, this message translates to:
  /// **'Pulmonology'**
  String get specialtyPulmonology;

  /// No description provided for @specialtyRheumatology.
  ///
  /// In en, this message translates to:
  /// **'Rheumatology'**
  String get specialtyRheumatology;

  /// No description provided for @specialtyUrology.
  ///
  /// In en, this message translates to:
  /// **'Urology'**
  String get specialtyUrology;

  /// No description provided for @categoryAllergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get categoryAllergies;

  /// No description provided for @categoryCareTeam.
  ///
  /// In en, this message translates to:
  /// **'Care Team'**
  String get categoryCareTeam;

  /// No description provided for @categoryClinicalNotes.
  ///
  /// In en, this message translates to:
  /// **'Clinical Notes'**
  String get categoryClinicalNotes;

  /// No description provided for @categoryFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get categoryFiles;

  /// No description provided for @categoryLabResults.
  ///
  /// In en, this message translates to:
  /// **'Lab Results'**
  String get categoryLabResults;

  /// No description provided for @categoryHealthIssues.
  ///
  /// In en, this message translates to:
  /// **'Health Issues'**
  String get categoryHealthIssues;

  /// No description provided for @categoryFacilities.
  ///
  /// In en, this message translates to:
  /// **'Facilities'**
  String get categoryFacilities;

  /// No description provided for @categoryHealthGoals.
  ///
  /// In en, this message translates to:
  /// **'Health Goals'**
  String get categoryHealthGoals;

  /// No description provided for @categoryImmunizations.
  ///
  /// In en, this message translates to:
  /// **'Immunizations'**
  String get categoryImmunizations;

  /// No description provided for @categoryMedications.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get categoryMedications;

  /// No description provided for @categoryDemographics.
  ///
  /// In en, this message translates to:
  /// **'Demographics'**
  String get categoryDemographics;

  /// No description provided for @categoryProcedures.
  ///
  /// In en, this message translates to:
  /// **'Procedures'**
  String get categoryProcedures;

  /// No description provided for @categoryHealthInsurance.
  ///
  /// In en, this message translates to:
  /// **'Health Insurance'**
  String get categoryHealthInsurance;

  /// No description provided for @fhirTypeAdverseEvent.
  ///
  /// In en, this message translates to:
  /// **'Adverse Event'**
  String get fhirTypeAdverseEvent;

  /// No description provided for @fhirTypeAllergyIntolerance.
  ///
  /// In en, this message translates to:
  /// **'Allergy'**
  String get fhirTypeAllergyIntolerance;

  /// No description provided for @fhirTypeBinary.
  ///
  /// In en, this message translates to:
  /// **'Binary'**
  String get fhirTypeBinary;

  /// No description provided for @fhirTypeCareTeam.
  ///
  /// In en, this message translates to:
  /// **'Care Team'**
  String get fhirTypeCareTeam;

  /// No description provided for @fhirTypeClaim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get fhirTypeClaim;

  /// No description provided for @fhirTypeCondition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get fhirTypeCondition;

  /// No description provided for @fhirTypeCoverage.
  ///
  /// In en, this message translates to:
  /// **'Coverage'**
  String get fhirTypeCoverage;

  /// No description provided for @fhirTypeDiagnosticReport.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic Report'**
  String get fhirTypeDiagnosticReport;

  /// No description provided for @fhirTypeDocumentReference.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get fhirTypeDocumentReference;

  /// No description provided for @fhirTypeEncounter.
  ///
  /// In en, this message translates to:
  /// **'Encounter'**
  String get fhirTypeEncounter;

  /// No description provided for @fhirTypeExplanationOfBenefit.
  ///
  /// In en, this message translates to:
  /// **'Explanation of Benefit'**
  String get fhirTypeExplanationOfBenefit;

  /// No description provided for @fhirTypeGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get fhirTypeGoal;

  /// No description provided for @fhirTypeImmunization.
  ///
  /// In en, this message translates to:
  /// **'Immunization'**
  String get fhirTypeImmunization;

  /// No description provided for @fhirTypeLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get fhirTypeLocation;

  /// No description provided for @fhirTypeMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get fhirTypeMedia;

  /// No description provided for @fhirTypeMedication.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get fhirTypeMedication;

  /// No description provided for @fhirTypeMedicationAdministration.
  ///
  /// In en, this message translates to:
  /// **'Medication Administration'**
  String get fhirTypeMedicationAdministration;

  /// No description provided for @fhirTypeMedicationDispense.
  ///
  /// In en, this message translates to:
  /// **'Medication Dispense'**
  String get fhirTypeMedicationDispense;

  /// No description provided for @fhirTypeMedicationRequest.
  ///
  /// In en, this message translates to:
  /// **'Medication Request'**
  String get fhirTypeMedicationRequest;

  /// No description provided for @fhirTypeMedicationStatement.
  ///
  /// In en, this message translates to:
  /// **'Medication Statement'**
  String get fhirTypeMedicationStatement;

  /// No description provided for @fhirTypeObservation.
  ///
  /// In en, this message translates to:
  /// **'Observation'**
  String get fhirTypeObservation;

  /// No description provided for @fhirTypeOrganization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get fhirTypeOrganization;

  /// No description provided for @fhirTypePatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get fhirTypePatient;

  /// No description provided for @fhirTypePractitioner.
  ///
  /// In en, this message translates to:
  /// **'Practitioner'**
  String get fhirTypePractitioner;

  /// No description provided for @fhirTypePractitionerRole.
  ///
  /// In en, this message translates to:
  /// **'Practitioner Role'**
  String get fhirTypePractitionerRole;

  /// No description provided for @fhirTypeProcedure.
  ///
  /// In en, this message translates to:
  /// **'Procedure'**
  String get fhirTypeProcedure;

  /// No description provided for @fhirTypeRelatedPerson.
  ///
  /// In en, this message translates to:
  /// **'Related Person'**
  String get fhirTypeRelatedPerson;

  /// No description provided for @fhirTypeServiceRequest.
  ///
  /// In en, this message translates to:
  /// **'Service Request'**
  String get fhirTypeServiceRequest;

  /// No description provided for @fhirTypeSpecimen.
  ///
  /// In en, this message translates to:
  /// **'Specimen'**
  String get fhirTypeSpecimen;

  /// No description provided for @fhirTypeGeneralResource.
  ///
  /// In en, this message translates to:
  /// **'Resource'**
  String get fhirTypeGeneralResource;

  /// No description provided for @processingOriginScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get processingOriginScan;

  /// No description provided for @processingOriginImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get processingOriginImport;

  /// No description provided for @processingOriginHandover.
  ///
  /// In en, this message translates to:
  /// **'Handover'**
  String get processingOriginHandover;

  /// No description provided for @processingStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get processingStatusPending;

  /// No description provided for @processingStatusProcessingPatient.
  ///
  /// In en, this message translates to:
  /// **'Processing Patient'**
  String get processingStatusProcessingPatient;

  /// No description provided for @processingStatusPatientExtracted.
  ///
  /// In en, this message translates to:
  /// **'Patient Extracted'**
  String get processingStatusPatientExtracted;

  /// No description provided for @processingStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processingStatusProcessing;

  /// No description provided for @processingStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get processingStatusDraft;

  /// No description provided for @processingStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get processingStatusCancelled;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show All'**
  String get showAll;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show Less'**
  String get showLess;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @homeSpecialties.
  ///
  /// In en, this message translates to:
  /// **'Specialties'**
  String get homeSpecialties;

  /// No description provided for @homeResources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get homeResources;

  /// No description provided for @homeDefaultUserName.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get homeDefaultUserName;

  /// No description provided for @selectSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Select Specialty'**
  String get selectSpecialty;

  /// No description provided for @removeSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Remove Specialty'**
  String get removeSpecialty;

  /// No description provided for @chooseRecordsForDashboard.
  ///
  /// In en, this message translates to:
  /// **'Choose the records you want to see on your dashboard.'**
  String get chooseRecordsForDashboard;

  /// No description provided for @selectAtLeastOneRecordType.
  ///
  /// In en, this message translates to:
  /// **'Select at least one record type to continue.'**
  String get selectAtLeastOneRecordType;

  /// No description provided for @chooseVitalsForDashboard.
  ///
  /// In en, this message translates to:
  /// **'Choose the vitals you want to see on your dashboard.'**
  String get chooseVitalsForDashboard;

  /// No description provided for @selectAtLeastOneVital.
  ///
  /// In en, this message translates to:
  /// **'Select at least one vital sign to continue.'**
  String get selectAtLeastOneVital;

  /// No description provided for @chooseSpecialtiesForDashboard.
  ///
  /// In en, this message translates to:
  /// **'Choose the specialities you want to see on your dashboard.'**
  String get chooseSpecialtiesForDashboard;

  /// No description provided for @selectAtLeastOneSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Select at least one specialty to continue.'**
  String get selectAtLeastOneSpecialty;

  /// No description provided for @selectAtLeastOneItem.
  ///
  /// In en, this message translates to:
  /// **'Select at least one item to continue.'**
  String get selectAtLeastOneItem;

  /// No description provided for @sourceSectionWallet.
  ///
  /// In en, this message translates to:
  /// **'WALLET'**
  String get sourceSectionWallet;

  /// No description provided for @sourceSectionEhr.
  ///
  /// In en, this message translates to:
  /// **'EHR SOURCES'**
  String get sourceSectionEhr;

  /// No description provided for @areYouSure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get areYouSure;

  /// No description provided for @resourceNotViewable.
  ///
  /// In en, this message translates to:
  /// **'This resource is not a viewable file'**
  String get resourceNotViewable;

  /// No description provided for @noFilePathFound.
  ///
  /// In en, this message translates to:
  /// **'No file path found'**
  String get noFilePathFound;

  /// No description provided for @handoverPatientMatched.
  ///
  /// In en, this message translates to:
  /// **'Handover patient matched'**
  String get handoverPatientMatched;

  /// No description provided for @desktopDiscovering.
  ///
  /// In en, this message translates to:
  /// **'Discovering...'**
  String get desktopDiscovering;

  /// No description provided for @desktopTransportWifi.
  ///
  /// In en, this message translates to:
  /// **'WiFi'**
  String get desktopTransportWifi;

  /// No description provided for @desktopTransportDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get desktopTransportDirect;

  /// No description provided for @desktopDeviceSync.
  ///
  /// In en, this message translates to:
  /// **'Device Sync'**
  String get desktopDeviceSync;

  /// No description provided for @desktopBackupLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get desktopBackupLocation;

  /// No description provided for @desktopBackupHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get desktopBackupHistory;

  /// No description provided for @desktopPairedWith.
  ///
  /// In en, this message translates to:
  /// **'Paired with {name}'**
  String desktopPairedWith(String name);

  /// No description provided for @desktopMobileDevice.
  ///
  /// In en, this message translates to:
  /// **'Mobile Device'**
  String get desktopMobileDevice;

  /// No description provided for @desktopNotFoundScanAgain.
  ///
  /// In en, this message translates to:
  /// **'Desktop not found. Try scanning QR again.'**
  String get desktopNotFoundScanAgain;

  /// No description provided for @desktopPairingExpired.
  ///
  /// In en, this message translates to:
  /// **'Could not connect. Scan QR code to pair again.'**
  String get desktopPairingExpired;

  /// No description provided for @desktopRemoteBackupName.
  ///
  /// In en, this message translates to:
  /// **'Remote {date}'**
  String desktopRemoteBackupName(String date);

  /// No description provided for @desktopNoBackupLocation.
  ///
  /// In en, this message translates to:
  /// **'No backup location set on desktop. Open the desktop app and choose a backup folder first.'**
  String get desktopNoBackupLocation;

  /// No description provided for @desktopBackupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed. Please try again.'**
  String get desktopBackupFailed;

  /// No description provided for @desktopRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed. Please try again.'**
  String get desktopRestoreFailed;

  /// No description provided for @desktopBackupActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the backups. Please try again.'**
  String get desktopBackupActionFailed;

  /// No description provided for @desktopSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed. Check the connection and try again.'**
  String get desktopSyncFailed;

  /// No description provided for @desktopHandoverTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get desktopHandoverTransfer;

  /// No description provided for @desktopHandoverNoActive.
  ///
  /// In en, this message translates to:
  /// **'No active handovers'**
  String get desktopHandoverNoActive;

  /// No description provided for @desktopHandoverSendFromPhone.
  ///
  /// In en, this message translates to:
  /// **'Send documents from your phone.'**
  String get desktopHandoverSendFromPhone;

  /// No description provided for @desktopHandoverFilesProgress.
  ///
  /// In en, this message translates to:
  /// **'{received}/{total} files'**
  String desktopHandoverFilesProgress(String received, String total);

  /// No description provided for @desktopHandoverTransferComplete.
  ///
  /// In en, this message translates to:
  /// **'Transfer complete'**
  String get desktopHandoverTransferComplete;

  /// No description provided for @desktopHandoverReceivingFiles.
  ///
  /// In en, this message translates to:
  /// **'Receiving files...'**
  String get desktopHandoverReceivingFiles;

  /// No description provided for @desktopHandoverProcessingStatus.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get desktopHandoverProcessingStatus;

  /// No description provided for @desktopHandoverSendingResults.
  ///
  /// In en, this message translates to:
  /// **'Sending results...'**
  String get desktopHandoverSendingResults;

  /// No description provided for @desktopHandoverDone.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get desktopHandoverDone;

  /// No description provided for @desktopHandoverStatusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get desktopHandoverStatusError;

  /// No description provided for @desktopHandoverWaitingForResults.
  ///
  /// In en, this message translates to:
  /// **'Waiting for results...'**
  String get desktopHandoverWaitingForResults;

  /// No description provided for @desktopHandoverNotAccepted.
  ///
  /// In en, this message translates to:
  /// **'The desktop did not accept the documents.'**
  String get desktopHandoverNotAccepted;

  /// No description provided for @desktopHandoverFileMissing.
  ///
  /// In en, this message translates to:
  /// **'A document could not be found on this device.'**
  String get desktopHandoverFileMissing;

  /// No description provided for @desktopHandoverCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get desktopHandoverCancelled;

  /// No description provided for @desktopHandoverFailed.
  ///
  /// In en, this message translates to:
  /// **'Processing failed. Please try again.'**
  String get desktopHandoverFailed;

  /// No description provided for @trayShowWindow.
  ///
  /// In en, this message translates to:
  /// **'Show Window'**
  String get trayShowWindow;

  /// No description provided for @trayHideWindow.
  ///
  /// In en, this message translates to:
  /// **'Hide Window'**
  String get trayHideWindow;

  /// No description provided for @trayNoDeviceConnected.
  ///
  /// In en, this message translates to:
  /// **'No device connected'**
  String get trayNoDeviceConnected;

  /// No description provided for @traySyncStatus.
  ///
  /// In en, this message translates to:
  /// **'Sync: {status}'**
  String traySyncStatus(String status);

  /// No description provided for @trayUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get trayUpToDate;

  /// No description provided for @trayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit {appName}'**
  String trayQuit(String appName);

  /// No description provided for @desktopFinishedProcessing.
  ///
  /// In en, this message translates to:
  /// **'Desktop finished processing'**
  String get desktopFinishedProcessing;

  /// No description provided for @biometricAuthReason.
  ///
  /// In en, this message translates to:
  /// **'Please authenticate to access your HealthWallet.me'**
  String get biometricAuthReason;

  /// No description provided for @sourceUploadedOn.
  ///
  /// In en, this message translates to:
  /// **'Uploaded {date}'**
  String sourceUploadedOn(String date);

  /// No description provided for @couldNotOpenPdf.
  ///
  /// In en, this message translates to:
  /// **'Could not open PDF: {message}'**
  String couldNotOpenPdf(String message);

  /// No description provided for @errorOpeningPdf.
  ///
  /// In en, this message translates to:
  /// **'Error opening PDF: {error}'**
  String errorOpeningPdf(String error);

  /// No description provided for @shareStatusReadyToShare.
  ///
  /// In en, this message translates to:
  /// **'Ready to share'**
  String get shareStatusReadyToShare;

  /// No description provided for @shareStatusWaitingForSender.
  ///
  /// In en, this message translates to:
  /// **'Waiting for sender...'**
  String get shareStatusWaitingForSender;

  /// No description provided for @shareStatusPermissionsRequired.
  ///
  /// In en, this message translates to:
  /// **'Permissions required'**
  String get shareStatusPermissionsRequired;

  /// No description provided for @shareStatusEnablePermissionsInSettings.
  ///
  /// In en, this message translates to:
  /// **'Please enable permissions in Settings'**
  String get shareStatusEnablePermissionsInSettings;

  /// No description provided for @shareSelectAtLeastOneRecord.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one record'**
  String get shareSelectAtLeastOneRecord;

  /// No description provided for @shareStatusLookingForDevices.
  ///
  /// In en, this message translates to:
  /// **'Looking for nearby devices...'**
  String get shareStatusLookingForDevices;

  /// No description provided for @shareStatusTransferFailed.
  ///
  /// In en, this message translates to:
  /// **'Transfer failed'**
  String get shareStatusTransferFailed;

  /// No description provided for @shareStatusConfirmExit.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit? Data will be deleted.'**
  String get shareStatusConfirmExit;

  /// No description provided for @shareStatusViewingRecords.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Viewing 1 record} other{Viewing {count} records}}'**
  String shareStatusViewingRecords(int count);

  /// No description provided for @shareStatusViewingRecordsFrom.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Viewing 1 record from {deviceName}} other{Viewing {count} records from {deviceName}}}'**
  String shareStatusViewingRecordsFrom(int count, String deviceName);

  /// No description provided for @shareStatusDataDeleted.
  ///
  /// In en, this message translates to:
  /// **'Data has been securely deleted'**
  String get shareStatusDataDeleted;

  /// No description provided for @shareStatusSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get shareStatusSessionExpired;

  /// No description provided for @shareStatusTerminatingSession.
  ///
  /// In en, this message translates to:
  /// **'Terminating remote session...'**
  String get shareStatusTerminatingSession;

  /// No description provided for @shareStatusSessionTerminated.
  ///
  /// In en, this message translates to:
  /// **'Session terminated'**
  String get shareStatusSessionTerminated;

  /// No description provided for @shareStatusRemoteSessionTerminated.
  ///
  /// In en, this message translates to:
  /// **'Remote session terminated'**
  String get shareStatusRemoteSessionTerminated;

  /// No description provided for @shareStatusExtensionDeclined.
  ///
  /// In en, this message translates to:
  /// **'Extension request was declined'**
  String get shareStatusExtensionDeclined;

  /// No description provided for @shareStatusReceiverViewing.
  ///
  /// In en, this message translates to:
  /// **'Receiver is viewing records - monitoring session'**
  String get shareStatusReceiverViewing;

  /// No description provided for @shareStatusReceiverDeclined.
  ///
  /// In en, this message translates to:
  /// **'Receiver declined invitation'**
  String get shareStatusReceiverDeclined;

  /// No description provided for @shareStatusReceivingFrom.
  ///
  /// In en, this message translates to:
  /// **'Receiving records from {deviceName}...'**
  String shareStatusReceivingFrom(String deviceName);

  /// No description provided for @shareNoDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get shareNoDataAvailable;

  /// No description provided for @shareStatusDeviceWantsToShare.
  ///
  /// In en, this message translates to:
  /// **'{deviceName} wants to share records'**
  String shareStatusDeviceWantsToShare(String deviceName);

  /// No description provided for @shareStatusScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning for devices...'**
  String get shareStatusScanning;

  /// No description provided for @shareStatusFoundDevices.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Found 1 device} other{Found {count} devices}}'**
  String shareStatusFoundDevices(int count);

  /// No description provided for @shareStatusConnectingTo.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {deviceName}...'**
  String shareStatusConnectingTo(String deviceName);

  /// No description provided for @shareStatusPreparingRecords.
  ///
  /// In en, this message translates to:
  /// **'Preparing records...'**
  String get shareStatusPreparingRecords;

  /// No description provided for @shareErrorPrepareFiles.
  ///
  /// In en, this message translates to:
  /// **'Failed to prepare files for sending'**
  String get shareErrorPrepareFiles;

  /// No description provided for @shareStatusTransferring.
  ///
  /// In en, this message translates to:
  /// **'Transferring {percent}%'**
  String shareStatusTransferring(int percent);

  /// No description provided for @shareStatusRecordsSentWaiting.
  ///
  /// In en, this message translates to:
  /// **'Records sent - waiting for receiver to accept'**
  String get shareStatusRecordsSentWaiting;

  /// No description provided for @shareStatusTransferCancelled.
  ///
  /// In en, this message translates to:
  /// **'Transfer cancelled'**
  String get shareStatusTransferCancelled;

  /// No description provided for @shareStatusInvitationRejected.
  ///
  /// In en, this message translates to:
  /// **'Invitation rejected'**
  String get shareStatusInvitationRejected;

  /// No description provided for @shareErrorParseData.
  ///
  /// In en, this message translates to:
  /// **'Failed to parse received data'**
  String get shareErrorParseData;

  /// No description provided for @shareStatusProcessingReceived.
  ///
  /// In en, this message translates to:
  /// **'Processing received records...'**
  String get shareStatusProcessingReceived;

  /// No description provided for @shareErrorParseFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to parse received file'**
  String get shareErrorParseFile;

  /// No description provided for @shareIncomingHealthRecords.
  ///
  /// In en, this message translates to:
  /// **'Incoming Health Records'**
  String get shareIncomingHealthRecords;

  /// No description provided for @shareDeviceWantsToShareHealthRecords.
  ///
  /// In en, this message translates to:
  /// **'{deviceName} wants to share health records with you'**
  String shareDeviceWantsToShareHealthRecords(String deviceName);

  /// No description provided for @sharePermissionExplanationIos.
  ///
  /// In en, this message translates to:
  /// **'To share records with nearby devices, HealthWallet needs access to:\n\n• Bluetooth - to discover and connect to nearby devices\n\nThis allows you to securely share health records with other devices nearby.'**
  String get sharePermissionExplanationIos;

  /// No description provided for @sharePermissionExplanationAndroid.
  ///
  /// In en, this message translates to:
  /// **'To share records with nearby devices, HealthWallet needs access to:\n\n• Bluetooth - to discover and connect to nearby devices\n• Location/Nearby Devices - required by Android to scan for Bluetooth and WiFi Direct devices\n\nYour location is never stored or transmitted.'**
  String get sharePermissionExplanationAndroid;

  /// No description provided for @sharePermissionsDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Please grant all permissions to share records with nearby devices.'**
  String get sharePermissionsDeniedMessage;

  /// No description provided for @sharePermissionsPermanentlyDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Some permissions were denied. Please enable them in Settings to use this feature.'**
  String get sharePermissionsPermanentlyDeniedMessage;

  /// No description provided for @shareDurationRequested.
  ///
  /// In en, this message translates to:
  /// **'{duration} requested'**
  String shareDurationRequested(String duration);

  /// No description provided for @noAttachments.
  ///
  /// In en, this message translates to:
  /// **'No attachments'**
  String get noAttachments;

  /// No description provided for @attachingFiles.
  ///
  /// In en, this message translates to:
  /// **'Attaching files...'**
  String get attachingFiles;

  /// No description provided for @addAttachment.
  ///
  /// In en, this message translates to:
  /// **'Add Attachment'**
  String get addAttachment;

  /// No description provided for @noFileName.
  ///
  /// In en, this message translates to:
  /// **'No file name'**
  String get noFileName;

  /// No description provided for @attachmentFileOfTotal.
  ///
  /// In en, this message translates to:
  /// **'( {current} of {total} files )'**
  String attachmentFileOfTotal(int current, int total);

  /// No description provided for @showDetails.
  ///
  /// In en, this message translates to:
  /// **'Show Details'**
  String get showDetails;

  /// No description provided for @viewRelated.
  ///
  /// In en, this message translates to:
  /// **'View Related'**
  String get viewRelated;

  /// No description provided for @hideRelated.
  ///
  /// In en, this message translates to:
  /// **'Hide Related'**
  String get hideRelated;

  /// No description provided for @noRelatedResourcesFound.
  ///
  /// In en, this message translates to:
  /// **'No related resources found'**
  String get noRelatedResourcesFound;

  /// No description provided for @loadingRelatedResources.
  ///
  /// In en, this message translates to:
  /// **'Loading related resources...'**
  String get loadingRelatedResources;

  /// No description provided for @noRelatedResourcesForEncounter.
  ///
  /// In en, this message translates to:
  /// **'No related resources found for this encounter'**
  String get noRelatedResourcesForEncounter;

  /// No description provided for @cannotAttachToDocumentReference.
  ///
  /// In en, this message translates to:
  /// **'Cannot attach files to DocumentReference resources'**
  String get cannotAttachToDocumentReference;

  /// No description provided for @attachFileFailed.
  ///
  /// In en, this message translates to:
  /// **'The file could not be attached. Please try again.'**
  String get attachFileFailed;

  /// No description provided for @attachmentDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'The attachment could not be deleted. Please try again.'**
  String get attachmentDeleteFailed;

  /// No description provided for @deleteRecordOfType.
  ///
  /// In en, this message translates to:
  /// **'Delete {type}'**
  String deleteRecordOfType(String type);

  /// No description provided for @dateFilterEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'End date must be after start date'**
  String get dateFilterEndBeforeStart;

  /// No description provided for @dateFilterChip.
  ///
  /// In en, this message translates to:
  /// **'Date: {range}'**
  String dateFilterChip(String range);

  /// No description provided for @aiModelCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'An error appeared while checking model existence'**
  String get aiModelCheckFailed;

  /// No description provided for @aiModelExistenceCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to check model existence'**
  String get aiModelExistenceCheckFailed;

  /// No description provided for @aiModelDownloadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading {modelName}'**
  String aiModelDownloadingTitle(String modelName);

  /// No description provided for @aiModelDownloadStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting download...'**
  String get aiModelDownloadStarting;

  /// No description provided for @aiModelReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'{modelName} Ready'**
  String aiModelReadyTitle(String modelName);

  /// No description provided for @aiModelDownloadedMessage.
  ///
  /// In en, this message translates to:
  /// **'{modelName} has been downloaded successfully.'**
  String aiModelDownloadedMessage(String modelName);

  /// No description provided for @aiModelDownloadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Download Failed'**
  String get aiModelDownloadFailedTitle;

  /// No description provided for @aiModelDownloadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'AI model download failed. Please check your connection and try again.'**
  String get aiModelDownloadFailedMessage;

  /// No description provided for @aiModelDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get aiModelDownloadFailed;

  /// No description provided for @aiModelDownloadCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Download Cancelled'**
  String get aiModelDownloadCancelledTitle;

  /// No description provided for @aiModelDownloadInterruptedMessage.
  ///
  /// In en, this message translates to:
  /// **'The download was interrupted. Please try again.'**
  String get aiModelDownloadInterruptedMessage;

  /// No description provided for @aiModelDownloadCancelledNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Model Download Cancelled'**
  String get aiModelDownloadCancelledNotificationTitle;

  /// No description provided for @aiModelDownloadWasCancelled.
  ///
  /// In en, this message translates to:
  /// **'AI model download was cancelled'**
  String get aiModelDownloadWasCancelled;

  /// No description provided for @aiModelDownloadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Download cancelled'**
  String get aiModelDownloadCancelled;

  /// No description provided for @aiModelDownloadingPercent.
  ///
  /// In en, this message translates to:
  /// **'Downloading... {percent}%'**
  String aiModelDownloadingPercent(String percent);

  /// No description provided for @processingNoImagesGenerated.
  ///
  /// In en, this message translates to:
  /// **'No images were generated from the scan. Please try scanning again.'**
  String get processingNoImagesGenerated;

  /// No description provided for @processingPatientMatched.
  ///
  /// In en, this message translates to:
  /// **'{origin} patient matched'**
  String processingPatientMatched(String origin);

  /// No description provided for @processingPatientInfoExtracted.
  ///
  /// In en, this message translates to:
  /// **'{origin} patient info extracted'**
  String processingPatientInfoExtracted(String origin);

  /// No description provided for @processingFinished.
  ///
  /// In en, this message translates to:
  /// **'{origin} processing finished'**
  String processingFinished(String origin);

  /// No description provided for @scanFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String scanFailedWithError(String error);

  /// No description provided for @noValidFilesFound.
  ///
  /// In en, this message translates to:
  /// **'No valid files found'**
  String get noValidFilesFound;

  /// No description provided for @failedToImportDocument.
  ///
  /// In en, this message translates to:
  /// **'Failed to import document: {error}'**
  String failedToImportDocument(String error);

  /// No description provided for @couldNotOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Could not open link. Please try again.'**
  String get couldNotOpenLink;

  /// No description provided for @continueProcessingOnDesktop.
  ///
  /// In en, this message translates to:
  /// **'Continue processing on Desktop'**
  String get continueProcessingOnDesktop;

  /// No description provided for @deleteResourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Resources'**
  String get deleteResourcesTitle;

  /// No description provided for @switchToDiagnosticReport.
  ///
  /// In en, this message translates to:
  /// **'Switch to Diagnostic Report'**
  String get switchToDiagnosticReport;

  /// No description provided for @switchToEncounter.
  ///
  /// In en, this message translates to:
  /// **'Switch to Encounter'**
  String get switchToEncounter;

  /// No description provided for @previewDocument.
  ///
  /// In en, this message translates to:
  /// **'Preview document'**
  String get previewDocument;

  /// No description provided for @summaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summaryTitle;

  /// No description provided for @pagesAvailableForProcessing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Total: {count} page available for processing} other{Total: {count} pages available for processing}}'**
  String pagesAvailableForProcessing(int count);

  /// No description provided for @betaBadge.
  ///
  /// In en, this message translates to:
  /// **'Beta'**
  String get betaBadge;

  /// No description provided for @pleaseSelectSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Please select a specialty'**
  String get pleaseSelectSpecialty;

  /// No description provided for @patientAndSourceInformation.
  ///
  /// In en, this message translates to:
  /// **'Patient & Source Information'**
  String get patientAndSourceInformation;

  /// No description provided for @noPatientsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No patients available'**
  String get noPatientsAvailable;

  /// No description provided for @selectPatient.
  ///
  /// In en, this message translates to:
  /// **'Select patient'**
  String get selectPatient;

  /// No description provided for @unknownPatient.
  ///
  /// In en, this message translates to:
  /// **'Unknown Patient'**
  String get unknownPatient;

  /// No description provided for @documentPreview.
  ///
  /// In en, this message translates to:
  /// **'Document Preview'**
  String get documentPreview;

  /// No description provided for @filePathLabel.
  ///
  /// In en, this message translates to:
  /// **'Path: {path}'**
  String filePathLabel(String path);

  /// No description provided for @confidenceMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium confidence'**
  String get confidenceMedium;

  /// No description provided for @confidenceLow.
  ///
  /// In en, this message translates to:
  /// **'Low confidence'**
  String get confidenceLow;

  /// No description provided for @dateFormatHintIso.
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DD'**
  String get dateFormatHintIso;

  /// No description provided for @retryStep.
  ///
  /// In en, this message translates to:
  /// **'Retry (Step {step})'**
  String retryStep(int step);

  /// No description provided for @failedToCreateEncounter.
  ///
  /// In en, this message translates to:
  /// **'Failed to create encounter: {error}'**
  String failedToCreateEncounter(String error);

  /// No description provided for @failedToAttachDocuments.
  ///
  /// In en, this message translates to:
  /// **'Failed to attach documents: {error}'**
  String failedToAttachDocuments(String error);

  /// No description provided for @fieldAccessionNumber.
  ///
  /// In en, this message translates to:
  /// **'Accession Number'**
  String get fieldAccessionNumber;

  /// No description provided for @fieldAchievementStatus.
  ///
  /// In en, this message translates to:
  /// **'Achievement Status'**
  String get fieldAchievementStatus;

  /// No description provided for @fieldActuality.
  ///
  /// In en, this message translates to:
  /// **'Actuality'**
  String get fieldActuality;

  /// No description provided for @fieldAdditionalInformation.
  ///
  /// In en, this message translates to:
  /// **'Additional Information'**
  String get fieldAdditionalInformation;

  /// No description provided for @fieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get fieldAddress;

  /// No description provided for @fieldAddresses.
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get fieldAddresses;

  /// No description provided for @fieldAdministeredBy.
  ///
  /// In en, this message translates to:
  /// **'Administered By'**
  String get fieldAdministeredBy;

  /// No description provided for @fieldAdmissionSource.
  ///
  /// In en, this message translates to:
  /// **'Admission Source'**
  String get fieldAdmissionSource;

  /// No description provided for @fieldAlert.
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get fieldAlert;

  /// No description provided for @fieldAllergyDetails.
  ///
  /// In en, this message translates to:
  /// **'Allergy Details'**
  String get fieldAllergyDetails;

  /// No description provided for @fieldAlsoKnownAs.
  ///
  /// In en, this message translates to:
  /// **'Also Known As'**
  String get fieldAlsoKnownAs;

  /// No description provided for @fieldAsserter.
  ///
  /// In en, this message translates to:
  /// **'Asserter'**
  String get fieldAsserter;

  /// No description provided for @fieldAttachmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Attachment Title'**
  String get fieldAttachmentTitle;

  /// No description provided for @fieldAuthenticatedBy.
  ///
  /// In en, this message translates to:
  /// **'Authenticated By'**
  String get fieldAuthenticatedBy;

  /// No description provided for @fieldAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get fieldAuthor;

  /// No description provided for @fieldAvailabilityExceptions.
  ///
  /// In en, this message translates to:
  /// **'Availability Exceptions'**
  String get fieldAvailabilityExceptions;

  /// No description provided for @fieldAvailabilityNotes.
  ///
  /// In en, this message translates to:
  /// **'Availability Notes'**
  String get fieldAvailabilityNotes;

  /// No description provided for @fieldBasedOn.
  ///
  /// In en, this message translates to:
  /// **'Based On'**
  String get fieldBasedOn;

  /// No description provided for @fieldBasicInformation.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get fieldBasicInformation;

  /// No description provided for @fieldBeneficiary.
  ///
  /// In en, this message translates to:
  /// **'Beneficiary'**
  String get fieldBeneficiary;

  /// No description provided for @fieldBillablePeriod.
  ///
  /// In en, this message translates to:
  /// **'Billable Period'**
  String get fieldBillablePeriod;

  /// No description provided for @fieldBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Birth Date'**
  String get fieldBirthDate;

  /// No description provided for @fieldBirthPlace.
  ///
  /// In en, this message translates to:
  /// **'Birth Place'**
  String get fieldBirthPlace;

  /// No description provided for @fieldBirthSex.
  ///
  /// In en, this message translates to:
  /// **'Birth Sex'**
  String get fieldBirthSex;

  /// No description provided for @fieldBodySite.
  ///
  /// In en, this message translates to:
  /// **'Body Site'**
  String get fieldBodySite;

  /// No description provided for @fieldCareTeam.
  ///
  /// In en, this message translates to:
  /// **'Care Team'**
  String get fieldCareTeam;

  /// No description provided for @fieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fieldCategory;

  /// No description provided for @fieldClinicalNotes.
  ///
  /// In en, this message translates to:
  /// **'Clinical Notes'**
  String get fieldClinicalNotes;

  /// No description provided for @fieldClinicalStatus.
  ///
  /// In en, this message translates to:
  /// **'Clinical Status'**
  String get fieldClinicalStatus;

  /// No description provided for @fieldCollectedBy.
  ///
  /// In en, this message translates to:
  /// **'Collected By'**
  String get fieldCollectedBy;

  /// No description provided for @fieldCollectionDate.
  ///
  /// In en, this message translates to:
  /// **'Collection Date'**
  String get fieldCollectionDate;

  /// No description provided for @fieldCollectionDuration.
  ///
  /// In en, this message translates to:
  /// **'Collection Duration'**
  String get fieldCollectionDuration;

  /// No description provided for @fieldCollectionInformation.
  ///
  /// In en, this message translates to:
  /// **'Collection Information'**
  String get fieldCollectionInformation;

  /// No description provided for @fieldCollectionMethod.
  ///
  /// In en, this message translates to:
  /// **'Collection Method'**
  String get fieldCollectionMethod;

  /// No description provided for @fieldCollectionPeriod.
  ///
  /// In en, this message translates to:
  /// **'Collection Period'**
  String get fieldCollectionPeriod;

  /// No description provided for @fieldComplicationDetails.
  ///
  /// In en, this message translates to:
  /// **'Complication Details'**
  String get fieldComplicationDetails;

  /// No description provided for @fieldComplications.
  ///
  /// In en, this message translates to:
  /// **'Complications'**
  String get fieldComplications;

  /// No description provided for @fieldConclusion.
  ///
  /// In en, this message translates to:
  /// **'Conclusion'**
  String get fieldConclusion;

  /// No description provided for @fieldConclusionCode.
  ///
  /// In en, this message translates to:
  /// **'Conclusion Code'**
  String get fieldConclusionCode;

  /// No description provided for @fieldCondition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get fieldCondition;

  /// No description provided for @fieldContactEmail.
  ///
  /// In en, this message translates to:
  /// **'Contact Email'**
  String get fieldContactEmail;

  /// No description provided for @fieldContactInformation.
  ///
  /// In en, this message translates to:
  /// **'Contact Information'**
  String get fieldContactInformation;

  /// No description provided for @fieldContactPerson.
  ///
  /// In en, this message translates to:
  /// **'Contact Person'**
  String get fieldContactPerson;

  /// No description provided for @fieldContactPhone.
  ///
  /// In en, this message translates to:
  /// **'Contact Phone'**
  String get fieldContactPhone;

  /// No description provided for @fieldContainerAdditive.
  ///
  /// In en, this message translates to:
  /// **'Container Additive'**
  String get fieldContainerAdditive;

  /// No description provided for @fieldContainerCapacity.
  ///
  /// In en, this message translates to:
  /// **'Container Capacity'**
  String get fieldContainerCapacity;

  /// No description provided for @fieldContainerType.
  ///
  /// In en, this message translates to:
  /// **'Container Type'**
  String get fieldContainerType;

  /// No description provided for @fieldContainers.
  ///
  /// In en, this message translates to:
  /// **'Containers'**
  String get fieldContainers;

  /// No description provided for @fieldContentType.
  ///
  /// In en, this message translates to:
  /// **'Content Type'**
  String get fieldContentType;

  /// No description provided for @fieldContext.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get fieldContext;

  /// No description provided for @fieldContract.
  ///
  /// In en, this message translates to:
  /// **'Contract'**
  String get fieldContract;

  /// No description provided for @fieldCostSharing.
  ///
  /// In en, this message translates to:
  /// **'Cost Sharing'**
  String get fieldCostSharing;

  /// No description provided for @fieldCourseOfTherapy.
  ///
  /// In en, this message translates to:
  /// **'Course of Therapy'**
  String get fieldCourseOfTherapy;

  /// No description provided for @fieldCoverage.
  ///
  /// In en, this message translates to:
  /// **'Coverage'**
  String get fieldCoverage;

  /// No description provided for @fieldCoverageClass.
  ///
  /// In en, this message translates to:
  /// **'Coverage Class'**
  String get fieldCoverageClass;

  /// No description provided for @fieldCoverageDetails.
  ///
  /// In en, this message translates to:
  /// **'Coverage Details'**
  String get fieldCoverageDetails;

  /// No description provided for @fieldCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get fieldCreated;

  /// No description provided for @fieldCriticality.
  ///
  /// In en, this message translates to:
  /// **'Criticality'**
  String get fieldCriticality;

  /// No description provided for @fieldCustodian.
  ///
  /// In en, this message translates to:
  /// **'Custodian'**
  String get fieldCustodian;

  /// No description provided for @fieldDataAbsentReason.
  ///
  /// In en, this message translates to:
  /// **'Data Absent Reason'**
  String get fieldDataAbsentReason;

  /// No description provided for @fieldDateGiven.
  ///
  /// In en, this message translates to:
  /// **'Date Given'**
  String get fieldDateGiven;

  /// No description provided for @fieldDatePerformed.
  ///
  /// In en, this message translates to:
  /// **'Date Performed'**
  String get fieldDatePerformed;

  /// No description provided for @fieldDaysSupply.
  ///
  /// In en, this message translates to:
  /// **'Days Supply'**
  String get fieldDaysSupply;

  /// No description provided for @fieldDependent.
  ///
  /// In en, this message translates to:
  /// **'Dependent'**
  String get fieldDependent;

  /// No description provided for @fieldDerivedFrom.
  ///
  /// In en, this message translates to:
  /// **'Derived From'**
  String get fieldDerivedFrom;

  /// No description provided for @fieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get fieldDescription;

  /// No description provided for @fieldDetected.
  ///
  /// In en, this message translates to:
  /// **'Detected'**
  String get fieldDetected;

  /// No description provided for @fieldDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get fieldDevice;

  /// No description provided for @fieldDiagnoses.
  ///
  /// In en, this message translates to:
  /// **'Diagnoses'**
  String get fieldDiagnoses;

  /// No description provided for @fieldDietPreference.
  ///
  /// In en, this message translates to:
  /// **'Diet Preference'**
  String get fieldDietPreference;

  /// No description provided for @fieldDimensions.
  ///
  /// In en, this message translates to:
  /// **'Dimensions'**
  String get fieldDimensions;

  /// No description provided for @fieldDischargeDisposition.
  ///
  /// In en, this message translates to:
  /// **'Discharge Disposition'**
  String get fieldDischargeDisposition;

  /// No description provided for @fieldDischargeTo.
  ///
  /// In en, this message translates to:
  /// **'Discharge To'**
  String get fieldDischargeTo;

  /// No description provided for @fieldDisposition.
  ///
  /// In en, this message translates to:
  /// **'Disposition'**
  String get fieldDisposition;

  /// No description provided for @fieldDocumentDetails.
  ///
  /// In en, this message translates to:
  /// **'Document Details'**
  String get fieldDocumentDetails;

  /// No description provided for @fieldDocumentId.
  ///
  /// In en, this message translates to:
  /// **'Document ID'**
  String get fieldDocumentId;

  /// No description provided for @fieldDocumentStatus.
  ///
  /// In en, this message translates to:
  /// **'Document Status'**
  String get fieldDocumentStatus;

  /// No description provided for @fieldDosage.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get fieldDosage;

  /// No description provided for @fieldDose.
  ///
  /// In en, this message translates to:
  /// **'Dose'**
  String get fieldDose;

  /// No description provided for @fieldDoseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Dose Quantity'**
  String get fieldDoseQuantity;

  /// No description provided for @fieldDriversLicenseNumber.
  ///
  /// In en, this message translates to:
  /// **'Driver\'s License Number'**
  String get fieldDriversLicenseNumber;

  /// No description provided for @fieldDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get fieldDuration;

  /// No description provided for @fieldEducationProvided.
  ///
  /// In en, this message translates to:
  /// **'Education Provided'**
  String get fieldEducationProvided;

  /// No description provided for @fieldEffective.
  ///
  /// In en, this message translates to:
  /// **'Effective'**
  String get fieldEffective;

  /// No description provided for @fieldEffectiveDates.
  ///
  /// In en, this message translates to:
  /// **'Effective Dates'**
  String get fieldEffectiveDates;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @fieldEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get fieldEmergency;

  /// No description provided for @fieldEncounterType.
  ///
  /// In en, this message translates to:
  /// **'Encounter Type'**
  String get fieldEncounterType;

  /// No description provided for @fieldEndpoints.
  ///
  /// In en, this message translates to:
  /// **'Endpoints'**
  String get fieldEndpoints;

  /// No description provided for @fieldEpisodeOfCare.
  ///
  /// In en, this message translates to:
  /// **'Episode of Care'**
  String get fieldEpisodeOfCare;

  /// No description provided for @fieldEthnicity.
  ///
  /// In en, this message translates to:
  /// **'Ethnicity'**
  String get fieldEthnicity;

  /// No description provided for @fieldExpiration.
  ///
  /// In en, this message translates to:
  /// **'Expiration'**
  String get fieldExpiration;

  /// No description provided for @fieldExpirationDate.
  ///
  /// In en, this message translates to:
  /// **'Expiration Date'**
  String get fieldExpirationDate;

  /// No description provided for @fieldFacility.
  ///
  /// In en, this message translates to:
  /// **'Facility'**
  String get fieldFacility;

  /// No description provided for @fieldFacilityDetails.
  ///
  /// In en, this message translates to:
  /// **'Facility Details'**
  String get fieldFacilityDetails;

  /// No description provided for @fieldFacilityType.
  ///
  /// In en, this message translates to:
  /// **'Facility Type'**
  String get fieldFacilityType;

  /// No description provided for @fieldFastingStatus.
  ///
  /// In en, this message translates to:
  /// **'Fasting Status'**
  String get fieldFastingStatus;

  /// No description provided for @fieldFax.
  ///
  /// In en, this message translates to:
  /// **'Fax'**
  String get fieldFax;

  /// No description provided for @fieldFocalDevice.
  ///
  /// In en, this message translates to:
  /// **'Focal Device'**
  String get fieldFocalDevice;

  /// No description provided for @fieldFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Follow-up'**
  String get fieldFollowUp;

  /// No description provided for @fieldForm.
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get fieldForm;

  /// No description provided for @fieldFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get fieldFormat;

  /// No description provided for @fieldFundingSource.
  ///
  /// In en, this message translates to:
  /// **'Funding Source'**
  String get fieldFundingSource;

  /// No description provided for @fieldGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get fieldGender;

  /// No description provided for @fieldGeneralPractitioner.
  ///
  /// In en, this message translates to:
  /// **'General Practitioner'**
  String get fieldGeneralPractitioner;

  /// No description provided for @fieldGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get fieldGoal;

  /// No description provided for @fieldGoalDetails.
  ///
  /// In en, this message translates to:
  /// **'Goal Details'**
  String get fieldGoalDetails;

  /// No description provided for @fieldGpsCoordinates.
  ///
  /// In en, this message translates to:
  /// **'GPS Coordinates'**
  String get fieldGpsCoordinates;

  /// No description provided for @fieldGroupNumber.
  ///
  /// In en, this message translates to:
  /// **'Group Number'**
  String get fieldGroupNumber;

  /// No description provided for @fieldHandedOver.
  ///
  /// In en, this message translates to:
  /// **'Handed Over'**
  String get fieldHandedOver;

  /// No description provided for @fieldHealthcareFacility.
  ///
  /// In en, this message translates to:
  /// **'Healthcare Facility'**
  String get fieldHealthcareFacility;

  /// No description provided for @fieldHealthcareService.
  ///
  /// In en, this message translates to:
  /// **'Healthcare Service'**
  String get fieldHealthcareService;

  /// No description provided for @fieldHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get fieldHours;

  /// No description provided for @fieldHowToTake.
  ///
  /// In en, this message translates to:
  /// **'How to Take'**
  String get fieldHowToTake;

  /// No description provided for @fieldIdentifiers.
  ///
  /// In en, this message translates to:
  /// **'Identifiers'**
  String get fieldIdentifiers;

  /// No description provided for @fieldInformationSource.
  ///
  /// In en, this message translates to:
  /// **'Information Source'**
  String get fieldInformationSource;

  /// No description provided for @fieldIngredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get fieldIngredients;

  /// No description provided for @fieldInstructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get fieldInstructions;

  /// No description provided for @fieldInsuranceCompany.
  ///
  /// In en, this message translates to:
  /// **'Insurance Company'**
  String get fieldInsuranceCompany;

  /// No description provided for @fieldInsurer.
  ///
  /// In en, this message translates to:
  /// **'Insurer'**
  String get fieldInsurer;

  /// No description provided for @fieldIntent.
  ///
  /// In en, this message translates to:
  /// **'Intent'**
  String get fieldIntent;

  /// No description provided for @fieldInterpreter.
  ///
  /// In en, this message translates to:
  /// **'Interpreter'**
  String get fieldInterpreter;

  /// No description provided for @fieldItemsUsed.
  ///
  /// In en, this message translates to:
  /// **'Items Used'**
  String get fieldItemsUsed;

  /// No description provided for @fieldLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get fieldLanguage;

  /// No description provided for @fieldLanguages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get fieldLanguages;

  /// No description provided for @fieldLastOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Last Occurrence'**
  String get fieldLastOccurrence;

  /// No description provided for @fieldLifecycleStatus.
  ///
  /// In en, this message translates to:
  /// **'Lifecycle Status'**
  String get fieldLifecycleStatus;

  /// No description provided for @fieldLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get fieldLocation;

  /// No description provided for @fieldLocationProvider.
  ///
  /// In en, this message translates to:
  /// **'Location & Provider'**
  String get fieldLocationProvider;

  /// No description provided for @fieldLotNumber.
  ///
  /// In en, this message translates to:
  /// **'Lot Number'**
  String get fieldLotNumber;

  /// No description provided for @fieldManagingOrganization.
  ///
  /// In en, this message translates to:
  /// **'Managing Organization'**
  String get fieldManagingOrganization;

  /// No description provided for @fieldManufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get fieldManufacturer;

  /// No description provided for @fieldMaritalStatus.
  ///
  /// In en, this message translates to:
  /// **'Marital Status'**
  String get fieldMaritalStatus;

  /// No description provided for @fieldMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get fieldMedia;

  /// No description provided for @fieldMedicalRecordNumber.
  ///
  /// In en, this message translates to:
  /// **'Medical Record Number'**
  String get fieldMedicalRecordNumber;

  /// No description provided for @fieldMedication.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get fieldMedication;

  /// No description provided for @fieldMedicationDetails.
  ///
  /// In en, this message translates to:
  /// **'Medication Details'**
  String get fieldMedicationDetails;

  /// No description provided for @fieldMemberId.
  ///
  /// In en, this message translates to:
  /// **'Member ID'**
  String get fieldMemberId;

  /// No description provided for @fieldMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get fieldMembers;

  /// No description provided for @fieldMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get fieldMethod;

  /// No description provided for @fieldModality.
  ///
  /// In en, this message translates to:
  /// **'Modality'**
  String get fieldModality;

  /// No description provided for @fieldMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get fieldMode;

  /// No description provided for @fieldMothersMaidenName.
  ///
  /// In en, this message translates to:
  /// **'Mother\'s Maiden Name'**
  String get fieldMothersMaidenName;

  /// No description provided for @fieldMultipleBirth.
  ///
  /// In en, this message translates to:
  /// **'Multiple Birth'**
  String get fieldMultipleBirth;

  /// No description provided for @fieldNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get fieldNetwork;

  /// No description provided for @fieldNextDose.
  ///
  /// In en, this message translates to:
  /// **'Next Dose'**
  String get fieldNextDose;

  /// No description provided for @fieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get fieldNotes;

  /// No description provided for @fieldOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Occurrence'**
  String get fieldOccurrence;

  /// No description provided for @fieldOnset.
  ///
  /// In en, this message translates to:
  /// **'Onset'**
  String get fieldOnset;

  /// No description provided for @fieldOperationalStatus.
  ///
  /// In en, this message translates to:
  /// **'Operational Status'**
  String get fieldOperationalStatus;

  /// No description provided for @fieldOperator.
  ///
  /// In en, this message translates to:
  /// **'Operator'**
  String get fieldOperator;

  /// No description provided for @fieldOrder.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get fieldOrder;

  /// No description provided for @fieldOrderedBy.
  ///
  /// In en, this message translates to:
  /// **'Ordered By'**
  String get fieldOrderedBy;

  /// No description provided for @fieldOrganization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get fieldOrganization;

  /// No description provided for @fieldOrganizationDetails.
  ///
  /// In en, this message translates to:
  /// **'Organization Details'**
  String get fieldOrganizationDetails;

  /// No description provided for @fieldOutcome.
  ///
  /// In en, this message translates to:
  /// **'Outcome'**
  String get fieldOutcome;

  /// No description provided for @fieldOutcomeMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Outcome Measurements'**
  String get fieldOutcomeMeasurements;

  /// No description provided for @fieldPanelComponents.
  ///
  /// In en, this message translates to:
  /// **'Panel Components'**
  String get fieldPanelComponents;

  /// No description provided for @fieldParentSpecimen.
  ///
  /// In en, this message translates to:
  /// **'Parent Specimen'**
  String get fieldParentSpecimen;

  /// No description provided for @fieldPartOf.
  ///
  /// In en, this message translates to:
  /// **'Part Of'**
  String get fieldPartOf;

  /// No description provided for @fieldPassportNumber.
  ///
  /// In en, this message translates to:
  /// **'Passport Number'**
  String get fieldPassportNumber;

  /// No description provided for @fieldPatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get fieldPatient;

  /// No description provided for @fieldPerformedBy.
  ///
  /// In en, this message translates to:
  /// **'Performed By'**
  String get fieldPerformedBy;

  /// No description provided for @fieldPerformer.
  ///
  /// In en, this message translates to:
  /// **'Performer'**
  String get fieldPerformer;

  /// No description provided for @fieldPerformerType.
  ///
  /// In en, this message translates to:
  /// **'Performer Type'**
  String get fieldPerformerType;

  /// No description provided for @fieldPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get fieldPeriod;

  /// No description provided for @fieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get fieldPhone;

  /// No description provided for @fieldPhysicalType.
  ///
  /// In en, this message translates to:
  /// **'Physical Type'**
  String get fieldPhysicalType;

  /// No description provided for @fieldPlanName.
  ///
  /// In en, this message translates to:
  /// **'Plan Name'**
  String get fieldPlanName;

  /// No description provided for @fieldPlanType.
  ///
  /// In en, this message translates to:
  /// **'Plan Type'**
  String get fieldPlanType;

  /// No description provided for @fieldPolicyHolder.
  ///
  /// In en, this message translates to:
  /// **'Policy Holder'**
  String get fieldPolicyHolder;

  /// No description provided for @fieldPracticeSetting.
  ///
  /// In en, this message translates to:
  /// **'Practice Setting'**
  String get fieldPracticeSetting;

  /// No description provided for @fieldPractitioner.
  ///
  /// In en, this message translates to:
  /// **'Practitioner'**
  String get fieldPractitioner;

  /// No description provided for @fieldPrepared.
  ///
  /// In en, this message translates to:
  /// **'Prepared'**
  String get fieldPrepared;

  /// No description provided for @fieldPrescribed.
  ///
  /// In en, this message translates to:
  /// **'Prescribed'**
  String get fieldPrescribed;

  /// No description provided for @fieldPrescribedBy.
  ///
  /// In en, this message translates to:
  /// **'Prescribed By'**
  String get fieldPrescribedBy;

  /// No description provided for @fieldPrimarySource.
  ///
  /// In en, this message translates to:
  /// **'Primary Source'**
  String get fieldPrimarySource;

  /// No description provided for @fieldPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get fieldPriority;

  /// No description provided for @fieldProcedureCode.
  ///
  /// In en, this message translates to:
  /// **'Procedure Code'**
  String get fieldProcedureCode;

  /// No description provided for @fieldProcedureDetails.
  ///
  /// In en, this message translates to:
  /// **'Procedure Details'**
  String get fieldProcedureDetails;

  /// No description provided for @fieldProcessingStorage.
  ///
  /// In en, this message translates to:
  /// **'Processing & Storage'**
  String get fieldProcessingStorage;

  /// No description provided for @fieldProfessionalInformation.
  ///
  /// In en, this message translates to:
  /// **'Professional Information'**
  String get fieldProfessionalInformation;

  /// No description provided for @fieldProgramEligibility.
  ///
  /// In en, this message translates to:
  /// **'Program Eligibility'**
  String get fieldProgramEligibility;

  /// No description provided for @fieldProgressNotes.
  ///
  /// In en, this message translates to:
  /// **'Progress Notes'**
  String get fieldProgressNotes;

  /// No description provided for @fieldProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get fieldProvider;

  /// No description provided for @fieldQualification.
  ///
  /// In en, this message translates to:
  /// **'Qualification'**
  String get fieldQualification;

  /// No description provided for @fieldQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get fieldQuantity;

  /// No description provided for @fieldQuantityCollected.
  ///
  /// In en, this message translates to:
  /// **'Quantity Collected'**
  String get fieldQuantityCollected;

  /// No description provided for @fieldRace.
  ///
  /// In en, this message translates to:
  /// **'Race'**
  String get fieldRace;

  /// No description provided for @fieldRangeAppliesTo.
  ///
  /// In en, this message translates to:
  /// **'Range Applies To'**
  String get fieldRangeAppliesTo;

  /// No description provided for @fieldRangeNotes.
  ///
  /// In en, this message translates to:
  /// **'Range Notes'**
  String get fieldRangeNotes;

  /// No description provided for @fieldReAdmission.
  ///
  /// In en, this message translates to:
  /// **'Re-admission'**
  String get fieldReAdmission;

  /// No description provided for @fieldReaction.
  ///
  /// In en, this message translates to:
  /// **'Reaction'**
  String get fieldReaction;

  /// No description provided for @fieldReactions.
  ///
  /// In en, this message translates to:
  /// **'Reactions'**
  String get fieldReactions;

  /// No description provided for @fieldReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get fieldReason;

  /// No description provided for @fieldReasonForVisit.
  ///
  /// In en, this message translates to:
  /// **'Reason for Visit'**
  String get fieldReasonForVisit;

  /// No description provided for @fieldReceivedAtLab.
  ///
  /// In en, this message translates to:
  /// **'Received at Lab'**
  String get fieldReceivedAtLab;

  /// No description provided for @fieldRecorded.
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get fieldRecorded;

  /// No description provided for @fieldRecorder.
  ///
  /// In en, this message translates to:
  /// **'Recorder'**
  String get fieldRecorder;

  /// No description provided for @fieldReferenceRange.
  ///
  /// In en, this message translates to:
  /// **'Reference Range'**
  String get fieldReferenceRange;

  /// No description provided for @fieldRefills.
  ///
  /// In en, this message translates to:
  /// **'Refills'**
  String get fieldRefills;

  /// No description provided for @fieldRelatedAppointment.
  ///
  /// In en, this message translates to:
  /// **'Related Appointment'**
  String get fieldRelatedAppointment;

  /// No description provided for @fieldRelatedCondition.
  ///
  /// In en, this message translates to:
  /// **'Related Condition'**
  String get fieldRelatedCondition;

  /// No description provided for @fieldRelatedDocument.
  ///
  /// In en, this message translates to:
  /// **'Related Document'**
  String get fieldRelatedDocument;

  /// No description provided for @fieldRelationship.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get fieldRelationship;

  /// No description provided for @fieldRelationshipToSubscriber.
  ///
  /// In en, this message translates to:
  /// **'Relationship to Subscriber'**
  String get fieldRelationshipToSubscriber;

  /// No description provided for @fieldReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get fieldReport;

  /// No description provided for @fieldReportedBy.
  ///
  /// In en, this message translates to:
  /// **'Reported By'**
  String get fieldReportedBy;

  /// No description provided for @fieldRequestedBy.
  ///
  /// In en, this message translates to:
  /// **'Requested By'**
  String get fieldRequestedBy;

  /// No description provided for @fieldRequester.
  ///
  /// In en, this message translates to:
  /// **'Requester'**
  String get fieldRequester;

  /// No description provided for @fieldResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get fieldResolved;

  /// No description provided for @fieldResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get fieldResult;

  /// No description provided for @fieldResultDate.
  ///
  /// In en, this message translates to:
  /// **'Result Date'**
  String get fieldResultDate;

  /// No description provided for @fieldResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get fieldResults;

  /// No description provided for @fieldRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get fieldRole;

  /// No description provided for @fieldRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get fieldRoute;

  /// No description provided for @fieldSecurityClassification.
  ///
  /// In en, this message translates to:
  /// **'Security Classification'**
  String get fieldSecurityClassification;

  /// No description provided for @fieldSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get fieldSeries;

  /// No description provided for @fieldSeriousness.
  ///
  /// In en, this message translates to:
  /// **'Seriousness'**
  String get fieldSeriousness;

  /// No description provided for @fieldServicePeriod.
  ///
  /// In en, this message translates to:
  /// **'Service Period'**
  String get fieldServicePeriod;

  /// No description provided for @fieldServiceType.
  ///
  /// In en, this message translates to:
  /// **'Service Type'**
  String get fieldServiceType;

  /// No description provided for @fieldSetBy.
  ///
  /// In en, this message translates to:
  /// **'Set By'**
  String get fieldSetBy;

  /// No description provided for @fieldSeverity.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get fieldSeverity;

  /// No description provided for @fieldSite.
  ///
  /// In en, this message translates to:
  /// **'Site'**
  String get fieldSite;

  /// No description provided for @fieldSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get fieldSize;

  /// No description provided for @fieldSpecialArrangements.
  ///
  /// In en, this message translates to:
  /// **'Special Arrangements'**
  String get fieldSpecialArrangements;

  /// No description provided for @fieldSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get fieldSpecialty;

  /// No description provided for @fieldSpecimenDetails.
  ///
  /// In en, this message translates to:
  /// **'Specimen Details'**
  String get fieldSpecimenDetails;

  /// No description provided for @fieldSpecimenQuantity.
  ///
  /// In en, this message translates to:
  /// **'Specimen Quantity'**
  String get fieldSpecimenQuantity;

  /// No description provided for @fieldSpecimenType.
  ///
  /// In en, this message translates to:
  /// **'Specimen Type'**
  String get fieldSpecimenType;

  /// No description provided for @fieldSpecimens.
  ///
  /// In en, this message translates to:
  /// **'Specimens'**
  String get fieldSpecimens;

  /// No description provided for @fieldStage.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get fieldStage;

  /// No description provided for @fieldStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get fieldStartDate;

  /// No description provided for @fieldStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get fieldStatus;

  /// No description provided for @fieldStatusDate.
  ///
  /// In en, this message translates to:
  /// **'Status Date'**
  String get fieldStatusDate;

  /// No description provided for @fieldStatusHistory.
  ///
  /// In en, this message translates to:
  /// **'Status History'**
  String get fieldStatusHistory;

  /// No description provided for @fieldStatusReason.
  ///
  /// In en, this message translates to:
  /// **'Status Reason'**
  String get fieldStatusReason;

  /// No description provided for @fieldStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get fieldStrength;

  /// No description provided for @fieldSubpotent.
  ///
  /// In en, this message translates to:
  /// **'Subpotent'**
  String get fieldSubpotent;

  /// No description provided for @fieldSubrogation.
  ///
  /// In en, this message translates to:
  /// **'Subrogation'**
  String get fieldSubrogation;

  /// No description provided for @fieldSubscriber.
  ///
  /// In en, this message translates to:
  /// **'Subscriber'**
  String get fieldSubscriber;

  /// No description provided for @fieldSubstitution.
  ///
  /// In en, this message translates to:
  /// **'Substitution'**
  String get fieldSubstitution;

  /// No description provided for @fieldSupplies.
  ///
  /// In en, this message translates to:
  /// **'Supplies'**
  String get fieldSupplies;

  /// No description provided for @fieldTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get fieldTarget;

  /// No description provided for @fieldTestDate.
  ///
  /// In en, this message translates to:
  /// **'Test Date'**
  String get fieldTestDate;

  /// No description provided for @fieldTimePeriod.
  ///
  /// In en, this message translates to:
  /// **'Time Period'**
  String get fieldTimePeriod;

  /// No description provided for @fieldTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get fieldTotal;

  /// No description provided for @fieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get fieldType;

  /// No description provided for @fieldUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get fieldUse;

  /// No description provided for @fieldVaccinationDetails.
  ///
  /// In en, this message translates to:
  /// **'Vaccination Details'**
  String get fieldVaccinationDetails;

  /// No description provided for @fieldVaccine.
  ///
  /// In en, this message translates to:
  /// **'Vaccine'**
  String get fieldVaccine;

  /// No description provided for @fieldValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get fieldValue;

  /// No description provided for @fieldVerification.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get fieldVerification;

  /// No description provided for @fieldVerifiedBy.
  ///
  /// In en, this message translates to:
  /// **'Verified By'**
  String get fieldVerifiedBy;

  /// No description provided for @fieldView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get fieldView;

  /// No description provided for @fieldVisitDetails.
  ///
  /// In en, this message translates to:
  /// **'Visit Details'**
  String get fieldVisitDetails;

  /// No description provided for @fieldVisitType.
  ///
  /// In en, this message translates to:
  /// **'Visit Type'**
  String get fieldVisitType;

  /// No description provided for @fieldWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get fieldWebsite;

  /// No description provided for @fieldDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get fieldDateOfBirth;

  /// No description provided for @fieldAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get fieldAge;

  /// No description provided for @fieldLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last Updated'**
  String get fieldLastUpdated;

  /// No description provided for @fieldAdditive.
  ///
  /// In en, this message translates to:
  /// **'Additive'**
  String get fieldAdditive;

  /// No description provided for @fieldTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get fieldTime;

  /// No description provided for @fieldProcessingNumber.
  ///
  /// In en, this message translates to:
  /// **'Processing {number}'**
  String fieldProcessingNumber(int number);

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @moreCount.
  ///
  /// In en, this message translates to:
  /// **'{count} more'**
  String moreCount(int count);

  /// No description provided for @qualificationIssuedBy.
  ///
  /// In en, this message translates to:
  /// **'{qualification} (issued by {issuer})'**
  String qualificationIssuedBy(String qualification, String issuer);

  /// No description provided for @qualificationValidPeriod.
  ///
  /// In en, this message translates to:
  /// **'{qualification} - Valid: {period}'**
  String qualificationValidPeriod(String qualification, String period);

  /// No description provided for @sizeBytes.
  ///
  /// In en, this message translates to:
  /// **'{size} bytes'**
  String sizeBytes(String size);

  /// No description provided for @doseNumberOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Dose {dose} of {total}'**
  String doseNumberOfTotal(String dose, String total);

  /// No description provided for @doseNumber.
  ///
  /// In en, this message translates to:
  /// **'Dose {dose}'**
  String doseNumber(String dose);

  /// No description provided for @immunizationPrimarySourceYes.
  ///
  /// In en, this message translates to:
  /// **'Yes (directly administered)'**
  String get immunizationPrimarySourceYes;

  /// No description provided for @immunizationPrimarySourceNo.
  ///
  /// In en, this message translates to:
  /// **'No (reported by patient or other source)'**
  String get immunizationPrimarySourceNo;

  /// No description provided for @immunizationReactionReported.
  ///
  /// In en, this message translates to:
  /// **'Reaction reported'**
  String get immunizationReactionReported;

  /// No description provided for @immunizationNoReactions.
  ///
  /// In en, this message translates to:
  /// **'No adverse reactions reported'**
  String get immunizationNoReactions;

  /// No description provided for @immunizationSeriesComplete.
  ///
  /// In en, this message translates to:
  /// **'Not scheduled (series complete)'**
  String get immunizationSeriesComplete;

  /// No description provided for @immunizationSubpotent.
  ///
  /// In en, this message translates to:
  /// **'Vaccine is subpotent'**
  String get immunizationSubpotent;

  /// No description provided for @documentPublished.
  ///
  /// In en, this message translates to:
  /// **'{document} (published {date})'**
  String documentPublished(String document, String date);

  /// No description provided for @refillsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} refills remaining}}'**
  String refillsRemaining(int count);

  /// No description provided for @validUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String validUntil(String date);

  /// No description provided for @validFrom.
  ///
  /// In en, this message translates to:
  /// **'Valid from {date}'**
  String validFrom(String date);

  /// No description provided for @substitutionAllowed.
  ///
  /// In en, this message translates to:
  /// **'Generic substitution allowed'**
  String get substitutionAllowed;

  /// No description provided for @substitutionNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Brand name required - no substitution'**
  String get substitutionNotAllowed;

  /// No description provided for @doNotPerformRequest.
  ///
  /// In en, this message translates to:
  /// **'Do NOT perform this request'**
  String get doNotPerformRequest;

  /// No description provided for @complicationsNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get complicationsNone;

  /// No description provided for @fastedFor.
  ///
  /// In en, this message translates to:
  /// **'Fasted for {duration}'**
  String fastedFor(String duration);

  /// No description provided for @containerCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} container(s)}}'**
  String containerCount(int count);

  /// No description provided for @coverageOrderPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary (1)'**
  String get coverageOrderPrimary;

  /// No description provided for @coverageOrderSecondary.
  ///
  /// In en, this message translates to:
  /// **'Secondary (2)'**
  String get coverageOrderSecondary;

  /// No description provided for @coverageOrderTertiary.
  ///
  /// In en, this message translates to:
  /// **'Tertiary (3)'**
  String get coverageOrderTertiary;

  /// No description provided for @coverageOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order {order}'**
  String coverageOrderNumber(int order);

  /// No description provided for @goalDueBy.
  ///
  /// In en, this message translates to:
  /// **'by {date}'**
  String goalDueBy(String date);

  /// No description provided for @durationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} seconds'**
  String durationSeconds(String seconds);

  /// No description provided for @ingredientCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} ingredient(s)}}'**
  String ingredientCount(int count);

  /// No description provided for @resultCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} result(s)}}'**
  String resultCount(int count);

  /// No description provided for @specimenCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} specimen(s)}}'**
  String specimenCount(int count);

  /// No description provided for @imageCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} image(s)}}'**
  String imageCount(int count);

  /// No description provided for @ageYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} year} other{{count} years}}'**
  String ageYears(int count);

  /// No description provided for @identifierPassport.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get identifierPassport;

  /// No description provided for @multipleBirthOrder.
  ///
  /// In en, this message translates to:
  /// **'Yes (Birth order: {order})'**
  String multipleBirthOrder(String order);

  /// No description provided for @timeAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day ago} other{{count} days ago}}'**
  String timeAgoDays(int count);

  /// No description provided for @timeAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} hour ago} other{{count} hours ago}}'**
  String timeAgoHours(int count);

  /// No description provided for @timeAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} minute ago} other{{count} minutes ago}}'**
  String timeAgoMinutes(int count);

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @bloodTypeNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not Available'**
  String get bloodTypeNotAvailable;

  /// No description provided for @settingsStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorage;

  /// No description provided for @settingsStorageDescription.
  ///
  /// In en, this message translates to:
  /// **'Clear all records, preferences and cached data'**
  String get settingsStorageDescription;

  /// No description provided for @settingsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsReset;

  /// No description provided for @resetDataWarning.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all your data including synced records, notes, attachments, and preferences.'**
  String get resetDataWarning;

  /// No description provided for @resetTypeToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type {word} to confirm:'**
  String resetTypeToConfirm(String word);

  /// No description provided for @deleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get deleting;

  /// No description provided for @aiModelDownloadContinuesInBackground.
  ///
  /// In en, this message translates to:
  /// **'Download continues in background'**
  String get aiModelDownloadContinuesInBackground;

  /// No description provided for @aiModelAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get aiModelAdvanced;

  /// No description provided for @aiModelMedical.
  ///
  /// In en, this message translates to:
  /// **'Medical'**
  String get aiModelMedical;

  /// No description provided for @aiModelDescriptionLite.
  ///
  /// In en, this message translates to:
  /// **'Fast and lightweight (~{sizeGb} GB)'**
  String aiModelDescriptionLite(double sizeGb);

  /// No description provided for @aiModelDescriptionAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Higher accuracy (~{sizeGb} GB)'**
  String aiModelDescriptionAdvanced(double sizeGb);

  /// No description provided for @aiModelDescriptionUltra.
  ///
  /// In en, this message translates to:
  /// **'Best accuracy for desktop (~{sizeGb} GB)'**
  String aiModelDescriptionUltra(double sizeGb);

  /// No description provided for @aiModelDescriptionPreviousAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Previous Advanced model (~{sizeGb} GB)'**
  String aiModelDescriptionPreviousAdvanced(double sizeGb);

  /// No description provided for @settingsEhrSync.
  ///
  /// In en, this message translates to:
  /// **'EHR Sync'**
  String get settingsEhrSync;

  /// No description provided for @shareProximityTitle.
  ///
  /// In en, this message translates to:
  /// **'Share Proximity'**
  String get shareProximityTitle;

  /// No description provided for @shareProximityDescription.
  ///
  /// In en, this message translates to:
  /// **'Advertise to nearby devices'**
  String get shareProximityDescription;

  /// No description provided for @allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// No description provided for @settingsSendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send us your feedback'**
  String get settingsSendFeedback;

  /// No description provided for @toggleOn.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get toggleOn;

  /// No description provided for @toggleOff.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get toggleOff;

  /// No description provided for @idScanVerifyDetails.
  ///
  /// In en, this message translates to:
  /// **'Verify the details are correct. Retry scanning if needed.'**
  String get idScanVerifyDetails;

  /// No description provided for @idScanPartial.
  ///
  /// In en, this message translates to:
  /// **'Some fields could not be read. Try a clearer photo.'**
  String get idScanPartial;

  /// No description provided for @idScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the document. Retake with better lighting.'**
  String get idScanFailed;

  /// No description provided for @genderOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get genderOther;

  /// No description provided for @genderUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get genderUnknown;

  /// No description provided for @walletPassAge.
  ///
  /// In en, this message translates to:
  /// **'Age {age}'**
  String walletPassAge(int age);

  /// No description provided for @privacyEffectiveDate.
  ///
  /// In en, this message translates to:
  /// **'Effective Date: {date}'**
  String privacyEffectiveDate(DateTime date);

  /// No description provided for @privacyCorePrincipleBody.
  ///
  /// In en, this message translates to:
  /// **'The most important thing to know is that we, the developers of **HealthWallet.me**, do not collect, store, or have access to any of your personal or health information. Our app operates entirely on your device.'**
  String get privacyCorePrincipleBody;

  /// No description provided for @privacyNoCloudProcessing.
  ///
  /// In en, this message translates to:
  /// **'✅ No Cloud Processing: All calculations, data organization, and other functions happen locally on your phone or tablet.'**
  String get privacyNoCloudProcessing;

  /// No description provided for @privacyNoDeveloperAccess.
  ///
  /// In en, this message translates to:
  /// **'✅ No Developer Access: We cannot see, access, or export your data. It is never sent to our servers.'**
  String get privacyNoDeveloperAccess;

  /// No description provided for @privacyYouAreInControl.
  ///
  /// In en, this message translates to:
  /// **'✅ You Are in Control: Your information is stored securely within the app\'s private storage on your device, which only you can access.'**
  String get privacyYouAreInControl;

  /// No description provided for @privacyDoNotCollectIntro.
  ///
  /// In en, this message translates to:
  /// **'To be perfectly clear, our app is intentionally built to avoid accessing your personal data. We **do not** collect, store, link, or process any information that can be tied to you.'**
  String get privacyDoNotCollectIntro;

  /// No description provided for @privacyPersonalIdentifiers.
  ///
  /// In en, this message translates to:
  /// **'Personal Identifiers: We do not access or store your name, email address, phone number, contacts, or any other personal account information from your device.'**
  String get privacyPersonalIdentifiers;

  /// No description provided for @privacyHealthInformation.
  ///
  /// In en, this message translates to:
  /// **'Health Information: Any health records, medical conditions, medications, or other data you import remain yours alone. We cannot access them.'**
  String get privacyHealthInformation;

  /// No description provided for @privacyNoCrossReferencing.
  ///
  /// In en, this message translates to:
  /// **'No Cross-Referencing: The app operates in isolation. It **does not** scan, index, or cross-reference your health data with any other personal information on your phone (like your contacts list, name, or phone number). Its only job is to organize the records you provide to it.'**
  String get privacyNoCrossReferencing;

  /// No description provided for @privacyUsageAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Usage Analytics: We do not track how you use the app, which buttons you tap, or how long you spend on certain screens.'**
  String get privacyUsageAnalytics;

  /// No description provided for @privacyYouManageIntro.
  ///
  /// In en, this message translates to:
  /// **'The only data processed by the app is the health information **you choose to import** into it. This can be done in the following ways:'**
  String get privacyYouManageIntro;

  /// No description provided for @privacyImportingIntro.
  ///
  /// In en, this message translates to:
  /// **'You can add health documents (such as PDFs of lab results or clinic summaries) directly into the app using standard mobile operating system features:'**
  String get privacyImportingIntro;

  /// No description provided for @privacyScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning: Using your device\'s camera to scan a physical document from within the app.'**
  String get privacyScanning;

  /// No description provided for @privacyShareActionSheet.
  ///
  /// In en, this message translates to:
  /// **'Share Action Sheet: Selecting a file from another app (like your email, photos, or file manager) and \"sharing\" it directly to **HealthWallet.me**.'**
  String get privacyShareActionSheet;

  /// No description provided for @privacyLocalProcessing.
  ///
  /// In en, this message translates to:
  /// **'Once a document is imported, the app processes it locally on your device in the background. It structures the information according to the **HL7 FHIR (Fast Healthcare Interoperability Resources)** standard to make it useful and organized. This entire process happens on your device; the document and the structured data never leave it.'**
  String get privacyLocalProcessing;

  /// No description provided for @privacyFastenIntro.
  ///
  /// In en, this message translates to:
  /// **'Our app allows you to consolidate your health records by connecting to **FastenHealth OnPrem**, a transparent, open-source platform.'**
  String get privacyFastenIntro;

  /// No description provided for @privacyFastenOpenSource.
  ///
  /// In en, this message translates to:
  /// **'Open-Source and On-Premises: FastenHealth OnPrem is open-source software that you or a trusted entity controls. This provides an exceptional level of privacy.'**
  String get privacyFastenOpenSource;

  /// No description provided for @privacyFastenDirectDownload.
  ///
  /// In en, this message translates to:
  /// **'Direct-to-Device Download: When you authorize the connection, your health records are downloaded **directly from your FastenHealth OnPrem instance to your device**. Our app is only a conduit; your data never passes through our servers.'**
  String get privacyFastenDirectDownload;

  /// No description provided for @privacyUsageIntro.
  ///
  /// In en, this message translates to:
  /// **'Since all your data resides on your device, it is only \"used\" by the app to help you organize and view your records. This includes:'**
  String get privacyUsageIntro;

  /// No description provided for @privacyUsageProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing and structuring imported or scanned documents.'**
  String get privacyUsageProcessing;

  /// No description provided for @privacyUsageDisplaying.
  ///
  /// In en, this message translates to:
  /// **'Displaying your health records, lab results, and medication history to you.'**
  String get privacyUsageDisplaying;

  /// No description provided for @privacyNoOtherUse.
  ///
  /// In en, this message translates to:
  /// **'We do not use your information for advertising, research, or any other purpose.'**
  String get privacyNoOtherUse;

  /// No description provided for @privacyStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage: All your data is stored in the app\'s secure, sandboxed storage on your device. It is as secure as your device itself. We strongly recommend you protect your device with a passcode, Face ID, or other biometric security.'**
  String get privacyStorage;

  /// No description provided for @privacySharing.
  ///
  /// In en, this message translates to:
  /// **'Sharing: We do not and cannot share your data with anyone because we don\'t have it. If you choose to export or share your data from the app, you are in complete control of where it goes.'**
  String get privacySharing;

  /// No description provided for @privacyDeletion.
  ///
  /// In en, this message translates to:
  /// **'Deletion: You can delete your information at any time from within the app. Deleting the app from your device will also permanently delete all data it has stored.'**
  String get privacyDeletion;

  /// No description provided for @privacyChildrenBody.
  ///
  /// In en, this message translates to:
  /// **'Our service is not directed to individuals under the age of 16, in accordance with the General Data Protection Regulation (GDPR) as applicable in Romania and across the EU. We do not knowingly collect personal information from children. If you become aware that a child has provided us with personal information, please contact us.'**
  String get privacyChildrenBody;

  /// No description provided for @privacyChangesBody.
  ///
  /// In en, this message translates to:
  /// **'We may update this policy from time to time. If we make any material changes, we will notify you through the app or by other means so you can review the changes before they take effect.'**
  String get privacyChangesBody;

  /// No description provided for @privacyContactBody.
  ///
  /// In en, this message translates to:
  /// **'If you have any questions or concerns about this Privacy Policy, please contact us at:'**
  String get privacyContactBody;

  /// No description provided for @syncQrScanInstructions.
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code from your **HealthWallet.me** desktop app or **Fasten Health** to sync your data.'**
  String get syncQrScanInstructions;

  /// No description provided for @syncSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Data was successfully synced!'**
  String get syncSuccessMessage;

  /// No description provided for @syncErrorConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Please check your network and try again.'**
  String get syncErrorConnection;

  /// No description provided for @syncErrorEndpointNotFound.
  ///
  /// In en, this message translates to:
  /// **'Sync endpoint not found. Please check server configuration.'**
  String get syncErrorEndpointNotFound;

  /// No description provided for @syncErrorAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please check your token.'**
  String get syncErrorAuthentication;

  /// No description provided for @syncErrorInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid sync data format'**
  String get syncErrorInvalidFormat;

  /// No description provided for @syncErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Data sync failed: {error}'**
  String syncErrorGeneric(String error);

  /// No description provided for @syncPlaceholderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync or update your data to view {recordType} records'**
  String syncPlaceholderSubtitle(String recordType);

  /// No description provided for @appLockTitle.
  ///
  /// In en, this message translates to:
  /// **'HealthWallet is locked'**
  String get appLockTitle;

  /// No description provided for @appLockMessage.
  ///
  /// In en, this message translates to:
  /// **'Unlock to view your health records'**
  String get appLockMessage;

  /// No description provided for @appLockUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get appLockUnlock;

  /// No description provided for @desktopRestoreSucceededTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup restored'**
  String get desktopRestoreSucceededTitle;

  /// No description provided for @desktopRestoreSucceededMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" has been restored. {count} records are now on this device.'**
  String desktopRestoreSucceededMessage(String name, int count);
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
