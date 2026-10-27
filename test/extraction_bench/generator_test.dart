import 'dart:convert';
import 'dart:io';

import 'package:fhir_r4/fhir_r4.dart' as fhir;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../tool/extraction_bench/src/codes.dart';
import '../../tool/extraction_bench/src/comparators.dart';
import '../../tool/extraction_bench/src/fields.dart';
import '../../tool/extraction_bench/src/formats.dart';
import '../../tool/extraction_bench/src/generator.dart';

List<File> _files(Directory dir) => dir.listSync(recursive: true).whereType<File>().toList()
  ..sort((a, b) => a.path.compareTo(b.path));

String _collapse(String s) => s.replaceAll(RegExp(r'\s+'), ' ');

/// How [value] of [spec] appears on a page in [lang].
List<String> _printedForms(FieldSpec spec, Object value, String lang) => switch (spec.kind) {
      FieldKind.text || FieldKind.identifier => [value as String],
      FieldKind.exact => [
          switch (spec.key) {
            'gender' => genderLabels[value]!.of(lang),
            'category' => allergyCategoryLabels[value]!.of(lang),
            _ => value as String,
          },
        ],
      FieldKind.date => [formatDate(value as String, lang)],
      FieldKind.set => [...(value as List<String>)],
      FieldKind.quantity => () {
          final q = value as QuantityValue;
          return ['${formatDecimal(q.value!, lang)} ${q.unit}'];
        }(),
      FieldKind.concept => [(value as ConceptValue).texts.first],
    };

void main() {
  final fonts = BenchFonts.load(BenchFonts.defaultDir);

  test('generate --seed 7 --per-cell 2 is byte-identical across runs, 16 valid Bundles', () async {
    final tmp = Directory.systemTemp.createTempSync('bench_gen_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    const options = GeneratorOptions(seed: 7, perCell: 2);
    final a = p.join(tmp.path, 'a');
    final b = p.join(tmp.path, 'b');
    await generateDataset(a, options, fonts);
    await generateDataset(b, options, fonts);

    final filesA = _files(Directory(a));
    final filesB = _files(Directory(b));
    expect(filesA.map((f) => p.relative(f.path, from: a)), filesB.map((f) => p.relative(f.path, from: b)));
    for (var i = 0; i < filesA.length; i++) {
      expect(filesA[i].readAsBytesSync(), filesB[i].readAsBytesSync(), reason: filesA[i].path);
    }

    final golds = filesA.where((f) => p.basename(f.path) == 'gold.json').toList();
    expect(golds, hasLength(16));
    expect(filesA.where((f) => p.basename(f.path) == 'document.pdf'), hasLength(16));
    for (final g in golds) {
      final bundle = fhir.Bundle.fromJson(jsonDecode(g.readAsStringSync()) as Map<String, dynamic>);
      expect(bundle.type.valueString, 'collection');
      expect(bundle.entry, isNotEmpty);
    }
    final metas = filesA.where((f) => p.basename(f.path) == 'meta.json').map(
          (f) => jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
        );
    expect({for (final m in metas) m['lang']}, benchLangs.toSet());
    expect({for (final m in metas) m['family']}, defaultFamilies.toSet());
  });

  test('a different seed gives different documents', () {
    final a = buildDocuments(const GeneratorOptions(seed: 7, perCell: 1));
    final b = buildDocuments(const GeneratorOptions(seed: 8, perCell: 1));
    expect(jsonEncode(a.first.gold), isNot(jsonEncode(b.first.gold)));
  });

  test('every scored gold value is printed on its page in its localized form', () async {
    final docs = buildDocuments(const GeneratorOptions(seed: 7, perCell: 4));
    var checked = 0;
    for (final doc in docs) {
      final text = _collapse((await renderDocument(doc, fonts)).text);
      for (final resource in doc.goldResources) {
        for (final spec in fieldSpecs[resource['resourceType']] ?? const <FieldSpec>[]) {
          final value = extractField(resource, spec);
          if (value == null) continue;
          for (final form in _printedForms(spec, value, doc.meta.lang)) {
            checked++;
            expect(text, contains(_collapse(form)),
                reason: '${doc.meta.docId} ${resource['resourceType']}.${spec.key}');
          }
        }
      }
      if (doc.meta.lang != 'en') {
        // Decimal values use a comma outside English.
        expect(text, isNot(matches(RegExp(r'\b\d+\.\d+ (g/d|mg|mmol|%|°C|x10|10\^)'))), reason: doc.meta.docId);
      }
    }
    expect(checked, greaterThan(500));
  });

  test('lab_report_long spans pages, repeats its letterhead per page and prints every scored value', () async {
    final docs = buildDocuments(const GeneratorOptions(seed: 7, perCell: 2, families: ['lab_report_long']));
    expect(docs.map((d) => d.meta.docId), contains('ro-labl-001'));
    for (final doc in docs) {
      final rendered = await renderDocument(doc, fonts);
      // The renderer prints the footer once per page.
      final pages = rendered.lines.where((l) => l == doc.footer).length;
      final orgName = (doc.pageHeader.first as HeadingBlock).text;
      expect(pages, greaterThanOrEqualTo(2), reason: doc.meta.docId);
      expect(rendered.lines.where((l) => l == orgName).length, pages, reason: doc.meta.docId);
      expect(doc.goldResources.where((r) => r['resourceType'] == 'Observation').length, greaterThanOrEqualTo(16));

      final text = _collapse(rendered.text);
      for (final resource in doc.goldResources) {
        for (final spec in fieldSpecs[resource['resourceType']] ?? const <FieldSpec>[]) {
          final value = extractField(resource, spec);
          if (value == null) continue;
          for (final form in _printedForms(spec, value, doc.meta.lang)) {
            expect(text, contains(_collapse(form)), reason: '${doc.meta.docId} ${resource['resourceType']}.${spec.key}');
          }
        }
      }
    }
  });

  test('a missing glyph fails before anything is written', () async {
    final tmp = Directory.systemTemp.createTempSync('bench_glyph_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final out = p.join(tmp.path, 'dataset');
    await expectLater(
      generateDataset(out, const GeneratorOptions(seed: 1, perCell: 1, footerNote: 'Snowman ☃'), fonts),
      throwsA(isA<MissingGlyphException>().having((e) => e.toString(), 'message', contains('☃'))),
    );
    expect(Directory(out).existsSync(), isFalse);
  });
}
