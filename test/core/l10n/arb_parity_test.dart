import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _arbDir = 'lib/core/l10n/arb';
const _translations = ['es', 'de', 'ro'];

/// The English each translation was made from; see
/// `tool/update_translation_baseline.dart`.
const _baselinePath = 'test/core/l10n/translated_english.json';

/// Plural forms a language needs beyond `other` when English has a singular
/// form (CLDR): Romanian also says "2 recipiente" but "20 de recipiente".
const _extraPluralForms = {
  'ro': ['few'],
};

final _plural = RegExp(r'^\{\w+, *plural,');
final _pluralForm = RegExp(r'(=\d+|zero|one|two|few|many|other)\{');

/// The plural forms a message selects on, with `=1` counted as `one`.
Set<String> _pluralForms(String message) => {
  for (final m in _pluralForm.allMatches(message))
    m.group(1) == '=1' ? 'one' : m.group(1)!,
};

Map<String, dynamic> _readArb(String locale) =>
    jsonDecode(File('$_arbDir/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final en = _readArb('en');
  final messageKeys = en.keys.where((k) => !k.startsWith('@')).toList();

  for (final locale in _translations) {
    group('app_$locale.arb', () {
      final arb = _readArb(locale);

      test('has every key of app_en.arb', () {
        final missing = messageKeys
            .where((k) => arb[k] is! String || (arb[k] as String).isEmpty)
            .toList();
        expect(missing, isEmpty, reason: 'keys missing in app_$locale.arb');
      });

      test('uses the same placeholders as app_en.arb', () {
        final mismatched = <String>[];
        for (final key in messageKeys) {
          final meta = en['@$key'];
          if (meta is! Map || meta['placeholders'] is! Map) continue;
          final translated = arb[key];
          if (translated is! String) continue;
          for (final name in (meta['placeholders'] as Map).keys) {
            if (!RegExp('\\{$name[,}]').hasMatch(translated)) {
              mismatched.add('$key: {$name}');
            }
          }
        }
        expect(mismatched, isEmpty);
      });

      test('keeps the plural forms the language needs', () {
        final wrong = <String>[];
        for (final key in messageKeys) {
          final english = en[key] as String;
          final translated = arb[key];
          if (!_plural.hasMatch(english) || translated is! String) continue;
          if (!_plural.hasMatch(translated)) {
            wrong.add('$key: no longer a plural');
            continue;
          }
          final forms = _pluralForms(translated);
          final needed = {
            'other',
            if (_pluralForms(english).contains('one')) ...[
              'one',
              ...?_extraPluralForms[locale],
            ],
          };
          final missing = needed.difference(forms);
          if (missing.isNotEmpty) wrong.add('$key: no ${missing.join(', ')}');
        }
        expect(wrong, isEmpty);
      });
    });
  }

  test('no English message changed since it was translated', () {
    final baseline = jsonDecode(
      File(_baselinePath).readAsStringSync(),
    ) as Map<String, dynamic>;
    final changed = [
      for (final key in messageKeys)
        if (baseline[key] != en[key]) key,
    ];
    final removed = baseline.keys.where((k) => !en.containsKey(k)).toList();
    expect(
      [...changed, ...removed],
      isEmpty,
      reason:
          'Update the es, de and ro texts of these messages, then run '
          '`fvm dart run tool/update_translation_baseline.dart`.',
    );
  });

  test('untranslated_messages.json lists no key', () {
    final file = File('untranslated_messages.json');
    if (!file.existsSync()) return;
    final untranslated = jsonDecode(file.readAsStringSync()) as Map;
    expect(untranslated, isEmpty);
  });
}
