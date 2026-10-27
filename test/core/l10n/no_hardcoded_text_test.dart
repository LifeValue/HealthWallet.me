import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against user-visible English literals in the mobile app.
///
/// Scans [_scannedDirs] (the mobile parts of `lib/`) for `Text('…')` and for `label:`, `title:`, `message:`,
/// `hintText:`, `labelText:` and `tooltip:` given a string literal that
/// starts with a letter. Strings shown to the user go through the ARB files
/// (`context.l10n`, an `AppLocalizations` parameter or `AppStringsProvider`).

/// The whole app is scanned, except the paths excluded below.
const _scannedDirs = ['lib'];

/// Paths that are not part of the mobile UI or are generated.
const _excludedPaths = [
  'lib/features/desktop/',
  'lib/core/l10n/arb/',
  'lib/gen/',
  // Removed from release builds by security item S3.
  'debug_log_sheet.dart',
  'share_debug_log_sheet.dart',
];

const _generatedSuffixes = [
  '.g.dart',
  '.freezed.dart',
  '.gen.dart',
  '.config.dart',
  '.gr.dart',
];

/// Literals that are not translated: brands, units, stored FHIR data.
const _allowedLiterals = {
  // Brand: the app title.
  'HealthWallet.me',
  // Stored FHIR data: the default patient's name, used to match it again.
  'Health Wallet Holder',
  // Stored FHIR data: the title of a blood-pressure observation built from a scan.
  'Blood Pressure Panel',
  // Stored FHIR data: the title of a blood-type observation saved from the profile.
  r'Blood Type: $bloodType',
  // Contact address and domain shown in the privacy policy.
  'hello@healthwallet.me',
  'healthwallet.me',
  // Typed confirmation word the user must enter; kept identical in every language.
  'RESET',
};

final _pattern = RegExp(
  r'''(?:\bText\(|\b(?:label|title|message|hintText|labelText|tooltip):)\s*(['"])([A-Za-z][^'"]*)\1''',
);

void main() {
  test('mobile code has no hardcoded user-visible English text', () {
    final offenders = <String>[];
    final files = _scannedDirs
        .expand((dir) => Directory(dir).listSync(recursive: true))
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !_generatedSuffixes.any(f.path.endsWith))
        .where((f) => !_excludedPaths.any(f.path.contains));

    for (final file in files) {
      final source = file.readAsStringSync();
      for (final match in _pattern.allMatches(source)) {
        final literal = match.group(2)!;
        if (_allowedLiterals.contains(literal)) continue;
        final line = '\n'.allMatches(source.substring(0, match.start)).length;
        offenders.add('${file.path}:${line + 1}: $literal');
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
