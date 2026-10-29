import 'package:flutter/services.dart';
import 'package:health_wallet/core/utils/validator.dart';

enum FieldType {
  text,
  date,
  dropdown,
}

class TextFieldDescriptor {
  TextFieldDescriptor({
    required this.label,
    required this.value,
    required this.confidenceLevel,
    this.fieldType = FieldType.text,
    this.validators,
    this.inputFormatters,
    this.keyboardType,
  });

  /// The field label in the language the descriptor was built with.
  final String label;
  final String value;
  final double confidenceLevel;
  final FieldType fieldType;
  final List<FieldValidationError? Function(String?)>? validators;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;

  /// The first validation error of [value], or null when it is valid.
  FieldValidationError? validate(String? value) {
    if (validators == null || validators!.isEmpty) {
      return null;
    }
    for (var validator in validators!) {
      final error = validator(value);

      if (error != null) {
        return error;
      }
    }

    return null;
  }
}
