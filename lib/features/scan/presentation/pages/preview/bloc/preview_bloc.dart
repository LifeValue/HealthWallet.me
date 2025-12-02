import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'preview_bloc.freezed.dart';
part 'preview_event.dart';
part 'preview_state.dart';

class PreviewBloc extends Bloc<PreviewEvent, PreviewState> {
  PreviewBloc() : super(const PreviewState(currentPageIndex: 0)) {
    on<PreviewPageChanged>(_onPageChanged);
    on<PreviewInitialized>(_onInitialized);
  }

  void _onPageChanged(
    PreviewPageChanged event,
    Emitter<PreviewState> emit,
  ) {
    emit(state.copyWith(currentPageIndex: event.pageIndex));
  }

  void _onInitialized(
    PreviewInitialized event,
    Emitter<PreviewState> emit,
  ) {
    emit(state.copyWith(currentPageIndex: event.initialPageIndex));
  }
}
