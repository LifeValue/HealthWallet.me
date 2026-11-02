import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/home/presentation/sections/recent_records_section.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';

class _MockUserBloc extends MockBloc<UserEvent, UserState>
    implements UserBloc {}

void main() {
  setUpAll(initializeDateFormatting);

  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<void> pump(
    WidgetTester tester,
    List<IFhirResource> records, {
    RegionPreset region = RegionPreset.europe,
    void Function(dynamic record)? onTapRecord,
  }) async {
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
        home: BlocProvider<UserBloc>.value(
          value: userBloc,
          child: Scaffold(
            body: SingleChildScrollView(
              child: RecentRecordsSection(
                recentRecords: records,
                onTapRecord: onTapRecord,
              ),
            ),
          ),
        ),
      ),
    );
  }

  final condition = entityFromJson(conditionJson());
  final weight = entityFromJson(
    observationJson(
      code: '29463-7',
      codeDisplay: 'Body Weight',
      value: {'valueQuantity': quantity(70, unit: 'kg')},
    ),
  );

  testWidgets('a card shows the record type, title and its first info line', (
    tester,
  ) async {
    await pump(tester, [condition]);

    final first = condition
        .additionalInfoIn(RegionPreset.europe, l10n)
        .first
        .info;
    expect(find.text(l10n.condition), findsOne);
    expect(find.text(condition.displayTitle), findsOne);
    expect(find.text(first), findsOne);
  });

  testWidgets('an observation card reads its first line in the user\'s '
      'region', (tester) async {
    await pump(tester, [weight], region: RegionPreset.us);

    final first = weight.additionalInfoIn(RegionPreset.us, l10n).first.info;
    expect(find.text(first), findsOne);
    expect(find.text(weight.displayTitle), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one card per record, and a tap reports the record', (
    tester,
  ) async {
    final tapped = <dynamic>[];
    await pump(tester, [condition, weight], onTapRecord: tapped.add);

    expect(find.text(condition.displayTitle), findsOne);
    expect(find.text(weight.displayTitle), findsOne);

    await tester.tap(find.text(weight.displayTitle));
    expect(tapped, [weight]);
  });
}
