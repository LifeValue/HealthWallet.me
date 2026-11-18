import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/ips_export_error_listener.dart';

class _FakeRecordsRepository extends Fake implements RecordsRepository {}

class _FakeSpecialtyClassifier extends Fake implements SpecialtyClassifier {}

void main() {
  late RecordsBloc bloc;

  setUp(() {
    bloc = RecordsBloc(_FakeRecordsRepository(), _FakeSpecialtyClassifier());
  });

  tearDown(() => bloc.close());

  Future<void> pump(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => IpsExportErrorListener(child: child!),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
  }

  // Emitting directly drives the listener without running an export.
  Future<void> emitStatus(WidgetTester tester, IpsExportStatus status) async {
    // ignore: invalid_use_of_visible_for_testing_member
    bloc.emit(bloc.state.copyWith(ipsExportStatus: status));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a failed export shows the translated message', (tester) async {
    final ro = lookupAppLocalizations(const Locale('ro'));
    await pump(tester, const Locale('ro'));

    await emitStatus(tester, IpsExportStatus.exporting);
    expect(find.byType(SnackBar), findsNothing);

    await emitStatus(tester, IpsExportStatus.failed);

    expect(find.text(ro.ipsExportFailed), findsOneWidget);
  });

  testWidgets('a successful export shows nothing', (tester) async {
    await pump(tester, const Locale('en'));

    await emitStatus(tester, IpsExportStatus.exporting);
    await emitStatus(tester, IpsExportStatus.idle);

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('other state changes do not repeat the message', (tester) async {
    final en = lookupAppLocalizations(const Locale('en'));
    await pump(tester, const Locale('en'));
    await emitStatus(tester, IpsExportStatus.failed);
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold)),
    ).removeCurrentSnackBar();
    await tester.pumpAndSettle();

    // ignore: invalid_use_of_visible_for_testing_member
    bloc.emit(bloc.state.copyWith(searchQuery: 'x'));
    await tester.pump();
    await tester.pump();

    expect(find.text(en.ipsExportFailed), findsNothing);
  });
}
