part of 'onboarding_bloc.dart';

abstract class OnboardingEvent {
  const OnboardingEvent();
}

@freezed
abstract class OnboardingPageChanged extends OnboardingEvent
    with _$OnboardingPageChanged {
  const OnboardingPageChanged._();

  const factory OnboardingPageChanged(int page) = _OnboardingPageChanged;
}

@freezed
abstract class OnboardingNextPage extends OnboardingEvent with _$OnboardingNextPage {
  const OnboardingNextPage._();

  const factory OnboardingNextPage() = _OnboardingNextPage;
}

@freezed
abstract class OnboardingPreviousPage extends OnboardingEvent
    with _$OnboardingPreviousPage {
  const OnboardingPreviousPage._();

  const factory OnboardingPreviousPage() = _OnboardingPreviousPage;
}

@freezed
abstract class OnboardingLaunchUrl extends OnboardingEvent with _$OnboardingLaunchUrl {
  const OnboardingLaunchUrl._();

  const factory OnboardingLaunchUrl(String url) = _OnboardingLaunchUrl;
}
