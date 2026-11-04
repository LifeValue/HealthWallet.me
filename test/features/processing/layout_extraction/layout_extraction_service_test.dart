import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/processing/data/extractors/clearvis/clearvis_io_extractor.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extraction_service.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extractor_registry.dart';
import 'package:health_wallet/features/processing/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/processing/domain/services/processing_log_buffer.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';

import 'clearvis_io_extractor_test.dart' show fixture;

class _Model extends Fake implements ProcessingRepository {
  _Model(this.exists);
  final bool exists;

  @override
  Future<bool> checkModelExistence() async => exists;
}

/// Pages are the file paths; their text is [text], or preparing them throws.
class _Ocr extends Fake implements OcrProcessingHelper {
  _Ocr(this.text, {this.prepareFails = false});
  String text;
  final bool prepareFails;
  int calls = 0;

  @override
  Future<List<String>> prepareAllImages({
    required List<String> filePaths,
  }) async {
    if (prepareFails) throw const FileSystemException('unreadable PDF');
    return filePaths;
  }

  @override
  Future<String> processOcrForImages(List<String> imagePaths) async {
    calls++;
    return text;
  }
}

class _Holders extends Fake implements HolderService {}

class _Records extends Fake implements RecordsRepository {}

void main() {
  setUpAll(
    () => ProcessingLogBuffer.debugOverrideInstance(
      ProcessingLogBuffer.forTesting(
        enabled: false,
        directory: Directory.systemTemp,
      ),
    ),
  );
  tearDownAll(() => ProcessingLogBuffer.debugOverrideInstance(null));

  LayoutExtractionService service(bool model, _Ocr ocr) =>
      LayoutExtractionService(
        _Model(model),
        ocr,
        LayoutExtractorRegistry(const [ClearvisIoExtractor()]),
        _Holders(),
        _Records(),
      );

  final recognised = fixture('clearvis_prescriptions');
  // Scores as clearvis.io but has no patient name: the AI must read it.
  final incomplete = recognised
      .split('\n')
      .where((l) => !l.contains('Ioana') && !l.contains('Marinescu'))
      .join('\n');
  const unrecognised = 'BULETIN DE ANALIZE\nHemoglobina 13,5 g/dL';

  final cases = {
    'recognised': (_Ocr(recognised), true),
    'scored but incomplete': (_Ocr(incomplete), false),
    'unrecognised': (_Ocr(unrecognised), false),
    'image preparation throws': (
      _Ocr(recognised, prepareFails: true),
      false,
    ),
  };

  for (final MapEntry(key: name, value: (ocr, readable)) in cases.entries) {
    test('with a model, $name: can be processed', () async {
      expect(
        await service(true, ocr).canProcess('s', filePaths: ['/a.pdf']),
        isTrue,
      );
    });

    test('without a model, $name: ${readable ? 'can' : 'cannot'} be '
        'processed', () async {
      expect(
        await service(false, ocr).canProcess('s', filePaths: ['/a.pdf']),
        readable,
      );
    });
  }

  test('empty OCR text is not kept, so a retry reads again', () async {
    final ocr = _Ocr('');
    final s = service(false, ocr);
    expect(await s.ocrText('s', ['/p1']), isEmpty);
    ocr.text = recognised;
    expect(await s.ocrText('s', ['/p1']), recognised);
    expect(await s.ocrText('s', ['/p1']), recognised);
    expect(ocr.calls, 2);
  });
}
