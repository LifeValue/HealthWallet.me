import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/utils/wallet_source_identifier.dart';

void main() {
  test('recognises the per-patient sources of scanned documents', () {
    expect(WalletSourceIdentifier.isWalletSource('wallet-pat-1'), isTrue);
    expect(
      WalletSourceIdentifier.isWalletSource('wallet-default_patient'),
      isTrue,
    );
  });

  test('provider and demo sources are not wallet sources', () {
    for (final id in ['demo_data', '3f2a9c1e-provider', 'mywallet-x', '']) {
      expect(WalletSourceIdentifier.isWalletSource(id), isFalse, reason: id);
    }
    expect(WalletSourceIdentifier.isWalletSource(null), isFalse);
  });
}
