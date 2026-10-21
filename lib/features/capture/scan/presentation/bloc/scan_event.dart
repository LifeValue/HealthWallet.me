part of 'scan_bloc.dart';

@freezed
abstract class ScanEvent with _$ScanEvent {
  const factory ScanEvent.scanPressed({
    @Default(CaptureMode.images) CaptureMode mode,
    @Default(10) int maxPages,
  }) = ScanPressed;
}
