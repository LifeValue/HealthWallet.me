import 'package:flutter/painting.dart';

/// Splits a translated sentence into spans, setting the parts wrapped in
/// `**` in [boldStyle], so translators can move the bold words freely:
/// `'We **do not** collect…'`. Text without markers is a single span.
List<TextSpan> boldMarkupSpans(String text, {required TextStyle boldStyle}) {
  final parts = text.split('**');
  return [
    for (final (i, part) in parts.indexed)
      if (part.isNotEmpty)
        TextSpan(text: part, style: i.isOdd ? boldStyle : null),
  ];
}
