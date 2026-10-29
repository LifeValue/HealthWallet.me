import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/widgets/resource_info_content.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';

class _MockUserBloc extends MockBloc<UserEvent, UserState>
    implements UserBloc {}

IFhirResource _lab(String code, num value, String unit) => entityFromJson(
  observationJson(
    code: code,
    codeDisplay: null,
    value: {'valueQuantity': quantity(value, unit: unit)},
  ),
);

void main() {
  Widget card(IFhirResource resource, {UserBloc? userBloc}) {
    final content = ResourceInfoContent(resource: resource, onTap: () {});
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: userBloc == null
            ? content
            : BlocProvider<UserBloc>.value(value: userBloc, child: content),
      ),
    );
  }

  UserBloc userBloc(RegionPreset region) {
    final bloc = _MockUserBloc();
    final state = UserState(regionPreset: region);
    whenListen(bloc, const Stream<UserState>.empty(), initialState: state);
    return bloc;
  }

  group('ResourceInfoContent', () {
    testWidgets('shows an observation in the region units, like the detail', (
      tester,
    ) async {
      await tester.pumpWidget(
        card(
          _lab('2339-0', 100, 'mg/dL'),
          userBloc: userBloc(RegionPreset.europe),
        ),
      );
      expect(find.text('Value: 5.55 mmol/L'), findsOneWidget);
    });

    testWidgets('shows a non-glucose lab as reported', (tester) async {
      await tester.pumpWidget(
        card(
          _lab('2093-3', 200, 'mg/dL'),
          userBloc: userBloc(RegionPreset.europe),
        ),
      );
      expect(find.text('Value: 200.00 mg/dL'), findsOneWidget);
    });

    testWidgets('shows values as reported without a user bloc', (
      tester,
    ) async {
      await tester.pumpWidget(card(_lab('2339-0', 100, 'mg/dL')));
      expect(find.text('Value: 100.00 mg/dL'), findsOneWidget);
    });
  });
}
