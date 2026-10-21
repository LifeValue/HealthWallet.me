part of 'desktop_bloc.dart';

@freezed
abstract class DesktopEvent with _$DesktopEvent {
  const factory DesktopEvent.filesDropped({
    required List<String> filePaths,
  }) = DesktopFilesDropped;
}
