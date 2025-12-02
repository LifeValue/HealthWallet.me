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
  const factory PreviewInitialized({required int initialPageIndex}) =
      _PreviewInitialized;
}

