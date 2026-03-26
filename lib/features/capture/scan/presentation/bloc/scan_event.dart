part of 'scan_bloc.dart';

@freezed
class ScanEvent with _$ScanEvent {
  const factory ScanEvent.scanPressed({
    @Default(CaptureMode.images) CaptureMode mode,
    @Default(10) int maxPages,
  }) = ScanPressed;
}
