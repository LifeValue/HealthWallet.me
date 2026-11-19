import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/features/onboarding/presentation/bloc/onboarding_bloc.dart';

import '../../../../helpers/log_capture.dart';

void main() {
  final logs = captureLogs();
  final strings = AppStringsProvider();
  final couldNotOpen = strings.l10n.couldNotOpenLink;

  late List<Uri> opened;

  OnboardingBloc blocOpening(Future<bool> Function(Uri) open) {
    final bloc = OnboardingBloc(
      strings,
      openLink: (url) {
        opened.add(url);
        return open(url);
      },
    );
    addTearDown(bloc.close);
    return bloc;
  }

  setUp(() => opened = []);

  Future<OnboardingState> run(
    OnboardingBloc bloc,
    OnboardingEvent event,
  ) async {
    bloc.add(event);
    await pumpEventQueue();
    return bloc.state;
  }

  group('pages', () {
    test('next and previous stay within the four pages', () async {
      final bloc = blocOpening((_) async => true);

      for (var i = 0; i < 5; i++) {
        await run(bloc, const OnboardingNextPage());
      }
      expect(bloc.state.currentPage, 3);

      for (var i = 0; i < 5; i++) {
        await run(bloc, const OnboardingPreviousPage());
      }
      expect(bloc.state.currentPage, 0);
    });

    test('a swipe sets the page', () async {
      final bloc = blocOpening((_) async => true);

      expect((await run(bloc, const OnboardingPageChanged(2))).currentPage, 2);
    });
  });

  group('links', () {
    test('an opened link reports success and no error', () async {
      final bloc = blocOpening((_) async => true);

      final state = await run(
        bloc,
        const OnboardingLaunchUrl('https://healthwallet.me'),
      );

      expect(opened, [Uri.parse('https://healthwallet.me')]);
      expect(state.urlLaunchSuccess, isTrue);
      expect(state.isLaunchingUrl, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('a link nothing can open says so', () async {
      final bloc = blocOpening((_) async => false);

      final state = await run(
        bloc,
        const OnboardingLaunchUrl('https://healthwallet.me'),
      );

      expect(state.urlLaunchSuccess, isFalse);
      expect(state.errorMessage, couldNotOpen);
      expect(logs, loggedWarning('Nothing could open the onboarding link'));
    });

    test('a failing opener says so and is logged', () async {
      final bloc = blocOpening((_) async => throw StateError('no browser'));

      final state = await run(
        bloc,
        const OnboardingLaunchUrl('https://healthwallet.me'),
      );

      expect(state.errorMessage, couldNotOpen);
      expect(logs, loggedWarning('Opening the onboarding link failed'));
    });

    test('each failed attempt is a new error, so it is shown again', () async {
      final bloc = blocOpening((_) async => false);
      final errors = <String?>[];
      final sub = bloc.stream.listen((s) => errors.add(s.errorMessage));

      await run(bloc, const OnboardingLaunchUrl('https://healthwallet.me'));
      await run(bloc, const OnboardingLaunchUrl('https://healthwallet.me'));
      await sub.cancel();

      expect(errors, [null, couldNotOpen, null, couldNotOpen]);
    });

    test('a page change after a failure does not repeat the error', () async {
      final bloc = blocOpening((_) async => false);
      await run(bloc, const OnboardingLaunchUrl('https://healthwallet.me'));

      final state = await run(bloc, const OnboardingNextPage());

      // The screen shows an error only when it changes (see
      // OnboardingScreen), so an unchanged message is not shown again.
      expect(state.errorMessage, couldNotOpen);
    });
  });
}
