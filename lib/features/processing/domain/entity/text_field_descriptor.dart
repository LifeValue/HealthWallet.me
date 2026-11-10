import 'package:flutter/services.dart';
import 'package:health_wallet/core/utils/validator.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';

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

  /// How sure the reading of [value] is, for the review's hint. An empty
  /// field shows none: nothing was read to doubt.
  ConfidenceLevel get confidence => value.trim().isEmpty
      ? ConfidenceLevel.high
      : ConfidenceLevel.fromDouble(confidenceLevel);

  /// Whether the field must be filled in: a validator rejects it empty.
  bool get isRequired => validate('') != null;

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
