import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/wallet_pass/domain/repository/wallet_pass_repository.dart';
import 'package:health_wallet/features/wallet_pass/domain/service/emergency_card_builder.dart';
import 'package:health_wallet/features/wallet_pass/presentation/bloc/wallet_pass_bloc.dart';
import 'package:health_wallet/features/wallet_pass/presentation/widgets/wallet_pass_error_listener.dart';

class _FakeCardBuilder extends Fake implements EmergencyCardBuilder {}

class _FakeWalletPassRepository extends Fake implements WalletPassRepository {}

void main() {
  final ro = lookupAppLocalizations(const Locale('ro'));
  late WalletPassBloc bloc;

  setUp(() {
    bloc = WalletPassBloc(
      _FakeCardBuilder(),
      _FakeWalletPassRepository(),
      AppStringsProvider.forLocale(const Locale('ro')),
    );
  });

  tearDown(() => bloc.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: MaterialApp(
          locale: const Locale('ro'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => WalletPassErrorListener(child: child!),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
  }

  // Emitting directly drives the listener without building a pass.
  Future<void> emit(WidgetTester tester, WalletPassState state) async {
    // ignore: invalid_use_of_visible_for_testing_member
    bloc.emit(state);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a failure shows the message the bloc carries', (tester) async {
    await pump(tester);

    await emit(
      tester,
      const WalletPassState(
        status: WalletPassStatus.failure,
        errorMessage: 'Mesaj tradus',
      ),
    );

    expect(find.text('Mesaj tradus'), findsOneWidget);
  });

  testWidgets('a failure without a message shows the generic one', (
    tester,
  ) async {
    await pump(tester);

    await emit(
      tester,
      const WalletPassState(status: WalletPassStatus.failure),
    );

    expect(find.text(ro.walletPassFailed), findsOneWidget);
  });

  testWidgets('a pass handed to the wallet shows nothing', (tester) async {
    await pump(tester);

    await emit(tester, const WalletPassState(status: WalletPassStatus.loading));
    await emit(
      tester,
      const WalletPassState(status: WalletPassStatus.passAddedToWallet),
    );

    expect(find.byType(SnackBar), findsNothing);
  });
}
