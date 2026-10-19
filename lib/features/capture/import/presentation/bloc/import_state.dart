part of 'import_bloc.dart';

@freezed
class ImportState with _$ImportState {
  const factory ImportState({
    @Default(false) bool isImporting,
    String? error,
  }) = _ImportState;
}
