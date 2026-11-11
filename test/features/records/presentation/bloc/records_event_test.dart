import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';

void main() {
  // The widgets send these as constants; built at run time (through a
  // constructor tear-off), they must still equal those.
  test('events built at run time equal the constant ones', () {
    final removed = RecordsFilterRemoved.new;
    final toggled = RecordsSelectionToggled.new;
    final loadDemo = LoadDemoData.new;
    final clearDemo = ClearDemoData.new;
    final cleared = RecordsSelectionCleared.new;

    expect(
      removed(FhirType.Condition),
      const RecordsFilterRemoved(FhirType.Condition),
    );
    expect(
      removed(FhirType.Condition),
      isNot(const RecordsFilterRemoved(FhirType.Observation)),
    );
    expect(toggled('a'), const RecordsSelectionToggled('a'));
    expect(toggled('a'), isNot(const RecordsSelectionToggled('b')));
    expect(loadDemo(), const LoadDemoData());
    expect(clearDemo(), const ClearDemoData());
    expect(cleared(), const RecordsSelectionCleared());
    expect(
      [removed(FhirType.Condition), toggled('a'), loadDemo(), cleared()],
      everyElement(isA<RecordsEvent>()),
    );
  });
}
