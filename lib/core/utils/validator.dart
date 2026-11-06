import 'package:health_wallet/core/l10n/arb/app_localizations.dart';

/// Why a field value is invalid. Validators return this instead of a
/// message, so callers check the kind of error and never compare text; the
/// widget turns it into a message with [message].
enum FieldValidationError {
  empty,
  invalidDate,
  invalidDioptre,
  invalidAxis;

  String message(AppLocalizations l10n) => switch (this) {
    FieldValidationError.empty => l10n.fieldCannotBeEmpty,
    FieldValidationError.invalidDate => l10n.dateFormatHintIso,
    FieldValidationError.invalidDioptre => l10n.visionInvalidDioptre,
    FieldValidationError.invalidAxis => l10n.visionInvalidAxis,
  };
}

FieldValidationError? nonEmptyValidator(String? value) {
  if (value == null || value.isEmpty) {
    return FieldValidationError.empty;
  }
  return null;
}

FieldValidationError? dateValidator(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  if (DateTime.tryParse(value) == null) {
    return FieldValidationError.invalidDate;
  }

  return null;
}

/// A lens power in dioptres as prescriptions print it: up to ±30, in
/// quarter steps ("+1.25", "-0,50", "2"). Empty is valid (not printed).
FieldValidationError? dioptreValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  if (!RegExp(r'^[+\-]?\d{1,2}([.,]\d{1,2})?$').hasMatch(text)) {
    return FieldValidationError.invalidDioptre;
  }
  final dioptres = double.parse(text.replaceAll(',', '.'));
  final quarters = dioptres * 4;
  if (dioptres.abs() > 30 || quarters != quarters.roundToDouble()) {
    return FieldValidationError.invalidDioptre;
  }
  return null;
}

/// An astigmatism angle in whole degrees, 0 to 180. Empty is valid.
FieldValidationError? axisValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final degrees = int.tryParse(text);
  if (degrees == null || degrees < 0 || degrees > 180) {
    return FieldValidationError.invalidAxis;
  }
  return null;
}
