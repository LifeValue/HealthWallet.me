import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/pdf_preview_service.dart';
import 'package:health_wallet/core/widgets/custom_app_bar.dart';
import 'package:health_wallet/features/home/data/services/specialty_classifier_impl.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/pages/record_detail_page.dart';
import 'package:health_wallet/features/records/presentation/widgets/delete_record_dialog.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';

/// Answers what the record page asks and records every deletion.
class _FakeRecordsRepository extends Fake implements RecordsRepository {
  _FakeRecordsRepository({
    this.related = const [],
    this.relatedForDeletion = const [],
  });

  final List<IFhirResource> related;
  final List<IFhirResource> relatedForDeletion;
  final deletedIds = <List<String>>[];

  @override
  Future<List<IFhirResource>> getRelatedResources({
    required IFhirResource resource,
  }) async => related;

  @override
  Future<List<IFhirResource>> getRelatedResourcesForEncounter({
    required String encounterId,
    String? sourceId,
  }) async => related;

  @override
  Future<List<IFhirResource>> getRelatedResourcesForDeletion(
    String resourceId,
  ) async => relatedForDeletion;

  @override
  Future<void> deleteResource(String resourceId) async =>
      deletedIds.add([resourceId]);

  @override
  Future<void> deleteResourcesByIds(List<String> ids) async =>
      deletedIds.add(ids);

  @override
  Future<List<IFhirResource>> getResources({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 20,
    int offset = 0,
    DateFilter? dateFilter,
  }) async => [];
}

/// The app-wide records bloc, keeping every event the page sends it.
class _RecordingRecordsBloc extends RecordsBloc {
  _RecordingRecordsBloc(RecordsRepository repository)
    : super(repository, SpecialtyClassifierImpl());

  final events = <RecordsEvent>[];

  @override
  void add(RecordsEvent event) {
    events.add(event);
    super.add(event);
  }
}

class _MockUserBloc extends MockBloc<UserEvent, UserState>
    implements UserBloc {}

class _FakePdfPreviewService extends Fake implements PdfPreviewService {}

/// Records the page closing itself after a delete.
class _FakeStackRouter extends Fake implements StackRouter {
  var pops = 0;

  @override
  Future<bool> maybePop<T extends Object?>([T? result]) async {
    pops++;
    return true;
  }
}

void main() {
  setUpAll(initializeDateFormatting);

  final l10n = lookupAppLocalizations(const Locale('en'));

  IFhirResource weight(String id, num value, String unit) => entityFromJson(
    observationJson(
      id: id,
      code: '29463-7',
      codeDisplay: 'Body Weight',
      value: {'valueQuantity': quantity(value, unit: unit)},
    ),
  );

  const relatedForDeletion = <IFhirResource>[
    Encounter(id: 'enc-1', title: 'General examination'),
    Observation(id: 'obs-1', title: 'Blood Pressure'),
    Observation(id: 'obs-2', title: 'Blood Glucose'),
  ];

  late _FakeStackRouter router;
  late _RecordingRecordsBloc appBloc;
  late _FakeRecordsRepository repository;

  tearDown(getIt.reset);

  Future<void> pumpPage(
    WidgetTester tester, {
    IFhirResource? resource,
    List<IFhirResource> related = const [],
    List<IFhirResource> forDeletion = const [],
    RegionPreset region = RegionPreset.europe,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await getIt.reset();
    repository = _FakeRecordsRepository(
      related: related,
      relatedForDeletion: forDeletion,
    );
    getIt
      ..registerSingleton<PdfPreviewService>(_FakePdfPreviewService())
      ..registerSingleton<SpecialtyClassifier>(SpecialtyClassifierImpl())
      ..registerFactory<RecordsBloc>(
        () => RecordsBloc(repository, SpecialtyClassifierImpl()),
      );
    appBloc = _RecordingRecordsBloc(repository);
    // Not awaited: close() waits for handlers the fake async zone never
    // finishes.
    addTearDown(() => unawaited(appBloc.close()));
    router = _FakeStackRouter();
    final userBloc = _MockUserBloc();
    whenListen(
      userBloc,
      const Stream<UserState>.empty(),
      initialState: UserState(regionPreset: region),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<RecordsBloc>.value(value: appBloc),
              BlocProvider<UserBloc>.value(value: userBloc),
            ],
            child: RecordDetailsPage(
              resource:
                  resource ??
                  const Observation(id: 'obs-main', title: 'Medical Report'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder trashButton() => find
      .descendant(
        of: find.byType(CustomAppBar),
        matching: find.byType(IconButton),
      )
      .last;

  List<RecordsResourceDeleted> deletions() =>
      appBloc.events.whereType<RecordsResourceDeleted>().toList();

  group('values in the user\'s region', () {
    testWidgets('the record and its related records show a weight in pounds '
        'for a user in the US', (tester) async {
      await pumpPage(
        tester,
        resource: weight('obs-w1', 70, 'kg'),
        related: [weight('obs-w2', 70, 'kg')],
        region: RegionPreset.us,
      );

      expect(find.text(l10n.relatedResources), findsOne);
      // Once in the record's card, once under its related records.
      expect(find.text('Value: 154.32 lbs'), findsNWidgets(2));
      expect(find.textContaining(' kg'), findsNothing);
    });

    testWidgets('a weight recorded in pounds shows in kilograms in Europe', (
      tester,
    ) async {
      await pumpPage(
        tester,
        resource: weight('obs-w1', 200, 'lbs'),
        related: [weight('obs-w2', 200, 'lbs')],
      );

      expect(find.text('Value: 90.72 kg'), findsNWidgets(2));
      expect(find.textContaining('lbs'), findsNothing);
    });
  });

  group('delete', () {
    testWidgets('a record with related records opens DeleteRecordDialog; the '
        'two ticked go with it after the confirmation', (tester) async {
      await pumpPage(tester, forDeletion: relatedForDeletion);

      await tester.tap(trashButton());
      await tester.pumpAndSettle();

      expect(find.byType(DeleteRecordDialog), findsOne);
      expect(find.text(l10n.deleteRecordOfType('Medical Report')), findsOne);
      expect(find.text('General examination'), findsOne);

      await tester.tap(find.text('General examination'));
      await tester.tap(find.text('Blood Glucose'));
      await tester.pump();
      await tester.tap(find.byKey(DeleteRecordDialog.deleteKey));
      await tester.pumpAndSettle();

      expect(find.byType(DeleteRecordDialog), findsNothing);
      expect(find.text(l10n.deleteRecordsConfirm(3)), findsOne);
      expect(find.text(l10n.actionCannotBeUndone), findsOne);
      expect(deletions(), isEmpty, reason: 'nothing before the confirmation');

      await tester.tap(find.text(l10n.deletePage).last);
      await tester.pumpAndSettle();

      expect(deletions(), hasLength(1));
      expect(deletions().single.resourceId, 'obs-main');
      expect(
        deletions().single.selectedRelatedIds,
        unorderedEquals(['enc-1', 'obs-2']),
      );
      expect(repository.deletedIds.single, [
        'obs-main',
        ...deletions().single.selectedRelatedIds,
      ]);
      expect(router.pops, 1, reason: 'the page closes after the delete');
    });

    testWidgets('Delete with nothing ticked deletes only the record', (
      tester,
    ) async {
      await pumpPage(tester, forDeletion: relatedForDeletion);

      await tester.tap(trashButton());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(DeleteRecordDialog.deleteKey));
      await tester.pumpAndSettle();

      expect(find.text(l10n.deleteRecordConfirm), findsOne);
      await tester.tap(find.text(l10n.deletePage).last);
      await tester.pumpAndSettle();

      expect(deletions().single.resourceId, 'obs-main');
      expect(deletions().single.selectedRelatedIds, isEmpty);
      expect(repository.deletedIds.single, ['obs-main']);
    });

    for (final (name, key) in [
      ('Cancel', DeleteRecordDialog.cancelKey),
      ('the close button', DeleteRecordDialog.closeKey),
    ]) {
      testWidgets('$name in DeleteRecordDialog deletes nothing and asks '
          'nothing more', (tester) async {
        await pumpPage(tester, forDeletion: relatedForDeletion);

        await tester.tap(trashButton());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Blood Pressure'));
        await tester.pump();
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();

        expect(find.byType(DeleteRecordDialog), findsNothing);
        expect(find.text(l10n.deleteRecordConfirm), findsNothing);
        expect(find.text(l10n.deleteRecordsConfirm(2)), findsNothing);
        expect(deletions(), isEmpty);
        expect(repository.deletedIds, isEmpty);
        expect(router.pops, 0);
      });
    }

    testWidgets('cancelling the confirmation deletes nothing', (tester) async {
      await pumpPage(tester, forDeletion: relatedForDeletion);

      await tester.tap(trashButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blood Pressure'));
      await tester.pump();
      await tester.tap(find.byKey(DeleteRecordDialog.deleteKey));
      await tester.pumpAndSettle();
      expect(find.text(l10n.deleteRecordsConfirm(2)), findsOne);

      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      expect(deletions(), isEmpty);
      expect(router.pops, 0);
    });

    testWidgets('a record without related records goes straight to "Are you '
        'sure?"', (tester) async {
      await pumpPage(tester);

      await tester.tap(trashButton());
      await tester.pumpAndSettle();

      expect(find.byType(DeleteRecordDialog), findsNothing);
      expect(find.text(l10n.deleteRecordConfirm), findsOne);

      await tester.tap(find.text(l10n.deletePage).last);
      await tester.pumpAndSettle();

      expect(deletions().single.resourceId, 'obs-main');
      expect(deletions().single.selectedRelatedIds, isEmpty);
      expect(repository.deletedIds.single, ['obs-main']);
      expect(router.pops, 1);
    });
  });
}
