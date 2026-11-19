import 'package:health_wallet/core/l10n/arb/app_localizations.dart';

/// The texts written onto an Apple or Google wallet pass, in the language
/// the pass is created in. A pass is a snapshot: it keeps this language
/// after the app's language changes. The QR payload never depends on it.
class WalletPassLabels {
  const WalletPassLabels({
    required this.localeName,
    required this.cardTitle,
    required this.patient,
    required this.bloodType,
    required this.allergies,
    required this.gender,
    required this.dateOfBirth,
    required this.emergencyPhone,
    required this.conditions,
    required this.medicalConditions,
    required this.medications,
    required this.male,
    required this.female,
    required this.otherGender,
    required this.unknownGender,
    required this.age,
  });

  factory WalletPassLabels.fromL10n(AppLocalizations l10n) => WalletPassLabels(
    localeName: l10n.localeName,
    cardTitle: l10n.emergencyMedicalId,
    patient: l10n.patient,
    bloodType: l10n.bloodType,
    allergies: l10n.allergiesLabel,
    gender: l10n.gender,
    dateOfBirth: l10n.dateOfBirthLabel,
    emergencyPhone: l10n.emergencyPhoneLabel,
    conditions: l10n.conditionsLabel,
    medicalConditions: l10n.medicalConditionsLabel,
    medications: l10n.medicationsLabel,
    male: l10n.male,
    female: l10n.female,
    otherGender: l10n.genderOther,
    unknownGender: l10n.genderUnknown,
    age: l10n.walletPassAge,
  );

  /// The app locale (`en`, `de`, …), for dates and the pass language tag.
  final String localeName;
  final String cardTitle;
  final String patient;
  final String bloodType;
  final String allergies;
  final String gender;
  final String dateOfBirth;
  final String emergencyPhone;
  final String conditions;
  final String medicalConditions;
  final String medications;
  final String male;
  final String female;
  final String otherGender;
  final String unknownGender;

  /// The patient's age, e.g. "Age 40".
  final String Function(int years) age;

  /// The display name of a FHIR `AdministrativeGender` code. An unknown code
  /// is shown capitalized, as before.
  String genderName(String fhirGender) => switch (fhirGender.toLowerCase()) {
    'male' => male,
    'female' => female,
    'other' => otherGender,
    'unknown' => unknownGender,
    _ =>
      fhirGender.isEmpty
          ? fhirGender
          : fhirGender[0].toUpperCase() + fhirGender.substring(1),
  };
}
