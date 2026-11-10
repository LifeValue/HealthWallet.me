import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/constants/blood_types.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_edit_service.dart';

const tomAtEpic = Patient(
  id: 'tom-epic',
  resourceId: 'tom-epic',
  sourceId: 'epic',
);
const tomWallet = Patient(
  id: 'tom-w',
  resourceId: 'tom-w',
  sourceId: 'wallet-tom',
);

class _FakeHolders extends Fake implements HolderService {
  @override
  Future<({Patient patient, String holderId})> walletPatientOf(
    String patientId, {
    Object? scanned,
  }) async => (patient: tomWallet, holderId: 'tom');
}

class _FakeRecords extends Fake implements RecordsRepository {
  final saved = <IFhirResource>[];

  @override
  Future<List<IFhirResource>> getBloodTypeObservations({
    required String patientId,
    String? sourceId,
  }) async => [];

  @override
  Future<String> saveObservation(IFhirResource observation) async {
    saved.add(observation);
    return observation.id;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("a blood type for a provider's patient goes on the person's wallet "
      'Patient, in their wallet source', () async {
    final records = _FakeRecords();
    final service = PatientEditService(
      records,
      const SourceTypeService(),
      _FakeHolders(),
    );

    await service.updateBloodTypeObservation(
      tomAtEpic,
      BloodTypes.getAllBloodTypes().first,
    );

    final observation = records.saved.single;
    expect(observation.sourceId, 'wallet-tom');
    expect(observation.rawResource['subject']?['reference'], 'Patient/tom-w');
  });
}
