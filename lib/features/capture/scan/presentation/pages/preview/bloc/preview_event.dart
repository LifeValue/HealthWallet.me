part of 'preview_bloc.dart';

abstract class PreviewEvent {
  const PreviewEvent();
}

@freezed
abstract class PreviewPageChanged extends PreviewEvent with _$PreviewPageChanged {
  const PreviewPageChanged._();

  const factory PreviewPageChanged({required int pageIndex}) =
      _PreviewPageChanged;
}

@freezed
abstract class PreviewInitialized extends PreviewEvent with _$PreviewInitialized {
  const PreviewInitialized._();

  const factory PreviewInitialized({
    required int initialPageIndex,
    @Default([]) List<String> images,
  }) = _PreviewInitialized;
}

@freezed
abstract class PreviewPageRotated extends PreviewEvent with _$PreviewPageRotated {
  const PreviewPageRotated._();

  const factory PreviewPageRotated({required int pageIndex}) =
      _PreviewPageRotated;
}

@freezed
abstract class PreviewPageDeleted extends PreviewEvent with _$PreviewPageDeleted {
  const PreviewPageDeleted._();

  const factory PreviewPageDeleted({required int pageIndex}) =
      _PreviewPageDeleted;
}

@freezed
abstract class PreviewPagesReordered extends PreviewEvent with _$PreviewPagesReordered {
  const PreviewPagesReordered._();

  const factory PreviewPagesReordered({
    required int oldIndex,
    required int newIndex,
  }) = _PreviewPagesReordered;
}

@freezed
abstract class PreviewReorderModeToggled extends PreviewEvent
    with _$PreviewReorderModeToggled {
  const PreviewReorderModeToggled._();

  const factory PreviewReorderModeToggled({required bool enabled}) =
      _PreviewReorderModeToggled;
}
