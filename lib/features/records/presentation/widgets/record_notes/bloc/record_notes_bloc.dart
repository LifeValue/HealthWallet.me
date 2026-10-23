import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:injectable/injectable.dart';

part 'record_notes_event.dart';
part 'record_notes_state.dart';
part 'record_notes_bloc.freezed.dart';

@injectable
class RecordNotesBloc extends Bloc<RecordNotesEvent, RecordNotesState> {
  RecordNotesBloc(this._recordsRepository) : super(const RecordNotesState()) {
    on<RecordNotesInitialised>(_onRecordNotesInitialised);
    on<RecordNotesInputInitialised>(_onRecordNotesInputInitialised);
    on<RecordNotesInputCanceled>(_onRecordNotesInputCanceled);
    on<RecordNotesInputDone>(_onRecordNotesInputDone);
    on<RecordNotesNoteDeleted>(_onRecordNotesNoteDeleted);
  }

  final RecordsRepository _recordsRepository;

  Future<void> _onRecordNotesInitialised(
    RecordNotesInitialised event,
    Emitter<RecordNotesState> emit,
  ) async {
    emit(state.copyWith(status: const RecordNotesStatus.loading()));

    try {
      // Get notes for this resource directly
      List<RecordNote> notes =
          await _recordsRepository.getRecordNotes(event.resource.id);

      emit(state.copyWith(
          notes: notes,
          resource: event.resource,
          status: const RecordNotesStatus.success()));
    } catch (e) {
      emit(state.copyWith(status: RecordNotesStatus.error(e)));
    }
  }

  void _onRecordNotesInputInitialised(
    RecordNotesInputInitialised event,
    Emitter<RecordNotesState> emit,
  ) {
    emit(state.copyWith(
      status: const RecordNotesStatus.input(),
      editNote: event.editNote,
    ));
  }

  void _onRecordNotesInputCanceled(
    RecordNotesInputCanceled event,
    Emitter<RecordNotesState> emit,
  ) {
    emit(state.copyWith(
      status: const RecordNotesStatus.success(),
      editNote: null,
    ));
  }

  Future<void> _onRecordNotesInputDone(
    RecordNotesInputDone event,
    Emitter<RecordNotesState> emit,
  ) async {
    emit(state.copyWith(status: const RecordNotesStatus.loading()));

    try {
      if (state.editNote != null) {
        await _recordsRepository
            .editRecordNote(state.editNote!.copyWith(content: event.content));
      } else {
        // Add note directly to the resource
        await _recordsRepository.addRecordNote(
          resourceId: state.resource.id,
          sourceId: state.resource.sourceId,
          content: event.content,
        );
      }

      emit(state.copyWith(
        status: const RecordNotesStatus.success(),
        editNote: null,
        selectedNoteId: null,
        notes: [],
      ));

      add(RecordNotesInitialised(resource: state.resource));
    } catch (e) {
      emit(state.copyWith(status: RecordNotesStatus.error(e)));
    }
  }

  Future<void> _onRecordNotesNoteDeleted(
    RecordNotesNoteDeleted event,
    Emitter<RecordNotesState> emit,
  ) async {
    emit(state.copyWith(status: const RecordNotesStatus.loading()));

    try {
      await _recordsRepository.deleteRecordNote(event.note);

      emit(state.copyWith(
        status: const RecordNotesStatus.success(),
        notes: [],
      ));

      add(RecordNotesInitialised(resource: state.resource));
    } catch (e) {
      emit(state.copyWith(status: RecordNotesStatus.error(e)));
    }
  }
}
