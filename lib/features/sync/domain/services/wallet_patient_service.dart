import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:injectable/injectable.dart';

@injectable
class WalletPatientService {
  final SyncRepository _syncRepository;

  WalletPatientService(this._syncRepository);

  Future<Source> createWalletSourceForPatient(
    String patientId,
    String patientName,
  ) async {
    final walletSourceId = 'wallet-$patientId';

    final existingSources = await _syncRepository.getSources();
    final existingWalletSource = existingSources
        .where((source) => source.id == walletSourceId)
        .firstOrNull;

    if (existingWalletSource != null) {
      return existingWalletSource;
    }

    final walletSource = Source(
      id: walletSourceId,
      platformName: 'wallet',
      labelSource: 'Wallet - $patientName',
      platformType: 'wallet',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return walletSource;
  }

  Future<List<Source>> getWalletSourcesForPatient(String patientId) async {
    final allSources = await _syncRepository.getSources();
    return allSources
        .where(
          (source) =>
              source.id == 'wallet-$patientId' ||
              (source.platformType == 'wallet' &&
                  source.id.contains(patientId)),
        )
        .toList();
  }

  Future<bool> hasWalletSourceForPatient(String patientId) async {
    final walletSources = await getWalletSourcesForPatient(patientId);
    return walletSources.isNotEmpty;
  }

  Future<Source?> getPrimaryWalletSourceForPatient(String patientId) async {
    final walletSources = await getWalletSourcesForPatient(patientId);
    return walletSources.firstOrNull;
  }

  Future<List<Source>> createWalletSourcesForAllFastenPatients() async {
    final allSources = await _syncRepository.getSources();
    final fastenSources = allSources
        .where((source) => source.platformType == 'fasten')
        .toList();

    final createdWalletSources = <Source>[];

    for (final fastenSource in fastenSources) {
      final patientId = _extractPatientIdFromSourceId(fastenSource.id);
      if (patientId != null) {
        final walletSource = await createWalletSourceForPatient(
          patientId,
          fastenSource.labelSource ?? 'Patient $patientId',
        );
        createdWalletSources.add(walletSource);
      }
    }

    return createdWalletSources;
  }

  String? _extractPatientIdFromSourceId(String sourceId) {
    if (sourceId.startsWith('fasten-')) {
      return sourceId.substring(7);
    }
    return null;
  }
}
