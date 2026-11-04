import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extractor.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extractor_registry.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/visit_reconciler.dart';
import 'package:health_wallet/features/processing/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/processing/domain/services/processing_log_buffer.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:injectable/injectable.dart';

/// The layout-extractor step of the pipeline, right after OCR: a document a
/// registered extractor recognises is read by it, offline and without the
/// AI model; any other document goes to the AI unchanged.
@lazySingleton
class LayoutExtractionService {
  LayoutExtractionService(
    this._processing,
    this._ocr,
    this._registry,
    this._holders,
    this._records,
  );

  final ProcessingRepository _processing;
  final OcrProcessingHelper _ocr;
  final LayoutExtractorRegistry _registry;
  final HolderService _holders;
  final RecordsRepository _records;
  final _reconciler = const VisitReconciler();

  /// OCR text and page count by session, so a session is read once even
  /// when the model gate asks before the pipeline runs (each may rasterise
  /// the PDF to its own files). Dropped by [forget] when the pages change.
  final _texts = <String, ({int pages, String text})>{};

  /// Every record of a person; a wallet holds hundreds, not millions.
  static const allRecords = 100000;

  /// The OCR text of [imagePaths] (a session's pages), read once per
  /// session. An empty result is not kept, so a retry reads again.
  Future<String> ocrText(String sessionId, List<String> imagePaths) async {
    final cached = _texts[sessionId];
    if (cached != null && cached.pages == imagePaths.length) {
      return cached.text;
    }
    final text = await _ocr.processOcrForImages(imagePaths);
    if (text.trim().isNotEmpty) {
      _texts[sessionId] = (pages: imagePaths.length, text: text);
    }
    return text;
  }

  /// Whether the session can be processed: the AI model is on the device,
  /// or a layout extractor reads the document ([recognise]). The one model
  /// gate of every entry point and of the queued-session message. A failing
  /// model check is passed on; a failing recognition counts as not
  /// recognised.
  Future<bool> canProcess(
    String sessionId, {
    required List<String> filePaths,
    List<String>? imagePaths,
  }) async =>
      await _processing.checkModelExistence() ||
      await recognise(sessionId, filePaths: filePaths, imagePaths: imagePaths);

  /// Whether a layout extractor reads the session's document completely
  /// (its required fields included), so it needs no AI model. The pages are
  /// prepared from [filePaths] unless [imagePaths] are given.
  Future<bool> recognise(
    String sessionId, {
    required List<String> filePaths,
    List<String>? imagePaths,
  }) async {
    if (_registry.extractors.isEmpty) return false;
    try {
      final images =
          imagePaths ?? await _ocr.prepareAllImages(filePaths: filePaths);
      if (images.isEmpty) return false;
      final text = await ocrText(sessionId, images);
      return text.trim().isNotEmpty && extract(text) != null;
    } catch (e, s) {
      // Not recognised: the model gate then decides as before.
      logger.w(
        '[LayoutExtraction] recognising session $sessionId failed',
        e,
        s,
      );
      return false;
    }
  }

  /// What the best extractor reads from [ocrText], or null when none
  /// recognises it or a required field is missing.
  LayoutExtraction? extract(String ocrText) {
    final extractor = _registry.best(ocrText);
    if (extractor == null) return null;
    LayoutExtraction? extraction;
    try {
      extraction = extractor.extract(ocrText);
    } catch (e, s) {
      logger.w('[LayoutExtraction] ${extractor.id} failed', e, s);
    }
    ProcessingLogBuffer.instance.log(
      '[${DateTime.now().toIso8601String().substring(11, 23)}][ScanAI] '
      'layout ${extractor.id}: ${extraction == null ? 'required fields missing, using the AI' : '${extraction.resources.length} records'}',
    );
    return extraction;
  }

  /// The container and resources [extraction] is staged with, reconciled
  /// with the records of the person [holderPatient] belongs to (none for
  /// someone new).
  Future<LayoutStaging> stage(
    LayoutExtraction extraction, {
    Patient? holderPatient,
  }) async {
    var records = const <IFhirResource>[];
    if (holderPatient != null) {
      final holder = (await _holders.load()).ofPatientId(holderPatient.id);
      if (holder != null && holder.sourceIds.isNotEmpty) {
        records = await _records.getResources(
          resourceTypes: const [
            FhirType.Encounter,
            FhirType.VisionPrescription,
            FhirType.Organization,
            FhirType.Practitioner,
          ],
          sourceIds: holder.sourceIds,
          limit: allRecords,
        );
      }
    }
    return _reconciler.reconcile(extraction, records);
  }

  /// Drops the cached text of [sessionId] (cleared, or pages changed).
  void forget(String sessionId) => _texts.remove(sessionId);
}
