/// On-device document→FHIR extraction benchmark.
///
/// ```sh
/// fvm dart run tool/extraction_bench/bench.dart generate --out <dir> [--seed 1234] [--per-cell 10]
///     [--langs en,es,de,ro] [--families lab_report,discharge_letter[,lab_report_long]]
/// fvm dart run tool/extraction_bench/bench.dart oracle --dataset <dir> --out <dir>
/// fvm dart run tool/extraction_bench/bench.dart score --dataset <dir> --predictions <jsonl> --out <dir> [--seed 1234]
/// fvm dart run tool/extraction_bench/bench.dart compare --dataset <dir> --a <jsonl> --b <jsonl> --out <dir> [--seed 1234]
/// ```
///
/// See tool/extraction_bench/README.md.
library;

import 'dart:io';

import 'package:args/args.dart';

import 'src/dataset.dart';
import 'src/formats.dart';
import 'src/generator.dart';
import 'src/report.dart';

const _defaultSeed = 1234;
const _bootstrapSamples = 10000;

ArgParser _parser() {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');
  parser.addCommand(
    'generate',
    ArgParser()
      ..addOption(
        'out',
        help: 'Output directory (the dataset root).',
        mandatory: true,
      )
      ..addOption('seed', defaultsTo: '$_defaultSeed')
      ..addOption(
        'per-cell',
        defaultsTo: '10',
        help: 'Documents per (language, family).',
      )
      ..addOption('langs', defaultsTo: benchLangs.join(','))
      ..addOption('families', defaultsTo: defaultFamilies.join(','))
      ..addOption('font-dir', defaultsTo: BenchFonts.defaultDir),
  );
  parser.addCommand(
    'score',
    ArgParser()
      ..addOption('dataset', mandatory: true)
      ..addOption('predictions', mandatory: true, help: 'predictions.jsonl')
      ..addOption('out', mandatory: true)
      ..addOption('seed', defaultsTo: '$_defaultSeed', help: 'Bootstrap seed.')
      ..addFlag(
        'only-predicted',
        negatable: false,
        help: 'Score only the documents with a record (a BENCH_LIMIT run), not the whole dataset.',
      ),
  );
  parser.addCommand(
    'compare',
    ArgParser()
      ..addOption('dataset', mandatory: true)
      ..addOption('a', mandatory: true, help: 'Baseline predictions.jsonl')
      ..addOption('b', mandatory: true, help: 'Candidate predictions.jsonl')
      ..addOption('out', mandatory: true)
      ..addOption('seed', defaultsTo: '$_defaultSeed', help: 'Bootstrap seed.'),
  );
  parser.addCommand(
    'oracle',
    ArgParser()
      ..addOption('dataset', mandatory: true)
      ..addOption(
        'out',
        mandatory: true,
        help: 'Directory for predictions.jsonl',
      ),
  );
  return parser;
}

int _int(ArgResults r, String name) {
  final v = int.tryParse(r[name] as String);
  if (v == null) {
    throw BenchInputException('--$name must be an integer, got "${r[name]}"');
  }
  return v;
}

List<String> _list(ArgResults r, String name) {
  final values = (r[name] as String)
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (values.isEmpty) {
    throw BenchInputException('--$name must list at least one value');
  }
  final duplicates = {
    for (final v in values)
      if (values.where((x) => x == v).length > 1) v,
  };
  if (duplicates.isNotEmpty) {
    throw BenchInputException(
      '--$name lists ${duplicates.join(', ')} more than once',
    );
  }
  return values;
}

Future<int> run(List<String> args) async {
  final parser = _parser();
  final ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln(parser.usage)
      ..writeln('Commands: ${parser.commands.keys.join(', ')}');
    return 64;
  }
  final command = results.command;
  if (results['help'] == true || command == null) {
    stdout
      ..writeln('Usage: bench.dart <generate|score|compare|oracle> [options]')
      ..writeln(parser.usage);
    for (final e in parser.commands.entries) {
      stdout
        ..writeln()
        ..writeln('${e.key}:')
        ..writeln(e.value.usage);
    }
    return command == null && results['help'] != true ? 64 : 0;
  }

  try {
    switch (command.name) {
      case 'generate':
        final perCell = _int(command, 'per-cell');
        if (perCell < 1) {
          throw BenchInputException('--per-cell must be at least 1');
        }
        final fontDir = command['font-dir'] as String;
        if (!File('$fontDir/Matter-Regular.ttf').existsSync()) {
          throw BenchInputException(
            'Font not found: $fontDir/Matter-Regular.ttf (run from the repository root '
            'or pass --font-dir)',
          );
        }
        final options = GeneratorOptions(
          seed: _int(command, 'seed'),
          perCell: perCell,
          langs: _list(command, 'langs'),
          families: _list(command, 'families'),
        );
        final docs = await generateDataset(
          command['out'] as String,
          options,
          BenchFonts.load(fontDir),
        );
        stdout.writeln('Wrote ${docs.length} documents to ${command['out']}');
      case 'score':
        final report = runScore(
          datasetPath: command['dataset'] as String,
          predictionsPath: command['predictions'] as String,
          outDir: command['out'] as String,
          seed: _int(command, 'seed'),
          samples: _bootstrapSamples,
          onlyPredicted: command['only-predicted'] as bool,
        );
        final overall = report['overall'] as Map;
        final f1 = overall['f1'] as Map;
        stdout.writeln(
          'Mean F1 ${(f1['mean'] as double).toStringAsFixed(4)} '
          '[${(f1['lo'] as double).toStringAsFixed(4)}, ${(f1['hi'] as double).toStringAsFixed(4)}] '
          'over ${overall['docs']} documents; report in ${command['out']}',
        );
      case 'compare':
        final c = runCompare(
          datasetPath: command['dataset'] as String,
          aPath: command['a'] as String,
          bPath: command['b'] as String,
          outDir: command['out'] as String,
          seed: _int(command, 'seed'),
          samples: _bootstrapSamples,
        );
        final overall = c['overall'] as Map;
        final diff = overall['diff'] as Map;
        stdout.writeln(
          'F1 B - A ${(diff['mean'] as double).toStringAsFixed(4)} '
          '[${(diff['lo'] as double).toStringAsFixed(4)}, ${(diff['hi'] as double).toStringAsFixed(4)}], '
          'P(diff <= 0) ${(overall['pDiffLeq0'] as double).toStringAsFixed(4)} over ${overall['docs']} documents; '
          'comparison in ${command['out']}',
        );
      case 'oracle':
        writeOraclePredictions(
          datasetPath: command['dataset'] as String,
          outDir: command['out'] as String,
        );
        stdout.writeln('Wrote ${command['out']}/predictions.jsonl');
    }
  } on BenchInputException catch (e) {
    stderr.writeln('error: ${e.message}');
    return 1;
  } on MissingGlyphException catch (e) {
    stderr.writeln('error: $e (nothing was written)');
    return 1;
  } on ArgumentError catch (e) {
    stderr.writeln('error: ${e.message}');
    return 1;
  } on FileSystemException catch (e) {
    stderr.writeln('error: ${e.message}: ${e.path}');
    return 1;
  }
  return 0;
}

Future<void> main(List<String> args) async {
  exitCode = await run(args);
}
