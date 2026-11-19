import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/data/data_source/local/sync_local_data_source.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';

/// Records the Patients and Observations the service writes, and answers
/// blood type reads from [bloodTypeObservations].
class FakeEditRecords extends Fake implements RecordsRepository {
  final updated = <Patient>[];
  final saved = <IFhirResource>[];
  final bloodTypeReads = <({String patientId, String? sourceId})>[];
  List<IFhirResource> bloodTypeObservations = [];
  Exception? bloodTypeReadError;

  @override
  Future<void> updatePatient(IFhirResource patient) async {
    updated.add(patient as Patient);
  }

  @override
  Future<List<IFhirResource>> getBloodTypeObservations({
    required String patientId,
    String? sourceId,
  }) async {
    bloodTypeReads.add((patientId: patientId, sourceId: sourceId));
    if (bloodTypeReadError case final error?) throw error;
    return bloodTypeObservations;
  }

  @override
  Future<String> saveObservation(IFhirResource observation) async {
    saved.add(observation);
    return observation.id;
  }
}

class FakeEditSyncLocalDataSource extends Fake implements SyncLocalDataSource {}

/// The people in [directory]; every holder writes to [walletSource] and
/// keeps blood types on [walletPatient].
class FakeEditHolders extends Fake implements HolderService {
  HolderDirectory directory = const HolderDirectory();
  Source walletSource = const Source(id: 'wallet-new');
  Patient walletPatient = const Patient();
  Error? walletPatientError;
  final walletSourceRequests = <String>[];
  final walletPatientRequests = <String>[];

  @override
  Future<HolderDirectory> load() async => directory;

  @override
  Future<Source> walletSourceOf(String holderId) async {
    walletSourceRequests.add(holderId);
    return walletSource;
  }

  @override
  Future<({Patient patient, String holderId})> walletPatientOf(
    String patientId, {
    Object? scanned,
  }) async {
    walletPatientRequests.add(patientId);
    if (walletPatientError case final error?) throw error;
    return (patient: walletPatient, holderId: patientId);
  }
}
