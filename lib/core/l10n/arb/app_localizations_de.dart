// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get onboardingWelcomeTitle => 'eine Gesundheits-Brieftasche für dich!';

  @override
  String get onboardingWelcomeSubtitle =>
      '<link>HealthWallet.me</link> verbindet dich bereits mit über 100.000 US-Gesundheitseinrichtungen und wir expandieren in neue Länder.';

  @override
  String get onboardingWelcomeDescription =>
      'Füge Aufzeichnungen von beliebigen Anbietern hinzu, importiere Dokumente manuell oder fordere Unterstützung für dein Land an.';

  @override
  String get onboardingRecordsTitle => 'Deine Gesundheit, Immer Synchron';

  @override
  String get onboardingRecordsSubtitle =>
      '<link>HealthWallet.me</link> bietet dir flexible Möglichkeiten, deine gesamte Krankengeschichte zusammenzubringen:';

  @override
  String get onboardingRecordsDescription =>
      '• Dokumente mit der Handykamera scannen\n• PDFs, Bilder oder Labordateien direkt hochladen\n• Aufzeichnungen teilen, indem du direkt von jeder App auf deinem Smartphone mit <link>HealthWallet.me</link> teilst.\n• QR-Code von Fasten Health OnPrem scannen und alle Aufzeichnungen aus dem US-Gesundheitssystem in dein Wallet übertragen.';

  @override
  String get onboardingRecordsContent =>
      '• Dokumente mit der Handykamera scannen\n• PDFs, Bilder oder Labordateien direkt hochladen\n• Aufzeichnungen importieren, indem du sie aus jeder App auf deinem Smartphone direkt mit <link>HealthWallet.me</link> teilst.\n• Den QR-Code von <link>Fasten Health OnPrem</link> scannen und alle Aufzeichnungen aus dem US-Gesundheitssystem in dein Wallet holen.';

  @override
  String get onboardingRecordsBottom =>
      'Alles wird sicher auf deinem Gerät organisiert.';

  @override
  String get onboardingRequestIntegration => 'Integration anfragen';

  @override
  String get onboardingScanButton => 'Scannen';

  @override
  String get onboardingSyncTitle => 'Sicherheit & Datenschutz';

  @override
  String get onboardingSyncSubtitle =>
      'Deine Gesundheitsdaten gehören nur dir.';

  @override
  String get onboardingSyncDescription =>
      'Wir glauben, dass deine sensiblen Gesundheitsinformationen niemals auf einem Firmenserver liegen sollten. Deine Daten sind verschlüsselt und ausschließlich auf deinem Gerät gespeichert, was bedeutet, dass nur du Zugang hast.';

  @override
  String get homeHi => 'Hallo, ';

  @override
  String get homeVitalSigns => 'Vitalzeichen';

  @override
  String get homeSource => 'Quelle:';

  @override
  String get homeNA => 'N/A';

  @override
  String get dashboardTitle => 'Übersicht';

  @override
  String get recordsTitle => 'Aufzeichnungen';

  @override
  String get goToRecords => 'Zu Aufzeichnungen';

  @override
  String get syncTitle => 'Synchronisieren';

  @override
  String get syncSuccessful => 'Synchronisierung erfolgreich!';

  @override
  String get syncDataLoadedSuccessfully =>
      'Deine medizinischen Aufzeichnungen wurden synchronisiert. Du wirst zur Startseite weitergeleitet.';

  @override
  String get cancelSyncTitle => 'Synchronisierung abbrechen?';

  @override
  String get cancelSyncMessage =>
      'Bist du sicher, dass du die Synchronisierung abbrechen möchtest? Dies wird den aktuellen Synchronisierungsprozess stoppen.';

  @override
  String get yesCancel => 'Ja, abbrechen';

  @override
  String get continueSync => 'Synchronisierung fortsetzen';

  @override
  String get tryAgain => 'Erneut versuchen';

  @override
  String get searchRecordsHint => 'Suche nach Aufzeichnungen, Ärzten, Orten...';

  @override
  String get patientId => 'Patienten-ID: ';

  @override
  String get age => 'Alter';

  @override
  String get sex => 'Geschlecht';

  @override
  String get bloodType => 'Blutgruppe';

  @override
  String get theme => 'Thema';

  @override
  String get authenticate => 'Authentifizieren';

  @override
  String get biometricAuthentication => 'Biometrische Authentifizierung';

  @override
  String get privacyPolicy => 'Datenschutz-Bestimmungen';

  @override
  String get setupDeviceSecurity => 'Gerätesicherheit einrichten';

  @override
  String get deviceSecurityMessage =>
      'Dein Gerät hat keine Sicherheitseinrichtung. Zu deiner Sicherheit richte bitte die Gerätesicherheit ein, bevor du diese App verwendest:';

  @override
  String get deviceSettingsStep1 => 'Gehe zu deinen Geräteeinstellungen';

  @override
  String get deviceSettingsStep2 =>
      'Navigiere zu Sicherheit oder Sperrbildschirm';

  @override
  String get deviceSettingsStep3 =>
      'Richte eine Bildschirmsperre ein (PIN, Muster oder Passwort)';

  @override
  String get deviceSettingsStep4 =>
      'Füge optional Fingerabdruck oder Gesichtserkennung für mehr Komfort hinzu';

  @override
  String get deviceSecurityReturnMessage =>
      'Nach dem Einrichten der Gerätesicherheit kehre zu dieser App zurück und versuche es erneut.';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get openSettings => 'Einstellungen öffnen';

  @override
  String get settingsNotAvailable => 'Einstellungen nicht verfügbar';

  @override
  String get settingsNotAvailableMessage =>
      'Geräteeinstellungen konnten nicht automatisch geöffnet werden. Bitte manuell:\n\n1. Einstellungen öffnen\n2. Zu Sicherheit → Biometrie gehen\n3. Fingerabdruck oder Gesichtserkennung hinzufügen\n4. Zu dieser App zurückkehren und erneut versuchen';

  @override
  String get ok => 'OK';

  @override
  String get or => 'oder';

  @override
  String get connect => 'Verbinden';

  @override
  String get loadDemoData => 'Demo-Daten laden';

  @override
  String get noMedicalRecordsYet => 'Noch keine medizinischen Aufzeichnungen';

  @override
  String get loadDemoDataMessage =>
      'Lade Demo-Daten, um die App zu erkunden, oder synchronisiere deine echten medizinischen Aufzeichnungen';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get pleaseEnterSourceName => 'Bitte gib einen Quellennamen ein';

  @override
  String get selectBirthDate => 'Geburtsdatum auswählen';

  @override
  String get years => 'Jahre';

  @override
  String get male => 'Männlich';

  @override
  String get female => 'Weiblich';

  @override
  String get preferNotToSay => 'Keine Angabe';

  @override
  String get errorUpdatingSourceLabel =>
      'Fehler beim Aktualisieren der Quellenbezeichnung';

  @override
  String get getStarted => 'Los geht\'s';

  @override
  String get failedToUpdateDisplayName =>
      'Fehler beim Aktualisieren des Anzeigenamens';

  @override
  String get actionCannotBeUndone =>
      'Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get deleteSourceConfirmPrefix => 'Dadurch werden ';

  @override
  String get deleteSourceConfirmSuffix =>
      ' und alle zugehörigen Aufzeichnungen dauerhaft gelöscht. Gib zur Bestätigung unten den Namen der Quelle ein.';

  @override
  String get deleteRecordConfirm =>
      'Bist du sicher, dass du diesen Eintrag löschen möchtest?';

  @override
  String get deleteNoteConfirm =>
      'Bist du sicher, dass du diese Notiz löschen möchtest?';

  @override
  String get deleteAttachmentConfirm =>
      'Bist du sicher, dass du diesen Anhang löschen möchtest?';

  @override
  String deleteRecordsConfirm(int count) {
    return 'Bist du sicher, dass du $count Einträge löschen möchtest?';
  }

  @override
  String get editSourceLabel => 'Quellenbezeichnung bearbeiten';

  @override
  String get saveDetails => 'Details speichern';

  @override
  String get editDetails => 'Details bearbeiten';

  @override
  String get done => 'Fertig';

  @override
  String get page => 'Seite';

  @override
  String get reorderPages => 'Seiten neu ordnen';

  @override
  String get attachments => 'Anhänge';

  @override
  String get noFilesAttached =>
      'Dieser Datensatz hat keine angehängten Dateien';

  @override
  String get attachFile => 'Datei anhängen';

  @override
  String get overview => 'Überblick';

  @override
  String get recentRecords => 'Neueste Einträge';

  @override
  String get displayName => 'Anzeigename';

  @override
  String get unknownSource => 'Unbekannte Quelle';

  @override
  String get desktopSyncAndBackup => 'Datensynchronisierung & Backup';

  @override
  String get desktopSyncDescription =>
      'Synchronisiere und sichere deine Gesundheitsdaten.\nÜbergib Dokumente zur digitalen Verarbeitung auf deinem Desktop.';

  @override
  String get processOnDesktop => 'Auf dem Desktop verarbeiten';

  @override
  String get continueImporting => 'Weiter importieren';

  @override
  String get noAiModel => 'Kein KI-Modell';

  @override
  String get noAiModelOnDesktop =>
      'Kein KI-Modell auf dem Desktop. Bitte lade zuerst das KI-Modell auf deiner Desktop-App herunter.';

  @override
  String get syncMedicalRecords =>
      'Medizinische Aufzeichnungen synchronisieren';

  @override
  String get lastSynced => 'Zuletzt synchronisiert';

  @override
  String get tapToSelectPatient => 'Tippe, um einen Patienten auszuwählen';

  @override
  String get preferences => 'Einstellungen';

  @override
  String get version => 'Version';

  @override
  String get on => 'EIN';

  @override
  String get off => 'AUS';

  @override
  String get confirmDisableBiometric =>
      'Bist du sicher, dass du die biometrische Authentifizierung (FaceID / Passcode) deaktivieren möchtest?';

  @override
  String get disable => 'Deaktivieren';

  @override
  String get continueButton => 'Weiter';

  @override
  String get enableBiometricAuth =>
      'Biometrische Authentifizierung aktivieren (FaceID / Passcode)';

  @override
  String get disableBiometricAuth =>
      'Biometrische Authentifizierung deaktivieren (FaceID / Passcode)';

  @override
  String get patient => 'Patient';

  @override
  String get noPatientsFound => 'Keine Patienten gefunden';

  @override
  String get id => 'ID';

  @override
  String get gender => 'Geschlecht';

  @override
  String get loading => 'Wird geladen...';

  @override
  String get source => 'Quelle';

  @override
  String get records => 'Aufzeichnungen';

  @override
  String get vitals => 'Vitalzeichen';

  @override
  String get selectAll => 'Alle auswählen';

  @override
  String get clearAll => 'Alle löschen';

  @override
  String get deselectAll => 'Alle abwählen';

  @override
  String get save => 'Speichern';

  @override
  String get noRecordsFound => 'Keine Aufzeichnungen gefunden';

  @override
  String get noRecords => 'keine Aufzeichnungen';

  @override
  String get tryDifferentKeywords => 'Versuche es mit anderen Suchbegriffen';

  @override
  String get syncingData => 'Daten werden synchronisiert';

  @override
  String get syncingMessage => 'Das kann eine Weile dauern. Bitte warten.';

  @override
  String get viewAll => 'Alle anzeigen';

  @override
  String get vitalSigns => 'Vitalzeichen';

  @override
  String get longPressToReorder =>
      'Lange drücken, um Karten zu verschieben und neu anzuordnen, oder filtern, um auszuwählen, welche in deinem Dashboard erscheinen.';

  @override
  String get finishProcessing => 'Verarbeitung beenden';

  @override
  String get finishProcessingMessage =>
      'Bist du sicher, dass du diese Verarbeitungssitzung beenden möchtest?';

  @override
  String get finishProcessingWarning => 'Dies löscht die aktuelle Sitzung.';

  @override
  String get fieldCannotBeEmpty => 'Dieses Feld darf nicht leer sein';

  @override
  String get selectDate => 'Datum auswählen';

  @override
  String get attachToEncounter => 'An Termin anhängen';

  @override
  String get attachToPatient => 'An Patient anhängen';

  @override
  String get continueProcessing => 'Verarbeitung fortsetzen';

  @override
  String get recordsSavedTitle => 'Erfolgreich gespeichert';

  @override
  String get whatNextQuestion => 'Was möchtest du als Nächstes tun?';

  @override
  String get continueScanning => 'Weiter Scannen';

  @override
  String get effectiveDate => 'Gültigkeitsdatum';

  @override
  String get privacyIntro => 'Deine Privatsphäre ist unsere höchste Priorität.';

  @override
  String get privacyDescription =>
      'ist ein einfaches, sicheres Tool, das dir hilft, deine Gesundheitsakten einfach direkt auf deinem Gerät zu organisieren. Diese Richtlinie erklärt unser Engagement für deine Privatsphäre: Wir sammeln deine Daten nicht und verfolgen dich nicht. Du hast die vollständige Kontrolle.';

  @override
  String get corePrinciple =>
      'Unser Grundprinzip: Deine Daten bleiben auf deinem Gerät';

  @override
  String get whatInformationHandled =>
      'Welche Informationen werden verarbeitet?';

  @override
  String get informationWeDoNotCollect =>
      'Informationen, die wir nicht sammeln oder darauf zugreifen';

  @override
  String get informationYouManage => 'Informationen, die du verwaltest';

  @override
  String get importingDocuments => 'Dokumente von deinem Gerät importieren';

  @override
  String get connectingFastenHealth => 'Verbindung zu FastenHealth OnPrem';

  @override
  String get howInformationUsed => 'Wie deine Informationen verwendet werden';

  @override
  String get dataStorageSecurity =>
      'Datenspeicherung, Sicherheit und Weitergabe';

  @override
  String get childrensPrivacy => 'Privatsphäre von Kindern';

  @override
  String get changesToPolicy => 'Änderungen an dieser Datenschutzrichtlinie';

  @override
  String get contactUs => 'Kontaktiere uns';

  @override
  String get builtWithLove => 'Mit Liebe von Life Value gebaut!';

  @override
  String get sourceName => 'Quellenname';

  @override
  String get provideCustomLabel => 'Gib ein benutzerdefiniertes Label an für:';

  @override
  String get success => 'Erfolg';

  @override
  String get demoDataLoadedSuccessfully =>
      'Demo-Daten wurden erfolgreich geladen. Du wirst zur Startseite weitergeleitet.';

  @override
  String get documentScanTitle => 'Scannen';

  @override
  String get fromPhoneTab => 'Vom Handy';

  @override
  String get onboardingAiModelTitle => 'KI-Modell aktivieren';

  @override
  String get onboardingAiModelDescription =>
      'Lade ein sicheres, geräteinternes KI-Modell herunter, um deine Gesundheitsakten automatisch zu analysieren und zu organisieren. Wähle zwischen zwei Optionen je nach Bedarf und Gerätekapazität. Dies ist eine einmalige Einrichtung.\n\n**Deine Daten bleiben privat auf deinem Gerät.**';

  @override
  String get onboardingAiModelSubtitle => 'KI-gestütztes Scannen freischalten';

  @override
  String get aiModelReady => 'KI bereit! Du kannst mit dem Scannen beginnen.';

  @override
  String get aiModelDownloading => 'Wird heruntergeladen...';

  @override
  String get aiModelEnableDownload => 'Auswählen & Herunterladen';

  @override
  String get aiModelError =>
      'Überprüfung fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String get aiModelMissing => 'Nicht heruntergeladen.';

  @override
  String get aiModelTitle => 'KI-Modell laden';

  @override
  String get aiModelUnlockTitle => 'KI-gestütztes Scannen freischalten';

  @override
  String get aiModelUnlockDescription =>
      'Um deine medizinischen Dokumente automatisch zu lesen und zu organisieren, verwendet diese Funktion ein sicheres, geräteinternes KI-Modell.\n\n**Deine Daten bleiben privat auf deinem Gerät.**';

  @override
  String get aiModelDownloadInfo =>
      'Um zu beginnen, wähle und lade eine der zwei verfügbaren KI-Optionen herunter. Dies ist eine einmalige Einrichtung.';

  @override
  String get setup => 'Einrichten';

  @override
  String get patientSetupSubtitle =>
      'Personalisiere deine Gesundheits-Brieftasche mit deinen Informationen';

  @override
  String get givenName => 'Vorname';

  @override
  String get familyName => 'Nachname';

  @override
  String get syncPlaceholderTutorialStep1 =>
      'Vervollständige dein Profil, um alle Funktionen freizuschalten.';

  @override
  String get syncPlaceholderTutorialStep2 =>
      'Noch nicht bereit zum Importieren? Lade Demo-Daten, um zu sehen, wie die App in Aktion aussieht.';

  @override
  String get syncPlaceholderTutorialStep3 =>
      'Halte deine Desktop- und Mobile-Wallet auf dem neuesten Stand.';

  @override
  String get tapToContinue => 'Tippe, um fortzufahren';

  @override
  String get homeOnboardingReorderMessage =>
      'Lange drücken, um sie nach deinen Wünschen neu anzuordnen.';

  @override
  String get processing => 'Verarbeitung';

  @override
  String get sessionNotFound => 'Sitzung nicht gefunden!';

  @override
  String get preparingPreview => 'Vorschau wird vorbereitet...';

  @override
  String get processingFailed => 'Verarbeitung fehlgeschlagen';

  @override
  String get modelNotFoundError =>
      'Modelldatei nicht gefunden. Bitte laden Sie das KI-Modell zuerst herunter.';

  @override
  String get modelCorruptedError =>
      'Modelldatei ist beschädigt. Bitte laden Sie das KI-Modell erneut herunter.';

  @override
  String get processingFailedGeneric =>
      'Beim Verarbeiten des Dokuments ist ein Fehler aufgetreten. Bitte versuche es erneut.';

  @override
  String get processingCancelled => 'Die Verarbeitung wurde abgebrochen';

  @override
  String get processingBasicDetails => 'Grunddaten werden verarbeitet...';

  @override
  String get processingPages => 'Seiten werden verarbeitet...';

  @override
  String get extractingPatientInfo =>
      'Patienten- und Termininformationen werden extrahiert.';

  @override
  String get pleaseWait => 'Es kann eine Weile dauern. Bitte warten.';

  @override
  String get focusMode => 'Fokusmodus';

  @override
  String get onlyOneSessionAtTime =>
      'Nur eine Verarbeitungssitzung kann gleichzeitig ausgeführt werden';

  @override
  String get aiModelNotAvailable => 'Intelligentes Scannen ist nicht verfügbar';

  @override
  String get addResources => 'Ressourcen hinzufügen';

  @override
  String get addResourcesTitle => 'Ressourcen hinzufügen';

  @override
  String get chooseResourcesDescription =>
      'Wähle die Ressourcen aus, die du zur Verarbeitung hinzufügen möchtest.';

  @override
  String get add => 'Hinzufügen';

  @override
  String get allergyIntolerance => 'Allergie';

  @override
  String get condition => 'Erkrankung';

  @override
  String get diagnosticReport => 'Diagnosebericht';

  @override
  String get medicationStatement => 'Medikamentenerklärung';

  @override
  String get observation => 'Beobachtung';

  @override
  String get organization => 'Organisation';

  @override
  String get practitioner => 'Fachkraft';

  @override
  String get procedure => 'Maßnahme';

  @override
  String get tapToViewProgress =>
      'Tippe irgendwo, um den Fortschritt anzuzeigen';

  @override
  String screenWillDarkenInSeconds(int remainingSeconds) {
    return 'Der Bildschirm wird sich in $remainingSeconds Sekunden verdunkeln.';
  }

  @override
  String get screenWillDarkenInZeroSeconds =>
      'Der Bildschirm wird sich in 0 Sekunden verdunkeln.';

  @override
  String get whileDocumentsProcessed =>
      'Während deine Dokumente verarbeitet werden:';

  @override
  String get doNotLockScreen =>
      'Sperre den Bildschirm nicht und verlasse die App nicht.';

  @override
  String get plugInCharger => 'Stecke das Ladegerät ein.';

  @override
  String get exitFocusMode => 'Fokusmodus beenden';

  @override
  String get chargerPluggedIn => 'Ladegerät eingesteckt.';

  @override
  String get plugInChargerEllipsis => 'Stecke das Ladegerät ein...';

  @override
  String get processingFailedCapacity =>
      'Das Dokument ist zu groß für den aktuellen KI-Arbeitsspeicher.';

  @override
  String get processingFailedCapacitySuggestion =>
      'Tippe oben auf das Einstellungssymbol und erhöhe den KI-Arbeitsspeicher auf 2048 oder höher, dann erneut versuchen.';

  @override
  String get increaseAiModelCapacity => 'KI-Kapazität erhöhen';

  @override
  String get goBack => 'Zurück';

  @override
  String get aiModelManage => 'KI-Optionen verwalten';

  @override
  String get aiModelNotSelected => 'Keine Option ausgewählt';

  @override
  String get aiModelSelect => 'Option auswählen';

  @override
  String get aiSettings => 'KI-Einstellungen';

  @override
  String get aiSettingsDescription =>
      'KI-Leistung für dein Gerät anpassen. Empfohlene Werte sind vorausgewählt.';

  @override
  String get setAiTokensUsage => 'Maximale Antwortlänge';

  @override
  String get tokenUsageDescription =>
      'Wie viel die KI pro Schritt höchstens schreiben darf, während sie die gefundenen Einträge deines Dokuments auflistet. Zu kurz, und manche Einträge werden abgeschnitten; länger dauert mehr Zeit. Es passt immer in den KI-Arbeitsspeicher.';

  @override
  String get gpuLayersLabel => 'Grafikchip (GPU)';

  @override
  String get gpuLayersDescription =>
      'Wie viel der KI auf dem Grafikchip deines Geräts läuft, der schneller ist als der Hauptprozessor. Höher ist schneller, braucht aber mehr Speicher. Wenn die App beim Scannen schließt oder abstürzt, verringere den Wert oder setze ihn auf 0.';

  @override
  String get threadsLabel => 'Prozessorkerne (CPU)';

  @override
  String get threadsDescription =>
      'Wie viele Prozessorkerne die KI gleichzeitig nutzt. Mehr ist schneller, verbraucht aber den Akku schneller und kann das Gerät warm machen.';

  @override
  String get recommended => 'Empfohlen';

  @override
  String get tokenPresetLow => 'Kurz';

  @override
  String get tokenPresetMedium => 'Mittel';

  @override
  String get tokenPresetHigh => 'Lang';

  @override
  String get tokenPresetCustom => 'Benutzerdefiniert';

  @override
  String get setTokens => 'Festlegen';

  @override
  String get contextSizeLabel => 'KI-Arbeitsspeicher';

  @override
  String get contextSizeDescription =>
      'Der Arbeitsbereich der KI für einen Schritt: Platz, um dein Dokument zu lesen und aufzuschreiben, was sie findet. Größer passt für längere Dokumente, braucht aber mehr Speicher deines Geräts. Wenn das Scannen mit „nicht genügend Speicher“ fehlschlägt, verringere ihn.';

  @override
  String get useVisionLabel => 'Tiefenscan';

  @override
  String get useVisionDescription =>
      'Liest Bilder für eine tiefere Analyse (z. B. Handschrift). Verbraucht mehr Speicher und erfordert ein leistungsfähigeres Gerät.';

  @override
  String get aiModelNotAvailableForDevice =>
      'Nicht verfügbar für dieses Telefon';

  @override
  String get aiModelNotAvailableForDeviceDescription =>
      'Dieses Gerät hat nicht genügend Speicher, um intelligentes Scannen auszuführen.';

  @override
  String get noInternetConnectionTitle => 'Keine Internetverbindung';

  @override
  String get noInternetConnectionDescription =>
      'Bitte überprüfe deine Internetverbindung und versuche es erneut.';

  @override
  String get processingStep2NotAvailableTitle =>
      'Tiefenscan auf diesem Gerät nicht verfügbar';

  @override
  String get processingStep2NotEnoughRam =>
      'Dieses Gerät hat nicht genügend Speicher für den Tiefenscan. Textbasierte Verarbeitung ist weiterhin verfügbar und funktioniert gut für die meisten Dokumente.';

  @override
  String get emergencyContact => 'Notfall-Telefonkontakt';

  @override
  String get rotatePage => 'Drehen';

  @override
  String get deletePage => 'Löschen';

  @override
  String get deletePageConfirmTitle => 'Seite löschen';

  @override
  String get deletePageConfirmMessage =>
      'Diese Seite wird aus dem Dokument entfernt.';

  @override
  String get regionAndUnits => 'Sprache & Einheiten';

  @override
  String get country => 'Land';

  @override
  String patientModifiedUpdating(String name) {
    return 'Bestehenden Patienten ändern: $name';
  }

  @override
  String patientSavingModified(String name) {
    return 'Geänderten Patienten speichern: $name';
  }

  @override
  String get dropModificationsTitle => 'Änderungen verwerfen?';

  @override
  String get dropModificationsMessage =>
      'Deine Änderungen an den Patientenfeldern werden verworfen.';

  @override
  String get scanIdCard => 'Ausweis oder Reisepass scannen';

  @override
  String get scanIdCardDescription =>
      'Automatisch aus deinem Dokument ausfüllen. Daten bleiben auf deinem Gerät.';

  @override
  String get newLabel => 'Neu';

  @override
  String get newPatient => 'Neuer Patient';

  @override
  String patientChangedTo(String name) {
    return 'Geändert zu: $name';
  }

  @override
  String patientMatchFound(String name) {
    return 'Bestehender Patient: $name';
  }

  @override
  String get language => 'Sprache';

  @override
  String get systemDefault => 'Systemstandard';

  @override
  String get regionUS => 'US';

  @override
  String get regionEurope => 'Europa';

  @override
  String get regionUK => 'UK';

  @override
  String get medGemmaIncompatibleDevice =>
      'Dieses Modell benötigt mehr Arbeitsspeicher als auf deinem Gerät verfügbar ist. Verwende stattdessen das Lite-Modell.';

  @override
  String get deepScanDownloadTitle => 'Visionsmodell herunterladen';

  @override
  String deepScanDownloadMessage(int size) {
    return 'Tiefenscan erfordert einen zusätzlichen Download (~$size MB). Jetzt herunterladen?';
  }

  @override
  String get shareUnknownDevice => 'Unbekanntes Gerät';

  @override
  String get shareViewOnlyBanner =>
      'NUR ANSICHT - Daten werden gelöscht, wenn du die Sitzung schließt oder den Näherungsbereich verlässt';

  @override
  String get shareViewOnlyBannerViewing =>
      'NUR ANSICHT - Daten werden beim Verlassen gelöscht';

  @override
  String get shareInfoBannerMessage =>
      'Geteilte Aufzeichnungen sind schreibgeschützt. Alle Daten werden automatisch gelöscht, wenn die Sitzung endet oder das Zeitlimit abläuft.';

  @override
  String get shareTitle => 'Teilen';

  @override
  String get shareFindDevices => 'Geräte suchen';

  @override
  String get shareWaiting => 'Warten...';

  @override
  String get shareConnectingTitle => 'Verbinden';

  @override
  String get shareSending => 'Senden';

  @override
  String get shareReceiving => 'Empfangen';

  @override
  String get shareSessionActive => 'Sitzung Aktiv';

  @override
  String get shareViewingRecords => 'Aufzeichnungen ansehen';

  @override
  String get shareComplete => 'Abgeschlossen';

  @override
  String get shareError => 'Fehler';

  @override
  String get sharePermissionsRequired => 'Berechtigungen Erforderlich';

  @override
  String get shareHealthWalletDevice => 'HealthWallet-Gerät';

  @override
  String get shareInvitationDeclined => 'Einladung Abgelehnt';

  @override
  String get shareSessionComplete => 'Sitzung Abgeschlossen';

  @override
  String get shareInvitationDeclinedMessage =>
      'Der Empfänger hat deine Einladung zur Ansicht der Aufzeichnungen abgelehnt.';

  @override
  String get shareSessionCompleteMessage =>
      'Alle geteilten Daten wurden sicher von diesem Gerät entfernt';

  @override
  String get shareBackHome => 'Zurück zum Start';

  @override
  String get shareConnectionFailed => 'Verbindung Fehlgeschlagen';

  @override
  String get shareUnableToConnect =>
      'Verbindung nicht möglich. Bitte versuche es erneut.';

  @override
  String get shareNoDataReceived => 'Keine Daten empfangen';

  @override
  String get shareSearchRecords => 'Aufzeichnungen suchen';

  @override
  String get shareNoRecordsMatchFilters =>
      'Keine Aufzeichnungen entsprechen den Filtern';

  @override
  String get shareNoRecordsAvailable => 'Keine Aufzeichnungen verfügbar';

  @override
  String get shareReceiverViewingRecords =>
      'Empfänger sieht sich Aufzeichnungen an';

  @override
  String get shareSessionAutoExpire =>
      'Die Sitzung läuft automatisch ab, wenn der Timer Null erreicht';

  @override
  String get shareRecordsDelivered => 'Aufzeichnungen erfolgreich zugestellt';

  @override
  String get shareConnecting => 'Verbinden...';

  @override
  String get shareConnectionInterrupted =>
      'Verbindung unterbrochen, Neuverbindung';

  @override
  String get shareSendingRecords => 'Aufzeichnungen werden gesendet...';

  @override
  String get shareReceivingRecords => 'Aufzeichnungen werden empfangen...';

  @override
  String get shareVerifyTitle => 'Codes vergleichen';

  @override
  String get shareVerifySenderHint =>
      'Prüfe, ob das andere Telefon denselben Code anzeigt. Deine Einträge bleiben gesperrt, bis du bestätigst.';

  @override
  String get shareVerifyReceiverHint =>
      'Prüfe, ob das andere Telefon denselben Code anzeigt. Die Einträge öffnen sich, sobald der Absender bestätigt.';

  @override
  String get shareVerifyCodesMatch => 'Codes stimmen überein';

  @override
  String get shareVerifyWaitingForSender =>
      'Warte auf die Bestätigung des Absenders...';

  @override
  String get shareAwaitingViewer =>
      'Codes bestätigt. Warte darauf, dass das andere Telefon die Einträge öffnet.';

  @override
  String get shareEndNotDelivered =>
      'Das andere Telefon war nicht erreichbar. Es behält die Einträge, bis sein Timer abläuft.';

  @override
  String get shareConfirmExit => 'Ausgang Bestätigen';

  @override
  String get shareDeleteSharedRecords => 'Geteilte Aufzeichnungen Löschen?';

  @override
  String get shareDeleteWarning =>
      'Die geteilte Aufzeichnung wird dauerhaft von diesem Gerät gelöscht. Die Aktion kann nicht rückgängig gemacht werden';

  @override
  String get shareDeleteAndExit => 'Löschen & Beenden';

  @override
  String get shareIncomingTransfer => 'Eingehende Übertragung';

  @override
  String get shareViewOnlyWarning =>
      'Aufzeichnungen sind schreibgeschützt und werden beim Verlassen automatisch gelöscht';

  @override
  String get shareDecline => 'Ablehnen';

  @override
  String get shareAccept => 'Akzeptieren';

  @override
  String get shareSearchingForDevices => 'Suche nach Geräten in der Nähe...';

  @override
  String get shareSearchForDevices => 'Nach Geräten suchen...';

  @override
  String get shareNoDevicesFound => 'Keine Geräte Gefunden';

  @override
  String get shareConnectionIssue => 'Verbindungsproblem';

  @override
  String get shareWifiDirectUnresponsive =>
      'WiFi Direct reagiert auf diesem Gerät nicht.';

  @override
  String get shareWifiToggleHint =>
      'WiFi Direct reagiert nicht. Schalte WiFi aus/ein und tippe auf Wiederholen.';

  @override
  String get shareDiscoveryHint =>
      'Stelle sicher, dass auf dem anderen Gerät die HealthWallet.me App geöffnet ist';

  @override
  String get shareProximityHint =>
      'Das empfangende Gerät muss Näherungsfreigabe in den Einstellungen AKTIVIERT haben, um erkennbar zu sein.';

  @override
  String get shareNoRecordsMatchSelectedFilters =>
      'Keine Aufzeichnungen entsprechen den ausgewählten Filtern';

  @override
  String get shareNoRecordsForAppliedFilters =>
      'Keine Aufzeichnungen für die angewendeten Filter gefunden';

  @override
  String get shareTryClearingFilters => 'Versuche, einige Filter zu löschen';

  @override
  String get shareRecordsPageFiltersNoResults =>
      'Die Filter der Aufzeichnungsseite ergaben keine Ergebnisse';

  @override
  String get shareImportOrSyncRecords =>
      'Importiere oder synchronisiere Aufzeichnungen, um sie zu teilen';

  @override
  String get shareSessionTime => 'Sitzungszeit';

  @override
  String get shareSetAsDefault => 'Als Standard festlegen';

  @override
  String get shareRecordsButton => 'Aufzeichnungen Teilen';

  @override
  String get shareSelectRecordsToShare => 'Wähle Aufzeichnungen zum Teilen';

  @override
  String get shareEndSession => 'Sitzung Beenden';

  @override
  String get shareRequestTenMin => '+10 Min anfordern';

  @override
  String get shareWaitingForResponse => 'Warte auf Antwort...';

  @override
  String get shareAddMoreTime => 'Mehr Zeit hinzufügen';

  @override
  String get shareSessionExpiresIn => 'Sitzung läuft ab in';

  @override
  String get shareExtensionRequestedTitle => 'Verlängerung Angefordert';

  @override
  String get shareHoursLabel => 'Stunden';

  @override
  String get shareMinLabel => 'Min';

  @override
  String shareSelectedCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String shareRecordCount(int recordCount) {
    return '$recordCount Aufzeichnung(en)';
  }

  @override
  String shareSharedFrom(String source) {
    return 'geteilt von $source';
  }

  @override
  String shareFoundDevices(int count) {
    return '$count Gerät(e) gefunden';
  }

  @override
  String shareRetryingCount(int retryCount) {
    return 'Wiederholung ($retryCount/3)...';
  }

  @override
  String shareDeviceWantsToShare(String deviceName) {
    return '$deviceName möchte Aufzeichnungen mit dir teilen';
  }

  @override
  String shareExtensionsUsed(int used, int max) {
    return '$used/$max Verlängerungen verwendet';
  }

  @override
  String shareDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h $minutes Min';
  }

  @override
  String shareDurationHours(int hours) {
    return '${hours}h';
  }

  @override
  String shareDurationMinutes(int minutes) {
    return '$minutes Min';
  }

  @override
  String shareTimerHoursMinutesSeconds(int hours, int minutes, int seconds) {
    return '${hours}h ${minutes}Min ${seconds}s';
  }

  @override
  String shareTimerMinutesSeconds(int minutes, int seconds) {
    return '${minutes}Min ${seconds}s';
  }

  @override
  String shareTimerSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String shareMinuteCount(int minutes) {
    return '$minutes Minute(n)';
  }

  @override
  String shareSecondsCount(int seconds) {
    return '$seconds Sekunden';
  }

  @override
  String shareExtensionRequestMessage(String peerRole, String duration) {
    return 'Der $peerRole möchte die Sitzung um $duration verlängern';
  }

  @override
  String get desktopSyncNotYet => 'Noch nicht';

  @override
  String get desktopSyncTransfer => 'Übertragung';

  @override
  String desktopSyncTransferValue(int sentRows, int receivedRows) {
    return '$sentRows gesendet, $receivedRows empfangen';
  }

  @override
  String get desktopSyncPending => 'Ausstehend';

  @override
  String desktopSyncPendingValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen',
      one: '1 Änderung',
    );
    return '$_temp0';
  }

  @override
  String desktopSyncingTable(String tableName) {
    return '$tableName wird synchronisiert...';
  }

  @override
  String get desktopSyncing => 'Synchronisiere...';

  @override
  String get desktopSyncNow => 'Jetzt synchronisieren';

  @override
  String get desktopSyncError => 'Fehler';

  @override
  String get desktopSyncInSync => 'Synchron';

  @override
  String get desktopSyncReady => 'Bereit';

  @override
  String get desktopSyncOffline => 'Offline';

  @override
  String get desktopTableHealthRecords => 'Gesundheitsdaten';

  @override
  String get desktopTableSources => 'Quellen';

  @override
  String get desktopTableNotes => 'Notizen';

  @override
  String get desktopTableSessions => 'Sitzungen';

  @override
  String get desktopConnection => 'Verbindung';

  @override
  String get desktopGeneratePairingQr => 'Kopplungs-QR generieren';

  @override
  String get desktopScanFromMobile => 'Über die mobile Sync-Seite scannen';

  @override
  String get desktopDevice => 'Gerät';

  @override
  String get desktopTransport => 'Übertragung';

  @override
  String get desktopIp => 'IP';

  @override
  String get desktopPort => 'Port';

  @override
  String get desktopNewPairing => 'Neue Kopplung';

  @override
  String get desktopTransportTcp => 'TCP über WLAN';

  @override
  String get desktopTransportMpc => 'MultipeerConnectivity (Direkt)';

  @override
  String desktopConnectedTo(String name) {
    return 'Verbunden mit $name';
  }

  @override
  String get desktopConnected => 'Verbunden';

  @override
  String desktopReconnectingTo(String name) {
    return 'Verbindung zu $name wird wiederhergestellt...';
  }

  @override
  String get desktopReconnecting => 'Verbindung wird wiederhergestellt...';

  @override
  String desktopDisconnectedFrom(String name) {
    return 'Verbindung zu $name getrennt';
  }

  @override
  String get desktopDisconnected => 'Getrennt';

  @override
  String get desktopDisconnect => 'Trennen';

  @override
  String get desktopReconnect => 'Erneut verbinden';

  @override
  String get desktopVpnDetected =>
      'VPN erkannt. Trenne das VPN, um mit dem Desktop zu synchronisieren.';

  @override
  String get desktopVpnBlocksPhone =>
      'Auf diesem Computer ist ein VPN aktiv. Es kann verhindern, dass sich dein Telefon verbindet: Schalte es aus oder erlaube in den VPN-Einstellungen den Zugriff auf das lokale Netzwerk.';

  @override
  String get desktopPairing => 'Kopplung';

  @override
  String get desktopLabel => 'Desktop';

  @override
  String get desktopScanFromPhoneToPair =>
      'Scanne mit deinem Handy, um zu koppeln';

  @override
  String get desktopNewQrCode => 'Neuer QR-Code';

  @override
  String get desktopGenerateQrCode => 'QR-Code generieren';

  @override
  String get desktopScanQrCode => 'QR-Code scannen';

  @override
  String get desktopChooseWhereToSave => 'Wähle einen Speicherort für Backups';

  @override
  String get desktopSelectBackupFolder =>
      'Wähle einen Ordner auf deinem Computer zum Speichern der Backup-Dateien';

  @override
  String get desktopChooseLocation => 'Speicherort wählen';

  @override
  String get desktopChooseBackupLocation => 'Backup-Speicherort wählen';

  @override
  String get desktopBackingUp => 'Sicherung läuft...';

  @override
  String get desktopCreateBackup => 'Backup erstellen';

  @override
  String get desktopSyncWithPhoneFirst =>
      'Zuerst mit dem Handy synchronisieren';

  @override
  String get desktopNotConnected => '(nicht verbunden)';

  @override
  String get desktopStartBackup => 'Backup starten';

  @override
  String get desktopNoBackupsYet => 'Noch keine Backups';

  @override
  String get desktopCreateFirstBackup =>
      'Erstelle dein erstes Backup, um deine Gesundheitsdaten zu sichern';

  @override
  String get desktopAllBackups => 'Alle Backups';

  @override
  String get desktopDate => 'Datum';

  @override
  String get desktopSize => 'Größe';

  @override
  String get desktopChecksum => 'Prüfsumme';

  @override
  String get desktopRestoreThisBackup => 'Dieses Backup wiederherstellen';

  @override
  String get desktopRestoreBackupTitle => 'Backup wiederherstellen?';

  @override
  String get desktopRestore => 'Wiederherstellen';

  @override
  String get desktopDeleteBackupTitle => 'Backup löschen?';

  @override
  String desktopDeleteBackupMessage(String name) {
    return '\"$name\" löschen?\n\nDies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get desktopDelete => 'Löschen';

  @override
  String get desktopBackupFrom => 'Backup vom';

  @override
  String get desktopBackup => 'Backup';

  @override
  String get desktopChange => 'Ändern';

  @override
  String get desktopProcessingHistory => 'Verarbeitungsverlauf';

  @override
  String get desktopScannedOnPhone => 'Auf dem Handy gescannt';

  @override
  String get desktopProcessedOnDesktop => 'Auf dem Desktop verarbeitet';

  @override
  String get desktopImportedOnDesktop => 'Auf dem Desktop importiert';

  @override
  String get desktopSyncRecent => 'Kürzlich';

  @override
  String get desktopUnknownDevice => 'Unbekanntes Gerät';

  @override
  String desktopSyncHistoryTransfer(int sentRows, int receivedRows) {
    return '$sentRows gesendet · $receivedRows empfangen';
  }

  @override
  String get desktopNewDeviceConnecting => 'Neues Gerät verbindet sich';

  @override
  String desktopNewDeviceMessage(String address, String currentDevice) {
    return 'Ein neues Gerät ($address) möchte sich verbinden.\n\nDies trennt die Verbindung zu \"$currentDevice\".\n\nZum neuen Gerät wechseln?';
  }

  @override
  String get desktopKeepCurrent => 'Aktuelles behalten';

  @override
  String get desktopSwitch => 'Wechseln';

  @override
  String get desktopCurrentDevice => 'aktuelles Gerät';

  @override
  String get desktopHandoverPreparing => 'Wird vorbereitet...';

  @override
  String get desktopHandoverSendingFiles => 'Dateien werden gesendet...';

  @override
  String get desktopHandoverSending => 'Wird gesendet...';

  @override
  String get desktopHandoverSendingToDesktop => 'Wird an den Desktop gesendet';

  @override
  String desktopHandoverFileCount(int count) {
    return '$count Dateien';
  }

  @override
  String get desktopClose => 'Schließen';

  @override
  String get desktopContinueImporting => 'Weiter importieren';

  @override
  String get desktopHandoverToDesktop => 'An Desktop übergeben';

  @override
  String get desktopHandoverProcessingMessage =>
      'Verarbeitung läuft. Die Übergabe wird die aktuelle Verarbeitung abbrechen und Dateien an den Desktop senden.';

  @override
  String get desktopHandover => 'Übergabe';

  @override
  String get attachedDocuments => 'Angehängte Dokumente';

  @override
  String get cameraPermissionRequired => 'Kamerazugriff erforderlich';

  @override
  String get cameraPermissionRequiredMessage =>
      'Diese App benötigt Kamerazugriff zum Scannen. Bitte erteile die Berechtigung.';

  @override
  String get cameraPermissionDenied => 'Kamerazugriff verweigert';

  @override
  String get cameraPermissionDeniedMessage =>
      'Der Kamerazugriff wurde dauerhaft verweigert. Bitte aktiviere ihn in den Einstellungen.';

  @override
  String get successTitle => 'Erfolg!';

  @override
  String attachmentSuccessMessage(int count) {
    return '$count Dokumente erfolgreich dem Termin angehängt.';
  }

  @override
  String get encounterLabel => 'Termin';

  @override
  String get viewRecords => 'Aufzeichnungen ansehen';

  @override
  String get errorTitle => 'Fehler';

  @override
  String get somethingWentWrong => 'Etwas ist schiefgelaufen';

  @override
  String get importDocument => 'Dokument importieren';

  @override
  String get pickImageFromGallery => 'Bild aus Galerie wählen';

  @override
  String get scanDocument => 'Dokument scannen';

  @override
  String get deleteSession => 'Sitzung löschen';

  @override
  String get deleteSessionConfirmation =>
      'Möchtest du diese Sitzung wirklich löschen?';

  @override
  String get delete => 'Löschen';

  @override
  String get canceling => 'Wird abgebrochen...';

  @override
  String get waitingForAiToFinish => 'Warte auf Abschluss der KI...';

  @override
  String get logsCopied => 'Protokolle kopiert';

  @override
  String get download => 'Herunterladen';

  @override
  String get active => 'Aktiv';

  @override
  String get tapToSelect => 'Tippen zum Auswählen';

  @override
  String deviceInfoChip(
    String platform,
    String ramGB,
    int cores,
    int estimatedMB,
  ) {
    return '$platform  •  $ramGB GB RAM  •  $cores Kerne  •  ~$estimatedMB MB benötigt';
  }

  @override
  String get downloadContinuesInBackground =>
      'Du kannst weiternavigieren — der Download läuft im Hintergrund.\nBenachrichtigungen zeigen den Fortschritt.';

  @override
  String get continueWithoutAi =>
      'Ohne KI fortfahren (Download im Hintergrund)';

  @override
  String get continueUsingApp => 'App weiter nutzen';

  @override
  String get attachWithoutProcessing => 'Dokument ohne Verarbeitung anhängen';

  @override
  String get currentPatientAndSource => 'Aktueller Patient & Quelle';

  @override
  String get createEncounter => 'Termin erstellen';

  @override
  String get encounterName => 'Terminname';

  @override
  String get enterEncounterName => 'Terminname eingeben';

  @override
  String get pleaseEnterEncounterName => 'Bitte gib einen Terminnamen ein';

  @override
  String get date => 'Datum';

  @override
  String get create => 'Erstellen';

  @override
  String get searchEncounters => 'Termine suchen...';

  @override
  String get noEncountersFound => 'Keine Termine gefunden';

  @override
  String get noEncountersFoundMessage =>
      'Erstelle zuerst einen neuen Termin oder wähle einen anderen Patienten.';

  @override
  String get newEncounterPrefix => 'Neuer Termin';

  @override
  String get scannedDocumentsTitle => 'Gescannte Dokumente';

  @override
  String scannedDocumentsPagesTitle(String count) {
    return 'Gescannte Dokumente ($count Seiten)';
  }

  @override
  String pdfFileTitle(String fileName) {
    return 'PDF: $fileName';
  }

  @override
  String get labelOrganizationName => 'Name der Organisation';

  @override
  String get labelAddress => 'Adresse';

  @override
  String get labelPhone => 'Telefon';

  @override
  String get labelEncounterName => 'Terminname';

  @override
  String get labelStartDate => 'Startdatum';

  @override
  String get labelFirstName => 'Vorname';

  @override
  String get labelFamilyName => 'Nachname';

  @override
  String get labelDateOfBirth => 'Geburtsdatum';

  @override
  String get labelGender => 'Geschlecht';

  @override
  String get labelReportName => 'Berichtsname';

  @override
  String get labelConclusion => 'Befund';

  @override
  String get labelIssuedDate => 'Ausstellungsdatum';

  @override
  String get labelPractitionerName => 'Arztname';

  @override
  String get labelSpecialty => 'Fachgebiet';

  @override
  String get labelIdentifier => 'Kennung';

  @override
  String get labelConditionName => 'Diagnose';

  @override
  String get labelOnsetDate => 'Beginn';

  @override
  String get labelClinicalStatus => 'Klinischer Status';

  @override
  String get labelSubstance => 'Substanz';

  @override
  String get labelManifestation => 'Symptome';

  @override
  String get labelCategory => 'Kategorie';

  @override
  String get labelProcedureName => 'Maßnahme';

  @override
  String get labelPerformedDate => 'Durchgeführt am';

  @override
  String get labelReason => 'Grund';

  @override
  String get labelMedicationName => 'Medikament';

  @override
  String get labelDosage => 'Dosierung';

  @override
  String get labelObservationName => 'Beobachtung';

  @override
  String get labelValue => 'Wert';

  @override
  String get labelUnit => 'Einheit';

  @override
  String get labelReferenceRange => 'Referenzbereich';

  @override
  String get permissionsRequired => 'Berechtigungen erforderlich';

  @override
  String recordsSelectedCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String get noRecordsSelected => 'Keine Aufzeichnungen ausgewählt';

  @override
  String get select => 'Auswählen';

  @override
  String get selectRecordsBeforeSharing =>
      'Aufzeichnungen auswählen\nvor dem Teilen';

  @override
  String get selectRecordToViewDetails =>
      'Wähle einen Eintrag, um Details anzuzeigen';

  @override
  String get recordDetails => 'Aufzeichnungsdetails';

  @override
  String get viewDocument => 'Dokument ansehen';

  @override
  String get encounterDetails => 'Termindetails';

  @override
  String get relatedResources => 'Zugehörige Einträge';

  @override
  String deletePlusRelated(int count) {
    return 'Löschen + $count zugehörige';
  }

  @override
  String get relatedResourcesKeptHint =>
      'Zugehörige Einträge bleiben erhalten, außer du wählst sie unten aus.';

  @override
  String relatedResourcesCount(int count) {
    return 'Zugehörige Einträge ($count)';
  }

  @override
  String get fileNotAvailable => 'Datei auf diesem Gerät nicht verfügbar';

  @override
  String get failedToLoadImage => 'Bild konnte nicht geladen werden';

  @override
  String get notes => 'Notizen';

  @override
  String get noNotesAttached => 'Keine Notizen vorhanden';

  @override
  String get addNote => 'Notiz hinzufügen';

  @override
  String get editNote => 'Notiz bearbeiten';

  @override
  String get filters => 'Filter';

  @override
  String get timeRange => 'Zeitraum';

  @override
  String get applyFilters => 'Filter anwenden';

  @override
  String get recordType => 'Aufzeichnungstyp';

  @override
  String get specialty => 'Fachgebiet';

  @override
  String get allSpecialties => 'Alle Fachgebiete';

  @override
  String get selectedRange => 'Ausgewählter Zeitraum';

  @override
  String get noRangeSelected => 'Kein Zeitraum ausgewählt';

  @override
  String get clearDateRange => 'Zeitraum zurücksetzen';

  @override
  String get start => 'Beginn';

  @override
  String get end => 'Ende';

  @override
  String fromDate(String date) {
    return 'Ab $date';
  }

  @override
  String untilDate(String date) {
    return 'Bis $date';
  }

  @override
  String get day => 'Tag';

  @override
  String get month => 'Monat';

  @override
  String get year => 'Jahr';

  @override
  String get mediaInfo => 'Medieninfo';

  @override
  String get linkToEncounter => 'Mit Termin verknüpfen';

  @override
  String get noPdfDataAvailable => 'Keine PDF-Daten verfügbar';

  @override
  String get failedToLoadPdf => 'PDF konnte nicht geladen werden';

  @override
  String get fileOpenFailed =>
      'Die Datei konnte nicht geöffnet werden. Bitte versuche es erneut.';

  @override
  String get mediaInformation => 'Medieninformationen';

  @override
  String get mediaInfoTitle => 'Titel:';

  @override
  String get mediaInfoType => 'Typ:';

  @override
  String get mediaInfoStatus => 'Status:';

  @override
  String get mediaInfoPatient => 'Patient:';

  @override
  String get mediaInfoEncounter => 'Termin:';

  @override
  String get mediaInfoFileSize => 'Dateigröße:';

  @override
  String get mediaInfoCreated => 'Erstellt:';

  @override
  String get mediaInfoResourceId => 'Ressourcen-ID:';

  @override
  String get mediaInfoSource => 'Quelle:';

  @override
  String get close => 'Schließen';

  @override
  String get linkMediaToEncounterDescription =>
      'Diese Mediendatei mit einem Termin verknüpfen:';

  @override
  String get encounterId => 'Termin-ID';

  @override
  String get encounterIdHint => 'z. B. termin-123';

  @override
  String get mediaLinkedSuccess =>
      'Mediendatei erfolgreich mit Termin verknüpft';

  @override
  String get linkMediaFailed =>
      'Die Mediendatei konnte nicht mit dem Termin verknüpft werden. Bitte versuche es erneut.';

  @override
  String get link => 'Verknüpfen';

  @override
  String get connectionLabel => 'Verbindung';

  @override
  String get connectionStatusConnected => 'Verbunden';

  @override
  String get connectionStatusConnecting => 'Verbindung wird hergestellt...';

  @override
  String get connectionStatusDisconnected => 'Getrennt';

  @override
  String get connectionStatusNotPaired => 'Nicht gekoppelt';

  @override
  String get syncLabel => 'Sync';

  @override
  String get syncStatusSyncing => 'Synchronisiere...';

  @override
  String get syncStatusNotSynced => 'Nicht synchronisiert';

  @override
  String get syncStatusInSync => 'Synchron';

  @override
  String syncStatusPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen ausstehend',
      one: '1 Änderung ausstehend',
    );
    return '$_temp0';
  }

  @override
  String get backupLabel => 'Backup';

  @override
  String get backupStatusWorking => 'In Arbeit...';

  @override
  String get backupStatusNoBackup => 'Kein Backup';

  @override
  String get backupStatusBackingUp => 'Sicherung läuft...';

  @override
  String get backupStatusRestoring => 'Wird wiederhergestellt...';

  @override
  String get backupStatusWaiting => 'Warten...';

  @override
  String get backupStatusNotConnected => 'Nicht verbunden';

  @override
  String get backupStatusNoFolder => 'Kein Backup-Ordner';

  @override
  String get backupStatusNoDesktopFolder => 'Kein Ordner am Desktop';

  @override
  String get backupNoFolderChosen => 'Kein Ordner gewählt';

  @override
  String get chooseLabel => 'Auswählen';

  @override
  String get exportIpsPdf => 'IPS exportieren (PDF)';

  @override
  String get addIpsToAppleWallet => 'IPS zu Apple Wallet hinzufügen';

  @override
  String get addIpsToGoogleWallet => 'IPS zu Google Wallet hinzufügen';

  @override
  String get ipsExportFailed =>
      'Deine Gesundheitsübersicht konnte nicht exportiert werden. Bitte versuche es erneut.';

  @override
  String get walletPassFailed =>
      'Der Pass konnte nicht zu deinem Wallet hinzugefügt werden. Bitte versuche es erneut.';

  @override
  String get sourcesTitle => 'Quellen';

  @override
  String get emergencyMedicalId => 'Medizinischer Notfallausweis';

  @override
  String get phoneLabel => 'Telefon';

  @override
  String get allergiesLabel => 'Allergien';

  @override
  String get medicalConditionsLabel => 'Erkrankungen';

  @override
  String get medicationsLabel => 'Medikamente';

  @override
  String get conditionsLabel => 'Erkrankungen';

  @override
  String get dateOfBirthLabel => 'Geburtsdatum';

  @override
  String get emergencyPhoneLabel => 'Notfalltelefon';

  @override
  String get openingScanner => 'Scanner wird geöffnet...';

  @override
  String get activeScanSessions => 'Aktive Scan-Sitzungen:';

  @override
  String get noScansYet => 'Noch keine Scans';

  @override
  String get scanOrImportToGetStarted =>
      'Scanne oder importiere Dokumente, um zu beginnen';

  @override
  String pageOfTotal(String current, String total) {
    return '$current von $total';
  }

  @override
  String get fileNotFound => 'Datei nicht gefunden';

  @override
  String get fileIsEmpty => 'Datei ist leer';

  @override
  String get importTitle => 'Importieren';

  @override
  String get activeImportSessions => 'Aktive Import-Sitzungen:';

  @override
  String get dropToImport => 'Zum Importieren ablegen';

  @override
  String get dropFilesHereToImport => 'Dateien hier zum Importieren ablegen';

  @override
  String get supportedFileFormats => 'PDF, JPG, PNG, TIFF';

  @override
  String get browseFiles => 'Dateien durchsuchen';

  @override
  String get noImportsYet => 'Noch keine Importe';

  @override
  String get importOrScanToGetStarted =>
      'Importiere oder scanne Dokumente, um zu beginnen';

  @override
  String get notificationsTitle => 'Benachrichtigungen';

  @override
  String get noNotifications => 'Keine Benachrichtigungen';

  @override
  String get cancelDownloadTitle => 'Download abbrechen';

  @override
  String get cancelDownloadMessage =>
      'Möchtest du den Download des KI-Modells wirklich abbrechen? Du kannst ihn später neu starten.';

  @override
  String get processingDone => 'Verarbeitung abgeschlossen';

  @override
  String pairedWithDevice(String deviceName) {
    return 'Gekoppelt mit $deviceName';
  }

  @override
  String get deviceSyncLabel => 'Gerätesync';

  @override
  String get disconnectLabel => 'Trennen';

  @override
  String get changeLabel => 'Ändern';

  @override
  String get minimizeToTray => 'In Taskleiste minimieren';

  @override
  String get changeSpecialty => 'Fachgebiet ändern';

  @override
  String get changeSpecialtyConfirm =>
      'Möchtest du das Fachgebiet wirklich ändern in';

  @override
  String get removeSpecialtyConfirm =>
      'Möchtest du das Fachgebiet wirklich von dieser Aufzeichnung entfernen?';

  @override
  String get confirm => 'Bestätigen';

  @override
  String get currentRecord => 'Aktueller Eintrag';

  @override
  String get vitalHeartRate => 'Herzfrequenz';

  @override
  String get vitalBloodPressure => 'Blutdruck';

  @override
  String get vitalTemperature => 'Temperatur';

  @override
  String get vitalBloodOxygen => 'Blutsauerstoff';

  @override
  String get vitalRespiratoryRate => 'Atemfrequenz';

  @override
  String get vitalWeight => 'Gewicht';

  @override
  String get vitalHeight => 'Größe';

  @override
  String get vitalBmi => 'BMI';

  @override
  String get vitalBloodGlucose => 'Blutzucker';

  @override
  String get vitalSystolicBloodPressure => 'Systolischer Blutdruck';

  @override
  String get vitalDiastolicBloodPressure => 'Diastolischer Blutdruck';

  @override
  String get unitBeatsPerMinute => 'Schläge/min';

  @override
  String get unitBreathsPerMinute => 'Atemzüge/min';

  @override
  String get unitPounds => 'Pfund';

  @override
  String get unitInches => 'Zoll';

  @override
  String get unitKilograms => 'Kilogramm';

  @override
  String get unitCentimeters => 'Zentimeter';

  @override
  String get specialtyAllergology => 'Allergologie';

  @override
  String get specialtyCardiology => 'Kardiologie';

  @override
  String get specialtyDental => 'Zahnmedizin';

  @override
  String get specialtyDermatology => 'Dermatologie';

  @override
  String get specialtyEmergencyMedicine => 'Notfallmedizin';

  @override
  String get specialtyEndocrinology => 'Endokrinologie';

  @override
  String get specialtyGastroenterology => 'Gastroenterologie';

  @override
  String get specialtyGeneralCare => 'Allgemeinmedizin';

  @override
  String get specialtyGynecology => 'Gynäkologie';

  @override
  String get specialtyNephrology => 'Nephrologie';

  @override
  String get specialtyNeurology => 'Neurologie';

  @override
  String get specialtyOncology => 'Onkologie';

  @override
  String get specialtyOphthalmology => 'Augenheilkunde';

  @override
  String get specialtyOrthopedics => 'Orthopädie';

  @override
  String get specialtyPsychiatry => 'Psychiatrie';

  @override
  String get specialtyPulmonology => 'Pneumologie';

  @override
  String get specialtyRheumatology => 'Rheumatologie';

  @override
  String get specialtyUrology => 'Urologie';

  @override
  String get categoryAllergies => 'Allergien';

  @override
  String get categoryCareTeam => 'Behandlungsteam';

  @override
  String get categoryClinicalNotes => 'Klinische Notizen';

  @override
  String get categoryFiles => 'Dateien';

  @override
  String get categoryLabResults => 'Laborergebnisse';

  @override
  String get categoryHealthIssues => 'Gesundheitsprobleme';

  @override
  String get categoryFacilities => 'Einrichtungen';

  @override
  String get categoryHealthGoals => 'Gesundheitsziele';

  @override
  String get categoryImmunizations => 'Impfungen';

  @override
  String get categoryMedications => 'Medikamente';

  @override
  String get categoryDemographics => 'Persönliche Daten';

  @override
  String get categoryProcedures => 'Maßnahmen';

  @override
  String get categoryHealthInsurance => 'Krankenversicherung';

  @override
  String get fhirTypeAdverseEvent => 'Unerwünschtes Ereignis';

  @override
  String get fhirTypeAllergyIntolerance => 'Allergie';

  @override
  String get fhirTypeBinary => 'Binärdatei';

  @override
  String get fhirTypeCareTeam => 'Behandlungsteam';

  @override
  String get fhirTypeClaim => 'Leistungsantrag';

  @override
  String get fhirTypeCondition => 'Erkrankung';

  @override
  String get fhirTypeCoverage => 'Versicherungsschutz';

  @override
  String get fhirTypeDiagnosticReport => 'Befundbericht';

  @override
  String get fhirTypeDocumentReference => 'Dokument';

  @override
  String get fhirTypeEncounter => 'Termin';

  @override
  String get fhirTypeExplanationOfBenefit => 'Leistungsabrechnung';

  @override
  String get fhirTypeGoal => 'Ziel';

  @override
  String get fhirTypeImmunization => 'Impfung';

  @override
  String get fhirTypeLocation => 'Standort';

  @override
  String get fhirTypeMedia => 'Medien';

  @override
  String get fhirTypeMedication => 'Medikament';

  @override
  String get fhirTypeMedicationAdministration => 'Medikamentengabe';

  @override
  String get fhirTypeMedicationDispense => 'Medikamentenausgabe';

  @override
  String get fhirTypeMedicationRequest => 'Medikamentenverordnung';

  @override
  String get fhirTypeMedicationStatement => 'Medikamentenerklärung';

  @override
  String get fhirTypeObservation => 'Beobachtung';

  @override
  String get fhirTypeOrganization => 'Organisation';

  @override
  String get fhirTypePatient => 'Patient';

  @override
  String get fhirTypePractitioner => 'Fachkraft';

  @override
  String get fhirTypePractitionerRole => 'Rolle der Fachkraft';

  @override
  String get fhirTypeProcedure => 'Maßnahme';

  @override
  String get fhirTypeRelatedPerson => 'Bezugsperson';

  @override
  String get fhirTypeServiceRequest => 'Leistungsanforderung';

  @override
  String get fhirTypeSpecimen => 'Probe';

  @override
  String get fhirTypeGeneralResource => 'Ressource';

  @override
  String get processingOriginScan => 'Scan';

  @override
  String get processingOriginImport => 'Import';

  @override
  String get processingOriginHandover => 'Übergabe';

  @override
  String get processingStatusPending => 'Ausstehend';

  @override
  String get processingStatusProcessingPatient => 'Patient wird verarbeitet';

  @override
  String get processingStatusPatientExtracted => 'Patient extrahiert';

  @override
  String get processingStatusProcessing => 'Wird verarbeitet';

  @override
  String get processingStatusDraft => 'Entwurf';

  @override
  String get processingStatusCancelled => 'Abgebrochen';

  @override
  String get showAll => 'Alle anzeigen';

  @override
  String get showLess => 'Weniger anzeigen';

  @override
  String get all => 'Alle';

  @override
  String get gotIt => 'Verstanden';

  @override
  String get homeSpecialties => 'Fachgebiete';

  @override
  String get homeResources => 'Ressourcen';

  @override
  String get homeDefaultUserName => 'Nutzer';

  @override
  String get selectSpecialty => 'Fachgebiet auswählen';

  @override
  String get removeSpecialty => 'Fachgebiet entfernen';

  @override
  String get chooseRecordsForDashboard =>
      'Wähle die Aufzeichnungen aus, die du in deiner Übersicht sehen möchtest.';

  @override
  String get selectAtLeastOneRecordType =>
      'Wähle mindestens eine Art von Aufzeichnung aus, um fortzufahren.';

  @override
  String get chooseVitalsForDashboard =>
      'Wähle die Vitalwerte aus, die du in deiner Übersicht sehen möchtest.';

  @override
  String get selectAtLeastOneVital =>
      'Wähle mindestens einen Vitalwert aus, um fortzufahren.';

  @override
  String get chooseSpecialtiesForDashboard =>
      'Wähle die Fachgebiete aus, die du in deiner Übersicht sehen möchtest.';

  @override
  String get selectAtLeastOneSpecialty =>
      'Wähle mindestens ein Fachgebiet aus, um fortzufahren.';

  @override
  String get selectAtLeastOneItem =>
      'Wähle mindestens einen Eintrag aus, um fortzufahren.';

  @override
  String get sourceSectionWallet => 'WALLET';

  @override
  String get sourceSectionEhr => 'EPA-QUELLEN';

  @override
  String get areYouSure => 'Bist du sicher?';

  @override
  String get resourceNotViewable =>
      'Diese Ressource ist keine anzeigbare Datei';

  @override
  String get noFilePathFound => 'Kein Dateipfad gefunden';

  @override
  String get desktopDiscovering => 'Suche läuft...';

  @override
  String get desktopTransportWifi => 'WLAN';

  @override
  String get desktopTransportDirect => 'Direkt';

  @override
  String get desktopDeviceSync => 'Gerätesynchronisierung';

  @override
  String get desktopBackupLocation => 'Speicherort';

  @override
  String get desktopBackupHistory => 'Verlauf';

  @override
  String desktopPairedWith(String name) {
    return 'Gekoppelt mit $name';
  }

  @override
  String get desktopMobileDevice => 'Mobilgerät';

  @override
  String get desktopNotFoundScanAgain =>
      'Desktop nicht gefunden. Scanne den QR-Code erneut.';

  @override
  String get desktopPairingExpired =>
      'Verbindung fehlgeschlagen. Scanne den QR-Code, um erneut zu koppeln.';

  @override
  String desktopRemoteBackupName(String date) {
    return 'Vom Telefon $date';
  }

  @override
  String get desktopNoBackupLocation =>
      'Auf dem Desktop ist kein Backup-Speicherort festgelegt. Öffne die Desktop-App und wähle zuerst einen Backup-Ordner.';

  @override
  String get desktopBackupFailed =>
      'Backup fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get desktopBackupActionFailed =>
      'Die Backups konnten nicht aktualisiert werden. Bitte versuche es erneut.';

  @override
  String get desktopSyncFailed =>
      'Synchronisierung fehlgeschlagen. Prüfe die Verbindung und versuche es erneut.';

  @override
  String get desktopHandoverTransfer => 'Übertragung';

  @override
  String get desktopHandoverNoActive => 'Keine aktiven Übergaben';

  @override
  String get desktopHandoverSendFromPhone =>
      'Sende Dokumente von deinem Telefon.';

  @override
  String desktopHandoverFilesProgress(String received, String total) {
    return '$received/$total Dateien';
  }

  @override
  String get desktopHandoverTransferComplete => 'Übertragung abgeschlossen';

  @override
  String get desktopHandoverReceivingFiles => 'Dateien werden empfangen...';

  @override
  String get desktopHandoverStatusError => 'Fehler';

  @override
  String get desktopHandoverNotAccepted =>
      'Der Desktop hat nicht geantwortet. Stelle sicher, dass HealthWallet dort geöffnet und aktuell ist.';

  @override
  String get desktopHandoverFileMissing =>
      'Ein Dokument wurde auf diesem Gerät nicht gefunden.';

  @override
  String get desktopHandoverCancelled => 'Abgebrochen';

  @override
  String get desktopHandoverFailed =>
      'Verarbeitung fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get trayShowWindow => 'Fenster anzeigen';

  @override
  String get trayHideWindow => 'Fenster ausblenden';

  @override
  String get trayNoDeviceConnected => 'Kein Gerät verbunden';

  @override
  String traySyncStatus(String status) {
    return 'Synchronisierung: $status';
  }

  @override
  String get trayUpToDate => 'Aktuell';

  @override
  String trayQuit(String appName) {
    return '$appName beenden';
  }

  @override
  String get biometricAuthReason =>
      'Bitte authentifiziere dich, um auf dein HealthWallet.me zuzugreifen';

  @override
  String sourceUploadedOn(String date) {
    return 'Hochgeladen $date';
  }

  @override
  String get shareStatusReadyToShare => 'Bereit zum Teilen';

  @override
  String get shareStatusWaitingForSender => 'Warten auf den Absender...';

  @override
  String get shareStatusPermissionsRequired => 'Berechtigungen erforderlich';

  @override
  String get shareStatusEnablePermissionsInSettings =>
      'Bitte aktiviere die Berechtigungen in den Einstellungen';

  @override
  String get shareSelectAtLeastOneRecord =>
      'Bitte wähle mindestens eine Aufzeichnung aus';

  @override
  String get shareStatusLookingForDevices =>
      'Suche nach Geräten in der Nähe...';

  @override
  String get shareStatusTransferFailed => 'Übertragung fehlgeschlagen';

  @override
  String get shareStatusConfirmExit =>
      'Möchtest du wirklich beenden? Die Daten werden gelöscht.';

  @override
  String shareStatusViewingRecords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufzeichnungen werden angezeigt',
      one: '1 Aufzeichnung wird angezeigt',
    );
    return '$_temp0';
  }

  @override
  String shareStatusViewingRecordsFrom(int count, String deviceName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufzeichnungen von $deviceName werden angezeigt',
      one: '1 Aufzeichnung von $deviceName wird angezeigt',
    );
    return '$_temp0';
  }

  @override
  String get shareStatusDataDeleted => 'Die Daten wurden sicher gelöscht';

  @override
  String get shareStatusSessionExpired => 'Sitzung abgelaufen';

  @override
  String get shareStatusTerminatingSession =>
      'Sitzung auf dem anderen Gerät wird beendet...';

  @override
  String get shareStatusSessionTerminated => 'Sitzung beendet';

  @override
  String get shareStatusRemoteSessionTerminated =>
      'Das andere Gerät hat die Sitzung beendet';

  @override
  String get shareStatusExtensionDeclined =>
      'Die Verlängerungsanfrage wurde abgelehnt';

  @override
  String get shareStatusReceiverViewing =>
      'Der Empfänger sieht die Aufzeichnungen an - Sitzung wird überwacht';

  @override
  String get shareStatusReceiverDeclined =>
      'Der Empfänger hat die Einladung abgelehnt';

  @override
  String shareStatusReceivingFrom(String deviceName) {
    return 'Aufzeichnungen von $deviceName werden empfangen...';
  }

  @override
  String get shareNoDataAvailable => 'Keine Daten verfügbar';

  @override
  String shareStatusDeviceWantsToShare(String deviceName) {
    return '$deviceName möchte Aufzeichnungen teilen';
  }

  @override
  String get shareStatusScanning => 'Suche nach Geräten...';

  @override
  String shareStatusFoundDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Geräte gefunden',
      one: '1 Gerät gefunden',
    );
    return '$_temp0';
  }

  @override
  String shareStatusConnectingTo(String deviceName) {
    return 'Verbindung mit $deviceName wird hergestellt...';
  }

  @override
  String get shareStatusPreparingRecords =>
      'Aufzeichnungen werden vorbereitet...';

  @override
  String get shareErrorPrepareFiles =>
      'Die Dateien konnten nicht für den Versand vorbereitet werden';

  @override
  String shareStatusTransferring(int percent) {
    return 'Übertragung $percent %';
  }

  @override
  String get shareStatusRecordsSentWaiting =>
      'Aufzeichnungen gesendet - warten, bis der Empfänger annimmt';

  @override
  String get shareStatusTransferCancelled => 'Übertragung abgebrochen';

  @override
  String get shareStatusInvitationRejected => 'Einladung abgelehnt';

  @override
  String get shareErrorParseData =>
      'Die empfangenen Daten konnten nicht gelesen werden';

  @override
  String get shareStatusProcessingReceived =>
      'Empfangene Aufzeichnungen werden verarbeitet...';

  @override
  String get shareErrorParseFile =>
      'Die empfangene Datei konnte nicht gelesen werden';

  @override
  String get shareStatusCompareWithSender =>
      'Vergleiche den Code mit dem Absender';

  @override
  String get shareStatusCompareWithReceiver =>
      'Vergleiche den Code mit dem Empfänger';

  @override
  String get shareStatusRecordsSentAwaitingViewer =>
      'Aufzeichnungen gesendet - warten, bis der Empfänger sie öffnet';

  @override
  String get shareErrorOlderVersion =>
      'Diese Freigabe stammt von einer älteren HealthWallet-Version. Aktualisiere die App auf beiden Telefonen und versuche es erneut.';

  @override
  String get shareErrorSecureConnection =>
      'Es konnte keine sichere Verbindung mit dem anderen Telefon hergestellt werden. Versuche es erneut.';

  @override
  String get shareStatusSecureConnectionFailed =>
      'Sichere Verbindung fehlgeschlagen';

  @override
  String get shareIncomingHealthRecords => 'Eingehende Gesundheitsdaten';

  @override
  String shareDeviceWantsToShareHealthRecords(String deviceName) {
    return '$deviceName möchte Gesundheitsdaten mit dir teilen';
  }

  @override
  String get sharePermissionExplanationIos =>
      'Um Aufzeichnungen mit Geräten in der Nähe zu teilen, benötigt HealthWallet Zugriff auf:\n\n• Bluetooth - um Geräte in der Nähe zu finden und sich mit ihnen zu verbinden\n\nSo kannst du Gesundheitsdaten sicher mit anderen Geräten in der Nähe teilen.';

  @override
  String get sharePermissionExplanationAndroid =>
      'Um Aufzeichnungen mit Geräten in der Nähe zu teilen, benötigt HealthWallet Zugriff auf:\n\n• Bluetooth - um Geräte in der Nähe zu finden und sich mit ihnen zu verbinden\n• Standort/Geräte in der Nähe - von Android verlangt, um nach Bluetooth- und WiFi-Direct-Geräten zu suchen\n\nDein Standort wird nie gespeichert oder übertragen.';

  @override
  String get sharePermissionsDeniedMessage =>
      'Bitte erteile alle Berechtigungen, um Aufzeichnungen mit Geräten in der Nähe zu teilen.';

  @override
  String get sharePermissionsPermanentlyDeniedMessage =>
      'Einige Berechtigungen wurden verweigert. Bitte aktiviere sie in den Einstellungen, um diese Funktion zu nutzen.';

  @override
  String shareDurationRequested(String duration) {
    return '$duration angefragt';
  }

  @override
  String get noAttachments => 'Keine Anhänge';

  @override
  String get attachingFiles => 'Dateien werden angehängt...';

  @override
  String get addAttachment => 'Anhang hinzufügen';

  @override
  String get noFileName => 'Kein Dateiname';

  @override
  String attachmentFileOfTotal(int current, int total) {
    return '( $current von $total Dateien )';
  }

  @override
  String get showDetails => 'Details anzeigen';

  @override
  String get viewRelated => 'Zugehörige anzeigen';

  @override
  String get hideRelated => 'Zugehörige ausblenden';

  @override
  String get noRelatedResourcesFound => 'Keine zugehörigen Einträge gefunden';

  @override
  String get loadingRelatedResources => 'Zugehörige Einträge werden geladen...';

  @override
  String get noRelatedResourcesForEncounter =>
      'Keine zugehörigen Einträge zu diesem Termin gefunden';

  @override
  String get cannotAttachToDocumentReference =>
      'An ein Dokument können keine Dateien angehängt werden';

  @override
  String get attachFileFailed =>
      'Die Datei konnte nicht angehängt werden. Bitte versuche es erneut.';

  @override
  String get attachmentDeleteFailed =>
      'Der Anhang konnte nicht gelöscht werden. Bitte versuche es erneut.';

  @override
  String deleteRecordOfType(String type) {
    return '$type löschen';
  }

  @override
  String get dateFilterEndBeforeStart =>
      'Das Enddatum muss nach dem Startdatum liegen';

  @override
  String dateFilterChip(String range) {
    return 'Datum: $range';
  }

  @override
  String get aiModelCheckFailed =>
      'Beim Prüfen, ob das Modell vorhanden ist, ist ein Fehler aufgetreten';

  @override
  String get aiModelExistenceCheckFailed =>
      'Prüfung, ob das Modell vorhanden ist, fehlgeschlagen';

  @override
  String aiModelDownloadingTitle(String modelName) {
    return '$modelName wird heruntergeladen';
  }

  @override
  String get aiModelDownloadStarting => 'Download wird gestartet...';

  @override
  String aiModelReadyTitle(String modelName) {
    return '$modelName bereit';
  }

  @override
  String aiModelDownloadedMessage(String modelName) {
    return '$modelName wurde erfolgreich heruntergeladen.';
  }

  @override
  String get aiModelDownloadFailedTitle => 'Download fehlgeschlagen';

  @override
  String get aiModelDownloadFailedMessage =>
      'Der Download des KI-Modells ist fehlgeschlagen. Bitte prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String get aiModelDownloadFailed => 'Download fehlgeschlagen';

  @override
  String get aiModelDownloadWasCancelled =>
      'Der Download des KI-Modells wurde abgebrochen';

  @override
  String get aiModelDownloadCancelled => 'Download abgebrochen';

  @override
  String aiModelDownloadingPercent(String percent) {
    return 'Wird heruntergeladen... $percent %';
  }

  @override
  String get processingNoImagesGenerated =>
      'Beim Scannen wurden keine Bilder erzeugt. Bitte scannen Sie erneut.';

  @override
  String processingPatientMatched(String origin) {
    return '$origin: Patient zugeordnet';
  }

  @override
  String processingPatientInfoExtracted(String origin) {
    return '$origin: Patientendaten extrahiert';
  }

  @override
  String processingFinished(String origin) {
    return '$origin: Verarbeitung abgeschlossen';
  }

  @override
  String get scanFailed =>
      'Der Scan ist fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get noValidFilesFound => 'Keine gültigen Dateien gefunden';

  @override
  String get importDocumentFailed =>
      'Das Dokument konnte nicht importiert werden. Bitte versuche es erneut.';

  @override
  String get couldNotOpenLink =>
      'Der Link konnte nicht geöffnet werden. Bitte versuchen Sie es erneut.';

  @override
  String get importFilesFailed =>
      'Die ausgewählten Dateien konnten nicht geöffnet werden. Bitte versuche es erneut.';

  @override
  String get continueProcessingOnDesktop =>
      'Verarbeitung auf dem Desktop fortsetzen';

  @override
  String get handoverSendFailed =>
      'Das Dokument konnte nicht an den Desktop gesendet werden. Bitte versuche es erneut.';

  @override
  String get deleteResourcesTitle => 'Ressourcen löschen';

  @override
  String get switchToDiagnosticReport => 'Zu Befundbericht wechseln';

  @override
  String get switchToEncounter => 'Zu Termin wechseln';

  @override
  String get previewDocument => 'Dokumentvorschau';

  @override
  String get summaryTitle => 'Zusammenfassung';

  @override
  String pagesAvailableForProcessing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gesamt: $count Seiten zur Verarbeitung verfügbar',
      one: 'Gesamt: $count Seite zur Verarbeitung verfügbar',
    );
    return '$_temp0';
  }

  @override
  String get betaBadge => 'Beta';

  @override
  String get pleaseSelectSpecialty => 'Bitte wählen Sie ein Fachgebiet aus';

  @override
  String get patientAndSourceInformation =>
      'Patienten- und Quelleninformationen';

  @override
  String get noPatientsAvailable => 'Keine Patienten verfügbar';

  @override
  String get selectPatient => 'Patient auswählen';

  @override
  String get unknownPatient => 'Unbekannter Patient';

  @override
  String get documentPreview => 'Dokumentvorschau';

  @override
  String filePathLabel(String path) {
    return 'Pfad: $path';
  }

  @override
  String get confidenceMedium => 'Mittlere Zuverlässigkeit';

  @override
  String get confidenceLow => 'Geringe Zuverlässigkeit';

  @override
  String get dateFormatHintIso => 'JJJJ-MM-TT';

  @override
  String retryStep(int step) {
    return 'Erneut versuchen (Schritt $step)';
  }

  @override
  String failedToCreateEncounter(String error) {
    return 'Termin konnte nicht erstellt werden: $error';
  }

  @override
  String failedToAttachDocuments(String error) {
    return 'Dokumente konnten nicht angehängt werden: $error';
  }

  @override
  String get fieldAccessionNumber => 'Eingangsnummer';

  @override
  String get fieldAchievementStatus => 'Erreichungsstatus';

  @override
  String get fieldActuality => 'Tatsächlichkeit';

  @override
  String get fieldAdditionalInformation => 'Zusätzliche Informationen';

  @override
  String get fieldAddress => 'Adresse';

  @override
  String get fieldAddresses => 'Adressen';

  @override
  String get fieldAdministeredBy => 'Verabreicht von';

  @override
  String get fieldAdmissionSource => 'Aufnahmequelle';

  @override
  String get fieldAlert => 'Warnung';

  @override
  String get fieldAllergyDetails => 'Allergiedetails';

  @override
  String get fieldAlsoKnownAs => 'Auch bekannt als';

  @override
  String get fieldAsserter => 'Feststellende Person';

  @override
  String get fieldAttachmentTitle => 'Titel des Anhangs';

  @override
  String get fieldAuthenticatedBy => 'Beglaubigt von';

  @override
  String get fieldAuthor => 'Autor';

  @override
  String get fieldAvailabilityExceptions => 'Ausnahmen der Verfügbarkeit';

  @override
  String get fieldAvailabilityNotes => 'Hinweise zur Verfügbarkeit';

  @override
  String get fieldBasedOn => 'Basierend auf';

  @override
  String get fieldBasicInformation => 'Grundlegende Informationen';

  @override
  String get fieldBeneficiary => 'Begünstigter';

  @override
  String get fieldBillablePeriod => 'Abrechnungszeitraum';

  @override
  String get fieldBirthDate => 'Geburtsdatum';

  @override
  String get fieldBirthPlace => 'Geburtsort';

  @override
  String get fieldBirthSex => 'Geburtsgeschlecht';

  @override
  String get fieldBodySite => 'Körperstelle';

  @override
  String get fieldCareTeam => 'Behandlungsteam';

  @override
  String get fieldCategory => 'Kategorie';

  @override
  String get fieldClinicalNotes => 'Klinische Notizen';

  @override
  String get fieldClinicalStatus => 'Klinischer Status';

  @override
  String get fieldCollectedBy => 'Entnommen von';

  @override
  String get fieldCollectionDate => 'Entnahmedatum';

  @override
  String get fieldCollectionDuration => 'Entnahmedauer';

  @override
  String get fieldCollectionInformation => 'Angaben zur Entnahme';

  @override
  String get fieldCollectionMethod => 'Entnahmemethode';

  @override
  String get fieldCollectionPeriod => 'Entnahmezeitraum';

  @override
  String get fieldComplicationDetails => 'Details zu Komplikationen';

  @override
  String get fieldComplications => 'Komplikationen';

  @override
  String get fieldConclusion => 'Schlussfolgerung';

  @override
  String get fieldConclusionCode => 'Befundcode';

  @override
  String get fieldCondition => 'Erkrankung';

  @override
  String get fieldContactEmail => 'Kontakt-E-Mail';

  @override
  String get fieldContactInformation => 'Kontaktinformationen';

  @override
  String get fieldContactPerson => 'Ansprechperson';

  @override
  String get fieldContactPhone => 'Kontakttelefon';

  @override
  String get fieldContainerAdditive => 'Zusatz im Behälter';

  @override
  String get fieldContainerCapacity => 'Fassungsvermögen des Behälters';

  @override
  String get fieldContainerType => 'Behältertyp';

  @override
  String get fieldContainers => 'Behälter';

  @override
  String get fieldContentType => 'Inhaltstyp';

  @override
  String get fieldContext => 'Kontext';

  @override
  String get fieldContract => 'Vertrag';

  @override
  String get fieldCostSharing => 'Kostenbeteiligung';

  @override
  String get fieldCourseOfTherapy => 'Therapieverlauf';

  @override
  String get fieldCoverage => 'Versicherungsschutz';

  @override
  String get fieldCoverageClass => 'Versicherungsklasse';

  @override
  String get fieldCoverageDetails => 'Details zum Versicherungsschutz';

  @override
  String get fieldCreated => 'Erstellt';

  @override
  String get fieldCriticality => 'Kritikalität';

  @override
  String get fieldCustodian => 'Verwahrer';

  @override
  String get fieldDataAbsentReason => 'Grund für fehlende Daten';

  @override
  String get fieldDateGiven => 'Verabreichungsdatum';

  @override
  String get fieldDatePerformed => 'Durchführungsdatum';

  @override
  String get fieldDaysSupply => 'Reichdauer in Tagen';

  @override
  String get fieldDependent => 'Mitversicherte Person';

  @override
  String get fieldDerivedFrom => 'Abgeleitet von';

  @override
  String get fieldDescription => 'Beschreibung';

  @override
  String get fieldDetected => 'Festgestellt';

  @override
  String get fieldDevice => 'Gerät';

  @override
  String get fieldDiagnoses => 'Diagnosen';

  @override
  String get fieldDietPreference => 'Ernährungspräferenz';

  @override
  String get fieldDimensions => 'Abmessungen';

  @override
  String get fieldDischargeDisposition => 'Entlassungsart';

  @override
  String get fieldDischargeTo => 'Entlassen nach';

  @override
  String get fieldDisposition => 'Verbleib';

  @override
  String get fieldDocumentDetails => 'Dokumentdetails';

  @override
  String get fieldDocumentId => 'Dokument-ID';

  @override
  String get fieldDocumentStatus => 'Dokumentstatus';

  @override
  String get fieldDosage => 'Dosierung';

  @override
  String get fieldDose => 'Dosis';

  @override
  String get fieldDoseQuantity => 'Dosismenge';

  @override
  String get fieldDriversLicenseNumber => 'Führerscheinnummer';

  @override
  String get fieldDuration => 'Dauer';

  @override
  String get fieldEducationProvided => 'Erteilte Aufklärung';

  @override
  String get fieldEffective => 'Zeitpunkt';

  @override
  String get fieldEffectiveDates => 'Gültigkeitszeitraum';

  @override
  String get fieldEmail => 'E-Mail';

  @override
  String get fieldEmergency => 'Notfall';

  @override
  String get fieldEncounterType => 'Art des Kontakts';

  @override
  String get fieldEndpoints => 'Endpunkte';

  @override
  String get fieldEpisodeOfCare => 'Behandlungsepisode';

  @override
  String get fieldEthnicity => 'Ethnische Zugehörigkeit';

  @override
  String get fieldExpiration => 'Ablauf';

  @override
  String get fieldExpirationDate => 'Verfallsdatum';

  @override
  String get fieldFacility => 'Einrichtung';

  @override
  String get fieldFacilityDetails => 'Details zur Einrichtung';

  @override
  String get fieldFacilityType => 'Art der Einrichtung';

  @override
  String get fieldFastingStatus => 'Nüchternstatus';

  @override
  String get fieldFax => 'Fax';

  @override
  String get fieldFocalDevice => 'Hauptgerät';

  @override
  String get fieldFollowUp => 'Nachsorge';

  @override
  String get fieldForm => 'Darreichungsform';

  @override
  String get fieldFormat => 'Format';

  @override
  String get fieldFundingSource => 'Kostenträger';

  @override
  String get fieldGender => 'Geschlecht';

  @override
  String get fieldGeneralPractitioner => 'Hausarzt';

  @override
  String get fieldGoal => 'Ziel';

  @override
  String get fieldGoalDetails => 'Details zum Ziel';

  @override
  String get fieldGpsCoordinates => 'GPS-Koordinaten';

  @override
  String get fieldGroupNumber => 'Gruppennummer';

  @override
  String get fieldHandedOver => 'Ausgehändigt';

  @override
  String get fieldHealthcareFacility => 'Gesundheitseinrichtung';

  @override
  String get fieldHealthcareService => 'Gesundheitsdienst';

  @override
  String get fieldHours => 'Öffnungszeiten';

  @override
  String get fieldHowToTake => 'Einnahme';

  @override
  String get fieldIdentifiers => 'Kennungen';

  @override
  String get fieldInformationSource => 'Informationsquelle';

  @override
  String get fieldIngredients => 'Bestandteile';

  @override
  String get fieldInstructions => 'Anweisungen';

  @override
  String get fieldInsuranceCompany => 'Versicherungsgesellschaft';

  @override
  String get fieldInsurer => 'Versicherer';

  @override
  String get fieldIntent => 'Absicht';

  @override
  String get fieldInterpreter => 'Dolmetscher';

  @override
  String get fieldItemsUsed => 'Verwendete Materialien';

  @override
  String get fieldLanguage => 'Sprache';

  @override
  String get fieldLanguages => 'Sprachen';

  @override
  String get fieldLastOccurrence => 'Letztes Auftreten';

  @override
  String get fieldLifecycleStatus => 'Lebenszyklusstatus';

  @override
  String get fieldLocation => 'Ort';

  @override
  String get fieldLocationProvider => 'Ort und Behandelnde';

  @override
  String get fieldLotNumber => 'Chargennummer';

  @override
  String get fieldManagingOrganization => 'Verwaltende Organisation';

  @override
  String get fieldManufacturer => 'Hersteller';

  @override
  String get fieldMaritalStatus => 'Familienstand';

  @override
  String get fieldMedia => 'Medien';

  @override
  String get fieldMedicalRecordNumber => 'Patientennummer';

  @override
  String get fieldMedication => 'Medikament';

  @override
  String get fieldMedicationDetails => 'Medikamentendetails';

  @override
  String get fieldMemberId => 'Versichertennummer';

  @override
  String get fieldMembers => 'Mitglieder';

  @override
  String get fieldMethod => 'Methode';

  @override
  String get fieldModality => 'Modalität';

  @override
  String get fieldMode => 'Modus';

  @override
  String get fieldMothersMaidenName => 'Geburtsname der Mutter';

  @override
  String get fieldMultipleBirth => 'Mehrlingsgeburt';

  @override
  String get fieldNetwork => 'Netzwerk';

  @override
  String get fieldNextDose => 'Nächste Dosis';

  @override
  String get fieldNotes => 'Notizen';

  @override
  String get fieldOccurrence => 'Zeitpunkt';

  @override
  String get fieldOnset => 'Beginn';

  @override
  String get fieldOperationalStatus => 'Betriebsstatus';

  @override
  String get fieldOperator => 'Bediener';

  @override
  String get fieldOrder => 'Rang';

  @override
  String get fieldOrderedBy => 'Angeordnet von';

  @override
  String get fieldOrganization => 'Organisation';

  @override
  String get fieldOrganizationDetails => 'Details zur Organisation';

  @override
  String get fieldOutcome => 'Ergebnis';

  @override
  String get fieldOutcomeMeasurements => 'Ergebnismessungen';

  @override
  String get fieldPanelComponents => 'Bestandteile des Panels';

  @override
  String get fieldParentSpecimen => 'Ausgangsprobe';

  @override
  String get fieldPartOf => 'Teil von';

  @override
  String get fieldPassportNumber => 'Reisepassnummer';

  @override
  String get fieldPatient => 'Patient';

  @override
  String get fieldPerformedBy => 'Durchgeführt von';

  @override
  String get fieldPerformer => 'Durchführende Person';

  @override
  String get fieldPerformerType => 'Art der durchführenden Person';

  @override
  String get fieldPeriod => 'Zeitraum';

  @override
  String get fieldPhone => 'Telefon';

  @override
  String get fieldPhysicalType => 'Physischer Typ';

  @override
  String get fieldPlanName => 'Tarifname';

  @override
  String get fieldPlanType => 'Tarifart';

  @override
  String get fieldPolicyHolder => 'Versicherungsnehmer';

  @override
  String get fieldPracticeSetting => 'Versorgungsbereich';

  @override
  String get fieldPractitioner => 'Behandelnde Person';

  @override
  String get fieldPrepared => 'Zubereitet';

  @override
  String get fieldPrescribed => 'Verordnet';

  @override
  String get fieldPrescribedBy => 'Verordnet von';

  @override
  String get fieldPrimarySource => 'Primärquelle';

  @override
  String get fieldPriority => 'Priorität';

  @override
  String get fieldProcedureCode => 'Prozedurcode';

  @override
  String get fieldProcedureDetails => 'Details zur Prozedur';

  @override
  String get fieldProcessingStorage => 'Verarbeitung und Lagerung';

  @override
  String get fieldProfessionalInformation => 'Berufliche Informationen';

  @override
  String get fieldProgramEligibility => 'Programmberechtigung';

  @override
  String get fieldProgressNotes => 'Verlaufsnotizen';

  @override
  String get fieldProvider => 'Leistungserbringer';

  @override
  String get fieldQualification => 'Qualifikation';

  @override
  String get fieldQuantity => 'Menge';

  @override
  String get fieldQuantityCollected => 'Entnommene Menge';

  @override
  String get fieldRace => 'Abstammung';

  @override
  String get fieldRangeAppliesTo => 'Bereich gilt für';

  @override
  String get fieldRangeNotes => 'Hinweise zum Bereich';

  @override
  String get fieldReAdmission => 'Wiederaufnahme';

  @override
  String get fieldReaction => 'Reaktion';

  @override
  String get fieldReactions => 'Reaktionen';

  @override
  String get fieldReason => 'Grund';

  @override
  String get fieldReasonForVisit => 'Anlass des Besuchs';

  @override
  String get fieldReceivedAtLab => 'Im Labor eingegangen';

  @override
  String get fieldRecorded => 'Erfasst';

  @override
  String get fieldRecorder => 'Erfasst von';

  @override
  String get fieldReferenceRange => 'Referenzbereich';

  @override
  String get fieldRefills => 'Folgeverordnungen';

  @override
  String get fieldRelatedAppointment => 'Zugehöriger Termin';

  @override
  String get fieldRelatedCondition => 'Zugehörige Erkrankung';

  @override
  String get fieldRelatedDocument => 'Zugehöriges Dokument';

  @override
  String get fieldRelationship => 'Beziehung';

  @override
  String get fieldRelationshipToSubscriber =>
      'Beziehung zum Versicherungsnehmer';

  @override
  String get fieldReport => 'Bericht';

  @override
  String get fieldReportedBy => 'Gemeldet von';

  @override
  String get fieldRequestedBy => 'Angefordert von';

  @override
  String get fieldRequester => 'Anfordernde Person';

  @override
  String get fieldResolved => 'Abgeklungen';

  @override
  String get fieldResult => 'Ergebnis';

  @override
  String get fieldResultDate => 'Ergebnisdatum';

  @override
  String get fieldResults => 'Ergebnisse';

  @override
  String get fieldRole => 'Rolle';

  @override
  String get fieldRoute => 'Verabreichungsweg';

  @override
  String get fieldSecurityClassification => 'Vertraulichkeitsstufe';

  @override
  String get fieldSeries => 'Serie';

  @override
  String get fieldSeriousness => 'Schweregrad';

  @override
  String get fieldServicePeriod => 'Leistungszeitraum';

  @override
  String get fieldServiceType => 'Leistungsart';

  @override
  String get fieldSetBy => 'Festgelegt von';

  @override
  String get fieldSeverity => 'Schweregrad';

  @override
  String get fieldSite => 'Stelle';

  @override
  String get fieldSize => 'Größe';

  @override
  String get fieldSpecialArrangements => 'Besondere Vorkehrungen';

  @override
  String get fieldSpecialty => 'Fachrichtung';

  @override
  String get fieldSpecimenDetails => 'Details zur Probe';

  @override
  String get fieldSpecimenQuantity => 'Probenmenge';

  @override
  String get fieldSpecimenType => 'Probenart';

  @override
  String get fieldSpecimens => 'Proben';

  @override
  String get fieldStage => 'Stadium';

  @override
  String get fieldStartDate => 'Startdatum';

  @override
  String get fieldStatus => 'Status';

  @override
  String get fieldStatusDate => 'Statusdatum';

  @override
  String get fieldStatusHistory => 'Statusverlauf';

  @override
  String get fieldStatusReason => 'Grund für den Status';

  @override
  String get fhirStatusActive => 'Aktiv';

  @override
  String get fhirStatusInactive => 'Inaktiv';

  @override
  String get fhirStatusResolved => 'Abgeklungen';

  @override
  String get fhirStatusRecurrence => 'Wiederauftreten';

  @override
  String get fhirStatusRelapse => 'Rückfall';

  @override
  String get fhirStatusRemission => 'Remission';

  @override
  String get fhirStatusUnconfirmed => 'Unbestätigt';

  @override
  String get fhirStatusProvisional => 'Vorläufig';

  @override
  String get fhirStatusDifferential => 'Differenzialdiagnose';

  @override
  String get fhirStatusConfirmed => 'Bestätigt';

  @override
  String get fhirStatusRefuted => 'Widerlegt';

  @override
  String get fhirStatusEnteredInError => 'Irrtümlich erfasst';

  @override
  String get fhirStatusOnHold => 'Pausiert';

  @override
  String get fhirStatusCancelled => 'Abgebrochen';

  @override
  String get fhirStatusCompleted => 'Abgeschlossen';

  @override
  String get fhirStatusStopped => 'Abgesetzt';

  @override
  String get fhirStatusDraft => 'Entwurf';

  @override
  String get fhirStatusUnknown => 'Unbekannt';

  @override
  String get fhirStatusIntended => 'Geplant';

  @override
  String get fhirStatusNotTaken => 'Nicht eingenommen';

  @override
  String get fhirStatusInProgress => 'Laufend';

  @override
  String get fhirStatusNotDone => 'Nicht durchgeführt';

  @override
  String get fhirStatusPreparation => 'In Vorbereitung';

  @override
  String get fhirStatusDeclined => 'Abgelehnt';

  @override
  String get fhirStatusRegistered => 'Registriert';

  @override
  String get fhirStatusPreliminary => 'Vorläufig';

  @override
  String get fhirStatusFinal => 'Endgültig';

  @override
  String get fhirStatusAmended => 'Geändert';

  @override
  String get fhirStatusCorrected => 'Korrigiert';

  @override
  String get fieldInterpretation => 'Bewertung';

  @override
  String get interpretationHigh => 'Erhöht';

  @override
  String get interpretationLow => 'Erniedrigt';

  @override
  String get interpretationNormal => 'Normal';

  @override
  String get interpretationAbnormal => 'Abnormal';

  @override
  String get interpretationCriticallyAbnormal => 'Kritisch abnormal';

  @override
  String get interpretationCriticallyHigh => 'Kritisch erhöht';

  @override
  String get interpretationCriticallyLow => 'Kritisch erniedrigt';

  @override
  String get interpretationSignificantlyHigh => 'Deutlich erhöht';

  @override
  String get interpretationSignificantlyLow => 'Deutlich erniedrigt';

  @override
  String get interpretationIntermediate => 'Intermediär';

  @override
  String get interpretationResistant => 'Resistent';

  @override
  String get interpretationSusceptible => 'Sensibel';

  @override
  String get interpretationPositive => 'Positiv';

  @override
  String get interpretationNegative => 'Negativ';

  @override
  String get interpretationDetected => 'Nachgewiesen';

  @override
  String get interpretationNotDetected => 'Nicht nachgewiesen';

  @override
  String get interpretationIndeterminate => 'Unbestimmt';

  @override
  String get interpretationEquivocal => 'Grenzwertig';

  @override
  String get fieldStrength => 'Wirkstärke';

  @override
  String get fieldSubpotent => 'Verminderte Wirksamkeit';

  @override
  String get fieldSubrogation => 'Forderungsübergang';

  @override
  String get fieldSubscriber => 'Versicherungsnehmer';

  @override
  String get fieldSubstitution => 'Austausch';

  @override
  String get fieldSupplies => 'Hilfsmittel';

  @override
  String get fieldTarget => 'Zielwert';

  @override
  String get fieldTestDate => 'Testdatum';

  @override
  String get fieldTimePeriod => 'Zeitraum';

  @override
  String get fieldTotal => 'Gesamt';

  @override
  String get fieldType => 'Typ';

  @override
  String get fieldUse => 'Verwendung';

  @override
  String get fieldVaccinationDetails => 'Details zur Impfung';

  @override
  String get fieldVaccine => 'Impfstoff';

  @override
  String get fieldValue => 'Wert';

  @override
  String get fieldVerification => 'Verifizierung';

  @override
  String get fieldVerifiedBy => 'Überprüft von';

  @override
  String get fieldView => 'Ansicht';

  @override
  String get fieldVisitDetails => 'Details zum Besuch';

  @override
  String get fieldVisitType => 'Art des Besuchs';

  @override
  String get fieldWebsite => 'Website';

  @override
  String get fieldDateOfBirth => 'Geburtsdatum';

  @override
  String get fieldAge => 'Alter';

  @override
  String get fieldLastUpdated => 'Zuletzt aktualisiert';

  @override
  String get fieldAdditive => 'Zusatz';

  @override
  String get fieldTime => 'Uhrzeit';

  @override
  String fieldProcessingNumber(int number) {
    return 'Verarbeitung $number';
  }

  @override
  String get inactive => 'Inaktiv';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nein';

  @override
  String moreCount(int count) {
    return '$count weitere';
  }

  @override
  String qualificationIssuedBy(String qualification, String issuer) {
    return '$qualification (ausgestellt von $issuer)';
  }

  @override
  String qualificationValidPeriod(String qualification, String period) {
    return '$qualification - Gültig: $period';
  }

  @override
  String doseNumberOfTotal(String dose, String total) {
    return 'Dosis $dose von $total';
  }

  @override
  String doseNumber(String dose) {
    return 'Dosis $dose';
  }

  @override
  String get immunizationPrimarySourceYes => 'Ja (direkt verabreicht)';

  @override
  String get immunizationPrimarySourceNo =>
      'Nein (vom Patienten oder einer anderen Quelle gemeldet)';

  @override
  String get immunizationReactionReported => 'Reaktion gemeldet';

  @override
  String get immunizationNoReactions => 'Keine Nebenwirkungen gemeldet';

  @override
  String get immunizationSeriesComplete =>
      'Nicht geplant (Serie abgeschlossen)';

  @override
  String get immunizationSubpotent =>
      'Der Impfstoff hat eine verminderte Wirksamkeit';

  @override
  String documentPublished(String document, String date) {
    return '$document (veröffentlicht am $date)';
  }

  @override
  String refillsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Folgeverordnungen übrig',
      one: '$count Folgeverordnung übrig',
    );
    return '$_temp0';
  }

  @override
  String validUntil(String date) {
    return 'Gültig bis $date';
  }

  @override
  String validFrom(String date) {
    return 'Gültig ab $date';
  }

  @override
  String get substitutionAllowed => 'Austausch gegen Generikum erlaubt';

  @override
  String get substitutionNotAllowed =>
      'Markenpräparat erforderlich - kein Austausch';

  @override
  String get doNotPerformRequest => 'Diese Anforderung NICHT durchführen';

  @override
  String get complicationsNone => 'Keine';

  @override
  String fastedFor(String duration) {
    return 'Nüchtern seit $duration';
  }

  @override
  String containerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Behälter',
    );
    return '$_temp0';
  }

  @override
  String get coverageOrderPrimary => 'Primär (1)';

  @override
  String get coverageOrderSecondary => 'Sekundär (2)';

  @override
  String get coverageOrderTertiary => 'Tertiär (3)';

  @override
  String coverageOrderNumber(int order) {
    return 'Rang $order';
  }

  @override
  String goalDueBy(String date) {
    return 'bis $date';
  }

  @override
  String durationSeconds(String seconds) {
    return '$seconds Sekunden';
  }

  @override
  String ingredientCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Bestandteile',
      one: '$count Bestandteil',
    );
    return '$_temp0';
  }

  @override
  String resultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ergebnisse',
      one: '$count Ergebnis',
    );
    return '$_temp0';
  }

  @override
  String specimenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Proben',
      one: '$count Probe',
    );
    return '$_temp0';
  }

  @override
  String imageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Bilder',
      one: '$count Bild',
    );
    return '$_temp0';
  }

  @override
  String ageYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Jahre',
      one: '$count Jahr',
    );
    return '$_temp0';
  }

  @override
  String get identifierPassport => 'Reisepass';

  @override
  String multipleBirthOrder(String order) {
    return 'Ja (Geburtsreihenfolge: $order)';
  }

  @override
  String timeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Tagen',
      one: 'vor $count Tag',
    );
    return '$_temp0';
  }

  @override
  String timeAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Stunden',
      one: 'vor $count Stunde',
    );
    return '$_temp0';
  }

  @override
  String timeAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Minuten',
      one: 'vor $count Minute',
    );
    return '$_temp0';
  }

  @override
  String get justNow => 'Gerade eben';

  @override
  String get bloodTypeNotAvailable => 'Nicht verfügbar';

  @override
  String get settingsStorage => 'Speicher';

  @override
  String get settingsStorageDescription =>
      'Alle Einträge, Einstellungen und zwischengespeicherten Daten löschen';

  @override
  String get settingsReset => 'Zurücksetzen';

  @override
  String get resetDataWarning =>
      'Dadurch werden alle deine Daten dauerhaft gelöscht, einschließlich synchronisierter Einträge, Notizen, Anhänge und Einstellungen.';

  @override
  String resetTypeToConfirm(String word) {
    return 'Gib $word ein, um zu bestätigen:';
  }

  @override
  String get deleting => 'Wird gelöscht...';

  @override
  String get aiModelDownloadContinuesInBackground =>
      'Der Download läuft im Hintergrund weiter';

  @override
  String get aiModelAdvanced => 'Erweitert';

  @override
  String get aiModelMedical => 'Medizinisch';

  @override
  String aiModelDescriptionLite(double sizeGb) {
    final intl.NumberFormat sizeGbNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String sizeGbString = sizeGbNumberFormat.format(sizeGb);

    return 'Schnell und kompakt (~$sizeGbString GB)';
  }

  @override
  String aiModelDescriptionAdvanced(double sizeGb) {
    final intl.NumberFormat sizeGbNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String sizeGbString = sizeGbNumberFormat.format(sizeGb);

    return 'Höhere Genauigkeit (~$sizeGbString GB)';
  }

  @override
  String aiModelDescriptionUltra(double sizeGb) {
    final intl.NumberFormat sizeGbNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String sizeGbString = sizeGbNumberFormat.format(sizeGb);

    return 'Beste Genauigkeit für den Desktop (~$sizeGbString GB)';
  }

  @override
  String aiModelDescriptionPreviousAdvanced(double sizeGb) {
    final intl.NumberFormat sizeGbNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String sizeGbString = sizeGbNumberFormat.format(sizeGb);

    return 'Bisheriges Erweitert-Modell (~$sizeGbString GB)';
  }

  @override
  String get settingsEhrSync => 'EPA-Synchronisierung';

  @override
  String get shareProximityTitle => 'Teilen in der Nähe';

  @override
  String get shareProximityDescription =>
      'Für Geräte in der Nähe sichtbar sein';

  @override
  String get allow => 'Erlauben';

  @override
  String get settingsSendFeedback => 'Sende uns dein Feedback';

  @override
  String get toggleOn => 'EIN';

  @override
  String get toggleOff => 'AUS';

  @override
  String get idScanVerifyDetails =>
      'Prüfe, ob die Angaben korrekt sind. Scanne bei Bedarf erneut.';

  @override
  String get idScanPartial =>
      'Einige Felder konnten nicht gelesen werden. Versuche es mit einem schärferen Foto.';

  @override
  String get idScanFailed =>
      'Das Dokument konnte nicht gelesen werden. Nimm es bei besserer Beleuchtung erneut auf.';

  @override
  String get genderOther => 'Divers';

  @override
  String get genderUnknown => 'Unbekannt';

  @override
  String walletPassAge(int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age Jahre',
      one: '$age Jahr',
    );
    return '$_temp0';
  }

  @override
  String privacyEffectiveDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Gültig ab: $dateString';
  }

  @override
  String get privacyCorePrincipleBody =>
      'Das Wichtigste vorab: Wir, die Entwickler von **HealthWallet.me**, erheben und speichern keine deiner persönlichen oder gesundheitlichen Daten und haben keinen Zugriff darauf. Unsere App läuft vollständig auf deinem Gerät.';

  @override
  String get privacyNoCloudProcessing =>
      '✅ Keine Cloud-Verarbeitung: Alle Berechnungen, die Organisation der Daten und alle anderen Funktionen laufen lokal auf deinem Smartphone oder Tablet.';

  @override
  String get privacyNoDeveloperAccess =>
      '✅ Kein Zugriff durch die Entwickler: Wir können deine Daten weder sehen noch darauf zugreifen oder sie exportieren. Sie werden nie an unsere Server gesendet.';

  @override
  String get privacyYouAreInControl =>
      '✅ Du hast die Kontrolle: Deine Informationen werden sicher im privaten Speicher der App auf deinem Gerät abgelegt, auf den nur du zugreifen kannst.';

  @override
  String get privacyDoNotCollectIntro =>
      'Um es ganz klar zu sagen: Unsere App ist bewusst so gebaut, dass sie nicht auf deine persönlichen Daten zugreift. Wir erheben, speichern, verknüpfen oder verarbeiten **keine** Informationen, die dir zugeordnet werden können.';

  @override
  String get privacyPersonalIdentifiers =>
      'Persönliche Kennungen: Wir greifen nicht auf deinen Namen, deine E-Mail-Adresse, deine Telefonnummer, deine Kontakte oder andere persönliche Kontoinformationen auf deinem Gerät zu und speichern sie nicht.';

  @override
  String get privacyHealthInformation =>
      'Gesundheitsinformationen: Alle Gesundheitsakten, Erkrankungen, Medikamente oder anderen Daten, die du importierst, gehören allein dir. Wir können nicht darauf zugreifen.';

  @override
  String get privacyNoCrossReferencing =>
      'Kein Datenabgleich: Die App arbeitet isoliert. Sie durchsucht, indexiert oder verknüpft deine Gesundheitsdaten **nicht** mit anderen persönlichen Informationen auf deinem Smartphone (etwa deiner Kontaktliste, deinem Namen oder deiner Telefonnummer). Ihre einzige Aufgabe ist es, die Einträge zu organisieren, die du ihr gibst.';

  @override
  String get privacyUsageAnalytics =>
      'Nutzungsanalyse: Wir verfolgen nicht, wie du die App nutzt, welche Schaltflächen du antippst oder wie lange du auf bestimmten Bildschirmen verbringst.';

  @override
  String get privacyYouManageIntro =>
      'Die einzigen Daten, die die App verarbeitet, sind die Gesundheitsinformationen, die **du selbst importierst**. Das geht auf folgende Weise:';

  @override
  String get privacyImportingIntro =>
      'Du kannst Gesundheitsdokumente (etwa PDFs mit Laborergebnissen oder Arztberichten) mit den Standardfunktionen deines mobilen Betriebssystems direkt in die App aufnehmen:';

  @override
  String get privacyScanning =>
      'Scannen: Mit der Kamera deines Geräts scannst du ein Papierdokument direkt in der App.';

  @override
  String get privacyShareActionSheet =>
      'Teilen-Menü: Du wählst eine Datei in einer anderen App (etwa in deinen E-Mails, Fotos oder im Dateimanager) aus und „teilst“ sie direkt mit **HealthWallet.me**.';

  @override
  String get privacyLocalProcessing =>
      'Sobald ein Dokument importiert ist, verarbeitet die App es lokal auf deinem Gerät im Hintergrund. Sie strukturiert die Informationen nach dem Standard **HL7 FHIR (Fast Healthcare Interoperability Resources)**, damit sie nützlich und übersichtlich sind. Der gesamte Vorgang findet auf deinem Gerät statt; das Dokument und die strukturierten Daten verlassen es nie.';

  @override
  String get privacyFastenIntro =>
      'Mit unserer App kannst du deine Gesundheitsakten zusammenführen, indem du dich mit **FastenHealth OnPrem** verbindest, einer transparenten Open-Source-Plattform.';

  @override
  String get privacyFastenOpenSource =>
      'Open Source und lokal betrieben: FastenHealth OnPrem ist Open-Source-Software, die du oder eine vertrauenswürdige Stelle kontrolliert. Das bietet ein außergewöhnliches Maß an Privatsphäre.';

  @override
  String get privacyFastenDirectDownload =>
      'Direkter Download aufs Gerät: Wenn du die Verbindung autorisierst, werden deine Gesundheitsakten **direkt von deiner FastenHealth-OnPrem-Instanz auf dein Gerät** heruntergeladen. Unsere App ist nur ein Übertragungsweg; deine Daten laufen nie über unsere Server.';

  @override
  String get privacyUsageIntro =>
      'Da alle deine Daten auf deinem Gerät liegen, „nutzt“ die App sie nur, um dir beim Organisieren und Anzeigen deiner Einträge zu helfen. Dazu gehört:';

  @override
  String get privacyUsageProcessing =>
      'Verarbeiten und Strukturieren importierter oder gescannter Dokumente.';

  @override
  String get privacyUsageDisplaying =>
      'Anzeigen deiner Gesundheitsakten, Laborergebnisse und Medikationshistorie.';

  @override
  String get privacyNoOtherUse =>
      'Wir verwenden deine Informationen nicht für Werbung, Forschung oder andere Zwecke.';

  @override
  String get privacyStorage =>
      'Speicherung: Alle deine Daten liegen im sicheren, abgeschotteten Speicher der App auf deinem Gerät. Sie sind so sicher wie dein Gerät selbst. Wir empfehlen dringend, dein Gerät mit einem Code, Face ID oder einer anderen biometrischen Sperre zu schützen.';

  @override
  String get privacySharing =>
      'Weitergabe: Wir geben deine Daten nicht weiter und können es auch nicht, weil wir sie nicht haben. Wenn du deine Daten aus der App exportierst oder teilst, bestimmst allein du, wohin sie gehen.';

  @override
  String get privacyDeletion =>
      'Löschung: Du kannst deine Informationen jederzeit in der App löschen. Wenn du die App von deinem Gerät löschst, werden auch alle von ihr gespeicherten Daten dauerhaft gelöscht.';

  @override
  String get privacyChildrenBody =>
      'Unser Dienst richtet sich nicht an Personen unter 16 Jahren, gemäß der Datenschutz-Grundverordnung (DSGVO), wie sie in Rumänien und in der gesamten EU gilt. Wir erheben wissentlich keine personenbezogenen Daten von Kindern. Wenn du erfährst, dass ein Kind uns personenbezogene Daten übermittelt hat, kontaktiere uns bitte.';

  @override
  String get privacyChangesBody =>
      'Wir können diese Richtlinie von Zeit zu Zeit aktualisieren. Wenn wir wesentliche Änderungen vornehmen, informieren wir dich über die App oder auf anderem Weg, damit du die Änderungen prüfen kannst, bevor sie wirksam werden.';

  @override
  String get privacyContactBody =>
      'Wenn du Fragen oder Bedenken zu dieser Datenschutzerklärung hast, kontaktiere uns unter:';

  @override
  String get syncQrScanInstructions =>
      'Scanne einen QR-Code aus deiner **HealthWallet.me**-Desktop-App oder aus **Fasten Health**, um deine Daten zu synchronisieren.';

  @override
  String get syncSuccessMessage =>
      'Die Daten wurden erfolgreich synchronisiert!';

  @override
  String get syncErrorConnection =>
      'Verbindung fehlgeschlagen. Prüfe dein Netzwerk und versuche es erneut.';

  @override
  String get syncErrorEndpointNotFound =>
      'Sync-Endpunkt nicht gefunden. Prüfe die Serverkonfiguration.';

  @override
  String get syncErrorAuthentication =>
      'Authentifizierung fehlgeschlagen. Prüfe dein Token.';

  @override
  String get syncErrorInvalidFormat =>
      'Ungültiges Format der Synchronisierungsdaten';

  @override
  String get syncErrorGeneric =>
      'Datensynchronisierung fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String syncPlaceholderSubtitle(String recordType) {
    return 'Synchronisiere oder aktualisiere deine Daten, um $recordType-Einträge zu sehen';
  }

  @override
  String get appLockTitle => 'HealthWallet ist gesperrt';

  @override
  String get appLockMessage =>
      'Entsperre die App, um deine Gesundheitsdaten zu sehen';

  @override
  String get appLockUnlock => 'Entsperren';

  @override
  String get desktopRestoreSucceededTitle => 'Backup wiederhergestellt';

  @override
  String desktopRestoreSucceededMessage(String name, int count) {
    return '\"$name\" wurde wiederhergestellt. Auf diesem Gerät sind jetzt $count Aufzeichnungen.';
  }

  @override
  String get sharedFileNotPreviewable =>
      'Dieser Dateityp kann in geteilten Unterlagen nicht angezeigt werden.';

  @override
  String get desktopWaitingForApproval =>
      'Warte, bis der Desktop dieses Telefon annimmt …';

  @override
  String get desktopPairingRejected =>
      'Der Desktop erkennt dieses Telefon nicht mehr. Scanne seinen QR-Code erneut.';

  @override
  String get desktopPairingDeclined =>
      'Der Desktop hat dieses Telefon abgelehnt.';

  @override
  String get desktopUpdateDesktopApp =>
      'Aktualisiere HealthWallet auf dem Desktop und versuche es erneut.';

  @override
  String get desktopUpdatePhoneApp =>
      'Ein Telefon mit einer älteren HealthWallet-Version wollte sich verbinden. Aktualisiere die App auf dem Telefon.';

  @override
  String get desktopQrOutdated =>
      'Dieser QR-Code stammt von einer älteren HealthWallet-Version. Aktualisiere die App auf dem Desktop und scanne den neuen Code.';

  @override
  String get desktopQrInvalid =>
      'Dieser QR-Code kann nicht zum Koppeln verwendet werden. Zeige auf dem Desktop einen neuen an.';

  @override
  String get desktopNoNetwork =>
      'Dieser Desktop ist mit keinem Netzwerk verbunden. Verbinde ihn mit einem WLAN, um ein Telefon zu koppeln.';

  @override
  String get desktopFirewallHint =>
      'Wenn dein Telefon diesen Desktop nicht findet, erlaube HealthWallet in der Windows-Firewall für private Netzwerke.';

  @override
  String desktopApprovePhoneMessage(String phone, String current) {
    return '„$phone“ möchte sich mit diesem Desktop verbinden.\n\nEs ersetzt „$current“ und erhält die hier gespeicherten Gesundheitsdaten.\n\nZulassen?';
  }

  @override
  String get desktopPairedPhone => 'Gekoppeltes Telefon';

  @override
  String get desktopNewQrUnpairsHint =>
      'Ein neuer QR-Code entkoppelt dieses Telefon; damit koppelst du ein anderes.';

  @override
  String get desktopNotFound =>
      'Desktop nicht gefunden. Prüfe, ob HealthWallet dort geöffnet ist und beide Geräte im selben Netzwerk sind.';

  @override
  String desktopBackupSucceededMessage(String name, int count) {
    return '\"$name\" wurde gespeichert. Sie enthält $count Aufzeichnungen.';
  }

  @override
  String get holderQuestionTitle => 'Wem gehören diese Aufzeichnungen?';

  @override
  String holderQuestionMessage(String name) {
    return 'Es sind Aufzeichnungen für $name eingegangen. Diese Person passt zu niemandem in deiner Wallet. Wer ist das?';
  }

  @override
  String get holderQuestionSomeoneElse => 'Jemand anderes';

  @override
  String get fhirTypeVisionPrescription => 'Brillenrezept';

  @override
  String get categoryVisionPrescriptions => 'Brillenrezepte';

  @override
  String get lensTypeMultifocal => 'Gleitsichtbrille';

  @override
  String get lensTypeDistance => 'Fernbrille';

  @override
  String get lensTypeReading => 'Lesebrille';

  @override
  String get lensTypeOther => 'Brille';

  @override
  String get fieldLensType => 'Glasart';

  @override
  String get fieldDateWritten => 'Ausgestellt am';

  @override
  String get fieldRecommendedFollowUp => 'Nächste Kontrolle';

  @override
  String get labelSerialNumber => 'Seriennummer';

  @override
  String get visionEyeRight => 'Rechtes Auge';

  @override
  String get visionEyeLeft => 'Linkes Auge';

  @override
  String get visionSphere => 'Stärke';

  @override
  String get visionCylinder => 'Astigmatismus';

  @override
  String get visionAxis => 'Winkel';

  @override
  String get visionAdd => 'Lesezusatz';

  @override
  String get visionPrism => 'Prisma';

  @override
  String get visionBase => 'Prismenbasis';

  @override
  String get visionInvalidDioptre =>
      'Einen Wert wie +1.25 eingeben, in Schritten von 0.25';

  @override
  String get visionInvalidAxis => 'Einen Winkel von 0 bis 180 eingeben';

  @override
  String get stagedAlreadyInWallet => 'Bereits in deiner Wallet';

  @override
  String get stagedWillBeCompleted => 'Bereits in deiner Wallet, wird ergänzt';

  @override
  String get documentAlreadyInWallet =>
      'Alles aus diesem Dokument ist bereits in deiner Wallet';

  @override
  String get processingStatusHandedOver => 'Auf dem Desktop';

  @override
  String get desktopHandoverSent =>
      'An den Desktop gesendet. Du wirst benachrichtigt, sobald du es hier oder auf dem Desktop prüfen kannst.';

  @override
  String get desktopHandoverConnectionLost =>
      'Die Verbindung zum Desktop wurde unterbrochen. Versuche es erneut.';

  @override
  String get desktopHandoverTooLarge =>
      'Das Dokument ist zu groß für den Desktop (über 200 MB).';

  @override
  String get desktopHandoverTimedOut =>
      'Der Desktop hat den Empfang des Dokuments abgebrochen. Versuche es erneut.';

  @override
  String get handoverOnDesktopTitle => 'Wird auf dem Desktop verarbeitet';

  @override
  String get handoverOnDesktopMessage =>
      'Der Entwurf kommt zum Prüfen hierher zurück, sobald der Desktop fertig ist. Du kannst ihn auch auf dem Desktop prüfen und speichern.';

  @override
  String get handoverTakeBack => 'Stattdessen auf diesem Telefon verarbeiten';

  @override
  String handoverReadyToReview(String origin) {
    return '$origin: bereit zur Prüfung';
  }

  @override
  String handoverFailedOnDesktop(String origin) {
    return '$origin: Der Desktop konnte es nicht verarbeiten. Es ist wieder auf diesem Telefon.';
  }

  @override
  String handoverNoModelOnDesktop(String origin) {
    return '$origin: Auf dem Desktop gibt es kein KI-Modell. Es ist wieder auf diesem Telefon.';
  }

  @override
  String handoverDeletedOnDesktop(String origin) {
    return '$origin wurde auf dem Desktop gelöscht. Es ist wieder auf diesem Telefon.';
  }

  @override
  String handoverSavedOnDesktop(String origin) {
    return '$origin wurde auf dem Desktop gespeichert. Die Einträge kommen mit der nächsten Synchronisierung auf dieses Telefon.';
  }

  @override
  String handoverSavedOnPhone(String origin) {
    return '$origin wurde auf dem Telefon gespeichert.';
  }

  @override
  String handoverDraftSavedOnDesktop(String origin) {
    return '$origin wurde auf dem Desktop gespeichert. Hier gemachte Änderungen am Entwurf wurden nicht übernommen.';
  }

  @override
  String handoverDraftSavedOnPhone(String origin) {
    return '$origin wurde auf dem Telefon gespeichert. Hier gemachte Änderungen am Entwurf wurden nicht übernommen.';
  }

  @override
  String failedToSaveSetting(String setting) {
    return '„$setting“ konnte nicht gespeichert werden. Versuche es erneut.';
  }

  @override
  String get processingFailedMemory =>
      'Nicht genügend freier Speicher, um das KI-Modell auszuführen. Schließe andere Apps und versuche es erneut, oder schalte den Tiefenscan in den KI-Einstellungen aus.';

  @override
  String get tokenPresetLowHint => 'ein paar Werte';

  @override
  String get tokenPresetMediumHint => 'ein kurzer Bericht';

  @override
  String get tokenPresetHighHint => 'ein vollständiger Bericht';

  @override
  String get backupRecordsOnly => 'Nur Aufzeichnungen';

  @override
  String backupRestoreConfirmPointInTime(String date) {
    return 'Dadurch werden deine Aufzeichnungen auf diesem Computer und deinem gekoppelten Telefon durch das Backup vom $date ersetzt. Seitdem hinzugefügte Aufzeichnungen werden entfernt. Vorher wird eine Kopie „Vor Wiederherstellung“ deiner aktuellen Daten gespeichert und 30 Tage aufbewahrt, damit du das rückgängig machen kannst.';
  }

  @override
  String get backupOldNoFiles =>
      'Dieses Backup enthält keine Dateien. Die Aufzeichnungen werden wiederhergestellt, deine aktuellen Dateien bleiben erhalten.';

  @override
  String backupSafetyName(String date) {
    return 'Vor Wiederherstellung $date';
  }

  @override
  String get backupRestoreFailed =>
      'Wiederherstellung fehlgeschlagen. Deine Daten wurden nicht geändert; das Backup \"Vor Wiederherstellung\" ist in der Liste.';

  @override
  String get backupSafetyFailed =>
      'Das Sicherheits-Backup konnte nicht erstellt werden, daher wurde nichts wiederhergestellt. Prüfe den freien Speicher und den Ordner.';

  @override
  String backupFilesNotRestored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien konnten nicht wiederhergestellt werden.',
      one: '1 Datei konnte nicht wiederhergestellt werden.',
    );
    return '$_temp0';
  }

  @override
  String get backupRestorePhoneOffline =>
      'Dein Telefon ist nicht verbunden. Seit der letzten Synchronisierung darauf hinzugefügte Aufzeichnungen kommen zurück, sobald es sich wieder verbindet; Änderungen an vorhandenen Aufzeichnungen werden durch das Backup ersetzt.';

  @override
  String aiModelDeleteTitle(String name) {
    return '$name löschen?';
  }

  @override
  String aiModelDeleteMessage(int size) {
    return 'Das Modell und seine Tiefenscan-Dateien werden von diesem Gerät entfernt. Um wieder damit zu scannen, musst du es erneut herunterladen (~$size MB).';
  }
}
