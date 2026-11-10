import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/utils/validator.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/text_field_descriptor.dart';

TextFieldDescriptor _field(
  String value,
  double confidence, {
  List<FieldValidationError? Function(String?)>? validators,
}) => TextFieldDescriptor(
  label: 'Label',
  value: value,
  confidenceLevel: confidence,
  validators: validators,
);

void main() {
  test('an empty field shows no confidence hint, however it was scored', () {
    expect(_field('', 0).confidence, ConfidenceLevel.high);
    expect(_field('  ', 0.7).confidence, ConfidenceLevel.high);
  });

  test('a value read from the document keeps its confidence', () {
    expect(_field('Dr. Exemplu', 0.2).confidence, ConfidenceLevel.low);
    expect(_field('Dr. Exemplu', 0.7).confidence, ConfidenceLevel.medium);
    expect(_field('Dr. Exemplu', 1).confidence, ConfidenceLevel.high);
  });

  test('a field is required when a validator rejects it empty', () {
    expect(
      _field('', 0, validators: [nonEmptyValidator, dateValidator]).isRequired,
      isTrue,
    );
    expect(_field('', 0, validators: [dateValidator]).isRequired, isFalse);
    expect(_field('', 0).isRequired, isFalse);
  });
}
