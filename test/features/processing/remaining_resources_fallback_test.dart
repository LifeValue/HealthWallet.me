import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_data_source.dart';
import 'package:health_wallet/features/processing/data/model/generation_stats.dart';
import 'package:health_wallet/features/processing/data/repository/ai_extraction_repository.dart';
import 'package:health_wallet/features/processing/domain/entity/extraction_output_mode.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_condition.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';

class _FakeOcr extends Fake implements TextRecognitionService {
  @override
  Future<String> recognizeTextFromImage(String imagePath) async =>
      'Diagnosen: Vorhofflimmern seit 2019. Entlassung am 08.06.2024.';
}

/// Throws on a vision load, as `initModel` does when model + projector exceed
/// the memory limit; a text-only load succeeds.
class _FakeDataSource extends Fake implements AiInferenceDataSource {
  final loads = <bool>[];
  var visionPrompts = 0;

  @override
  PromptFamily get promptFamily => PromptFamily.standard;

  @override
  int get visionPagesPerBatch => 2;

  @override
  GenerationStats? get lastGenerationStats => null;

  @override
  Future<void> initModel({bool withVision = true, int? contextSize, int? gpuLayers, int? threads}) async {
    loads.add(withVision);
    if (withVision) {
      throw Exception('Not enough memory to load the AI model. Available: 3989MB, required: ~4721MB.');
    }
  }

  @override
  Future<void> disposeModel() async {}

  @override
  Future<String?> runVisionPrompt({
    required String prompt,
    required List<String> imagePaths,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
  }) async {
    visionPrompts++;
    return '[]';
  }

  @override
  Future<String?> runTextPrompt({
    required String prompt,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
    Map<String, dynamic>? chatTemplateKwargs,
  }) async =>
      '[{"resourceType":"Condition","conditionName":"Vorhofflimmern","onsetDateTime":"2019","clinicalStatus":"active"}]';
}

class _Repository with AiExtractionRepository {
  _Repository(this.networkDataSource);

  @override
  final AiInferenceDataSource networkDataSource;

  @override
  final TextRecognitionService textRecognitionService = _FakeOcr();

  @override
  bool get shouldCancelGeneration => false;

  @override
  Future<void> disposeModel() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a vision model that fails to load falls back to text-only instead of throwing', () async {
    final dataSource = _FakeDataSource();
    final events = await _Repository(dataSource)
        .processMapRemainingResources(const ['page-1.png'],
            documentCategory: 'visit', useVision: true, outputMode: ExtractionOutputMode.grammar)
        .toList();

    expect(dataSource.loads, [true, false]);
    expect(dataSource.visionPrompts, 0);
    final (resources, progress) = events.last;
    expect(progress, 1.0);
    expect(resources.single, isA<MappingCondition>());
  });
}
