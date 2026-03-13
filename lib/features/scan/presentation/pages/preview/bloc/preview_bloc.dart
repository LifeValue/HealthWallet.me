import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter/painting.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/scan/presentation/pages/preview/image_rotation_utils.dart';

part 'preview_bloc.freezed.dart';
part 'preview_event.dart';
part 'preview_state.dart';

class PreviewBloc extends Bloc<PreviewEvent, PreviewState> {
  PreviewBloc() : super(const PreviewState()) {
    on<PreviewPageChanged>(_onPageChanged);
    on<PreviewInitialized>(_onInitialized);
    on<PreviewPageRotated>(_onPageRotated);
    on<PreviewPageDeleted>(_onPageDeleted);
    on<PreviewPagesReordered>(_onPagesReordered);
    on<PreviewReorderModeToggled>(_onReorderModeToggled);
  }

  void _onPageChanged(
    PreviewPageChanged event,
    Emitter<PreviewState> emit,
  ) {
    emit(state.copyWith(currentPageIndex: event.pageIndex));
  }

  void _onInitialized(
    PreviewInitialized event,
    Emitter<PreviewState> emit,
  ) {
    emit(state.copyWith(
      currentPageIndex: event.initialPageIndex,
      images: List.of(event.images),
    ));
  }

  Future<void> _onPageRotated(
    PreviewPageRotated event,
    Emitter<PreviewState> emit,
  ) async {
    if (state.isRotating) return;
    emit(state.copyWith(isRotating: true));

    try {
      final imagePath = state.images[event.pageIndex];
      await rotateImage90CW(imagePath);
      imageCache.evict(FileImage(File(imagePath)));
      emit(state.copyWith(isRotating: false, hasChanges: true));
    } catch (_) {
      emit(state.copyWith(isRotating: false));
    }
  }

  void _onPageDeleted(
    PreviewPageDeleted event,
    Emitter<PreviewState> emit,
  ) {
    if (state.images.length <= 1) return;

    final updatedImages = List<String>.from(state.images)
      ..removeAt(event.pageIndex);
    final newIndex = event.pageIndex >= updatedImages.length
        ? updatedImages.length - 1
        : event.pageIndex;

    emit(state.copyWith(
      images: updatedImages,
      currentPageIndex: newIndex,
      hasChanges: true,
    ));
  }

  void _onPagesReordered(
    PreviewPagesReordered event,
    Emitter<PreviewState> emit,
  ) {
    final updatedImages = List<String>.from(state.images);
    final item = updatedImages.removeAt(event.oldIndex);
    updatedImages.insert(event.newIndex, item);

    emit(state.copyWith(
      images: updatedImages,
      hasChanges: true,
    ));
  }

  void _onReorderModeToggled(
    PreviewReorderModeToggled event,
    Emitter<PreviewState> emit,
  ) {
    emit(state.copyWith(
      isReordering: event.enabled,
      currentPageIndex: event.enabled ? state.currentPageIndex : 0,
    ));
  }
}
