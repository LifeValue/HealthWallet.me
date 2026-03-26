import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/services/pdf_storage_service.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/repository/scan_repository.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/helpers/scan_path_helper.dart';
import 'package:injectable/injectable.dart';

part 'scan_event.dart';
part 'scan_state.dart';
part 'scan_bloc.freezed.dart';

@injectable
class ScanBloc extends Bloc<ScanEvent, ScanState> {
  final PdfStorageService _pdfStorageService;
  final ScanRepository _scanRepository;
  final ProcessingBloc _processingBloc;

  ScanBloc(
    this._pdfStorageService,
    this._scanRepository,
    this._processingBloc,
  ) : super(const ScanState()) {
    on<ScanPressed>(_onScanPressed);
  }

  Future<void> _onScanPressed(
    ScanPressed event,
    Emitter<ScanState> emit,
  ) async {
    emit(state.copyWith(isCapturing: true, error: null));

    try {
      final filePaths = event.mode == CaptureMode.pdf
          ? await _scanPdf()
          : await _scanImages(event.maxPages);

      if (filePaths == null || filePaths.isEmpty) {
        emit(state.copyWith(isCapturing: false));
        return;
      }

      _processingBloc.add(DocumentImported(filePaths: filePaths));
      emit(state.copyWith(isCapturing: false));
    } on PlatformException catch (e) {
      emit(state.copyWith(isCapturing: false, error: _parsePlatformError(e)));
    } catch (e) {
      emit(state.copyWith(isCapturing: false, error: _parseGeneralError(e)));
    }
  }

  Future<List<String>?> _scanPdf() async {
    final result = await FlutterDocScanner().getScannedDocumentAsPdf();
    if (result == null) return null;

    final pdfPath = result.pdfUri;
    if (pdfPath.isEmpty || !_isValidResult(pdfPath)) return null;

    final savedPath = await _pdfStorageService.savePdfToStorage(
      sourcePdfPath: pdfPath,
      customFileName:
          'health_scan_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    return savedPath != null ? [savedPath] : null;
  }

  Future<List<String>?> _scanImages(int maxPages) async {
    final result = await FlutterDocScanner().getScannedDocumentAsImages(
      page: maxPages,
    );
    if (result == null) return null;

    final imagePaths =
        result.images.where((path) => path.isNotEmpty).toList();

    if (imagePaths.isEmpty || !_isValidResult(imagePaths.first)) return null;

    final persistedPaths = await ScanPathHelper.persistScanFiles(
      sourcePaths: imagePaths,
      repository: _scanRepository,
    );

    return persistedPaths.isNotEmpty ? persistedPaths : imagePaths;
  }

  bool _isValidResult(String path) {
    return !path.contains('Failed') && !path.contains('Unknown');
  }

  String _parsePlatformError(PlatformException error) {
    final code = error.code.toLowerCase();
    final message = error.message?.toLowerCase() ?? '';

    if (code.contains('permission') || message.contains('permission')) {
      return 'Camera permission is required.';
    } else if (code.contains('cancel') || message.contains('cancel')) {
      return 'Scanning was cancelled';
    } else if (code.contains('unavailable') ||
        message.contains('unavailable')) {
      return 'Scanner not available on this device';
    }
    return 'Scanner error: ${error.message ?? "Unknown error"}';
  }

  String _parseGeneralError(dynamic error) {
    final s = error.toString().toLowerCase();
    if (s.contains('cancel')) return 'Scanning was cancelled';
    if (s.contains('permission')) return 'Camera permission required.';
    if (s.contains('camera')) return 'Unable to access camera.';
    return 'Failed to scan. Please try again.';
  }
}
