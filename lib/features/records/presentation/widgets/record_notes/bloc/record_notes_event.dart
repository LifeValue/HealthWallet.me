part of 'record_notes_bloc.dart';

abstract class RecordNotesEvent {
  const RecordNotesEvent();
}

@freezed
abstract class RecordNotesInitialised extends RecordNotesEvent
    with _$RecordNotesInitialised {
  const RecordNotesInitialised._();

  const factory RecordNotesInitialised({required IFhirResource resource}) =
      _RecordNotesInitialised;
}

@freezed
abstract class RecordNotesInputInitialised extends RecordNotesEvent
    with _$RecordNotesInputInitialised {
  const RecordNotesInputInitialised._();

  const factory RecordNotesInputInitialised({RecordNote? editNote}) =
      _RecordNotesInputInitialised;
}

@freezed
abstract class RecordNotesInputCanceled extends RecordNotesEvent
    with _$RecordNotesInputCanceled {
  const RecordNotesInputCanceled._();

  const factory RecordNotesInputCanceled() = _RecordNotesInputCanceled;
}

@freezed
abstract class RecordNotesInputDone extends RecordNotesEvent
    with _$RecordNotesInputDone {
  const RecordNotesInputDone._();

  const factory RecordNotesInputDone({required String content}) =
      _RecordNotesInputDone;
}

@freezed
abstract class RecordNotesNoteDeleted extends RecordNotesEvent
    with _$RecordNotesNoteDeleted {
  const RecordNotesNoteDeleted._();

  const factory RecordNotesNoteDeleted({required RecordNote note}) =
      _RecordNotesNoteDeleted;
}
