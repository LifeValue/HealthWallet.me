part of 'scan_bloc.dart';

@freezed
class ScanState with _$ScanState {
  const factory ScanState({
    @Default(false) bool isCapturing,
    String? error,
  }) = _ScanState;
}
