import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against user-visible English literals in the mobile app.
///
/// Scans [_scannedDirs] (the mobile parts of `lib/`) for `Text('…')` and for `label:`, `title:`, `message:`,
/// `hintText:`, `labelText:` and `tooltip:` given a string literal that
/// starts with a letter. Strings shown to the user go through the ARB files
/// (`context.l10n`, an `AppLocalizations` parameter or `AppStringsProvider`).

/// The directories scanned so far. Widen this list as each feature is
/// translated, until it is just `lib/`.
const _scannedDirs = [
  'lib/core',
  'lib/features/home',
  'lib/features/dashboard',
];

/// Paths that are not part of the mobile UI or are generated.
const _excludedPaths = [
  'lib/features/desktop/',
  'lib/core/l10n/arb/',
  'lib/gen/',
  // Removed from release builds by security item S3.
  'debug_log_sheet.dart',
  // The field-descriptor labels are English defaults; the review form shows
  // `localizedLabels(l10n)` instead.
  'lib/features/processing/domain/entity/mapping_resources/',
  // Record-detail domain formatter, translated together with the record
  // entities' additionalInfo; remove this line once it takes AppLocalizations.
  'lib/core/utils/blood_observation_utils.dart',
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
