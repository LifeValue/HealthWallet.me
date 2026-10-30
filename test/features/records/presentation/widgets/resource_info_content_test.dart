import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/widgets/resource_info_content.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';

class _MockUserBloc extends MockBloc<UserEvent, UserState>
    implements UserBloc {}

void main() {
  setUpAll(initializeDateFormatting);

  IFhirResource weightOf(num value, String unit) => entityFromJson(
    observationJson(
      code: '29463-7',
      codeDisplay: 'Body Weight',
      value: {'valueQuantity': quantity(value, unit: unit)},
    ),
  );
  final weight = weightOf(70, 'kg');

  Future<void> pump(
    WidgetTester tester,
    IFhirResource resource, {
    RegionPreset region = RegionPreset.europe,
    VoidCallback? onTap,
    int maxInfoLines = 2,
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
            body: ResourceInfoContent(
              resource: resource,
              onTap: onTap,
              maxInfoLines: maxInfoLines,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows a weight in pounds for a user in the US', (tester) async {
    await pump(tester, weight, region: RegionPreset.us);

    expect(find.text('Value: 154.32 lbs'), findsOne);
    expect(find.textContaining('kg'), findsNothing);
  });

  testWidgets('shows a weight recorded in pounds in kilograms for a user in '
      'Europe', (tester) async {
    await pump(tester, weightOf(200, 'lbs'));

    expect(find.text('Value: 90.72 kg'), findsOne);
    expect(find.textContaining('lbs'), findsNothing);
  });

  testWidgets('shows the title, skips section headers and keeps to '
      'maxInfoLines', (tester) async {
    await pump(tester, weight, region: RegionPreset.us, maxInfoLines: 1);

    expect(find.text(weight.displayTitle), findsOne);
    expect(find.text('Result'), findsNothing, reason: 'a section header');
    expect(find.text('Value: 154.32 lbs'), findsOne);
    final lines = find.descendant(
      of: find.byType(ResourceInfoContent),
      matching: find.byType(Row),
    );
    expect(lines, findsOne);
  });

  testWidgets('a tap calls onTap', (tester) async {
    var taps = 0;
    await pump(tester, weight, onTap: () => taps++);

    await tester.tap(find.byType(ResourceInfoContent));

    expect(taps, 1);
  });
}
