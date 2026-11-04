import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/holders/domain/entity/holder_snapshot.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';

/// The name a source is shown under, the same in the Home chip and the
/// source list.
///
/// A wallet source is named after its person, as they are named now:
/// older versions stored `Wallet - <name>` (in English, and stale once the
/// person was renamed), newer ones store no label. A label the user gave is
/// shown as it is.
String sourceDisplayName(
  AppLocalizations l10n,
  Source source, {
  String? holderName,
}) {
  if (source.id == 'All') return l10n.all;

  final label = source.labelSource ?? '';
  if (_isWallet(source) && (label.isEmpty || label.startsWith(_walletPrefix))) {
    final name =
        holderName ??
        (label.startsWith(_walletPrefix)
            ? label.substring(_walletPrefix.length)
            : '');
    return name.isEmpty || name == SourceTypeService.unknownPatientName
        ? l10n.unknownPatient
        : name;
  }
  if (label.isNotEmpty) return label;
  if (source.platformName?.isNotEmpty ?? false) return source.platformName!;
  // A provider's internal id means nothing to the user.
  return source.id.length > 20 ? l10n.unknownSource : source.id;
}

const _walletPrefix = 'Wallet - ';

bool _isWallet(Source source) =>
    source.id.startsWith(HolderSource.walletPrefix) &&
    source.platformType == 'wallet';
