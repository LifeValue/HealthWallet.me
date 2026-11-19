import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/sync/presentation/widgets/sync_error_listener.dart';
import 'package:health_wallet/features/user/domain/services/default_patient_service.dart';

class _FakeSyncRepository extends Fake implements SyncRepository {}

class _FakeRecordsRepository extends Fake implements RecordsRepository {}

class _FakeDefaultPatientService extends Fake
    implements DefaultPatientService {}

void main() {
  late SyncBloc bloc;

  setUp(() {
    bloc = SyncBloc(
      _FakeSyncRepository(),
      _FakeRecordsRepository(),
      _FakeDefaultPatientService(),
      AppStringsProvider.forLocale(const Locale('en')),
    );
  });

  tearDown(() => bloc.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: const MaterialApp(
          home: SyncErrorListener(child: Scaffold(body: SizedBox.shrink())),
        ),
      ),
    );
  }

  // Emitting directly drives the listener without running a sync.
  Future<void> emit(WidgetTester tester, SyncState state) async {
    // ignore: invalid_use_of_visible_for_testing_member
    bloc.emit(state);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a sync error is shown', (tester) async {
    await pump(tester);

    await emit(tester, const SyncState(errorMessage: 'Connection failed.'));

    expect(find.text('Connection failed.'), findsOneWidget);
  });

  testWidgets('clearing the error shows nothing', (tester) async {
    await pump(tester);

    await emit(tester, const SyncState(isLoading: true));
    await emit(tester, const SyncState());

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('the same error is not shown again on other changes', (
    tester,
  ) async {
    await pump(tester);
    await emit(tester, const SyncState(errorMessage: 'Connection failed.'));
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold)),
    ).removeCurrentSnackBar();
    await tester.pumpAndSettle();

    await emit(
      tester,
      const SyncState(errorMessage: 'Connection failed.', hasDemoData: true),
    );

    expect(find.byType(SnackBar), findsNothing);
  });
}
