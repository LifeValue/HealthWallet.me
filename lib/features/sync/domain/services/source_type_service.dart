import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:injectable/injectable.dart';

@injectable
class SourceTypeService {
  const SourceTypeService();

  bool isSourceWritable(String platformType) {
    return platformType == 'wallet';
  }

  /// Stored as the patient name of a wallet source when the patient has no
  /// name. It is synced data, so it stays English; screens show
  /// `l10n.unknownPatient` in its place.
  static const unknownPatientName = 'Unknown Patient';

  /// A provider's source and the demo data can be removed. A wallet source
  /// can't: it holds the person's own Patient row and what they scanned.
  bool canDeleteSource(Source source) =>
      !isSourceWritable(source.platformType) || source.id == 'demo_data';
}
