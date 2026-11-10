// Records the English text every translation was made from, in
// test/core/l10n/translated_english.json. Run it after updating the es, de and
// ro texts of an English message that changed (or after adding a message):
//
//   fvm dart run tool/update_translation_baseline.dart
//
// arb_parity_test.dart fails while an English message differs from this
// record, so a changed English text can't leave the translations behind.
import 'dart:convert';
import 'dart:io';

const _english = 'lib/core/l10n/arb/app_en.arb';
const baselinePath = 'test/core/l10n/translated_english.json';

void main() {
  final en = jsonDecode(File(_english).readAsStringSync()) as Map;
  final messages = <String, String>{
    for (final MapEntry(:key, :value) in en.entries)
      if (key is String && !key.startsWith('@') && value is String) key: value,
  };
  final sorted = Map.fromEntries(
    messages.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
  File(
    baselinePath,
  ).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(sorted)}\n',
  );
  stdout.writeln('Wrote ${sorted.length} English messages to $baselinePath');
}
