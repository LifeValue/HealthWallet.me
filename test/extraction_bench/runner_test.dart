import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_data_source.dart';
import 'package:health_wallet/features/processing/data/model/generation_stats.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:llamadart/llamadart.dart';
import 'package:path/path.dart' as p;

import '../../integration_test/extraction_bench/document_runner.dart';
import '../../integration_test/extraction_bench/recording_data_source.dart';
import '../../integration_test/extraction_bench/run_record.dart';
import '../../tool/extraction_bench/src/dataset.dart';
import '../../tool/extraction_bench/src/scoring.dart';

class FakeAiInferenceDataSource extends Fake implements AiInferenceDataSource {
  FakeAiInferenceDataSource(this.outputs);
  final List<String> outputs;
  var _calls = 0;
  GenerationStats? _stats;

  @override
  GenerationStats? get lastGenerationStats => _stats;

  @override
  Future<String?> runTextPrompt({required String prompt, int? maxTokens, String? grammar}) async {
    _stats = const GenerationStats(mode: GenerationMode.text, promptTokens: 10, timeToFirstTokenMs: 12.5);
    return outputs[_calls++];
  }

  @override
  Future<String?> runVisionPrompt({
    required String prompt,
    required List<String> imagePaths,
    int? maxTokens,
    String? grammar,
  }) async {
    _stats = const GenerationStats(mode: GenerationMode.vision, promptEvalMs: 900);
    return outputs[_calls++];
  }
}

class _FakeProcessingRepository extends Fake implements ProcessingRepository {
  _FakeProcessingRepository(
    this.failingImages, {
    this.container = const {'resourceType': 'DiagnosticReport', 'reportName': 'Hemoleucograma'},
  });

  /// Pages whose phase 1 throws.
  final Set<String> failingImages;

  /// Phase 1's container, in the model's JSON shape.
  final Map<String, dynamic> container;
  final remainingCategories = <String?>[];

  @override
  Future<(MappingPatient, MappingResource)> mapBasicInfo(
    List<String> imagePaths, {
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
  }) async {
    if (imagePaths.any(failingImages.contains)) throw Exception('boom');
    return (
      MappingResource.fromJson({
        'resourceType': 'Patient',
        'familyName': 'Popescu',
        'givenName': 'Ana',
        'gender': 'female',
      }) as MappingPatient,
      MappingResource.fromJson(Map.of(container)),
    );
  }

  @override
  Stream<MappingResourcesWithProgress> mapRemainingResources(
    List<String> imagePaths, {
    String? documentCategory,
    bool useVision = false,
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
  }) async* {
    remainingCategories.add(documentCategory);
    final hb = MappingResource.fromJson(
        {'resourceType': 'Observation', 'observationName': 'Hemoglobina', 'value': '13,5', 'unit': 'g/dL'});
    yield ([hb], 0.5);
    yield ([hb], 1.0);
  }
}

class _DisposableFakeDataSource extends FakeAiInferenceDataSource {
  _DisposableFakeDataSource() : super(const []);
  var disposed = 0;

  @override
  Future<void> disposeModel() async => disposed++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recording decorator flags non-strict JSON and passes output through', () async {
    const fenced = '```json\n[{"resourceType":"Patient"}]\n```';
    final recorder = RecordingAiInferenceDataSource(
      FakeAiInferenceDataSource(['[{"resourceType":"Patient"}]', fenced]),
    )..phase = 'basic';
    expect(await recorder.runTextPrompt(prompt: 'p'), '[{"resourceType":"Patient"}]');
    recorder.phase = 'remaining';
    final second = recorder.runVisionPrompt(prompt: 'p', imagePaths: const []);
    recorder.onLog(LlamaLogRecord(
        level: LlamaLogLevel.info,
        message: 'encoding image slice...\nimage slice encoded in 412 ms',
        time: DateTime(2026)));
    recorder.onLog(LlamaLogRecord(
        level: LlamaLogLevel.info, message: 'image decoded (batch 1/1) in 37 ms', time: DateTime(2026)));
    expect(await second, fenced);

    expect(RecordingAiInferenceDataSource.isStrictJson('[]'), isTrue);
    expect(RecordingAiInferenceDataSource.isStrictJson('{"a": 1}'), isTrue);
    for (final notContainer in ['null', '"text"', '42', 'true', '', '[1,']) {
      expect(RecordingAiInferenceDataSource.isStrictJson(notContainer), isFalse, reason: notContainer);
    }
    expect(RecordingAiInferenceDataSource.isStrictJson(null), isFalse);

    final [text, vision] = recorder.generations;
    expect(text.strictJsonValid, isTrue);
    expect(text.phase, 'basic');
    expect(text.stats!.timeToFirstTokenMs, 12.5);
    expect(text.imageEncodeMs, isNull);
    expect(vision.strictJsonValid, isFalse);
    expect(vision.phase, 'remaining');
    expect(vision.imageEncodeMs, 412);
    expect(vision.imageDecodeMs, 37);
    expect(vision.stats!.promptEvalMs, 900);

    final json = jsonDecode(jsonEncode(RunRecord(
      docId: 'd',
      runId: 'r',
      model: 'qwen',
      platform: 'macos',
      useVision: true,
      predictedResources: const [],
      generations: recorder.generations,
      peakRssBytes: 1,
      wallMs: 2,
    ).toJson())) as Map<String, dynamic>;
    final parsed = PredictionRecord.fromJson(json);
    expect(parsed.generations.map((g) => g.strictJsonValid), [true, false]);
    expect(parsed.generations[1].imageEncodeMs, 412);
    expect(parsed.error, isNull);
  });

  test('pipeline-shaped predictions are read by the field specs', () {
    String toFhir(Map<String, dynamic> m) => jsonEncode(MappingResource.fromJson(m)
        .toFhirResource(subjectId: 'bench-patient', encounterId: 'bench-container')
        .rawResource);
    final pred = [
      for (final m in <Map<String, dynamic>>[
        {
          'resourceType': 'Patient',
          'familyName': 'Müller',
          'givenName': 'Hans Peter',
          'dateOfBirth': '1970-04-02',
          'gender': 'male',
          'patientIdentifier': 'A123456789',
        },
        {'resourceType': 'Observation', 'observationName': 'Hämoglobin', 'value': '13.5', 'unit': 'g/dl'},
        {'resourceType': 'Observation', 'observationName': 'Heart rate', 'value': '72', 'unit': 'bpm'},
        {'resourceType': 'Condition', 'conditionName': 'Vorhofflimmern', 'onsetDateTime': '2019-05'},
        {'resourceType': 'MedicationStatement', 'medicationName': 'Bisoprolol 5 mg', 'dosage': '1-0-0'},
        {'resourceType': 'DiagnosticReport', 'reportName': 'Laborbefund', 'issuedDate': '2025-03-14', 'conclusion': 'Alle Werte im Referenzbereich.'},
        {'resourceType': 'Encounter', 'encounterType': 'Entlassungsbrief', 'specialty': 'Cardiology', 'periodStart': '2024-06-08'},
        {'resourceType': 'AllergyIntolerance', 'substance': 'Penicillin', 'manifestation': 'Hautausschlag', 'category': 'medication'},
        {'resourceType': 'Procedure', 'procedureName': 'Koloskopie', 'performedDateTime': '2024-06-10'},
        {'resourceType': 'Practitioner', 'practitionerName': 'Dr. med. Felix Böhm', 'specialty': 'Kardiologie', 'identifier': '471354493'},
        {'resourceType': 'Organization', 'organizationName': 'Kreisklinikum Bergheide', 'address': 'Hauptstraße 12, 10115 Berlin', 'phone': '+49 30 23125 390'},
      ])
        jsonDecode(toFhir(m)) as Map<String, dynamic>,
    ];
    final gold = <Map<String, dynamic>>[
      {
        'resourceType': 'Patient',
        'name': [
          {'family': 'Müller', 'given': ['Hans', 'Peter']},
        ],
        'birthDate': '1970-04-02',
        'gender': 'male',
        'identifier': [
          {'value': 'A123456789'},
        ],
      },
      {
        'resourceType': 'Observation',
        'code': {
          'coding': [
            {'system': 'http://loinc.org', 'code': '718-7'},
          ],
          'text': 'Hämoglobin',
        },
        'valueQuantity': {'value': 13.5, 'unit': 'g/dl', 'system': 'http://unitsofmeasure.org', 'code': 'g/dL'},
      },
      {
        'resourceType': 'Observation',
        'code': {
          'coding': [
            {'system': 'http://loinc.org', 'code': '8867-4'},
          ],
          'text': 'Herzfrequenz',
        },
        'valueQuantity': {'value': 72, 'unit': '/min', 'system': 'http://unitsofmeasure.org', 'code': '/min'},
      },
      {
        'resourceType': 'Condition',
        'code': {
          'coding': [
            {'system': 'http://snomed.info/sct', 'code': '49436004'},
          ],
          'text': 'Vorhofflimmern',
        },
        'onsetDateTime': '2019-05',
      },
      {
        'resourceType': 'MedicationStatement',
        'medicationCodeableConcept': {'text': 'Bisoprolol 5 mg'},
        'dosage': [
          {'text': '1-0-0'},
        ],
      },
      {
        'resourceType': 'DiagnosticReport',
        'code': {'text': 'Laborbefund'},
        'effectiveDateTime': '2025-03-14',
        'conclusion': 'Alle Werte im Referenzbereich.',
      },
      {
        'resourceType': 'Encounter',
        'type': [
          {'text': 'Entlassungsbrief'},
        ],
        'serviceType': {
          'coding': [
            {'system': 'http://snomed.info/sct', 'code': '394579002', 'display': 'Cardiology'},
          ],
          'text': 'Kardiologie',
        },
        'period': {'start': '2024-06-08', 'end': '2024-06-20'},
      },
      {
        'resourceType': 'AllergyIntolerance',
        'category': ['medication'],
        'code': {
          'coding': [
            {'system': 'http://snomed.info/sct', 'code': '764146007'},
          ],
          'text': 'Penicillin',
        },
        'reaction': [
          {
            'manifestation': [
              {'text': 'Hautausschlag'},
            ],
          },
        ],
      },
      {
        'resourceType': 'Procedure',
        'code': {
          'coding': [
            {'system': 'http://snomed.info/sct', 'code': '73761001'},
          ],
          'text': 'Koloskopie',
        },
        'performedDateTime': '2024-06-10',
      },
      {
        'resourceType': 'Practitioner',
        'identifier': [
          {'value': '471354493'},
        ],
        'name': [
          {'text': 'Dr. med. Felix Böhm', 'family': 'Böhm'},
        ],
        'qualification': [
          {
            'code': {'text': 'Kardiologie'},
          },
        ],
      },
      {
        'resourceType': 'Organization',
        'name': 'Kreisklinikum Bergheide',
        'telecom': [
          {'system': 'phone', 'value': '+49 30 23125 390'},
        ],
        'address': [
          {'text': 'Hauptstraße 12, 10115 Berlin'},
        ],
      },
    ];
    final s = scoreResources(gold, pred);
    expect(s.byType['Patient']!.f1, 1, reason: 'patient fields');
    expect(s.byType['MedicationStatement']!.f1, 1);
    expect(s.byType['DiagnosticReport']!.f1, 1);
    // Text-only codes earn half credit against a coded gold concept; the
    // vital sign's LOINC code from the app earns full credit.
    final obs = s.byType['Observation']!;
    expect(obs.tp, 3.5);
    final condition = s.byType['Condition']!;
    expect(condition.tp, 1.5);
    // The app codes the specialty with the same SNOMED code.
    expect(s.byType['Encounter']!.f1, 1);
    expect(s.byType['Practitioner']!.f1, 1);
    expect(s.byType['Organization']!.f1, 1);
    // Substance text-only against a coded gold (0.5), category 1, text-only
    // manifestation 1.
    expect(s.byType['AllergyIntolerance']!.tp, 2.5);
    expect(s.byType['AllergyIntolerance']!.hallucinated, 0);
    // Procedure code text-only against a coded gold (0.5), date 1.
    expect(s.byType['Procedure']!.tp, 1.5);
    expect(s.byType['Procedure']!.hallucinated, 0);
  });

  test('a pipeline failure is recorded with empty predictions and the next document still runs', () async {
    final tmp = Directory.systemTemp.createTempSync('bench_runner_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    BenchDoc doc(String id) {
      final dir = Directory(p.join(tmp.path, 'real', id))..createSync(recursive: true);
      File(p.join(dir.path, 'page-1.png')).writeAsBytesSync(const [0]);
      return BenchDoc(id, dir.path, {'docId': id, 'degradation': 'clean'});
    }

    final failing = doc('a-fails');
    final ok = doc('b-ok');
    final repository = _FakeProcessingRepository({p.join(failing.dir, 'page-1.png')});
    final inner = _DisposableFakeDataSource();
    final recorder = RecordingAiInferenceDataSource(inner);
    final records = <RunRecord>[
      for (final d in [failing, ok])
        await runBenchDocument(
          doc: d,
          repository: repository,
          recorder: recorder,
          pages: (d) async => [p.join(d.dir, 'page-1.png')],
          workDir: tmp.path,
          runId: 'r',
          model: 'qwen',
          useVision: true,
          pref: (_) => null,
        ),
    ];

    expect(records[0].error, contains('boom'));
    expect(records[0].predictedResources, isEmpty);
    expect(inner.disposed, 1);
    expect(records[1].error, isNull);
    expect(repository.remainingCategories, ['lab_report']);
    // Patient, the DiagnosticReport container and both yielded batches.
    expect(records[1].predictedResources.map((r) => r['resourceType']),
        ['Patient', 'DiagnosticReport', 'Observation', 'Observation']);
    expect(File(p.join(ok.dir, 'page-1.png')).existsSync(), isTrue, reason: 'dataset images are kept');
    // The report had no date, so the DateTime.now() fill-in is dropped.
    expect(records[1].predictedResources[1], isNot(contains('issued')));
  });

  test('phase 2 category follows the container; a parsed report date is kept', () async {
    final tmp = Directory.systemTemp.createTempSync('bench_runner_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final dir = Directory(p.join(tmp.path, 'real', 'd'))..createSync(recursive: true);
    final doc = BenchDoc('d', dir.path, const {'docId': 'd', 'degradation': 'clean'});

    Future<(RunRecord, _FakeProcessingRepository)> run(Map<String, dynamic> container) async {
      final repository = _FakeProcessingRepository(const {}, container: container);
      final record = await runBenchDocument(
        doc: doc,
        repository: repository,
        recorder: RecordingAiInferenceDataSource(_DisposableFakeDataSource()),
        pages: (d) async => [p.join(d.dir, 'page-1.png')],
        workDir: tmp.path,
        runId: 'r',
        model: 'qwen',
        useVision: false,
        pref: (_) => null,
      );
      return (record, repository);
    }

    final (visit, visitRepo) = await run(const {'resourceType': 'Encounter', 'encounterType': 'Bilet de ieșire din spital'});
    expect(visitRepo.remainingCategories, ['visit']);
    expect(visit.predictedResources[1]['resourceType'], 'Encounter');

    final (lab, labRepo) = await run(const {
      'resourceType': 'DiagnosticReport',
      'reportName': 'Hemoleucograma',
      'issuedDate': '2025-03-14',
    });
    expect(labRepo.remainingCategories, ['lab_report']);
    expect(lab.predictedResources[1]['issued'], startsWith('2025-03-14'));
  });
}
