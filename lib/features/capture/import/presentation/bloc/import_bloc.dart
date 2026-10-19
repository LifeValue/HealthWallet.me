import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';

part 'import_event.dart';
part 'import_state.dart';
part 'import_bloc.freezed.dart';

@injectable
class ImportBloc extends Bloc<ImportEvent, ImportState> {
  final ProcessingBloc _processingBloc;

  static const _allowedExtensions = [
    'pdf', 'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'tiff'
  ];

  ImportBloc(this._processingBloc)
      : super(const ImportState()) {
    on<ImportDocumentPressed>(_onImportDocument);
    on<PickImagePressed>(_onPickImage);
    on<ExternalFilesReceived>(_onExternalFiles);
  }

  Future<void> _onImportDocument(
    ImportDocumentPressed event,
    Emitter<ImportState> emit,
  ) async {
    emit(state.copyWith(isImporting: true, error: null));

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        allowCompression: false,
        withData: false,
        withReadStream: false,
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
      );

      final validPaths = await _validateFiles(result);
      if (validPaths.isNotEmpty) {
        _processingBloc.add(DocumentImported(filePaths: validPaths));
      }
      emit(state.copyWith(isImporting: false));
    } catch (e) {
      emit(state.copyWith(isImporting: false, error: e.toString()));
    }
  }

  Future<void> _onPickImage(
    PickImagePressed event,
    Emitter<ImportState> emit,
  ) async {
    emit(state.copyWith(isImporting: true, error: null));

    try {
      final images = await ImagePicker().pickMultiImage();
      if (images.isEmpty) {
        emit(state.copyWith(isImporting: false));
        return;
      }

      final validPaths = <String>[];
      for (final image in images) {
        if (await File(image.path).exists()) {
          validPaths.add(image.path);
        }
      }

      if (validPaths.isNotEmpty) {
        _processingBloc.add(DocumentImported(filePaths: validPaths));
      }
      emit(state.copyWith(isImporting: false));
    } catch (e) {
      emit(state.copyWith(isImporting: false, error: e.toString()));
    }
  }

  void _onExternalFiles(
    ExternalFilesReceived event,
    Emitter<ImportState> emit,
  ) {
    if (event.filePaths.isNotEmpty) {
      _processingBloc.add(DocumentImported(filePaths: event.filePaths));
    }
  }

  Future<List<String>> _validateFiles(FilePickerResult? result) async {
    if (result == null || result.files.isEmpty) return [];

    final validPaths = <String>[];
    for (final file in result.files) {
      if (file.path == null || file.path!.isEmpty) continue;
      if (await File(file.path!).exists()) {
        validPaths.add(file.path!);
      }
    }
    return validPaths;
  }
}
