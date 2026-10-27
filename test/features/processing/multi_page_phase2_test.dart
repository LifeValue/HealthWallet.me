import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_data_source.dart';
import 'package:health_wallet/features/processing/data/model/generation_stats.dart';
import 'package:health_wallet/features/processing/data/repository/ai_extraction_repository.dart';
import 'package:health_wallet/features/processing/domain/entity/extraction_output_mode.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_observation.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';

/// The letterhead and patient block a lab prints on every page.
const _header = 'Laborator Exemplu SRL\n'
    'Str. Exemplului Nr. 12, et.1\n'
    'Telefon: 0700 123 456\n'
    'Nume pacient: Popescu\n'
    'CNP: 1850101000000\n'
    'Data recoltarii: 12/03/2024 08:15';

/// Page n: the header, then the result named TEST-n padded with a long
/// reference range, so the 4 pages do not fit one chunk.
String _page(int n) => '$_header\nTEST-$n\n${n * 1.5}\nmUI/mL\n${'Interval de referinta ${n}x ' * 40}';

class _PageOcr extends Fake implements TextRecognitionService {
  @override
  Future<String> recognizeTextFromImage(String imagePath) async =>
      _page(int.parse(RegExp(r'page-(\d+)').firstMatch(imagePath)!.group(1)!));
}

/// Answers every call with one observation named after the TEST-n markers
/// in its prompt; records prompts, loads and vision batches.
class _FakeDataSource extends Fake implements AiInferenceDataSource {
  _FakeDataSource({this.memoryLimitCtx});

  /// Text loads above this context throw the app's not-enough-memory error.
  final int? memoryLimitCtx;
  final loads = <({bool withVision, int? contextSize})>[];
  final textPrompts = <String>[];
  final visionCalls = <({List<String> images, String prompt})>[];

  @override
  PromptFamily get promptFamily => PromptFamily.standard;

  @override
  GenerationStats? get lastGenerationStats => null;

  @override
  Future<void> initModel({bool withVision = true, int? contextSize, int? gpuLayers, int? threads}) async {
    if (!withVision && memoryLimitCtx != null && (contextSize ?? 0) > memoryLimitCtx!) {
      throw Exception('Not enough memory to load the AI model. Available: 3000MB, required: ~3400MB.');
    }
    loads.add((withVision: withVision, contextSize: contextSize));
  }

  @override
  Future<void> disposeModel() async {}

  @override
  Future<({int availableMB, int requiredMB, bool canProceed})> checkMemoryHealth({
    bool withVision = true,
    int? contextSize,
  }) async =>
      (availableMB: -1, requiredMB: 0, canProceed: true);

  String _answer(String prompt) => jsonEncode({
        'observations': [
          for (final m in RegExp(r'TEST-(\d+)').allMatches(prompt).map((m) => m.group(0)!).toSet())
            {'observationName': m, 'value': '1', 'unit': 'mUI/mL', 'referenceRange': ''},
        ],
        'practitioners': [],
        'organizations': [],
      });

  @override
  Future<String?> runVisionPrompt({
    required String prompt,
    required List<String> imagePaths,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
  }) async {
    visionCalls.add((images: imagePaths, prompt: prompt));
    return _answer(prompt);
  }

  @override
  Future<String?> runTextPrompt({
    required String prompt,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
    Map<String, dynamic>? chatTemplateKwargs,
  }) async {
    textPrompts.add(prompt);
    return _answer(prompt);
  }
}

class _Repository with AiExtractionRepository {
  _Repository(this.networkDataSource);

  @override
  final AiInferenceDataSource networkDataSource;

  @override
  final TextRecognitionService textRecognitionService = _PageOcr();

  @override
  bool get shouldCancelGeneration => false;

  @override
  Future<void> disposeModel() async {}
}

const _pages = ['page-1.png', 'page-2.png', 'page-3.png', 'page-4.png'];

Future<List<String>> _observationNames(_FakeDataSource dataSource, {bool useVision = false}) async {
  final events = await _Repository(dataSource)
      .processMapRemainingResources(_pages,
          documentCategory: 'lab_report', useVision: useVision, outputMode: ExtractionOutputMode.schema)
      .toList();
  final (resources, _) = events.last;
  return resources.whereType<MappingObservation>().map((o) => o.observationName.value).toList()..sort();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('text phase 2 reads every page: header once, chunks at a 4096 context, results merged', () async {
    final dataSource = _FakeDataSource();
    final names = await _observationNames(dataSource);

    expect(dataSource.loads, [(withVision: false, contextSize: 4096)]);
    expect(dataSource.textPrompts.length, greaterThan(1));
    expect(names, ['TEST-1', 'TEST-2', 'TEST-3', 'TEST-4']);
    final all = dataSource.textPrompts.join('\n');
    expect('Laborator Exemplu SRL'.allMatches(all).length, 1);
    expect('CNP: 1850101000000'.allMatches(all).length, 1);
  });

  test('a 4096 text context that does not fit in memory falls back to 2048 with smaller chunks', () async {
    final dataSource = _FakeDataSource(memoryLimitCtx: 2048);
    final names = await _observationNames(dataSource);

    expect(dataSource.loads, [(withVision: false, contextSize: 2048)]);
    expect(names, ['TEST-1', 'TEST-2', 'TEST-3', 'TEST-4']);
  });

  test('each vision batch gets the OCR of its own pages', () async {
    final dataSource = _FakeDataSource();
    final names = await _observationNames(dataSource, useVision: true);

    expect(dataSource.visionCalls.map((c) => c.images), [
      ['page-1.png', 'page-2.png'],
      ['page-3.png', 'page-4.png'],
    ]);
    expect(dataSource.visionCalls[0].prompt, allOf(contains('TEST-1'), isNot(contains('TEST-3'))));
    expect(dataSource.visionCalls[1].prompt, allOf(contains('TEST-3'), isNot(contains('TEST-1'))));
    expect(names, ['TEST-1', 'TEST-2', 'TEST-3', 'TEST-4']);
  });
}
