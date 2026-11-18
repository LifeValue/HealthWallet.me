import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';

part 'onboarding_bloc.freezed.dart';
part 'onboarding_event.dart';
part 'onboarding_state.dart';

/// Opens [url] outside the app; false when nothing could open it.
typedef LinkOpener = Future<bool> Function(Uri url);

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc(this._strings, {LinkOpener? openLink})
    : _openLink = openLink ?? _openExternally,
      super(const OnboardingState()) {
    on<OnboardingPageChanged>(_onPageChanged);
    on<OnboardingNextPage>(_onNextPage);
    on<OnboardingPreviousPage>(_onPreviousPage);
    on<OnboardingLaunchUrl>(_onLaunchUrl);
  }

  final AppStringsProvider _strings;
  final LinkOpener _openLink;

  static Future<bool> _openExternally(Uri url) async =>
      await canLaunchUrl(url) &&
      await launchUrl(url, mode: LaunchMode.externalApplication);

  void _onPageChanged(
    OnboardingPageChanged event,
    Emitter<OnboardingState> emit,
  ) {
    emit(state.copyWith(currentPage: event.page));
  }

  void _onNextPage(OnboardingNextPage event, Emitter<OnboardingState> emit) {
    if (state.currentPage < 3) {
      emit(state.copyWith(currentPage: state.currentPage + 1));
    }
  }

  void _onPreviousPage(
    OnboardingPreviousPage event,
    Emitter<OnboardingState> emit,
  ) {
    if (state.currentPage > 0) {
      emit(state.copyWith(currentPage: state.currentPage - 1));
    }
  }

  /// Opens the link; one that can't be opened sets [OnboardingState.errorMessage]
  /// for this attempt only, so each failure is shown once.
  Future<void> _onLaunchUrl(
    OnboardingLaunchUrl event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(state.copyWith(isLaunchingUrl: true, errorMessage: null));

    var launched = false;
    try {
      launched = await _openLink(Uri.parse(event.url));
      if (!launched) logger.w('Nothing could open the onboarding link');
    } catch (e, s) {
      logger.w('Opening the onboarding link failed', e, s);
    }
    emit(
      state.copyWith(
        isLaunchingUrl: false,
        urlLaunchSuccess: launched,
        errorMessage: launched ? null : _strings.l10n.couldNotOpenLink,
      ),
    );
  }
}
