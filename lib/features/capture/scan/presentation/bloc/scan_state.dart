part of 'scan_bloc.dart';

@freezed
abstract class ScanState with _$ScanState {
  const factory ScanState({
    @Default(false) bool isCapturing,
    String? error,
  }) = _ScanState;
}
