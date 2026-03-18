import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:health_wallet/features/wallet_pass/data/service/apple_pass_builder.dart';
import 'package:health_wallet/features/wallet_pass/data/service/google_pass_builder.dart';
import 'package:health_wallet/features/wallet_pass/domain/entity/emergency_card_data.dart';
import 'package:health_wallet/features/wallet_pass/domain/repository/wallet_pass_repository.dart';

@Injectable(as: WalletPassRepository)
class WalletPassRepositoryImpl implements WalletPassRepository {
  final ApplePassBuilder _applePassBuilder;
  final GooglePassBuilder _googlePassBuilder;

  WalletPassRepositoryImpl(this._applePassBuilder, this._googlePassBuilder);

  @override
  Future<Uint8List> generateApplePass({
    required EmergencyCardData cardData,
    required String patientId,
  }) async {
    return _applePassBuilder.build(cardData, patientId: patientId);
  }

  @override
  Future<String> generateGooglePassJson({
    required EmergencyCardData cardData,
    required String patientId,
  }) async {
    return _googlePassBuilder.build(cardData, patientId: patientId);
  }
}
