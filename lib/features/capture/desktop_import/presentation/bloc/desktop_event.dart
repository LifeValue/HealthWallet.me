part of 'desktop_bloc.dart';

@freezed
class DesktopEvent with _$DesktopEvent {
  const factory DesktopEvent.filesDropped({
    required List<String> filePaths,
  }) = DesktopFilesDropped;
}
