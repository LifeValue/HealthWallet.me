import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../tool/extraction_bench/bench.dart' as bench;
import '../../tool/extraction_bench/src/bootstrap.dart';
import '../../tool/extraction_bench/src/dataset.dart';
import '../../tool/extraction_bench/src/generator.dart';
import '../../tool/extraction_bench/src/report.dart';

void main() {
  late Directory tmp;
  late String dataset;

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('bench_report_');
    dataset = p.join(tmp.path, 'dataset');
    await generateDataset(dataset, const GeneratorOptions(seed: 7, perCell: 2), BenchFonts.load(BenchFonts.defaultDir));
    writeOraclePredictions(datasetPath: dataset, outDir: p.join(tmp.path, 'oracle'));
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));

  String oracle() => p.join(tmp.path, 'oracle', 'predictions.jsonl');

  test('oracle predictions score F1 1.0 with no omissions or hallucinations', () {
    final out = p.join(tmp.path, 'oracle-report');
    final report = runScore(datasetPath: dataset, predictionsPath: oracle(), outDir: out, seed: 1234, samples: 500);
    final overall = report['overall'] as Map;
    expect((overall['f1'] as Map)['mean'], 1.0);
    expect((overall['f1'] as Map)['lo'], 1.0);
    expect(overall['omissionRate'], {'mean': 0.0, 'lo': 0.0, 'hi': 0.0});
    expect(overall['hallucinationRate'], {'mean': 0.0, 'lo': 0.0, 'hi': 0.0});
    expect(overall['docs'], 16);
    for (final d in report['documents'] as List) {
      expect((d as Map)['f1'], 1.0, reason: '${d['docId']}');
    }

    final md = File(p.join(out, 'report.md')).readAsStringSync();
    final metas = loadDataset(dataset).map((d) => d.meta).toList();
    final strata = report['strata'] as Map;
    for (final key in strataKeys) {
      final values = {
        for (final m in metas)
          switch (key) {
            'split' => m.split,
            'lang' => m.lang,
            'family' => m.family,
            _ => m.degradation,
          },
      };
      final groups = strata[key] as Map;
      expect(groups.keys.toSet(), values, reason: key);
      expect(groups.values.fold<int>(0, (n, g) => n + ((g as Map)['docs'] as int)), 16, reason: key);
      for (final g in groups.values) {
        expect(((g as Map)['f1'] as Map)['mean'], 1.0);
      }
      // Rows sit under this stratum's own heading in report.md.
      final start = md.indexOf('### $key\n');
      expect(start, isNonNegative, reason: key);
      final end = md.indexOf('\n#', start + 1);
      final section = md.substring(start, end < 0 ? md.length : end);
      for (final v in values) {
        expect(section, contains('\n| $v | ${(groups[v] as Map)['docs']} |'), reason: '$key=$v');
      }
    }
    final types = report['resourceTypes'] as Map;
    expect(types.keys, containsAll(['Patient', 'Observation', 'DiagnosticReport', 'Encounter', 'Condition',
        'MedicationStatement', 'Practitioner', 'Organization']));
    for (final t in types.values) {
      expect(((t as Map)['f1'] as Map)['mean'], 1.0);
    }
    expect(jsonDecode(File(p.join(out, 'report.json')).readAsStringSync()), isA<Map>());
  });

  test('missing and failed documents are scored empty and counted, never dropped', () {
    final lines = File(oracle()).readAsLinesSync();
    final records = [for (final l in lines) jsonDecode(l) as Map<String, dynamic>];
    final missingId = records[0]['docId'];
    final failed = {...records[1], 'error': 'Exception: boom'};
    final rest = records.skip(2).map((r) => {
          ...r,
          'generations': [
            {'phase': 'basic', 'mode': 'text', 'strictJsonValid': true, 'timeToFirstTokenMs': 100.0, 'promptEvalMs': 80.0},
            {'phase': 'remaining', 'mode': 'vision', 'strictJsonValid': false, 'timeToFirstTokenMs': 300.0},
          ],
          'wallMs': 1000,
          'peakRssBytes': 1 << 30,
        });
    final path = p.join(tmp.path, 'partial.jsonl');
    File(path).writeAsStringSync([failed, ...rest].map(jsonEncode).join('\n'));

    final report = runScore(
        datasetPath: dataset, predictionsPath: path, outDir: p.join(tmp.path, 'partial'), seed: 1, samples: 200);
    final counts = report['counts'] as Map;
    expect(counts['documents'], 16);
    expect(counts['missing'], 1);
    expect(counts['errors'], 1);
    final docs = {for (final d in report['documents'] as List) (d as Map)['docId']: d};
    expect(docs[missingId]!['status'], 'missing');
    expect(docs[missingId]!['f1'], 0);
    expect(docs[failed['docId']]!['status'], 'error');
    expect(docs[failed['docId']]!['f1'], 0);
    final overall = report['overall'] as Map;
    expect((overall['f1'] as Map)['mean'], closeTo(14 / 16, 1e-9));
    expect(overall['strictJsonValidRate'], 0.5);
    final latency = report['latency'] as Map;
    expect((latency['timeToFirstTokenMs'] as Map)['n'], 28);
    expect((latency['imageEncodeMs'] as Map)['median'], isNull);
    final byMode = latency['byMode'] as Map;
    expect(byMode.keys, ['text', 'vision']);
    expect(((byMode['text'] as Map)['timeToFirstTokenMs'] as Map)['median'], 100.0);
    expect(((byMode['vision'] as Map)['timeToFirstTokenMs'] as Map)['median'], 300.0);
    expect(((byMode['vision'] as Map)['promptEvalMs'] as Map)['n'], 0);
    expect(File(p.join(tmp.path, 'partial', 'report.md')).readAsStringSync(), contains('| vision: time to first token (ms) | 14 | 300 | 300 |'));
    expect(File(p.join(tmp.path, 'partial', 'report.md')).readAsStringSync(), contains('| n/a | n/a |'));
  });

  test('a later line for the same document replaces an earlier one', () {
    final records = [for (final l in File(oracle()).readAsLinesSync()) jsonDecode(l) as Map<String, dynamic>];
    final id = records[3]['docId'];
    final path = p.join(tmp.path, 'resumed.jsonl');
    File(path).writeAsStringSync([
      {...records[3], 'error': 'Exception: first attempt', 'predictedResources': <Object>[]},
      ...records,
    ].map(jsonEncode).join('\n'));
    final report = runScore(
        datasetPath: dataset, predictionsPath: path, outDir: p.join(tmp.path, 'resumed'), seed: 1, samples: 100);
    final doc = (report['documents'] as List).cast<Map>().firstWhere((d) => d['docId'] == id);
    expect(doc['status'], 'ok');
    expect(doc['f1'], 1.0);
    expect((report['counts'] as Map)['errors'], 0);
  });

  test('compare pairs only documents present in both runs', () {
    final records = [for (final l in File(oracle()).readAsLinesSync()) jsonDecode(l) as Map<String, dynamic>];
    final dropped = records[5]['docId'] as String;
    final bPath = p.join(tmp.path, 'b-partial.jsonl');
    File(bPath).writeAsStringSync([
      for (final r in records)
        if (r['docId'] != dropped) r,
      {...records[0], 'docId': 'not-in-dataset'},
    ].map(jsonEncode).join('\n'));
    final c = runCompare(
        datasetPath: dataset, aPath: oracle(), bPath: bPath, outDir: p.join(tmp.path, 'cmp-partial'), seed: 5, samples: 200);
    expect(c['sharedDocs'], 15);
    expect(c['onlyInA'], [dropped]);
    expect(c['onlyInB'], isEmpty);
    expect((c['overall'] as Map)['docs'], 15);
  });

  test('compare is deterministic for a seed; identical runs differ by 0 with CI [0, 0]', () {
    final a = p.join(tmp.path, 'cmp1');
    final b = p.join(tmp.path, 'cmp2');
    runCompare(datasetPath: dataset, aPath: oracle(), bPath: oracle(), outDir: a, seed: 99, samples: 1000);
    runCompare(datasetPath: dataset, aPath: oracle(), bPath: oracle(), outDir: b, seed: 99, samples: 1000);
    final ja = File(p.join(a, 'compare.json')).readAsStringSync();
    expect(File(p.join(b, 'compare.json')).readAsStringSync(), ja);
    expect(File(p.join(b, 'compare.md')).readAsStringSync(), File(p.join(a, 'compare.md')).readAsStringSync());
    final overall = (jsonDecode(ja) as Map)['overall'] as Map;
    expect(overall['docs'], 16);
    expect(overall['diff'], {'mean': 0.0, 'lo': 0.0, 'hi': 0.0});
    expect(overall['pDiffLeq0'], 1.0);
  });

  test('bootstrap is deterministic and seed-dependent', () {
    final values = {
      'f1': [0.1, 0.5, 0.9, 0.7, 0.3, 0.8],
    };
    final x = bootstrapMeans(values, samples: 2000, seed: 3, label: 'g');
    final y = bootstrapMeans(values, samples: 2000, seed: 3, label: 'g');
    final z = bootstrapMeans(values, samples: 2000, seed: 4, label: 'g');
    expect(x['f1']!.toJson(), y['f1']!.toJson());
    expect(x['f1']!.mean, closeTo(3.3 / 6, 1e-12));
    expect(x['f1']!.lo, lessThan(x['f1']!.mean));
    expect(x['f1']!.hi, greaterThan(x['f1']!.mean));
    expect(z['f1']!.toJson(), isNot(x['f1']!.toJson()));

    final same = pairedBootstrap(values['f1']!, values['f1']!, samples: 2000, seed: 3, label: 'p');
    expect(same.diff.toJson(), {'mean': 0.0, 'lo': 0.0, 'hi': 0.0});
    final better = pairedBootstrap(values['f1']!, [for (final v in values['f1']!) v + 0.1],
        samples: 2000, seed: 3, label: 'p');
    expect(better.diff.mean, closeTo(0.1, 1e-12));
    expect(better.pDiffLeq0, 0);
  });

  test('the CLI exits non-zero with a message on bad input', () async {
    expect(await bench.run(['score', '--dataset', p.join(tmp.path, 'nope'), '--predictions', oracle(), '--out', tmp.path]), 1);
    expect(await bench.run(['score', '--dataset', dataset, '--predictions', p.join(tmp.path, 'nope.jsonl'), '--out', tmp.path]), 1);
    expect(await bench.run(['generate', '--out', p.join(tmp.path, 'x'), '--langs', 'fr']), 1);
    expect(await bench.run(['generate', '--out', p.join(tmp.path, 'x'), '--langs', ',']), 1);
    expect(await bench.run(['generate', '--out', p.join(tmp.path, 'x'), '--langs', 'en,en']), 1);
    expect(await bench.run(['generate', '--out', p.join(tmp.path, 'x'), '--families', '']), 1);
    expect(await bench.run(['generate', '--out', p.join(tmp.path, 'x'), '--families', 'lab_report,lab_report']), 1);
    // A non-empty --out is refused before anything is written.
    final before = Directory(dataset).listSync(recursive: true).length;
    expect(await bench.run(['generate', '--out', dataset, '--per-cell', '1']), 1);
    expect(Directory(dataset).listSync(recursive: true).length, before);
    expect(await bench.run(['frobnicate']), 64);
    expect(Directory(p.join(tmp.path, 'x')).existsSync(), isFalse);
  });
}
