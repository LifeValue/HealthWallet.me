import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/utils/bold_markup.dart';

const _bold = TextStyle(fontWeight: FontWeight.bold);

List<(String?, bool)> _spans(String text) => [
  for (final span in boldMarkupSpans(text, boldStyle: _bold))
    (span.text, span.style == _bold),
];

void main() {
  test('text without markers is one plain span', () {
    expect(_spans('We collect nothing.'), [('We collect nothing.', false)]);
  });

  test('balanced markers bold the wrapped parts', () {
    expect(_spans('We **do not** collect **any** data.'), [
      ('We ', false),
      ('do not', true),
      (' collect ', false),
      ('any', true),
      (' data.', false),
    ]);
    expect(_spans('**Bold** start'), [('Bold', true), (' start', false)]);
  });

  test('unbalanced markers render the text without bold', () {
    expect(_spans('We **do not collect data.'), [
      ('We do not collect data.', false),
    ]);
    expect(_spans('A **b** c **d'), [('A b c d', false)]);
  });

  test('empty text gives no spans', () {
    expect(_spans(''), isEmpty);
  });
}
