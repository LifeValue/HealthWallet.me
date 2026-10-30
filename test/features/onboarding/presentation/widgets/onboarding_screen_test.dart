import 'dart:async';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:health_wallet/features/onboarding/presentation/widgets/onboarding_screen.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/gen/assets.gen.dart';

/// Records the events the screen sends instead of running them.
class _MockOnboardingBloc extends MockBloc<OnboardingEvent, OnboardingState>
    implements OnboardingBloc {
  final events = <OnboardingEvent>[];

  @override
  void add(OnboardingEvent event) => events.add(event);
}

class _MockUserBloc extends MockBloc<UserEvent, UserState>
    implements UserBloc {}

void main() {
  late _MockOnboardingBloc onboardingBloc;
  late StreamController<OnboardingState> onboardingStates;

  setUp(() {
    onboardingBloc = _MockOnboardingBloc();
    onboardingStates = StreamController<OnboardingState>();
    whenListen(
      onboardingBloc,
      onboardingStates.stream,
      initialState: const OnboardingState(),
    );
  });

  tearDown(() => onboardingStates.close());

  Future<void> pumpScreen(
    WidgetTester tester, {
    required String subtitle,
    String description = 'Plain description',
    String? content,
    String? bottom,
  }) async {
    final userBloc = _MockUserBloc();
    whenListen(
      userBloc,
      const Stream<UserState>.empty(),
      initialState: const UserState(),
    );
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<UserBloc>.value(value: userBloc),
              BlocProvider<OnboardingBloc>.value(value: onboardingBloc),
            ],
            child: OnboardingScreen(
              title: 'Welcome',
              subtitle: subtitle,
              description: description,
              content: content,
              bottom: bottom,
              image: Assets.onboarding.onboarding1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder errorSnackBar(String message) => find.descendant(
    of: find.byKey(AppSnackBar.cardKey),
    matching: find.text(message),
  );

  /// Lets the queued snackbars time out so no timer is left pending.
  Future<void> drainSnackBars(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('a link in the subtitle opens its page', (tester) async {
    await pumpScreen(tester, subtitle: 'Made by <link>HealthWallet.me</link>.');

    await tester.tapOnText(find.textRange.ofSubstring('HealthWallet.me'));

    expect(onboardingBloc.events, [
      const OnboardingLaunchUrl('https://healthwallet.me'),
    ]);
  });

  testWidgets('a link that fails to open shows its error, from the subtitle '
      'and from the description', (tester) async {
    await pumpScreen(
      tester,
      subtitle: 'Made by <link>HealthWallet.me</link>.',
      description: 'Runs on <link>Fasten</link> on-prem.',
    );

    onboardingStates.add(
      const OnboardingState(errorMessage: 'Could not open the link'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(errorSnackBar('Could not open the link'), findsOne);
    await drainSnackBars(tester);
  });

  testWidgets('a failed link also shows its error next to bullet points', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      subtitle: 'Plain subtitle',
      content: '• Private\n• Offline',
      bottom: '• Yours',
    );
    expect(find.textContaining('Private', findRichText: true), findsOne);

    onboardingStates.add(
      const OnboardingState(errorMessage: 'Could not open the link'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(errorSnackBar('Could not open the link'), findsOne);
    await drainSnackBars(tester);
  });

  testWidgets('no error, no snackbar', (tester) async {
    await pumpScreen(
      tester,
      subtitle: 'Made by <link>HealthWallet.me</link>.',
      description: '• Private',
    );

    onboardingStates.add(const OnboardingState(currentPage: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(AppSnackBar.cardKey), findsNothing);
  });
}
