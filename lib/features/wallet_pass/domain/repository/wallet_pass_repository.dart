import 'dart:typed_data';

import 'package:health_wallet/features/wallet_pass/domain/entity/emergency_card_data.dart';
import 'package:health_wallet/features/wallet_pass/domain/entity/wallet_pass_labels.dart';

enum WalletPassType { apple, google }

abstract class WalletPassRepository {
  Future<Uint8List> generateApplePass({
    required EmergencyCardData cardData,
    required String patientId,
    required WalletPassLabels labels,
  });

  Future<String> generateGooglePassJson({
    required EmergencyCardData cardData,
    required String patientId,
    required WalletPassLabels labels,
  });
}
