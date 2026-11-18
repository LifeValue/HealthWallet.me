/// The sources that hold the records the app reads from scanned and imported
/// documents, one per patient (`wallet-<patient id>`). Nothing else writes
/// records there; provider records come from Fasten sources and the demo
/// records from `demo_data`.
class WalletSourceIdentifier {
  static const String prefix = 'wallet-';

  static bool isWalletSource(String? sourceId) =>
      sourceId?.startsWith(prefix) ?? false;
}
