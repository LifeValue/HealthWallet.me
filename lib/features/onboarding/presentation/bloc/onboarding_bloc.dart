import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

part 'onboarding_bloc.freezed.dart';
part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc() : super(const OnboardingState()) {
    on<OnboardingPageChanged>(_onPageChanged);
    on<OnboardingNextPage>(_onNextPage);
    on<OnboardingPreviousPage>(_onPreviousPage);
    on<OnboardingLaunchUrl>(_onLaunchUrl);
  }

  void _onPageChanged(
      OnboardingPageChanged event, Emitter<OnboardingState> emit) {
    emit(state.copyWith(currentPage: event.page));
  }

  void _onNextPage(OnboardingNextPage event, Emitter<OnboardingState> emit) {
    if (state.currentPage < 3) {
      emit(state.copyWith(currentPage: state.currentPage + 1));
    }
  }

  void _onPreviousPage(
      OnboardingPreviousPage event, Emitter<OnboardingState> emit) {
    if (state.currentPage > 0) {
      emit(state.copyWith(currentPage: state.currentPage - 1));
    }
  }

  Future<void> _onLaunchUrl(
      OnboardingLaunchUrl event, Emitter<OnboardingState> emit) async {
    emit(state.copyWith(isLaunchingUrl: true));

    try {
      final url = Uri.parse(event.url);
      if (await canLaunchUrl(url)) {
        final launched = await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        emit(state.copyWith(
          isLaunchingUrl: false,
          urlLaunchSuccess: launched,
        ));
      } else {
        emit(state.copyWith(
          isLaunchingUrl: false,
          urlLaunchSuccess: false,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLaunchingUrl: false,
        urlLaunchSuccess: false,
        errorMessage: 'Could not open link. Please try again.',
      ));
    }
  }
}
