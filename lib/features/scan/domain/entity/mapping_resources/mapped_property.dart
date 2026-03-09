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

    final chunkLength = (value.length * 1.2).ceil();
    if (inputText.length < chunkLength) {
      final bestMatch = StringSimilarity.findBestMatch(value, [inputText]);
      return copyWith(confidenceLevel: bestMatch.bestMatch.rating ?? 0.0);
    }

    final List<String> textChunks =
        _createOverlappingChunks(inputText, chunkLength);

    final bestMatch = StringSimilarity.findBestMatch(value, textChunks);
    final rating = bestMatch.bestMatch.rating ?? 0.0;

    return copyWith(confidenceLevel: rating);
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
