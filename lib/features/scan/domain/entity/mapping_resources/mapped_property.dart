import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:string_similarity/string_similarity.dart';

part 'mapped_property.freezed.dart';

@freezed
class MappedProperty with _$MappedProperty {
  const MappedProperty._();

  const factory MappedProperty({
    @Default('') String value,
    @Default(0.0) double confidenceLevel,
  }) = _MappedProperty;

  factory MappedProperty.fromJson(dynamic json) {
    if (json is String?) {
      return MappedProperty(value: json ?? '');
    }

    return MappedProperty(
      value: json["value"] ?? '',
      confidenceLevel: json["confidenceLevel"] ?? 0.0,
    );
  }

  factory MappedProperty.empty() {
    return const MappedProperty(confidenceLevel: 1);
  }

  Map<String, dynamic> toJson() => {
        'value': value,
        'confidenceLevel': confidenceLevel,
      };

  List<String> _createOverlappingChunks(String text, int chunkLength) {
    if (text.length <= chunkLength) {
      return [text];
    }

    final chunks = <String>[];
    for (int i = 0; i <= text.length - chunkLength; i++) {
      chunks.add(text.substring(i, i + chunkLength));
    }
    return chunks;
  }

  /// Does fuzzy matching between the [value] and overlapping chunks of [inputText]
  /// to see if the [inputText] contains a substring similar to [value]
  MappedProperty calculateConfidence(String inputText) {
    if (value.isEmpty) {
      return copyWith(confidenceLevel: 0.0);
    }

    final normalizedValue = _normalize(value);
    final normalizedInput = _normalize(inputText);

    if (normalizedInput.contains(normalizedValue)) {
      return copyWith(confidenceLevel: 1.0);
    }

    final valueTokens = _extractTokens(normalizedValue);
    if (valueTokens.isNotEmpty) {
      final matchedTokens =
          valueTokens.where((t) => normalizedInput.contains(t)).length;
      final tokenRatio = matchedTokens / valueTokens.length;
      if (tokenRatio >= 0.8) {
        return copyWith(confidenceLevel: 0.9);
      }
      if (tokenRatio >= 0.5) {
        return copyWith(confidenceLevel: 0.7);
      }
    }

    final chunkLength = (normalizedValue.length * 1.5).ceil();
    if (normalizedInput.length < chunkLength) {
      final bestMatch =
          StringSimilarity.findBestMatch(normalizedValue, [normalizedInput]);
      return copyWith(confidenceLevel: bestMatch.bestMatch.rating ?? 0.0);
    }

    final List<String> textChunks =
        _createOverlappingChunks(normalizedInput, chunkLength);

    final bestMatch =
        StringSimilarity.findBestMatch(normalizedValue, textChunks);
    final rating = bestMatch.bestMatch.rating ?? 0.0;

    return copyWith(confidenceLevel: rating);
  }

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[/\-.,]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<String> _extractTokens(String normalizedText) {
    return normalizedText
        .split(' ')
        .where((t) => t.length >= 2)
        .toList();
  }

  MappedProperty calculateGenderConfidence(String inputText) {
    if (value.isEmpty) return copyWith(confidenceLevel: 0.0);

    final normalizedInput = inputText.toLowerCase();
    final normalizedValue = value.toLowerCase();

    const genderMap = {
      'male': ['male', 'masculin', 'masc', 'mann', 'männlich', 'hombre', 'masculino', 'm'],
      'female': ['female', 'feminin', 'fem', 'frau', 'weiblich', 'mujer', 'femenino', 'f'],
    };

    final synonyms = genderMap[normalizedValue];
    if (synonyms != null) {
      for (final synonym in synonyms) {
        if (normalizedInput.contains(synonym)) {
          return copyWith(confidenceLevel: 1.0);
        }
      }
    }

    return calculateConfidence(inputText);
  }

  MappedProperty calculateDateConfidence(String inputText) {
    if (value.isEmpty) return copyWith(confidenceLevel: 0.0);

    final digits = RegExp(r'\d+').allMatches(value).map((m) => m.group(0)!).toList();
    if (digits.isEmpty) return calculateConfidence(inputText);

    final year = digits.firstWhere((d) => d.length == 4, orElse: () => '');
    final others = digits.where((d) => d.length <= 2).toList();

    if (year.isNotEmpty && inputText.contains(year)) {
      final allFound = others.every((d) => inputText.contains(d));
      if (allFound) return copyWith(confidenceLevel: 1.0);
      return copyWith(confidenceLevel: 0.85);
    }

    return calculateConfidence(inputText);
  }

  bool get isValid => confidenceLevel > 0.6;

  MappedProperty withFullConfidence() =>
      value.isNotEmpty ? copyWith(confidenceLevel: 1.0) : this;
}

enum ConfidenceLevel {
  high,
  medium,
  low;

  factory ConfidenceLevel.fromDouble(double value) => switch (value) {
        < 0.6 => ConfidenceLevel.low,
        >= 0.6 && < 0.8 => ConfidenceLevel.medium,
        _ => ConfidenceLevel.high
      };

  Color getColor(BuildContext context) => switch (this) {
        ConfidenceLevel.high =>
          context.isDarkMode ? AppColors.borderDark : AppColors.border,
        ConfidenceLevel.medium => AppColors.warningDraft,
        ConfidenceLevel.low => AppColors.error
      };

  String getString() => switch (this) {
        ConfidenceLevel.high => "",
        ConfidenceLevel.medium => "Medium confidence",
        ConfidenceLevel.low => "Low confidence",
      };

  SvgGenImage? getIcon() => switch (this) {
        ConfidenceLevel.high => null,
        ConfidenceLevel.medium => Assets.icons.warningTriangle,
        ConfidenceLevel.low => Assets.icons.warning,
      };
}
