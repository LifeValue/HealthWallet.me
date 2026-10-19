part of 'desktop_bloc.dart';

@freezed
class DesktopState with _$DesktopState {
  const factory DesktopState({
    @Default(false) bool isImporting,
    String? error,
  }) = _DesktopState;
}
