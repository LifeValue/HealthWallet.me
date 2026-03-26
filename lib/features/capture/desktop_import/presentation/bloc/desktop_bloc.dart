import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:injectable/injectable.dart';

part 'desktop_event.dart';
part 'desktop_state.dart';
part 'desktop_bloc.freezed.dart';

@injectable
class DesktopBloc extends Bloc<DesktopEvent, DesktopState> {
  final ProcessingBloc _processingBloc;

  static const _allowedExtensions = [
    '.pdf', '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff'
  ];

  DesktopBloc(this._processingBloc)
      : super(const DesktopState()) {
    on<DesktopFilesDropped>(_onFilesDropped);
  }

  Future<void> _onFilesDropped(
    DesktopFilesDropped event,
    Emitter<DesktopState> emit,
  ) async {
    emit(state.copyWith(isImporting: true, error: null));

    try {
      final validPaths = <String>[];
      for (final path in event.filePaths) {
        final extension = path.toLowerCase().substring(path.lastIndexOf('.'));
        if (!_allowedExtensions.contains(extension)) continue;
        if (await File(path).exists()) {
          validPaths.add(path);
        }
      }

      if (validPaths.isEmpty) {
        emit(state.copyWith(
          isImporting: false,
          error: 'No valid files found. Supported: PDF, JPG, PNG, TIFF',
        ));
        return;
      }

      debugPrint('[DesktopImport] ${validPaths.length} files dropped');
      _processingBloc.add(DocumentImported(filePaths: validPaths));
      emit(state.copyWith(isImporting: false));
    } catch (e) {
      emit(state.copyWith(isImporting: false, error: e.toString()));
    }
  }
}
