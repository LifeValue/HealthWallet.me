import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:injectable/injectable.dart';

@injectable
class SourceTypeService {
  const SourceTypeService();

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

  /// Stored as the patient name of a wallet source when the patient has no
  /// name. It is synced data, so it stays English; screens show
  /// `l10n.unknownPatient` in its place.
  static const unknownPatientName = 'Unknown Patient';

  bool canEditSource(Source source) {
    if (isSourceWritable(source.platformType)) {
      return true;
    }
    return true;
  }

  bool canDeleteSource(Source source) {
    return isSourceWritable(source.platformType) && source.id != 'demo_data';
  }

  bool canAddDataToSource(Source source) {
    return isSourceWritable(source.platformType);
  }
}

enum SourceType {
  wallet,
  fasten,
  ehr,
  external,
}
