part of 'preview_bloc.dart';

@freezed
class PreviewState with _$PreviewState {
  const factory PreviewState({
    @Default(0) int currentPageIndex,
    @Default([]) List<String> images,
    @Default(false) bool isReordering,
    @Default(false) bool isRotating,
    @Default(false) bool hasChanges,
  }) = _PreviewState;
}
