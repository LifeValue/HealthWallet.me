import 'package:flutter/painting.dart';

/// Splits a translated sentence into spans, setting the parts wrapped in
/// `**` in [boldStyle], so translators can move the bold words freely:
/// `'We **do not** collect…'`. Text without markers is a single span.
///
/// When the markers are unbalanced (an odd number of `**`), nothing is bold:
/// the text is returned as one plain span with the markers removed, so a
/// translation typo never bolds the rest of the sentence.
List<TextSpan> boldMarkupSpans(String text, {required TextStyle boldStyle}) {
  final parts = text.split('**');
  if (parts.length.isEven) {
    final plain = parts.join();
    return [if (plain.isNotEmpty) TextSpan(text: plain)];
  }
  return [
    for (final (i, part) in parts.indexed)
      if (part.isNotEmpty)
        TextSpan(text: part, style: i.isOdd ? boldStyle : null),
  ];
}
