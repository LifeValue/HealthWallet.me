import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_data_source.dart';
import 'package:health_wallet/features/processing/data/model/generation_stats.dart';
import 'package:health_wallet/features/processing/data/repository/ai_extraction_repository.dart';
import 'package:health_wallet/features/processing/domain/entity/extraction_output_mode.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_condition.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_observation.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_organization.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';
import 'package:image/image.dart' as img;

/// Long enough for the phase-1 text pass (200 characters or more).
final _longOcr = 'Scrisoare medicala. Pacient: Pop Ana. ${'Diagnostic. ' * 20}';

class _FakeOcr extends Fake implements TextRecognitionService {
  _FakeOcr(this.text);
  final String text;
  final read = <String>[];

  @override
  Future<String> recognizeTextFromImage(String imagePath) async {
    read.add(imagePath);
    return text;
  }
}

/// Answers each prompt with the next queued output (an [Exception] is
/// thrown) and records the calls and model loads.
class _FakeDataSource extends Fake implements AiInferenceDataSource {
  _FakeDataSource(this.outputs);

  final List<Object?> outputs;
  final calls = <String>[];
  final loads = <({bool withVision, int? contextSize})>[];
  bool memoryOk = true;
  Exception? loadError;

  @override
  PromptFamily get promptFamily => PromptFamily.standard;

  @override
  int get visionPagesPerBatch => 1;

  @override
  GenerationStats? get lastGenerationStats => null;

  @override
  Future<void> initModel({
    bool withVision = true,
    int? contextSize,
    int? gpuLayers,
    int? threads,
  }) async {
    loads.add((withVision: withVision, contextSize: contextSize));
    if (loadError != null && !withVision) throw loadError!;
  }

  @override
  Future<void> disposeModel() async {}

  @override
  Future<bool> checkMmprojExistence() async => true;

  @override
  bool isVisionModelAvailable() => loads.lastOrNull?.withVision == true;

  @override
  Future<({int availableMB, int requiredMB, bool canProceed})>
  checkMemoryHealth({bool withVision = true, int? contextSize}) async => (
    availableMB: memoryOk ? 8000 : 100,
    requiredMB: 2000,
    canProceed: memoryOk,
  );

  Future<String?> _answer(String kind) async {
    calls.add(kind);
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
  }) => _answer('vision');

  @override
  Future<String?> runTextPrompt({
    required String prompt,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
    Map<String, dynamic>? chatTemplateKwargs,
  }) => _answer(grammar == null && responseFormat == null ? 'draft' : 'text');
}

class _Repository with AiExtractionRepository {
  _Repository(this.networkDataSource, String ocr)
    : textRecognitionService = _FakeOcr(ocr);

  @override
  final AiInferenceDataSource networkDataSource;

  @override
  final _FakeOcr textRecognitionService;

  @override
  bool get shouldCancelGeneration => false;

  @override
  Future<void> disposeModel() async {}
}

String _array(List<Map<String, Object?>> items) => jsonEncode(items);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('phase 1', () {
    Future<(MappingResource, MappingResource)> basicInfo(
      _FakeDataSource ds, {
      String ocr = '',
      ExtractionOutputMode mode = ExtractionOutputMode.grammar,
      List<String> pages = const ['p.png'],
    }) async {
      final (patient, container) = await _Repository(
        ds,
        ocr,
      ).processMapBasicInfo(pages, outputMode: mode);
      return (patient as MappingResource, container);
    }

    test('an answer cut off mid-array keeps its complete objects, quotes and '
        'escapes included', () async {
      const cut =
          '[{"resourceType":"Patient","familyName":"Pop \\"Ana\\" \\\\ {x}",'
          '"givenName":"Ana","documentCategory":"visit"},'
          '{"resourceType":"Encounter","encounterType":"Consu';
      final ds = _FakeDataSource([cut]);

      final (patient, container) = await basicInfo(ds, ocr: _longOcr);

      expect(ds.calls, ['text']);
      expect(patient.toJson()['givenName']['value'], 'Ana');
      expect(container, isA<MappingEncounter>());
    });

    test('a visit takes its encounter as the container', () async {
      final ds = _FakeDataSource([
        _array([
          {
            'resourceType': 'Patient',
            'familyName': 'Pop',
            'documentCategory': 'visit',
          },
          {
            'resourceType': 'DiagnosticReport',
            'reportName': 'Hemoleucograma',
            'issuedDate': '2025-03-14',
          },
          {
            'resourceType': 'Encounter',
            'encounterType': 'Scrisoare medicala',
            'periodStart': '2025-03-14',
          },
        ]),
      ]);

      final (_, container) = await basicInfo(ds, ocr: _longOcr);

      expect(
        (container as MappingEncounter).encounterType.value,
        'Scrisoare medicala',
      );
    });

    test('without a category or an encounter a report is the '
        'container', () async {
      final ds = _FakeDataSource([
        _array([
          {'resourceType': 'Patient', 'familyName': 'Pop'},
          {
            'resourceType': 'DiagnosticReport',
            'reportName': 'Hemoleucograma',
            'issuedDate': '2025-03-14',
          },
        ]),
      ]);

      final (_, container) = await basicInfo(
        ds,
        ocr: 'Hemoleucograma 2025-03-14 Pop $_longOcr',
      );

      expect(
        (container as MappingDiagnosticReport).reportName.value,
        'Hemoleucograma',
      );
    });

    test('a page without text is read from the image alone', () async {
      final ds = _FakeDataSource([
        _array([
          {'resourceType': 'Patient', 'familyName': 'Pop', 'givenName': 'Ana'},
        ]),
      ]);

      final (patient, _) = await basicInfo(ds);

      expect(ds.calls, ['vision']);
      expect(patient.toJson()['familyName']['value'], 'Pop');
    });

    test('in schemaDraft mode a short page is drafted from the image, then '
        'read by a constrained text pass', () async {
      final ds = _FakeDataSource([
        'Patient: Ana Pop',
        jsonEncode({
          'familyName': 'Pop',
          'givenName': 'Ana',
          'dateOfBirth': '',
          'gender': '',
          'patientIdentifier': '',
          'identifierLabel': '',
          'documentTitle': 'Scrisoare medicala',
          'documentDate': '2025-03-14',
          'conclusion': '',
          'documentCategory': 'visit',
        }),
      ]);

      final (patient, _) = await basicInfo(
        ds,
        ocr: 'Pacient: Ana Pop',
        mode: ExtractionOutputMode.schemaDraft,
      );

      expect(ds.calls, ['vision', 'text']);
      expect(ds.loads.map((l) => l.withVision), [true, false]);
      expect(patient.toJson()['givenName']['value'], 'Ana');
    });

    test('a page image is sharpened for OCR in a copy that is deleted '
        'afterwards', () async {
      final root = Directory.systemTemp.createTempSync('hw_ocr_pre_');
      addTearDown(() => root.deleteSync(recursive: true));
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => root.path);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final page = File('${root.path}/page.png')
        ..writeAsBytesSync(img.encodePng(img.Image(width: 8, height: 8)));
      final ds = _FakeDataSource([
        _array([
          {'resourceType': 'Patient', 'familyName': 'Pop'},
        ]),
      ]);
      final repo = _Repository(ds, '');

      await repo.processMapBasicInfo([
        page.path,
      ], outputMode: ExtractionOutputMode.grammar);

      final read = repo.textRecognitionService.read.single;
      if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        expect(read, isNot(page.path));
        expect(File(read).existsSync(), isFalse);
      }
      expect(page.existsSync(), isTrue);
    });
  });

  group('container only', () {
    test('a context above the minimum is kept, and a long page is cut for '
        'the prompt', () async {
      final ds = _FakeDataSource([
        _array([
          {
            'resourceType': 'DiagnosticReport',
            'reportName': 'Hemoleucograma',
            'issuedDate': '2025-03-14',
          },
        ]),
      ]);

      final container = await _Repository(ds, '').mapContainerOnly(
        'x' * 2000,
        contextSize: 8192,
        outputMode: ExtractionOutputMode.grammar,
      );

      expect(ds.loads.single.contextSize, 8192);
      expect(container, isA<MappingDiagnosticReport>());
    });

    test('in schemaDraft mode an empty draft leaves the constrained pass '
        'without one', () async {
      final ds = _FakeDataSource([
        '  ',
        jsonEncode({
          'documentTitle': 'Scrisoare medicala',
          'documentDate': '2025-03-14',
          'conclusion': '',
          'documentCategory': 'visit',
        }),
      ]);

      final container = await _Repository(ds, '').mapContainerOnly(
        'Scrisoare medicala',
        outputMode: ExtractionOutputMode.schemaDraft,
      );

      expect(ds.calls, ['draft', 'text']);
      expect(ds.loads.single.contextSize, 4096);
      expect(
        (container as MappingEncounter).encounterType.value,
        'Scrisoare medicala',
      );
    });

    for (final (label, output) in [
      ('no answer', null),
      ('an empty array', '[]'),
      ('an answer that is not JSON', 'not json'),
    ]) {
      test('$label gives an empty encounter', () async {
        final ds = _FakeDataSource([output]);

        final container = await _Repository(ds, '').mapContainerOnly(
          'Scrisoare medicala',
          outputMode: ExtractionOutputMode.grammar,
        );

        expect((container as MappingEncounter).encounterType.value, isEmpty);
      });
    }
  });

  group('phase 2', () {
    Future<List<MappingResource>> remaining(
      _FakeDataSource ds, {
      String ocr = 'Hemoglobina 13,5 g/dl',
      bool useVision = true,
      ExtractionOutputMode mode = ExtractionOutputMode.grammar,
    }) async {
      final events = await _Repository(ds, ocr)
          .processMapRemainingResources(
            const ['p.png'],
            documentCategory: 'lab_report',
            useVision: useVision,
            outputMode: mode,
          )
          .toList();
      return events.last.$1;
    }

    test('low memory stops the vision batches and reads the pages as '
        'text', () async {
      final ds = _FakeDataSource([
        _array([
          {
            'resourceType': 'Observation',
            'observationName': 'Hemoglobina',
            'value': '13,5',
            'unit': 'g/dl',
          },
        ]),
      ])..memoryOk = false;

      final resources = await remaining(ds);

      expect(ds.calls, ['text']);
      expect(resources.single, isA<MappingObservation>());
    });

    test('a failed vision batch is logged and the pages are read as '
        'text', () async {
      final ds = _FakeDataSource([
        Exception('image encode failed'),
        _array([
          {
            'resourceType': 'Condition',
            'conditionName': 'Anemie',
            'clinicalStatus': 'active',
          },
        ]),
      ]);

      final resources = await remaining(ds, ocr: 'Anemie');

      expect(ds.calls, ['vision', 'text']);
      expect(resources.single, isA<MappingCondition>());
    });

    test('a page without text keeps the confidence the answer itself '
        'gives', () async {
      final ds = _FakeDataSource([
        _array([
          {
            'resourceType': 'Organization',
            'organizationName': 'Spitalul Judetean',
          },
          {
            'resourceType': 'Organization',
            'organizationName': 'Spitalul Judetean',
          },
          {'resourceType': 'Observation', 'observationName': 'Puls'},
        ]),
      ]);

      final resources = await remaining(ds, ocr: '');

      expect(ds.calls, ['vision']);
      expect(resources.whereType<MappingOrganization>(), hasLength(1));
    });

    test('a non-numeric observation of several words is dropped', () async {
      final ds = _FakeDataSource([
        _array([
          {
            'resourceType': 'Observation',
            'observationName': 'Aspect',
            'value': 'clar fara sediment vizibil',
          },
          {'resourceType': 'AllergyIntolerance', 'substance': 'Penicilina'},
          {'resourceType': 'AllergyIntolerance', 'substance': 'Penicilina'},
        ]),
      ]);

      final resources = await remaining(
        ds,
        ocr: 'Penicilina',
        useVision: false,
      );

      expect(resources.whereType<MappingObservation>(), isEmpty);
      expect(resources, hasLength(1));
    });

    test('in schemaDraft mode a text model that does not load after the '
        'vision drafts fails the step', () async {
      final ds = _FakeDataSource(['draft'])..loadError = Exception('no model');

      await expectLater(
        remaining(ds, mode: ExtractionOutputMode.schemaDraft),
        throwsA(isA<Exception>()),
      );
      expect(ds.calls, ['vision']);
    });

    test('in schemaDraft mode a constrained pass whose prompt is too long '
        'fails the step', () async {
      final ds = _FakeDataSource(['draft', Exception('Tokenization failed')]);

      await expectLater(
        remaining(ds, mode: ExtractionOutputMode.schemaDraft),
        throwsA(isA<Exception>()),
      );
    });

    test('a text fallback whose prompt is too long fails the step', () async {
      final ds = _FakeDataSource([Exception('prompt too long')]);

      await expectLater(
        remaining(ds, useVision: false),
        throwsA(isA<Exception>()),
      );
    });

    test('a text model that does not load gives no resources', () async {
      final ds = _FakeDataSource([])..loadError = Exception('no model');

      expect(await remaining(ds, useVision: false), isEmpty);
    });

    test('a text model that does not load for lack of memory is not retried '
        'when it already is at the smallest context', () async {
      final ds = _FakeDataSource([])
        ..loadError = Exception('Tokenization failed while loading');

      await expectLater(
        remaining(ds, useVision: false),
        throwsA(isA<Exception>()),
      );
    });
  });
}
