import 'package:health_wallet/core/l10n/arb/app_localizations.dart';

/// Why a field value is invalid. Validators return this instead of a
/// message, so callers check the kind of error and never compare text; the
/// widget turns it into a message with [message].
enum FieldValidationError {
  empty,
  invalidDate;

  String message(AppLocalizations l10n) => switch (this) {
    FieldValidationError.empty => l10n.fieldCannotBeEmpty,
    FieldValidationError.invalidDate => l10n.dateFormatHintIso,
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
