import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'mapping_identifier.freezed.dart';

/// An identifier a staged resource carries into FHIR: a document serial or
/// the key of a visit, in the system that scopes it.
@freezed
abstract class MappingIdentifier with _$MappingIdentifier {
  const MappingIdentifier._();

  const factory MappingIdentifier({
    @Default('') String system,
    @Default('') String value,
  }) = _MappingIdentifier;

  factory MappingIdentifier.fromJson(Map<String, dynamic> json) {
    return MappingIdentifier(
      system: json['system'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'system': system, 'value': value};

  fhir_r4.Identifier toFhir() => fhir_r4.Identifier(
    system: system.isEmpty ? null : fhir_r4.FhirUri(system),
    value: fhir_r4.FhirString(value),
  );

  /// Whether a stored FHIR identifier JSON is this one.
  bool matchesJson(Object? json) =>
      json is Map && json['system'] == system && json['value'] == value;

  static List<MappingIdentifier> listFromJson(Object? json) => [
    if (json is List)
      for (final item in json)
        if (item is Map<String, dynamic>) MappingIdentifier.fromJson(item),
  ];
}
