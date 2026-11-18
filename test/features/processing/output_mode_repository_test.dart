import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_data_source.dart';
import 'package:health_wallet/features/processing/data/model/generation_stats.dart';
import 'package:health_wallet/features/processing/data/model/grammar/gbnf_grammars.dart';
import 'package:health_wallet/features/processing/data/model/prompt_template/draft_prompt.dart';
import 'package:health_wallet/features/processing/data/model/structured_output/extraction_schemas.dart';
import 'package:health_wallet/features/processing/data/repository/ai_extraction_repository.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_condition.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_observation.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';

const _labOcr = '''Laborbefund
Patient: Müller, Anna   Geburtsdatum: 02.04.1960   Versichertennummer: A123456789
Befunddatum: 14.03.2025
Untersuchung Ergebnis Einheit Referenzbereich
Hämoglobin 13,5 g/dl 12 - 16
Leukozyten 6,2 G/l 4 - 10
Dr. med. Klaus Weber, Labor Berlin, Tel. 030 23125123''';

/// A German lab report longer than 800 characters, with a marker after
/// character 800 (the old vision OCR limit).
final _longLabOcr =
    '${_labOcr.padRight(900, ' ')}\nMARKER-AFTER-800 Kreatinin 0,9 mg/dl 0,5 - 1,1';

class _FakeOcr extends Fake implements TextRecognitionService {
  _FakeOcr(this.text);
  final String text;

  @override
  Future<String> recognizeTextFromImage(String imagePath) async => text;
}

class _Call {
  _Call(
    this.kind,
    this.prompt,
    this.maxTokens,
    this.grammar,
    this.responseFormat, [
    this.chatTemplateKwargs,
  ]);
  final String kind;
  final String prompt;
  final int? maxTokens;
  final String? grammar;
  final Map<String, dynamic>? responseFormat;
  final Map<String, dynamic>? chatTemplateKwargs;

  bool get isDraft => grammar == null && responseFormat == null;

  /// Property names of the requested schema's root object.
  Set<String> get schemaKeys =>
      ((((responseFormat!['json_schema'] as Map)['schema']
                  as Map)['properties'])
              as Map)
          .keys
          .cast<String>()
          .toSet();
}

/// Answers each call with the next queued output (a [Exception] is thrown)
/// and records what was asked.
class _FakeDataSource extends Fake implements AiInferenceDataSource {
  _FakeDataSource(this.outputs, {this.promptFamily = PromptFamily.standard});
  final List<Object?> outputs;

  @override
  final PromptFamily promptFamily;

  @override
  int get visionPagesPerBatch => 2;
  final calls = <_Call>[];
  final loads = <({bool withVision, int? contextSize})>[];

  @override
  GenerationStats? get lastGenerationStats => null;

  @override
  Future<void> initModel({
    bool withVision = true,
    int? contextSize,
    int? gpuLayers,
    int? threads,
  }) async => loads.add((withVision: withVision, contextSize: contextSize));

  @override
  Future<void> disposeModel() async {}

  /// Whether the vision projector file is on the device, and whether it
  /// loads with the model.
  bool projectorOnDisk = true;
  bool projectorLoads = true;

  @override
  Future<bool> checkMmprojExistence() async => projectorOnDisk;

  @override
  bool isVisionModelAvailable() =>
      projectorOnDisk && projectorLoads && loads.lastOrNull?.withVision == true;

  @override
  Future<({int availableMB, int requiredMB, bool canProceed})>
  checkMemoryHealth({
    bool withVision = true,
    int? contextSize,
  }) async => (availableMB: -1, requiredMB: 0, canProceed: true);

  Future<String?> _answer(_Call call) async {
    calls.add(call);
    final out = outputs.removeAt(0);
    if (out is Exception) throw out;
    return out as String?;
  }

  @override
  Future<String?> runVisionPrompt({
    required String prompt,
    required List<String> imagePaths,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
  }) => _answer(_Call('vision', prompt, maxTokens, grammar, responseFormat));

  @override
  Future<String?> runTextPrompt({
    required String prompt,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
    Map<String, dynamic>? chatTemplateKwargs,
  }) => _answer(
    _Call(
      'text',
      prompt,
      maxTokens,
      grammar,
      responseFormat,
      chatTemplateKwargs,
    ),
  );
}

class _Repository with AiExtractionRepository {
  _Repository(this.networkDataSource, String ocr)
    : textRecognitionService = _FakeOcr(ocr);

  @override
  final AiInferenceDataSource networkDataSource;

  @override
  final TextRecognitionService textRecognitionService;

  @override
  bool get shouldCancelGeneration => false;

  @override
  Future<void> disposeModel() async {}
}

final _labObject = jsonEncode({
  'observations': [
    {
      'observationName': 'Hämoglobin',
      'value': '13,5',
      'unit': 'g/dl',
      'referenceRange': '12 - 16',
    },
    {
      'observationName': 'Leukozyten',
      'value': '6,2',
      'unit': 'G/l',
      'referenceRange': '4 - 10',
    },
  ],
  'practitioners': [
    {
      'practitionerName': 'Dr. med. Klaus Weber',
      'specialty': '',
      'identifier': '',
    },
  ],
  'organizations': [],
});

final _basicObject = jsonEncode({
  'familyName': 'Müller',
  'givenName': 'Anna',
  'dateOfBirth': '1960-04-02',
  'gender': 'female',
  'patientIdentifier': 'A123456789',
  'identifierLabel': 'KVNR',
  'documentTitle': 'Laborbefund',
  'documentDate': '2025-03-14',
  'conclusion': '',
  'documentCategory': 'lab_report',
});

Future<List<Object>> _remaining(
  _FakeDataSource ds, {
  required ExtractionOutputMode mode,
  bool useVision = false,
  String? category = 'lab_report',
  String ocr = _labOcr,
}) async {
  final events = await _Repository(ds, ocr)
      .processMapRemainingResources(
        const ['page-1.png'],
        documentCategory: category,
        useVision: useVision,
        outputMode: mode,
      )
      .toList();
  return events.last.$1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('grammar mode', () {
    test(
      'every phase sends the JSON-array grammar and no response format',
      () async {
        final ds = _FakeDataSource([
          '[{"resourceType":"Patient","familyName":"Müller","givenName":"Anna","documentCategory":"lab_report"},'
              '{"resourceType":"DiagnosticReport","reportName":"Laborbefund","issuedDate":"2025-03-14"}]',
          '[{"resourceType":"Observation","observationName":"Hämoglobin","value":"13,5","unit":"g/dl"}]',
          '[{"resourceType":"Observation","observationName":"Leukozyten","value":"6,2","unit":"G/l"}]',
          '[{"resourceType":"Encounter","encounterType":"Laborbefund","periodStart":"2025-03-14"}]',
        ]);
        final repo = _Repository(ds, _labOcr);
        final (_, container) = await repo.processMapBasicInfo(const [
          'p.png',
        ], outputMode: ExtractionOutputMode.grammar);
        expect(container, isA<MappingDiagnosticReport>());
        await repo
            .processMapRemainingResources(
              const ['p.png'],
              documentCategory: 'lab_report',
              outputMode: ExtractionOutputMode.grammar,
            )
            .toList();
        await repo
            .processMapRemainingResources(
              const ['p.png'],
              documentCategory: 'lab_report',
              useVision: true,
              outputMode: ExtractionOutputMode.grammar,
            )
            .toList();
        await repo.mapContainerOnly(
          _labOcr,
          outputMode: ExtractionOutputMode.grammar,
        );

        expect(ds.calls.map((c) => c.kind), ['text', 'text', 'vision', 'text']);
        for (final c in ds.calls) {
          expect(c.grammar, GbnfGrammars.jsonArray);
          expect(c.responseFormat, isNull);
        }
      },
    );

    test('lab-report prompts no longer offer Condition; vision gets the full OCR and the few-shot', () async {
      final ds = _FakeDataSource(['[]', '[]']);
      await _remaining(
        ds,
        mode: ExtractionOutputMode.grammar,
        useVision: true,
        ocr: _longLabOcr,
      );
      expect(ds.calls.map((c) => c.kind), ['vision', 'text']);
      final prompt = ds.calls.first.prompt;
      expect(prompt, isNot(contains('"resourceType":"Condition"')));
      expect(prompt, isNot(contains('Conditions =')));
      expect(prompt, contains('MARKER-AFTER-800'));
      expect(prompt, contains('EXAMPLE OUTPUT'));
    });

    test('a lab-report example drawn from a template with Conditions leaves them out', () async {
      // "anatomo-patologic" selects ro/histopathology_report_female.json, whose
      // first resources include Conditions.
      final ds = _FakeDataSource([
        '[{"resourceType":"Observation","observationName":"Hb","value":"13","unit":"g/dL"}]',
      ]);
      await _remaining(
        ds,
        mode: ExtractionOutputMode.grammar,
        ocr: 'Buletin anatomo-patologic\nPacienta: Ionescu Maria\nExamen histopatologic: fragment tisular',
      );
      final prompt = ds.calls.single.prompt;
      expect(prompt, contains('EXAMPLE OUTPUT'));
      expect(
        prompt,
        contains('Serviciul de Anatomie Patologica'),
        reason: 'the histopathology template was picked',
      );
      expect(prompt, isNot(contains('"resourceType":"Condition"')));
    });
  });

  group('schema mode', () {
    test('a lab report phase 2 sends a json_schema without Condition and maps the object', () async {
      final ds = _FakeDataSource([_labObject]);
      final resources = await _remaining(ds, mode: ExtractionOutputMode.schema);

      final call = ds.calls.single;
      expect(call.grammar, isNull);
      expect(call.responseFormat!['type'], 'json_schema');
      expect(call.schemaKeys, {
        'observations',
        'practitioners',
        'organizations',
      });
      expect(jsonEncode(call.responseFormat), isNot(contains('condition')));
      expect(call.prompt, contains('"observations"'));
      expect(call.prompt, isNot(contains('resourceType')));

      expect(
        resources.whereType<MappingObservation>().map(
          (o) => o.observationName.value,
        ),
        containsAll(['Hämoglobin', 'Leukozyten']),
      );
      expect(resources.whereType<MappingCondition>(), isEmpty);
    });

    test(
      'a visit gets the visit arrays, an unknown category the union',
      () async {
        final visit = _FakeDataSource(['{}']);
        await _remaining(
          visit,
          mode: ExtractionOutputMode.schema,
          category: 'visit',
        );
        expect(visit.calls.single.schemaKeys, contains('conditions'));
        expect(visit.calls.single.schemaKeys, isNot(contains('observations')));

        final union = _FakeDataSource(['{}']);
        await _remaining(
          union,
          mode: ExtractionOutputMode.schema,
          category: null,
        );
        expect(
          union.calls.single.schemaKeys,
          ExtractionSchemas.allSections.map((s) => s.key).toSet(),
        );
      },
    );

    test(
      'vision phase 2 gets the full OCR and the example in the object shape',
      () async {
        final ds = _FakeDataSource([_labObject]);
        await _remaining(
          ds,
          mode: ExtractionOutputMode.schema,
          useVision: true,
          ocr: _longLabOcr,
        );
        final prompt = ds.calls.single.prompt;
        expect(prompt, contains('MARKER-AFTER-800'));
        final example = prompt.substring(prompt.indexOf('EXAMPLE OUTPUT'));
        expect(example, contains('"observations":'));
        expect(example, isNot(contains('resourceType')));
      },
    );

    test('vision phase 2 sends the schema too', () async {
      final ds = _FakeDataSource([_labObject]);
      final resources = await _remaining(
        ds,
        mode: ExtractionOutputMode.schema,
        useVision: true,
      );
      expect(ds.calls.single.kind, 'vision');
      expect(ds.calls.single.responseFormat, isNotNull);
      expect(resources, isNotEmpty);
    });

    test('truncated output keeps the complete items; garbage gives no resources and no error', () async {
      final truncated = _labObject.substring(
        0,
        _labObject.indexOf('Leukozyten') + 5,
      );
      // OCR without the cut-off test, so the OCR validator cannot add it back.
      final salvaged = await _remaining(
        _FakeDataSource([truncated]),
        mode: ExtractionOutputMode.schema,
        ocr: 'Laborbefund\nHämoglobin 13,5 g/dl 12 - 16',
      );
      expect(
        salvaged.whereType<MappingObservation>().map(
          (o) => o.observationName.value,
        ),
        ['Hämoglobin'],
      );

      final none = await _remaining(
        _FakeDataSource(['{"observations":[{"obs']),
        mode: ExtractionOutputMode.schema,
      );
      expect(none, isEmpty);
    });

    test(
      'phase 1 maps the object to the patient and a DiagnosticReport',
      () async {
        final ds = _FakeDataSource([_basicObject]);
        final (patient, container) = await _Repository(ds, _labOcr)
            .processMapBasicInfo(const [
              'p.png',
            ], outputMode: ExtractionOutputMode.schema);
        expect(ds.calls.single.schemaKeys, contains('documentCategory'));
        expect(ds.calls.single.grammar, isNull);
        expect(patient.familyName.value, 'Müller');
        expect(patient.identifierLabel, 'KVNR');
        expect(
          (container as MappingDiagnosticReport).reportName.value,
          'Laborbefund',
        );
        // The German document gets German hints whatever the phone's locale.
        expect(
          ds.calls.single.prompt,
          contains('KVNR (Krankenversichertennummer)'),
        );
      },
    );

    test('unparseable phase-1 text output falls back to vision', () async {
      final ds = _FakeDataSource(['{"familyName":"Mü', _basicObject]);
      final (patient, _) = await _Repository(ds, _labOcr).processMapBasicInfo(
        const ['p.png'],
        outputMode: ExtractionOutputMode.schema,
      );
      expect(ds.calls.map((c) => c.kind), ['text', 'vision']);
      expect(ds.calls.last.responseFormat, isNotNull);
      // The vision prompt takes its hints from the document too.
      expect(
        ds.calls.last.prompt,
        contains('KVNR (Krankenversichertennummer)'),
      );
      expect(patient.givenName.value, 'Anna');
    });

    test(
      'a German document without an ID on a Romanian phone is not labelled CNP',
      () async {
        TestWidgetsFlutterBinding.instance.platformDispatcher.localeTestValue =
            const Locale('ro', 'RO');
        addTearDown(
          TestWidgetsFlutterBinding
              .instance
              .platformDispatcher
              .clearLocaleTestValue,
        );
        const ocr =
            'Laborbefund\nPatient: Müller, Anna   Geburtsdatum: 02.04.1960\nBefunddatum: 14.03.2025\n'
            'Untersuchung Ergebnis Einheit Referenzbereich\nHämoglobin 13,5 g/dl 12 - 16\nLeukozyten 6,2 G/l 4 - 10\n'
            'Dr. med. Klaus Weber, Labor Berlin';
        final noId = (jsonDecode(_basicObject) as Map<String, dynamic>)
          ..['patientIdentifier'] = ''
          ..['identifierLabel'] = 'MRN';
        final ds = _FakeDataSource([jsonEncode(noId)]);
        final (patient, _) = await _Repository(ds, ocr).processMapBasicInfo(
          const ['p.png'],
          outputMode: ExtractionOutputMode.schema,
        );
        expect(ds.calls.single.kind, 'text');
        expect(patient.identifierLabel, isNot('CNP'));
        expect(patient.identifierLabel, 'KVNR');
      },
    );

    test('container-only maps the document fields', () async {
      final ds = _FakeDataSource([
        jsonEncode({
          'documentTitle': 'Entlassungsbrief',
          'documentDate': '2025-06-08',
          'conclusion': '',
          'documentCategory': 'visit',
        }),
      ]);
      final container = await _Repository(
        ds,
        _labOcr,
      ).mapContainerOnly(_labOcr, outputMode: ExtractionOutputMode.schema);
      expect(ds.calls.single.schemaKeys, {
        'documentTitle',
        'documentDate',
        'conclusion',
        'documentCategory',
      });
      expect(
        (container as MappingEncounter).encounterType.value,
        'Entlassungsbrief',
      );
    });
  });

  group('schemaDraft mode', () {
    test('an unconstrained draft call precedes the constrained call, whose prompt carries the draft', () async {
      final ds = _FakeDataSource([
        'Hämoglobin 13,5 g/dl (12 - 16)',
        _labObject,
      ]);
      final resources = await _remaining(
        ds,
        mode: ExtractionOutputMode.schemaDraft,
      );

      final [draft, constrained] = ds.calls;
      expect(draft.kind, 'text');
      expect(draft.isDraft, isTrue);
      expect(draft.maxTokens, lessThanOrEqualTo(384));
      expect(constrained.kind, 'text');
      expect(constrained.responseFormat, isNotNull);
      expect(constrained.prompt, contains('Notes from a first reading'));
      expect(constrained.prompt, contains('Hämoglobin 13,5 g/dl (12 - 16)'));
      expect(constrained.prompt, contains('Leukozyten 6,2 G/l'));
      expect(ds.loads.single.contextSize, greaterThanOrEqualTo(4096));
      expect(resources, isNotEmpty);
    });

    test(
      'a failed draft leaves the constrained call without a draft',
      () async {
        final ds = _FakeDataSource([Exception('draft boom'), _labObject]);
        final resources = await _remaining(
          ds,
          mode: ExtractionOutputMode.schemaDraft,
        );
        expect(ds.calls, hasLength(2));
        expect(ds.calls.last.responseFormat, isNotNull);
        expect(
          ds.calls.last.prompt,
          isNot(contains('Notes from a first reading')),
        );
        expect(resources, isNotEmpty);
      },
    );

    test('vision: draft from the image, then a text-only constrained pass, no second fallback', () async {
      final ds = _FakeDataSource(['Hb 13,5', _labObject]);
      final resources = await _remaining(
        ds,
        mode: ExtractionOutputMode.schemaDraft,
        useVision: true,
      );
      expect(ds.calls.map((c) => (c.kind, c.isDraft)), [
        ('vision', true),
        ('text', false),
      ]);
      expect(ds.calls.last.prompt, contains('Hb 13,5'));
      expect(ds.loads.map((l) => l.withVision), [true, false]);
      expect(ds.loads.last.contextSize, greaterThanOrEqualTo(4096));
      expect(resources, isNotEmpty);
    });

    test('phase 1: text draft, then the constrained phase-1 schema', () async {
      final ds = _FakeDataSource(['Name: Müller, Anna', _basicObject]);
      final (patient, _) = await _Repository(ds, _labOcr).processMapBasicInfo(
        const ['p.png'],
        outputMode: ExtractionOutputMode.schemaDraft,
      );
      expect(ds.calls.map((c) => c.isDraft), [true, false]);
      expect(ds.calls.last.schemaKeys, contains('familyName'));
      expect(ds.calls.last.prompt, contains('Name: Müller, Anna'));
      expect(patient.familyName.value, 'Müller');
    });
  });

  group('NuExtract models', () {
    test('NuExtract3 gets the OCR text as the document, its template and instructions, and keeps the schema', () async {
      final ds = _FakeDataSource([
        _basicObject,
      ], promptFamily: PromptFamily.nuExtract3);
      final (patient, container) = await _Repository(ds, _labOcr)
          .processMapBasicInfo(const [
            'p.png',
          ], outputMode: ExtractionOutputMode.schema);
      final call = ds.calls.single;
      expect(call.prompt, _labOcr);
      expect(call.schemaKeys, contains('familyName'));
      final template = jsonDecode(
        call.chatTemplateKwargs!['template'] as String,
      ) as Map<String, dynamic>;
      expect(template['familyName'], 'string');
      expect(template['dateOfBirth'], 'date-time');
      expect(template['documentCategory'], ['visit', 'lab_report']);
      expect(template['gender'], isNot(contains('')));
      expect(
        call.chatTemplateKwargs!['instructions'],
        contains('documentCategory'),
      );
      expect(patient.familyName.value, 'Müller');
      expect(container, isA<MappingDiagnosticReport>());
    });

    test('NuExtract 2.0 gets no instructions; a lab report phase 2 template has no conditions', () async {
      final ds = _FakeDataSource([
        _labObject,
      ], promptFamily: PromptFamily.nuExtract2);
      final resources = await _remaining(
        ds,
        mode: ExtractionOutputMode.schema,
        ocr: _longLabOcr,
      );
      final kwargs = ds.calls.single.chatTemplateKwargs!;
      expect(kwargs.keys, ['template']);
      final template =
          jsonDecode(kwargs['template'] as String) as Map<String, dynamic>;
      expect(template.keys, ['observations', 'practitioners', 'organizations']);
      expect(template['observations'], [
        {
          'observationName': 'string',
          'value': 'string',
          'unit': 'string',
          'referenceRange': 'string',
        },
      ]);
      expect(ds.calls.single.prompt, contains('MARKER-AFTER-800'));
      expect(
        resources.whereType<MappingObservation>().map(
          (o) => o.observationName.value,
        ),
        contains('Hämoglobin'),
      );
    });

    test('grammar and schemaDraft modes keep the standard prompts', () async {
      for (final mode in [
        ExtractionOutputMode.grammar,
        ExtractionOutputMode.schemaDraft,
      ]) {
        final ds = _FakeDataSource([
          'Hb 13,5',
          _labObject,
        ], promptFamily: PromptFamily.nuExtract3);
        if (mode == ExtractionOutputMode.grammar) ds.outputs.removeAt(0);
        await _remaining(ds, mode: mode);
        expect(
          ds.calls.map((c) => c.chatTemplateKwargs),
          everyElement(isNull),
          reason: mode.name,
        );
      }
    });
  });

  test(
    'the draft section is capped, so joined batch drafts fit the text context',
    () {
      expect(
        DraftPrompt.section('x' * 5000).length,
        lessThan(DraftPrompt.maxSectionLength + 200),
      );
    },
  );

  group('without the vision projector', () {
    const encounterOnly =
        '[{"resourceType":"Encounter","encounterType":"Consult",'
        '"periodStart":"2025-03-14"}]';

    test('a text pass that finds no patient is kept, without sending '
        'images', () async {
      final ds = _FakeDataSource([encounterOnly])..projectorOnDisk = false;

      final (patient, container) = await _Repository(ds, _labOcr)
          .processMapBasicInfo(
            const ['p.png'],
            outputMode: ExtractionOutputMode.grammar,
          );

      expect(ds.calls.map((c) => c.kind), ['text']);
      expect(ds.loads.map((l) => l.withVision), [false]);
      expect(patient.isIdentified, isFalse);
      expect(
        (container as MappingEncounter).encounterType.value,
        'Consult',
      );
    });

    test('a page too short for the text pass gives no patient and loads no '
        'model', () async {
      final ds = _FakeDataSource([])..projectorOnDisk = false;

      final (patient, container) = await _Repository(ds, 'Rp.')
          .processMapBasicInfo(
            const ['p.png'],
            outputMode: ExtractionOutputMode.grammar,
          );

      expect(ds.calls, isEmpty);
      expect(ds.loads, isEmpty);
      expect(patient.isIdentified, isFalse);
      expect((container as MappingEncounter).encounterType.value, isEmpty);
    });

    test('a projector that does not load sends no images and keeps the text '
        'result', () async {
      final ds = _FakeDataSource([encounterOnly])..projectorLoads = false;

      final (patient, container) = await _Repository(ds, _labOcr)
          .processMapBasicInfo(
            const ['p.png'],
            outputMode: ExtractionOutputMode.grammar,
          );

      expect(ds.calls.map((c) => c.kind), ['text']);
      expect(ds.loads.map((l) => l.withVision), [false, true]);
      expect(patient.isIdentified, isFalse);
      expect(
        (container as MappingEncounter).encounterType.value,
        'Consult',
      );
    });

    test('phase 2 with Deep Scan reads the pages as text when the projector '
        'does not load', () async {
      final ds = _FakeDataSource(['[]'])..projectorLoads = false;

      await _remaining(
        ds,
        mode: ExtractionOutputMode.grammar,
        useVision: true,
      );

      expect(ds.calls.map((c) => c.kind), ['text']);
      expect(ds.loads.map((l) => l.withVision), [true, false]);
    });
  });
}
