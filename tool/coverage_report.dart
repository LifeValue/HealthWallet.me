// Prints line coverage from coverage/lcov.info: the total, each feature area and the critical
// areas. Run it through scripts/coverage.sh, which loads every app file first so untested files
// count as 0% instead of being left out.
//
//   dart run tool/coverage_report.dart                 summary
//   dart run tool/coverage_report.dart --files <dir>   per-file lines for one directory
import 'dart:io';

/// Areas where a regression loses or corrupts user data, or breaks a contract with something
/// already in users' hands (wallet passes, the paired desktop app).
const criticalAreas = <String, String>{
  'Emergency QR + wallet pass': 'lib/features/wallet_pass/data/',
  'LWW sync': 'lib/features/desktop/lww_sync/',
  'Desktop wire protocol': 'lib/features/desktop/communication/data/',
  'Backup': 'lib/features/desktop/backup/data/',
  'Handover': 'lib/features/desktop/handover/data/',
  'Database + migrations': 'lib/core/data/local/',
  'FHIR record extractors': 'lib/features/records/domain/utils/',
  'Scan → FHIR mapping':
      'lib/features/processing/domain/entity/mapping_resources/',
  'Patient services': 'lib/features/user/domain/services/',
  'Share records': 'lib/features/share_records/data/',
  'Sync data': 'lib/features/sync/data/',
  'App lock': 'lib/features/app_lock/',
  'Temp file sweeper': 'lib/core/services/temp_file_sweeper.dart',
  'Deep links': 'lib/core/services/deep_link_service.dart',
};

final _generated = RegExp(
  r'\.(g|freezed|gr|config|gen)\.dart$|/app_localizations[^/]*\.dart$',
);

class Coverage {
  int hit = 0;
  int found = 0;

  void add(Coverage other) {
    hit += other.hit;
    found += other.found;
  }

  String get percent => found == 0
      ? '   -  '
      : '${(100 * hit / found).toStringAsFixed(1)}%'.padLeft(6);
}

Map<String, Coverage> parseLcov(String lcov) {
  final result = <String, Coverage>{};
  Coverage? current;
  for (final line in lcov.split('\n')) {
    if (line.startsWith('SF:')) {
      current = result.putIfAbsent(line.substring(3).trim(), Coverage.new);
    } else if (line.startsWith('DA:') && current != null) {
      final hits = int.parse(line.substring(3).split(',')[1]);
      current.found++;
      if (hits > 0) current.hit++;
    }
  }
  return result;
}

String areaOf(String path) {
  final parts = path.split('/');
  if (parts.length > 3 && parts[1] == 'features') return 'features/${parts[2]}';
  return parts.length > 2 ? parts[1] : '(root)';
}

Future<void> main(List<String> args) async {
  final lcovFile = File('coverage/lcov.info');
  if (!lcovFile.existsSync()) {
    stderr.writeln('coverage/lcov.info not found; run scripts/coverage.sh');
    exit(1);
  }
  final byFile = parseLcov(lcovFile.readAsStringSync());
  final listing = await Process.run('git', ['ls-files', 'lib/*.dart']);
  final files = (listing.stdout as String)
      .split('\n')
      .where((f) => f.isNotEmpty && !_generated.hasMatch(f))
      .toList();
  Coverage of(String file) => byFile[file] ?? Coverage();

  final filesIndex = args.indexOf('--files');
  if (filesIndex != -1 && filesIndex + 1 < args.length) {
    final prefix = args[filesIndex + 1];
    final selected = files.where((f) => f.startsWith(prefix)).toList()
      ..sort((a, b) {
        final ca = of(a), cb = of(b);
        return (cb.found - cb.hit).compareTo(ca.found - ca.hit);
      });
    for (final file in selected) {
      final c = of(file);
      stdout.writeln(
        '${c.percent}  ${'${c.hit}/${c.found}'.padLeft(9)}  $file',
      );
    }
    return;
  }

  final total = Coverage();
  final areas = <String, Coverage>{};
  final touched = <String, int>{};
  final counts = <String, int>{};
  for (final file in files) {
    final c = of(file);
    final area = areaOf(file);
    total.add(c);
    areas.putIfAbsent(area, Coverage.new).add(c);
    counts[area] = (counts[area] ?? 0) + 1;
    if (c.hit > 0) touched[area] = (touched[area] ?? 0) + 1;
  }

  stdout
    ..writeln(
      'Total ${total.percent.trim()}  (${total.hit}/${total.found} lines, '
      '${touched.values.fold(0, (a, b) => a + b)} of ${files.length} files run by a test)',
    )
    ..writeln()
    ..writeln('${'Area'.padRight(26)}  Cover     Lines       Files');
  final sorted = areas.entries.toList()
    ..sort((a, b) => b.value.found.compareTo(a.value.found));
  for (final MapEntry(key: area, value: c) in sorted) {
    stdout.writeln(
      '${area.padRight(26)}  ${c.percent}  ${'${c.hit}/${c.found}'.padLeft(11)}  '
      '${touched[area] ?? 0}/${counts[area]}',
    );
  }

  stdout
    ..writeln()
    ..writeln('${'Critical area'.padRight(28)}  Cover     Lines');
  for (final MapEntry(key: name, value: prefix) in criticalAreas.entries) {
    final c = Coverage();
    for (final file in files.where((f) => f.startsWith(prefix))) {
      c.add(of(file));
    }
    stdout.writeln(
      '${name.padRight(28)}  ${c.percent}  ${'${c.hit}/${c.found}'.padLeft(11)}',
    );
  }
}
