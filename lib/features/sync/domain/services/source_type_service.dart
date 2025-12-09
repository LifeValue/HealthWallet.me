import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/services/wallet_patient_service.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:injectable/injectable.dart';

@injectable
class SourceTypeService {
  final WalletPatientService _walletPatientService;
  final SyncRepository _syncRepository;

  SourceTypeService(this._walletPatientService, this._syncRepository);

  bool isSourceWritable(String platformType) {
    return platformType == 'wallet';
  }

  SourceType getSourceType(String platformType) {
    switch (platformType) {
      case 'wallet':
        return SourceType.wallet;
      case 'fasten':
        return SourceType.fasten;
      default:
        return SourceType.fasten;
    }
  }

  String getSourceTypeDescription(SourceType type) {
    switch (type) {
      case SourceType.wallet:
        return 'Personal Health Wallet - You can add, edit, and manage data';
      case SourceType.fasten:
        return 'Fasten Health System - Read-only data from your healthcare provider';
      case SourceType.ehr:
        return 'Electronic Health Record - Read-only data from your medical records';
      case SourceType.external:
        return 'External System - Read-only data from external healthcare systems';
    }
  }

  bool canEditSource(Source source) {
    if (isSourceWritable(source.platformType)) {
      return true;
    }
    return true;
  }

  bool canDeleteSource(Source source) {
    return isSourceWritable(source.platformType) && source.id != 'wallet';
  }

  bool canAddDataToSource(Source source) {
    return isSourceWritable(source.platformType);
  }

  Future<Source> ensureWalletSourceForPatient({
    required String patientId,
    String? patientName,
    required List<Source> availableSources,
  }) async {
    if (patientId == 'default_wallet_holder') {
      final genericWallet = availableSources
          .where((s) => s.id == 'wallet' && s.platformType == 'wallet')
          .firstOrNull;

      if (genericWallet != null) {
        return genericWallet;
      }

      await _syncRepository.createWalletSource();

      final updatedSources = await _syncRepository.getSources();
      return updatedSources.firstWhere((s) => s.id == 'wallet');
    }

    final existingWallet = availableSources
        .where(
          (s) => s.platformType == 'wallet' && s.id == 'wallet-$patientId',
        )
        .firstOrNull;

    if (existingWallet != null) {
      return existingWallet;
    }

    final walletSource =
        await _walletPatientService.createWalletSourceForPatient(
      patientId,
      patientName ?? 'Patient $patientId',
    );

    await _syncRepository.cacheSources([walletSource]);

    return walletSource;
  }

  Future<Source> getWritableSourceForPatient({
    required String patientId,
    String? patientName,
    required List<Source> availableSources,
  }) async {
    return await ensureWalletSourceForPatient(
      patientId: patientId,
      patientName: patientName,
      availableSources: availableSources,
    );
  }
}

enum SourceType {
  wallet,
  fasten,
  ehr,
  external,
}
