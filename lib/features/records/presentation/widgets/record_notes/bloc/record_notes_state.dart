part of 'record_notes_bloc.dart';

@freezed
abstract class RecordNotesState with _$RecordNotesState {
  const factory RecordNotesState({
    @Default(RecordNotesStatus.loading()) RecordNotesStatus status,
    @Default(GeneralResource()) IFhirResource resource,
    @Default([]) List<RecordNote> notes,
    @Default('') String content,
    RecordNote? editNote,
    int? selectedNoteId,
  }) = _RecordNotesState;
}

@freezed
sealed class RecordNotesStatus with _$RecordNotesStatus {
  const factory RecordNotesStatus.loading() = _Loading;
  const factory RecordNotesStatus.success() = _Success;
  const factory RecordNotesStatus.error(Object? e) = _Error;
  const factory RecordNotesStatus.input() = _Input;
}
