import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _arbDir = 'lib/core/l10n/arb';
const _translations = ['es', 'de', 'ro'];

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
    });
  }

  test('untranslated_messages.json lists no key', () {
    final file = File('untranslated_messages.json');
    if (!file.existsSync()) return;
    final untranslated = jsonDecode(file.readAsStringSync()) as Map;
    expect(untranslated, isEmpty);
  });
}
