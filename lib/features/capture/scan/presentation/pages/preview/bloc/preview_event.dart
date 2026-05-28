part of 'preview_bloc.dart';

abstract class PreviewEvent {
  const PreviewEvent();
}

@freezed
class PreviewPageChanged extends PreviewEvent with _$PreviewPageChanged {
  const factory PreviewPageChanged({required int pageIndex}) =
      _PreviewPageChanged;
}

@freezed
class PreviewInitialized extends PreviewEvent with _$PreviewInitialized {
  const factory PreviewInitialized({
    required int initialPageIndex,
    @Default([]) List<String> images,
  }) = _PreviewInitialized;
}

@freezed
class PreviewPageRotated extends PreviewEvent with _$PreviewPageRotated {
  const factory PreviewPageRotated({required int pageIndex}) =
      _PreviewPageRotated;
}

@freezed
class PreviewPageDeleted extends PreviewEvent with _$PreviewPageDeleted {
  const factory PreviewPageDeleted({required int pageIndex}) =
      _PreviewPageDeleted;
}

@freezed
class PreviewPagesReordered extends PreviewEvent with _$PreviewPagesReordered {
  const factory PreviewPagesReordered({
    required int oldIndex,
    required int newIndex,
  }) = _PreviewPagesReordered;
}

@freezed
class PreviewReorderModeToggled extends PreviewEvent
    with _$PreviewReorderModeToggled {
  const factory PreviewReorderModeToggled({required bool enabled}) =
      _PreviewReorderModeToggled;
}
