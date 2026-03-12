import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';


abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('de'),
  ];

  String get appTitle;

  String get homeTitle;

  String get profileTitle;

  String get settingsTitle;

  String get welcomeMessage;

  String get onboardingBack;

  String get onboardingGetStarted;

  String get onboardingNext;

  String get onboardingWelcomeTitle;

  String get onboardingWelcomeSubtitle;

  String get onboardingWelcomeDescription;

  String get onboardingRecordsTitle;

  String get onboardingRecordsSubtitle;

  String get onboardingRecordsDescription;

  String get onboardingRecordsContent;

  String get onboardingRecordsBottom;

  String get onboardingRequestIntegration;

  String get onboardingScanButton;

  String get onboardingSyncTitle;

  String get onboardingSyncSubtitle;

  String get onboardingSyncDescription;

  String get onboardingBiometricText;

  String get homeHi;

  String get homeLastSynced;

  String get homeNever;

  String get homeVitalSigns;

  String get homeOverview;

  String get homeSource;

  String get homeAll;

  String get homeRecentRecords;

  String get homeViewAll;

  String get homeNA;

  String get dashboardTitle;

  String get recordsTitle;

  String get syncTitle;

  String get syncSuccessful;

  String get syncDataLoadedSuccessfully;

  String get cancelSyncTitle;

  String get cancelSyncMessage;

  String get yesCancel;

  String get continueSync;

  String get syncAgain;

  String get syncFailed;

  String get tryAgain;

  String get syncedAt;

  String get pasteSyncData;

  String get submit;

  String get hideManualEntry;

  String get enterDataManually;

  String get medicalRecords;

  String get searchRecordsHint;

  String get detailsFor;

  String get patientId;

  String get age;

  String get sex;

  String get bloodType;

  String get lastSyncedProfile;

  String get syncLatestRecords;

  String get scanToSync;

  String get theme;

  String get pleaseAuthenticate;

  String get authenticate;

  String get bypass;

  String get onboardingAuthTitle;

  String get onboardingAuthDescription;

  String get onboardingAuthEnable;

  String get onboardingAuthSkip;

  String get biometricAuthentication;

  String get privacyPolicy;

  String get setupDeviceSecurity;

  String get deviceSecurityMessage;

  String get deviceSettingsStep1;

  String get deviceSettingsStep2;

  String get deviceSettingsStep3;

  String get deviceSettingsStep4;

  String get deviceSecurityReturnMessage;

  String get cancel;

  String get openSettings;

  String get settingsNotAvailable;

  String get settingsNotAvailableMessage;

  String get ok;

  String get scanCode;

  String get or;

  String get manualSyncMessage;

  String get pasteSyncDataHint;

  String get connect;

  String get scanNewQRCode;

  String get loadDemoData;

  String get syncData;

  String get noMedicalRecordsYet;

  String noRecordTypeYet(Object recordType);

  String get loadDemoDataMessage;

  String syncDataMessage(Object recordType);

  String get retry;

  String get pleaseEnterSourceName;

  String get selectBirthDate;

  String get years;

  String get male;

  String get female;

  String get preferNotToSay;

  String get errorUpdatingSourceLabel;

  String get noChangesDetected;

  String get pleaseSelectBirthDate;

  String get errorSavingPatientData;

  String get walletHolder;

  String get walletHolderDescription;

  String get getStarted;

  String get failedToUpdateDisplayName;

  String get actionCannotBeUndone;

  String confirmDeleteFile(Object filename);

  String selectAtLeastOne(Object type);

  String get editSourceLabel;

  String get saveDetails;

  String get editDetails;

  String get done;

  String get page;

  String get reorderPages;

  String get attachments;

  String get noFilesAttached;

  String get attachFile;

  String get overview;

  String get recentRecords;

  String chooseToDisplay(Object type);

  String get displayName;

  String get bloodTypeAPositive;

  String get bloodTypeANegative;

  String get bloodTypeBPositive;

  String get bloodTypeBNegative;

  String get bloodTypeABPositive;

  String get bloodTypeABNegative;

  String get bloodTypeOPositive;

  String get bloodTypeONegative;

  String get serverError;

  String get serverTimeout;

  String get connectionError;

  String get unknownSource;

  String get synchronization;

  String get syncMedicalRecords;

  String get syncLatestMedicalRecords;

  String get neverSynced;

  String get lastSynced;

  String get tapToSelectPatient;

  String get preferences;

  String get version;

  String get on;

  String get off;

  String get confirmDisableBiometric;

  String get disable;

  String get continueButton;

  String get enableBiometricAuth;

  String get disableBiometricAuth;

  String get patient;

  String get noPatientsFound;

  String get id;

  String get gender;

  String get loading;

  String get source;

  String get showAll;

  String get records;

  String get vitals;

  String get selectAll;

  String get clearAll;

  String get save;

  String get noRecordsFound;

  String get noRecords;

  String get tryDifferentKeywords;

  String get clearAllFilters;

  String get syncingData;

  String get syncingMessage;

  String get scanQRMessage;

  String get viewAll;

  String get vitalSigns;

  String get longPressToReorder;

  String get finishProcessing;

  String get finishProcessingMessage;

  String get finishProcessingWarning;

  String get fieldCannotBeEmpty;

  String get selectDate;

  String get attachToEncounter;

  String get continueProcessing;

  String get effectiveDate;

  String get privacyIntro;

  String get privacyDescription;

  String get corePrinciple;

  String get whatInformationHandled;

  String get informationWeDoNotCollect;

  String get informationYouManage;

  String get importingDocuments;

  String get connectingFastenHealth;

  String get howInformationUsed;

  String get dataStorageSecurity;

  String get childrensPrivacy;

  String get changesToPolicy;

  String get contactUs;

  String get builtWithLove;

  String get sourceName;

  String get provideCustomLabel;

  String get success;

  String get demoDataLoadedSuccessfully;

  String get documentScanTitle;

  String get onboardingAiModelTitle;

  String get onboardingAiModelDescription;

  String get onboardingAiModelSubtitle;

  String get aiModelReady;

  String get aiModelDownloading;

  String get aiModelEnableDownload;

  String get aiModelError;

  String get aiModelMissing;

  String get aiModelTitle;

  String get aiModelUnlockTitle;

  String get aiModelUnlockDescription;

  String get aiModelDownloadInfo;

  String get setup;

  String get patientSetupTitle;

  String get patientSetupSubtitle;

  String get onboardingSetupTitle;

  String get onboardingSetupBody;

  String get onboardingDemoTitle;

  String get onboardingDemoBody;

  String get onboardingSyncTitle2;

  String get onboardingSyncBody;

  String get givenName;

  String get familyName;

  String get skipForNow;

  String get setUpProfile;

  String get useDefaults;

  String get syncPlaceholderTutorialStep1;

  String get syncPlaceholderTutorialStep2;

  String get syncPlaceholderTutorialStep3;

  String get tapToContinue;

  String get homeOnboardingReorderMessage;

  String get processing;

  String get sessionNotFound;

  String get preparingPreview;

  String get processingFailed;

  String get processingCancelled;

  String get processingBasicDetails;

  String get processingPages;

  String get extractingPatientInfo;

  String get pleaseWait;

  String get focusMode;

  String get onlyOneSessionAtTime;

  String get aiModelNotAvailable;

  String get addResources;

  String get addResourcesTitle;

  String get chooseResourcesDescription;

  String get add;

  String get allergyIntolerance;

  String get condition;

  String get diagnosticReport;

  String get medicationStatement;

  String get observation;

  String get organization;

  String get practitioner;

  String get procedure;

  String get tapToViewProgress;

  String screenWillDarkenInSeconds(int remainingSeconds);

  String get screenWillDarkenInZeroSeconds;

  String get whileDocumentsProcessed;

  String get doNotLockScreen;

  String get plugInCharger;

  String get exitFocusMode;

  String get chargerPluggedIn;

  String get plugInChargerEllipsis;

  String get processingFailedCapacity;

  String get processingFailedCapacitySuggestion;

  String get increaseAiModelCapacity;

  String get goBack;

  String get aiModelManage;

  String get aiModelNotSelected;

  String get aiModelSelect;

  String get aiSettings;

  String get aiSettingsDescription;

  String get setAiTokensUsage;

  String get tokenUsageDescription;

  String get gpuLayersLabel;

  String get gpuLayersDescription;

  String get threadsLabel;

  String get threadsDescription;

  String get recommended;

  String get tokenPresetLow;

  String get tokenPresetLowDescription;

  String get tokenPresetMedium;

  String get tokenPresetMediumDescription;

  String get tokenPresetHigh;

  String get tokenPresetHighDescription;

  String get tokenPresetCustom;

  String get tokenPresetCustomDescription;

  String get setTokens;

  String get tokens;

  String get contextSizeLabel;

  String get contextSizeDescription;

  String get useVisionLabel;

  String get useVisionDescription;

  String get aiModelNotAvailableForDevice;

  String get aiModelNotAvailableForDeviceDescription;

  String get noInternetConnectionTitle;

  String get noInternetConnectionDescription;

  String get processingStep2NotAvailableTitle;

  String get processingStep2NotEnoughRam;

  String get emergencyContact;

  String get emergencyContactHint;

  String get searchCountry;

  String get rotatePage;

  String get deletePage;

  String get deletePageConfirmTitle;

  String get deletePageConfirmMessage;

  String get cannotDeleteLastPage;

  String get pageRotated;

  String get regionAndUnits;

  String get regionUS;

  String get regionEurope;

  String get regionUK;

  String get medGemmaIncompatibleDevice;
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
      <String>['de', 'en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
