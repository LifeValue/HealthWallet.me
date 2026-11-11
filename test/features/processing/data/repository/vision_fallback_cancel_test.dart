import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_data_source.dart';
import 'package:health_wallet/features/processing/data/repository/ai_extraction_repository.dart';
import 'package:health_wallet/features/processing/domain/entity/extraction_output_mode.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';

class _FakeOcr extends Fake implements TextRecognitionService {
  @override
  Future<String> recognizeTextFromImage(String imagePath) async => 'Short';
}

/// Runs [onProjectorCheck] while the projector is looked for, and records
/// every model load.
class _FakeDataSource extends Fake implements AiInferenceDataSource {
  void Function()? onProjectorCheck;
  final loads = <bool>[];
  final prompts = <String>[];

  @override
  Future<bool> checkMmprojExistence() async {
    onProjectorCheck?.call();
    return true;
  }

  @override
  Future<void> initModel({
    bool withVision = true,
    int? contextSize,
    int? gpuLayers,
    int? threads,
  }) async => loads.add(withVision);

  @override
  bool isVisionModelAvailable() => loads.lastOrNull ?? false;

  @override
  Future<String?> runVisionPrompt({
    required String prompt,
    required List<String> imagePaths,
    int? maxTokens,
    String? grammar,
    Map<String, dynamic>? responseFormat,
  }) async {
    prompts.add(prompt);
    return null;
  }
}

class _Repository with AiExtractionRepository {
  _Repository(this.networkDataSource);

  @override
  final _FakeDataSource networkDataSource;

  @override
  final TextRecognitionService textRecognitionService = _FakeOcr();

  bool cancelled = false;

  @override
  bool get shouldCancelGeneration => cancelled;

  @override
  Future<void> disposeModel() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('vision fallback cancel', () {
    test('a cancel before the vision model loads does not load it', () async {
      final dataSource = _FakeDataSource();
      final repository = _Repository(dataSource);

      // Cancelled while the projector was looked for.
      dataSource.onProjectorCheck = () => repository.cancelled = true;

      // Too little text for the text pass: the vision pass is next.
      final (patient, _) = await repository.processMapBasicInfo(
        const ['p.png'],
        outputMode: ExtractionOutputMode.grammar,
      );

      expect(dataSource.loads, isEmpty);
      expect(dataSource.prompts, isEmpty);
      expect(patient.isIdentified, isFalse);
    });
  });
}
