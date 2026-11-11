import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';

void main() {
  // The widgets send these as constants; built at run time (through a
  // constructor tear-off), they must still equal those.
  test('events built at run time equal the constant ones', () {
    final initialised = RecordsInitialised.new;
    final loadMore = RecordsLoadMore.new;
    final sourceChanged = RecordsSourceChanged.new;
    final filtersApplied = RecordsFiltersApplied.new;
    final removed = RecordsFilterRemoved.new;
    final detailLoaded = RecordDetailLoaded.new;
    final loadDemo = LoadDemoData.new;
    final clearDemo = ClearDemoData.new;
    final search = RecordsSearch.new;
    final searchExecuted = RecordsSearchExecuted.new;
    final sharePressed = RecordsSharePressed.new;
    final toggled = RecordsSelectionToggled.new;
    final cleared = RecordsSelectionCleared.new;
    final modeToggled = RecordsSelectionModeToggled.new;
    final datesCleared = RecordsDateRangeCleared.new;
    final deleted = RecordsResourceDeleted.new;
    final specialtyApplied = RecordsSpecialtyApplied.new;

    final pairs = <(RecordsEvent, RecordsEvent)>[
      (initialised(), const RecordsInitialised()),
      (
        initialised(isShareContext: true),
        const RecordsInitialised(isShareContext: true),
      ),
      (loadMore(), const RecordsLoadMore()),
      (
        sourceChanged('src-1', personId: 'p'),
        const RecordsSourceChanged('src-1', personId: 'p'),
      ),
      (
        filtersApplied([FhirType.Condition], remember: false),
        const RecordsFiltersApplied([FhirType.Condition], remember: false),
      ),
      (
        removed(FhirType.Condition),
        const RecordsFilterRemoved(FhirType.Condition),
      ),
      (
        detailLoaded(const Patient(id: 'p')),
        const RecordDetailLoaded(Patient(id: 'p')),
      ),
      (loadDemo(), const LoadDemoData()),
      (clearDemo(), const ClearDemoData()),
      (search('heart'), const RecordsSearch('heart')),
      (searchExecuted('heart'), const RecordsSearchExecuted('heart')),
      (
        sharePressed(patientName: 'Ana', sourceId: 'src-1'),
        const RecordsSharePressed(patientName: 'Ana', sourceId: 'src-1'),
      ),
      (toggled('a'), const RecordsSelectionToggled('a')),
      (cleared(), const RecordsSelectionCleared()),
      (modeToggled(), const RecordsSelectionModeToggled()),
      (datesCleared(), const RecordsDateRangeCleared()),
      (
        deleted(resourceId: 'r', deleteRelated: true),
        const RecordsResourceDeleted(resourceId: 'r', deleteRelated: true),
      ),
      (
        specialtyApplied([MedicalSpecialty.cardiology]),
        const RecordsSpecialtyApplied([MedicalSpecialty.cardiology]),
      ),
    ];

    for (final (built, constant) in pairs) {
      expect(built, constant);
      expect(built.hashCode, constant.hashCode);
    }
  });

  test('events with different values differ', () {
    final removed = RecordsFilterRemoved.new;
    final toggled = RecordsSelectionToggled.new;

    expect(
      removed(FhirType.Condition),
      isNot(const RecordsFilterRemoved(FhirType.Observation)),
    );
    expect(toggled('a'), isNot(const RecordsSelectionToggled('b')));
  });
}
