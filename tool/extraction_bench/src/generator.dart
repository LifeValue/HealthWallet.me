/// Seeded synthetic medical documents with exact FHIR R4 ground truth.
///
/// Each document is built twice from the same random draws: once as the gold
/// Bundle and once as the lines printed on the page, so the gold is by
/// construction what the page shows.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';

import 'codes.dart';
import 'dataset.dart' show BenchInputException;
import 'formats.dart';
import 'rng.dart';

const generatorVersion = '1.0.0';
const benchFamilies = ['lab_report', 'discharge_letter', 'lab_report_long'];

/// The families `generate` writes unless `--families` says otherwise.
/// `lab_report_long` (opt-in) is a lab report of 16+ tests with age and sex
/// reference brackets over several pages, the letterhead and patient block
/// printed on every page.
const defaultFamilies = ['lab_report', 'discharge_letter'];
const benchDegradations = ['clean', 'scan', 'photo'];

class GeneratorOptions {
  const GeneratorOptions({
    required this.seed,
    this.perCell = 10,
    this.langs = benchLangs,
    this.families = defaultFamilies,
    this.footerNote,
  });

  final int seed;

  /// Documents per (language, family) cell.
  final int perCell;
  final List<String> langs;
  final List<String> families;

  /// Replaces the default footer text printed on every page.
  final String? footerNote;
}

class DocMeta {
  const DocMeta({
    required this.docId,
    required this.split,
    required this.lang,
    required this.family,
    required this.degradation,
    required this.seed,
    required this.generatorVersion,
  });

  factory DocMeta.fromJson(Map<String, dynamic> json) => DocMeta(
        docId: json['docId'] as String,
        split: json['split'] as String? ?? 'unknown',
        lang: json['lang'] as String? ?? 'unknown',
        family: json['family'] as String? ?? 'unknown',
        degradation: json['degradation'] as String? ?? 'clean',
        seed: (json['seed'] as num?)?.toInt() ?? 0,
        generatorVersion: json['generatorVersion'] as String? ?? '',
      );

  final String docId;
  final String split;
  final String lang;
  final String family;
  final String degradation;
  final int seed;
  final String generatorVersion;

  Map<String, dynamic> toJson() => {
        'docId': docId,
        'split': split,
        'lang': lang,
        'family': family,
        'degradation': degradation,
        'seed': seed,
        'generatorVersion': generatorVersion,
      };
}

// ---------------------------------------------------------------------------
// Page content
// ---------------------------------------------------------------------------

sealed class Block {
  const Block();

  /// Every string this block prints.
  Iterable<String> get texts;
}

class HeadingBlock extends Block {
  const HeadingBlock(this.text, {this.size = 16});
  final String text;
  final double size;
  @override
  Iterable<String> get texts => [text];
}

/// Wrapped text.
class ParagraphBlock extends Block {
  const ParagraphBlock(this.text, {this.bold = false, this.size = 10, this.indent = 0});
  final String text;
  final bool bold;
  final double size;
  final double indent;
  @override
  Iterable<String> get texts => [text];
}

/// One line of cells at fixed column offsets (fractions of the text width).
class RowBlock extends Block {
  const RowBlock(this.cells, this.columns, {this.bold = false, this.size = 9.5});
  final List<String> cells;
  final List<double> columns;
  final bool bold;
  final double size;
  @override
  Iterable<String> get texts => cells;
}

class RuleBlock extends Block {
  const RuleBlock();
  @override
  Iterable<String> get texts => const [];
}

class SpacerBlock extends Block {
  const SpacerBlock(this.height);
  final double height;
  @override
  Iterable<String> get texts => const [];
}

class SyntheticDoc {
  SyntheticDoc(this.meta, this.gold, this.blocks, this.footer, {this.pageHeader = const []});

  final DocMeta meta;

  /// FHIR R4 Bundle, type collection.
  final Map<String, dynamic> gold;
  final List<Block> blocks;
  final String footer;

  /// Printed at the top of every page, before [blocks] continue.
  final List<Block> pageHeader;

  List<Map<String, dynamic>> get goldResources => [
        for (final e in gold['entry'] as List)
          (e as Map<String, dynamic>)['resource'] as Map<String, dynamic>,
      ];

  Iterable<String> get allTexts sync* {
    for (final b in [...pageHeader, ...blocks]) {
      yield* b.texts;
    }
    yield footer;
  }
}

class RenderedDoc {
  RenderedDoc(this.lines, this.pdf);

  /// The text of every printed line, in page order.
  final List<String> lines;
  final Uint8List pdf;

  String get text => lines.join('\n');
}

class MissingGlyphException implements Exception {
  MissingGlyphException(this.char, this.docId, this.fontName);
  final String char;
  final String docId;
  final String fontName;

  @override
  String toString() {
    final code = char.runes.first.toRadixString(16).toUpperCase().padLeft(4, '0');
    return 'Font $fontName has no glyph for "$char" (U+$code), needed by $docId';
  }
}

class BenchFonts {
  BenchFonts(this.regular, this.bold)
      : _regularParser = TtfParser(ByteData.sublistView(regular)),
        _boldParser = TtfParser(ByteData.sublistView(bold));

  /// Loads `Matter-Regular.ttf` and `Matter-Bold.ttf` from [dir].
  factory BenchFonts.load(String dir) => BenchFonts(
        File(p.join(dir, 'Matter-Regular.ttf')).readAsBytesSync(),
        File(p.join(dir, 'Matter-Bold.ttf')).readAsBytesSync(),
      );

  static const defaultDir = 'assets/font/matter-font';

  final Uint8List regular;
  final Uint8List bold;
  final TtfParser _regularParser;
  final TtfParser _boldParser;

  /// Throws [MissingGlyphException] for the first character of [text] that
  /// either font lacks.
  void checkText(String text, String docId) {
    for (final rune in text.runes) {
      if (rune == 0x20 || rune == 0x0A) continue;
      for (final parser in [_regularParser, _boldParser]) {
        if (!parser.charToGlyphIndexMap.containsKey(rune)) {
          throw MissingGlyphException(String.fromCharCode(rune), docId, parser.fontName);
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Building documents
// ---------------------------------------------------------------------------

String _fhirDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _shortFamily(String family) => switch (family) {
      'lab_report' => 'lab',
      'discharge_letter' => 'dis',
      'lab_report_long' => 'labl',
      _ => family,
    };

/// All documents for [options], in a fixed order.
List<SyntheticDoc> buildDocuments(GeneratorOptions options) {
  for (final lang in options.langs) {
    if (!benchLangs.contains(lang)) {
      throw ArgumentError('Unknown language "$lang"; expected one of ${benchLangs.join(', ')}');
    }
  }
  for (final family in options.families) {
    if (!benchFamilies.contains(family)) {
      throw ArgumentError('Unknown family "$family"; expected one of ${benchFamilies.join(', ')}');
    }
  }
  final docs = <SyntheticDoc>[];
  for (final lang in options.langs) {
    for (final family in options.families) {
      for (var i = 1; i <= options.perCell; i++) {
        final docId = '$lang-${_shortFamily(family)}-${i.toString().padLeft(3, '0')}';
        final docSeed = fnv1a32('${options.seed}/$docId');
        final rng = BenchRng(docSeed);
        final meta = DocMeta(
          docId: docId,
          split: 'synthetic',
          lang: lang,
          family: family,
          degradation: rng.pick(benchDegradations),
          seed: docSeed,
          generatorVersion: generatorVersion,
        );
        final footer = '${options.footerNote ?? labels['footer']!.of(lang)} - $docId';
        final builder = _DocBuilder(meta, rng);
        docs.add(switch (family) {
          'lab_report' => builder.labReport(footer),
          'lab_report_long' => builder.labReport(footer, long: true),
          _ => builder.dischargeLetter(footer),
        });
      }
    }
  }
  return docs;
}

class _Person {
  _Person(this.given, this.family, this.gender);
  final List<String> given;
  final String family;
  final String gender;
  String get display => '${given.join(' ')} $family';
}

class _DocBuilder {
  _DocBuilder(this.meta, this.rng);

  final DocMeta meta;
  final BenchRng rng;
  final _entries = <Map<String, dynamic>>[];

  String get lang => meta.lang;
  String l(String key) => labels[key]!.of(lang);

  String _ref(Map<String, dynamic> resource) => 'urn:uuid:${resource['id']}';

  Map<String, dynamic> _add(Map<String, dynamic> resource) {
    _entries.add({'fullUrl': _ref(resource), 'resource': resource});
    return resource;
  }

  Map<String, dynamic> _bundle() => {
        'resourceType': 'Bundle',
        'id': rng.uuid(),
        'type': 'collection',
        'entry': _entries,
      };

  Map<String, dynamic> _concept(List<Code> codings, String text, {List<Code> alternatives = const []}) => {
        if (alternatives.isNotEmpty)
          'extension': [
            for (final a in alternatives) {'url': alternativeCodingUrl, 'valueCoding': a.toJson()},
          ],
        if (codings.isNotEmpty) 'coding': [for (final c in codings) c.toJson()],
        'text': text,
      };

  _Person _person() {
    final pool = namePools[lang]!;
    final gender = rng.chance(0.5) ? 'male' : 'female';
    final givenPool = gender == 'male' ? pool.male : pool.female;
    final given = rng.chance(0.25) ? rng.sample(givenPool, 2) : [rng.pick(givenPool)];
    final family = pool.doubleSurname ? rng.sample(pool.family, 2).join(' ') : rng.pick(pool.family);
    return _Person(given, family, gender);
  }

  DateTime _date(DateTime from, int maxDays) => from.add(Duration(days: rng.nextInt(maxDays + 1)));

  ({Map<String, dynamic> resource, List<Block> blocks}) _patient() {
    final person = _person();
    final birth = DateTime.utc(rng.intBetween(1942, 2004), rng.intBetween(1, 12), rng.intBetween(1, 28));
    final id = randomIdentifier(lang, rng, birthDate: birth, gender: person.gender);
    final resource = _add({
      'resourceType': 'Patient',
      'id': rng.uuid(),
      'identifier': [
        {
          'type': {
            'coding': [
              {'system': v20203System, 'code': id.typeCode},
            ],
            'text': id.label,
          },
          'system': id.system,
          'value': id.value,
        },
      ],
      'name': [
        {'family': person.family, 'given': person.given},
      ],
      'gender': person.gender,
      'birthDate': _fhirDate(birth),
    });
    const cols = [0.0, 0.62];
    return (
      resource: resource,
      blocks: [
        RowBlock(['${l('patient')}: ${person.display}', '${l('sex')}: ${genderLabels[person.gender]!.of(lang)}'], cols, size: 10),
        RowBlock(['${l('dob')}: ${formatDate(_fhirDate(birth), lang)}', '${id.label}: ${id.value}'], cols, size: 10),
      ],
    );
  }

  Map<String, dynamic> _organization(String name, String address, String phone) => _add({
        'resourceType': 'Organization',
        'id': rng.uuid(),
        'name': name,
        'telecom': [
          {'system': 'phone', 'value': phone},
        ],
        'address': [
          {'text': address},
        ],
      });

  ({Map<String, dynamic> resource, String line}) _practitioner(String qualification) {
    final person = _person();
    final prefix = lang == 'es' && person.gender == 'female' ? 'Dra.' : practitionerPrefix.of(lang);
    final text = '$prefix ${person.display}';
    final license = randomLicense(lang, rng);
    final resource = _add({
      'resourceType': 'Practitioner',
      'id': rng.uuid(),
      'identifier': [
        {'value': license},
      ],
      'name': [
        {
          'text': text,
          'family': person.family,
          'given': person.given,
          'prefix': [prefix],
        },
      ],
      'qualification': [
        {
          'code': {'text': qualification},
        },
      ],
    });
    return (resource: resource, line: '${l('physician')}: $text | $qualification | ${l('license')} $license');
  }

  List<Block> _header(String orgName, String address, String phone, String title) => [
        HeadingBlock(orgName, size: 14),
        ParagraphBlock('$address | ${l('phone')} $phone', size: 9),
        const SpacerBlock(10),
        HeadingBlock(title),
        const SpacerBlock(4),
      ];

  // ------------------------------------------------------------------ lab --

  /// Age and sex reference brackets around [test]'s range, printed under its
  /// row in a long report, as many labs do.
  List<Block> _rangeBrackets(LabTest test, String unit) {
    String r(double f1, double f2) =>
        '${formatDecimal(roundTo(test.low * f1, test.decimals), lang)} - ${formatDecimal(roundTo(test.high * f2, test.decimals), lang)} $unit';
    return [
      for (final line in [
        '${l('men')}: ${r(rng.doubleBetween(0.95, 1.1), rng.doubleBetween(0.95, 1.1))}',
        '${l('women')}: ${r(rng.doubleBetween(0.8, 0.95), rng.doubleBetween(0.8, 0.95))}',
        '${l('children')} 1-5 ${l('years')}: ${r(rng.doubleBetween(0.5, 0.8), rng.doubleBetween(0.6, 0.9))}',
        '${l('children')} 6-12 ${l('years')}: ${r(rng.doubleBetween(0.6, 0.9), rng.doubleBetween(0.7, 0.95))}',
      ])
        ParagraphBlock(line, size: 8, indent: 0.70 * _Renderer._width),
    ];
  }

  SyntheticDoc labReport(String footer, {bool long = false}) {
    final orgName = rng.pick(organizationNames[lang]!.$2);
    final address = randomAddress(lang, rng);
    final phone = randomPhone(lang, rng);
    final title = l('labReportTitle');
    final reportDate = _fhirDate(_date(DateTime.utc(2023, 1, 1), 900));

    final patient = _patient();
    final org = _organization(orgName, address, phone);
    final practitioner = _practitioner(labMedicine.of(lang));

    final count = long ? rng.intBetween(16, labTests.length) : rng.intBetween(6, 12);
    final tests = rng.sample(labTests, count);
    final observations = <Map<String, dynamic>>[];
    final rows = <Block>[];
    final elevated = <String>[];
    final decreased = <String>[];
    const cols = [0.0, 0.40, 0.54, 0.70, 0.93];
    final tableHeader = RowBlock([l('test'), l('result'), l('unit'), l('range'), l('flag')], cols, bold: true);
    if (!long) rows.add(tableHeader);
    for (final test in tests) {
      final roll = rng.nextDouble();
      double value;
      String? flag;
      if (roll < 0.15) {
        value = test.high * rng.doubleBetween(1.1, 1.6);
        flag = 'H';
      } else if (roll < 0.25 && test.low > 0) {
        value = test.low * rng.doubleBetween(0.55, 0.9);
        flag = 'L';
      } else {
        value = rng.doubleBetween(test.low, test.high);
      }
      value = roundTo(value, test.decimals);
      if (flag == 'H' && value <= test.high) flag = null;
      if (flag == 'L' && value >= test.low) flag = null;
      final name = test.name.of(lang);
      if (flag == 'H') elevated.add(name);
      if (flag == 'L') decreased.add(name);
      final unit = test.printUnit.of(lang);
      final range = '${formatDecimal(test.low, lang)} - ${formatDecimal(test.high, lang)}';
      Map<String, dynamic> qty(num v) => {'value': v, 'unit': unit, 'system': ucumSystem, 'code': test.ucum};
      observations.add({
        'resourceType': 'Observation',
        'id': rng.uuid(),
        'status': 'final',
        'category': [
          {
            'coding': [
              {'system': 'http://terminology.hl7.org/CodeSystem/observation-category', 'code': 'laboratory'},
            ],
          },
        ],
        'code': _concept([test.code], name, alternatives: test.alternatives),
        'subject': {'reference': _ref(patient.resource)},
        'effectiveDateTime': reportDate,
        'valueQuantity': qty(value),
        if (flag != null)
          'interpretation': [
            {
              'coding': [
                {'system': 'http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation', 'code': flag},
              ],
            },
          ],
        'referenceRange': [
          {'low': qty(test.low), 'high': qty(test.high), 'text': range},
        ],
      });
      rows.add(RowBlock([name, formatDecimal(value, lang), unit, range, flag ?? ''], cols));
      if (long) rows.addAll(_rangeBrackets(test, unit));
    }

    final conclusion = [
      if (elevated.isNotEmpty) '${l('elevated')}: ${elevated.join(', ')}.',
      if (decreased.isNotEmpty) '${l('decreased')}: ${decreased.join(', ')}.',
      if (elevated.isEmpty && decreased.isEmpty) l('allNormal'),
    ].join(' ');

    final report = {
      'resourceType': 'DiagnosticReport',
      'id': rng.uuid(),
      'status': 'final',
      'code': _concept([labReportCode], title),
      'subject': {'reference': _ref(patient.resource)},
      'effectiveDateTime': reportDate,
      'performer': [
        {'reference': _ref(org)},
      ],
      'resultsInterpreter': [
        {'reference': _ref(practitioner.resource)},
      ],
      'result': [
        for (final o in observations) {'reference': _ref(o)},
      ],
      'conclusion': conclusion,
    };
    _add(report);
    observations.forEach(_add);

    if (long) {
      return SyntheticDoc(
        meta,
        _bundle(),
        [
          ...rows,
          const RuleBlock(),
          const SpacerBlock(6),
          ParagraphBlock('${l('conclusion')}: $conclusion'),
          ParagraphBlock(practitioner.line),
        ],
        footer,
        pageHeader: [
          ..._header(orgName, address, phone, title),
          ...patient.blocks,
          RowBlock(['${l('reportDate')}: ${formatDate(reportDate, lang)}'], const [0.0], size: 10),
          const SpacerBlock(6),
          const RuleBlock(),
          tableHeader,
        ],
      );
    }

    final blocks = <Block>[
      ..._header(orgName, address, phone, title),
      ...patient.blocks,
      RowBlock(['${l('reportDate')}: ${formatDate(reportDate, lang)}'], const [0.0], size: 10),
      ParagraphBlock(practitioner.line),
      const SpacerBlock(6),
      const RuleBlock(),
      ...rows,
      const RuleBlock(),
      const SpacerBlock(6),
      ParagraphBlock('${l('conclusion')}: $conclusion'),
    ];
    return SyntheticDoc(meta, _bundle(), blocks, footer);
  }

  // ------------------------------------------------------------ discharge --

  ({String fhir, String printed}) _onset(DateTime admission, bool acute) {
    if (acute) {
      final d = _fhirDate(admission);
      return (fhir: d, printed: formatDate(d, lang));
    }
    final onset = admission.subtract(Duration(days: rng.intBetween(60, 3650)));
    final roll = rng.nextDouble();
    final full = _fhirDate(onset);
    final fhir = roll < 0.4
        ? full
        : roll < 0.7
            ? full.substring(0, 7)
            : full.substring(0, 4);
    return (fhir: fhir, printed: formatDate(fhir, lang));
  }

  SyntheticDoc dischargeLetter(String footer) {
    final orgName = rng.pick(organizationNames[lang]!.$1);
    final address = randomAddress(lang, rng);
    final phone = randomPhone(lang, rng);
    final title = l('dischargeTitle');
    final admission = _date(DateTime.utc(2023, 1, 1), 900);
    final discharge = admission.add(Duration(days: rng.intBetween(2, 12)));

    final chosenConditions = rng.sample(conditions, rng.intBetween(1, 3));
    // A randomly chosen diagnosis sets the department.
    final primary = chosenConditions[rng.nextInt(chosenConditions.length)];
    final specialty = specialties[primary.specialty]!;

    final patient = _patient();
    final org = _organization(orgName, address, phone);
    final practitioner = _practitioner(specialty.name.of(lang));

    final encounter = _add({
      'resourceType': 'Encounter',
      'id': rng.uuid(),
      'status': 'finished',
      'class': {
        'system': 'http://terminology.hl7.org/CodeSystem/v3-ActCode',
        'code': 'IMP',
        'display': 'inpatient encounter',
      },
      'type': [
        {'text': title},
      ],
      'serviceType': _concept([specialty.code], specialty.name.of(lang)),
      'subject': {'reference': _ref(patient.resource)},
      'participant': [
        {
          'individual': {'reference': _ref(practitioner.resource)},
        },
      ],
      'period': {'start': _fhirDate(admission), 'end': _fhirDate(discharge)},
      'serviceProvider': {'reference': _ref(org)},
    });

    Map<String, dynamic> subject() => {'reference': _ref(patient.resource)};
    Map<String, dynamic> enc() => {'reference': _ref(encounter)};

    final blocks = <Block>[
      ..._header(orgName, address, phone, title),
      RowBlock(['${l('department')}: ${specialty.name.of(lang)}'], const [0.0], size: 10),
      ...patient.blocks,
      RowBlock([
        '${l('admission')}: ${formatDate(_fhirDate(admission), lang)}',
        '${l('discharge')}: ${formatDate(_fhirDate(discharge), lang)}',
      ], const [0.0, 0.62], size: 10),
      const SpacerBlock(6),
      ParagraphBlock(l('diagnoses'), bold: true, size: 11),
    ];

    var index = 1;
    for (final c in chosenConditions) {
      final onset = _onset(admission, identical(c, primary) && rng.chance(0.5));
      final name = c.name.of(lang);
      _add({
        'resourceType': 'Condition',
        'id': rng.uuid(),
        'clinicalStatus': {
          'coding': [
            {'system': 'http://terminology.hl7.org/CodeSystem/condition-clinical', 'code': 'active'},
          ],
        },
        'category': [
          {
            'coding': [
              {'system': 'http://terminology.hl7.org/CodeSystem/condition-category', 'code': 'encounter-diagnosis'},
            ],
          },
        ],
        'code': _concept([c.snomed, c.icd10], name, alternatives: c.alternatives),
        'subject': subject(),
        'encounter': enc(),
        'onsetDateTime': onset.fhir,
      });
      blocks.add(ParagraphBlock('$index. $name (ICD-10: ${c.icd10.code}) - ${l('since')} ${onset.printed}', indent: 10));
      index++;
    }

    final vitals = rng.sample(vitalSigns, rng.intBetween(2, 4));
    blocks
      ..add(const SpacerBlock(4))
      ..add(ParagraphBlock(l('vitals'), bold: true, size: 11));
    for (final v in vitals) {
      final value = roundTo(rng.doubleBetween(v.low, v.high), v.decimals);
      final unit = v.printUnit.of(lang);
      _add({
        'resourceType': 'Observation',
        'id': rng.uuid(),
        'status': 'final',
        'category': [
          {
            'coding': [
              {'system': 'http://terminology.hl7.org/CodeSystem/observation-category', 'code': 'vital-signs'},
            ],
          },
        ],
        'code': _concept(v.codes, v.name.of(lang)),
        'subject': subject(),
        'encounter': enc(),
        'effectiveDateTime': _fhirDate(admission),
        'valueQuantity': {'value': value, 'unit': unit, 'system': ucumSystem, 'code': v.ucum},
      });
      blocks.add(ParagraphBlock('${v.name.of(lang)}: ${formatDecimal(value, lang)} $unit', indent: 10));
    }

    final meds = rng.sample(medications, rng.intBetween(2, 4));
    blocks
      ..add(const SpacerBlock(4))
      ..add(ParagraphBlock(l('medication'), bold: true, size: 11));
    for (final m in meds) {
      final strength = rng.pick(m.strengths);
      final text = '${m.name.of(lang)} ${formatDecimal(strength.value, lang)} ${strength.unit}';
      final dosage = rng.pick(dosagePatterns[m.form]!).of(lang);
      _add({
        'resourceType': 'MedicationStatement',
        'id': rng.uuid(),
        'status': 'active',
        'medicationCodeableConcept': _concept([m.atc, m.rxnorm], text, alternatives: m.alternatives),
        'subject': subject(),
        'context': enc(),
        'dosage': [
          {'text': dosage},
        ],
      });
      blocks.add(ParagraphBlock('- $text: $dosage', indent: 10));
    }

    final allergyDefs = rng.sample(allergens, rng.intBetween(0, 2));
    blocks
      ..add(const SpacerBlock(4))
      ..add(ParagraphBlock(l('allergies'), bold: true, size: 11));
    if (allergyDefs.isEmpty) {
      blocks.add(ParagraphBlock(l('noAllergies'), indent: 10));
    }
    for (final a in allergyDefs) {
      final (mCode, mName) = rng.pick(manifestations);
      _add({
        'resourceType': 'AllergyIntolerance',
        'id': rng.uuid(),
        'clinicalStatus': {
          'coding': [
            {'system': 'http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical', 'code': 'active'},
          ],
        },
        'category': [a.category],
        'code': _concept([a.code], a.name.of(lang)),
        'patient': subject(),
        'encounter': enc(),
        'reaction': [
          {
            'manifestation': [_concept([mCode], mName.of(lang))],
          },
        ],
      });
      blocks.add(ParagraphBlock(
          '- ${a.name.of(lang)} (${allergyCategoryLabels[a.category]!.of(lang)}): ${mName.of(lang)}',
          indent: 10));
    }

    if (rng.chance(0.5)) {
      final (pCode, pName) = rng.pick(procedures);
      final performed = _fhirDate(_date(admission, discharge.difference(admission).inDays));
      _add({
        'resourceType': 'Procedure',
        'id': rng.uuid(),
        'status': 'completed',
        'code': _concept([pCode], pName.of(lang)),
        'subject': subject(),
        'encounter': enc(),
        'performedDateTime': performed,
      });
      blocks
        ..add(const SpacerBlock(4))
        ..add(ParagraphBlock(l('procedures'), bold: true, size: 11))
        ..add(ParagraphBlock('- ${pName.of(lang)} ${l('on')} ${formatDate(performed, lang)}', indent: 10));
    }

    blocks
      ..add(const SpacerBlock(14))
      ..add(ParagraphBlock(practitioner.line));
    return SyntheticDoc(meta, _bundle(), blocks, footer);
  }
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// A PdfDocument whose trailer ID comes from the document seed, so the same
/// seed writes the same bytes.
class _SeededPdfDocument extends PdfDocument {
  _SeededPdfDocument(int seed) : _id = _idFor(seed);

  final Uint8List _id;

  static Uint8List _idFor(int seed) {
    final rng = BenchRng.derive(seed, 'pdf-id');
    final bytes = Uint8List(32);
    for (var i = 0; i < 32; i += 4) {
      final v = rng.nextUint32();
      bytes[i] = v & 0xFF;
      bytes[i + 1] = (v >> 8) & 0xFF;
      bytes[i + 2] = (v >> 16) & 0xFF;
      bytes[i + 3] = (v >> 24) & 0xFF;
    }
    return bytes;
  }

  @override
  Uint8List get documentID => _id;
}

class _Renderer {
  _Renderer(this.doc, BenchFonts fonts) : pdf = _SeededPdfDocument(doc.meta.seed) {
    regular = PdfTtfFont(pdf, ByteData.sublistView(fonts.regular));
    bold = PdfTtfFont(pdf, ByteData.sublistView(fonts.bold));
  }

  static const _margin = 50.0;
  static const _format = PdfPageFormat.a4;
  static double get _width => _format.width - 2 * _margin;

  final SyntheticDoc doc;
  final PdfDocument pdf;
  late final PdfTtfFont regular;
  late final PdfTtfFont bold;
  final lines = <String>[];

  late PdfGraphics _g;
  late double _y;

  void _newPage() {
    final page = PdfPage(pdf, pageFormat: _format);
    _g = page.getGraphics();
    _y = _format.height - _margin;
    _g.setFillColor(PdfColors.grey600);
    _g.drawString(regular, 7, doc.footer, _margin, 28);
    _g.setFillColor(PdfColors.black);
    lines.add(doc.footer);
    doc.pageHeader.forEach(_draw);
  }

  void _ensure(double height) {
    if (_y - height < _margin) _newPage();
  }

  double _textWidth(PdfTtfFont font, double size, String text) =>
      font.stringMetrics(text).advanceWidth * size;

  List<String> _wrap(PdfTtfFont font, double size, String text, double width) {
    final out = <String>[];
    var current = '';
    for (final word in text.split(' ')) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (current.isNotEmpty && _textWidth(font, size, candidate) > width) {
        out.add(current);
        current = word;
      } else {
        current = candidate;
      }
    }
    if (current.isNotEmpty) out.add(current);
    return out;
  }

  void _line(PdfTtfFont font, double size, List<(String, double)> runs) {
    final height = size * 1.45;
    _ensure(height);
    _y -= height;
    for (final (text, x) in runs) {
      if (text.isEmpty) continue;
      _g.drawString(font, size, text, _margin + x, _y);
    }
    lines.add(runs.map((r) => r.$1).where((t) => t.isNotEmpty).join('  '));
  }

  void _draw(Block block) {
    switch (block) {
      case HeadingBlock(:final text, :final size):
        _line(bold, size, [(text, 0)]);
      case ParagraphBlock(:final text, bold: final isBold, :final size, :final indent):
        final font = isBold ? bold : regular;
        for (final part in _wrap(font, size, text, _width - indent)) {
          _line(font, size, [(part, indent)]);
        }
      case RowBlock(:final cells, :final columns, bold: final isBold, :final size):
        _line(isBold ? bold : regular, size, [
          for (var i = 0; i < cells.length; i++) (cells[i], columns[i] * _width),
        ]);
      case RuleBlock():
        _ensure(6);
        _y -= 4;
        _g
          ..setLineWidth(0.5)
          ..drawLine(_margin, _y, _margin + _width, _y)
          ..strokePath();
      case SpacerBlock(:final height):
        _y -= height;
    }
  }

  Future<RenderedDoc> render() async {
    _newPage();
    doc.blocks.forEach(_draw);
    final os = PdfStream();
    await pdf.write(os);
    return RenderedDoc(lines, os.output());
  }
}

/// Lays out [doc] and writes its PDF in memory.
Future<RenderedDoc> renderDocument(SyntheticDoc doc, BenchFonts fonts) =>
    _Renderer(doc, fonts).render();

const _json = JsonEncoder.withIndent('  ');

/// Builds every document, checks every printed character against [fonts],
/// renders them all, and only then writes `<outDir>/synthetic/<docId>/` and
/// `<outDir>/manifest.json`. A missing glyph throws before anything is written.
/// A non-empty [outDir] is refused, so documents of an earlier run can't mix in.
Future<List<SyntheticDoc>> generateDataset(
  String outDir,
  GeneratorOptions options,
  BenchFonts fonts,
) async {
  final out = Directory(outDir);
  if (out.existsSync() && out.listSync().isNotEmpty) {
    throw BenchInputException('Output directory $outDir is not empty; choose a new --out or delete it first');
  }
  final docs = buildDocuments(options);
  for (final doc in docs) {
    for (final text in doc.allTexts) {
      fonts.checkText(text, doc.meta.docId);
    }
  }
  final rendered = <RenderedDoc>[];
  for (final doc in docs) {
    rendered.add(await renderDocument(doc, fonts));
  }

  for (var i = 0; i < docs.length; i++) {
    final doc = docs[i];
    final dir = Directory(p.join(outDir, 'synthetic', doc.meta.docId))..createSync(recursive: true);
    File(p.join(dir.path, 'document.pdf')).writeAsBytesSync(rendered[i].pdf);
    File(p.join(dir.path, 'gold.json')).writeAsStringSync('${_json.convert(doc.gold)}\n');
    File(p.join(dir.path, 'meta.json')).writeAsStringSync('${_json.convert(doc.meta.toJson())}\n');
  }
  final manifest = {
    'generatorVersion': generatorVersion,
    'seed': options.seed,
    'perCell': options.perCell,
    'langs': options.langs,
    'families': options.families,
    'documents': [
      for (final d in docs)
        {...d.meta.toJson(), 'path': 'synthetic/${d.meta.docId}'},
    ],
  };
  File(p.join(outDir, 'manifest.json')).writeAsStringSync('${_json.convert(manifest)}\n');
  return docs;
}
