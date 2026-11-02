import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/utils/patient_source_utils.dart';
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';

void main() {
  const jane = Patient(id: 'jane');
  const janeGroup = Holder(
    id: 'jane',
    representativePatient: jane,
    sourceIds: ['s1', 's2'],
    allPatientInstances: [jane],
  );
  const loaded = PatientState(
    status: PatientStatus.success(),
    selectedPatientId: 'jane',
    patientGroups: {'jane': janeGroup},
  );

  String describe(({String? sourceId, List<String>? sourceIds}) scope) =>
      '${scope.sourceId}|${scope.sourceIds?.join(',')}';

  test('a source picked on Home wins', () {
    expect(describe(PatientSourceUtils.recordsScope('s3', loaded)), 's3|null');
  });

  test('all sources means the selected patient\'s sources', () {
    expect(
      describe(PatientSourceUtils.recordsScope('All', loaded)),
      'null|s1,s2',
    );
  });

  test('before the patients load, nothing matches', () {
    expect(
      describe(PatientSourceUtils.recordsScope('All', const PatientState())),
      'null|',
    );
  });

  test('reloading the patients keeps the scope they had', () {
    final reloading = loaded.copyWith(status: const PatientStatus.loading());

    expect(
      describe(PatientSourceUtils.recordsScope('All', reloading)),
      'null|s1,s2',
    );
  });

  test('a selected patient without a group matches nothing', () {
    final unknown = loaded.copyWith(selectedPatientId: 'tom');

    expect(
      describe(PatientSourceUtils.recordsScope('All', unknown)),
      'null|',
    );
  });

  test('with no patients at all, every record shows', () {
    const none = PatientState(status: PatientStatus.success());

    expect(
      describe(PatientSourceUtils.recordsScope('All', none)),
      'null|null',
    );
  });
}
